extends SceneTree
## Generated art must animate inside the real game viewport, not a concept sheet.
var game: Node2D
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("SKILLS_RENDER_FAILED: "+message)

func settle(count: int = 6) -> void:
	for i: int in count:
		await process_frame

func capture(name: String) -> void:
	await settle()
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://artifacts/screenshots/30_"+name+".png") == OK,"save "+name)

func clear_effects() -> void:
	for effect: Node in get_nodes_in_group("skill_effects"):
		effect.queue_free()
	game.skills.reset()
	game.skills.energy = 100
	await settle(2)

func _run() -> void:
	root.size = Vector2i(1280,720)
	var progress: Node = root.get_node("Progress")
	progress.save_path = "user://symbiont_skills_capture.json"
	progress._defaults()
	progress.settings["touch"] = false
	progress.settings["autofire"] = false
	progress.tutorial = true
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await settle()
	game.ui.close()
	await game.start_mission(0)
	game.set_physics_process(false)
	game.skills.set_physics_process(false)
	game.player.set_physics_process(false)
	game.player.position = Vector2(1280,960)
	game.player.invulnerable = 99999
	game.camera.position_smoothing_enabled = false
	game.camera.zoom = Vector2.ONE*1.15
	game.camera.reset_smoothing()
	game.camera.force_update_scroll()
	game.ui.toast_time = 0
	for enemy: Node in get_nodes_in_group("enemies"):
		enemy.queue_free()
	await settle(2)
	for offset: Vector2 in [Vector2(-80,-20),Vector2(40,80),Vector2(140,-35),Vector2(-120,95)]:
		var enemy: Node2D = game.spawn_enemy("shell",game.player.position+offset)
		enemy.set_physics_process(false)
		enemy.hp = 1000
		enemy.max_hp = 1000
	game.skills.energy = 48
	await capture("skills_hud")
	var origin: Vector2 = game.player.position
	var names := ["neural_wave","spore_cloud","chitin_shield","predatory_dash","synaptic_rupture"]
	for index: int in 5:
		await clear_effects()
		game.player.position = origin
		game.camera.reset_smoothing()
		game.camera.force_update_scroll()
		check(game.skills.cast(index,origin+Vector2(150,-25)),"cast "+names[index])
		var effect: BioSkillEffect
		for node: BioSkillEffect in get_nodes_in_group("skill_effects"):
			effect = node
		var initial_frame: int = effect.sprite.frame
		await create_timer(0.15).timeout
		check(effect.sprite.frame != initial_frame,"generated frames advance for "+names[index])
		# After proving playback, fix the peak for comparable readable screenshots.
		effect.set_physics_process(false)
		effect.sprite.pause()
		effect.sprite.frame = 2
		effect.modulate.a = 1.0
		await capture(names[index])
		if index == 1:
			effect.set_physics_process(true)
			var age: float = effect.age
			game.ui.open_pause()
			await create_timer(0.15).timeout
			check(is_equal_approx(effect.age,age),"pause freezes persistent spore effect")
			game.ui.close()
	await clear_effects()
	game.player.position = origin
	root.size = Vector2i(640,360)
	await capture("skills_compact")
	progress.settings["touch"] = true
	await capture("skills_touch")
	root.size = Vector2i(640,960)
	await capture("skills_portrait")
	progress.settings["touch"] = false
	root.size = Vector2i(1920,1080)
	await capture("skills_wide")
	var audio: Node = root.get_node("Audio")
	for voice: AudioStreamPlayer in audio._music_players+audio._effects_players:
		voice.stop()
		voice.stream = null
	if audio._ambient != null:
		audio._ambient.stop()
		audio._ambient.stream = null
	audio._cache.clear()
	await create_timer(0.2).timeout
	game.queue_free()
	await settle()
	print("SKILLS_RENDER_CHECKS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures > 0 else 0)
