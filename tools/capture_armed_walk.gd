extends SceneTree
## Real GL viewport verification of the firing-torso/walking-legs composition.
var game: Node2D
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("ARMED_WALK_RENDER_FAILED: "+message)

func settle() -> void:
	for i: int in 10:
		await process_frame

func capture(name: String) -> void:
	await settle()
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://artifacts/screenshots/27_armed_walk_"+name+".png") == OK,"save "+name)

func verify_pixels(direction: int) -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(64,64)
	viewport.transparent_bg = true
	viewport.world_2d = World2D.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var sprite := Sprite2D.new()
	sprite.position = Vector2(32,32)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.material = game.player.armed_walk_material
	viewport.add_child(sprite)
	var samples: Array[Image] = []
	for phase: int in 2:
		sprite.texture = game.player.anim.sprite_frames.get_frame_texture("walk_%d" % direction,phase)
		await settle()
		await RenderingServer.frame_post_draw
		samples.append(viewport.get_texture().get_image())
	var changed_legs := 0
	var changed_upper := 0
	for y: int in 64:
		for x: int in 64:
			if samples[0].get_pixel(x,y) != samples[1].get_pixel(x,y):
				if y < 40:
					changed_upper += 1
				else:
					changed_legs += 1
	check(changed_upper == 0,"firing torso and raised arm remain identical between steps, direction %d" % direction)
	check(changed_legs > 8,"rendered leg pixels change between steps, direction %d (%d pixels)" % [direction,changed_legs])
	viewport.queue_free()
	await process_frame

func _run() -> void:
	root.size = Vector2i(1280,720)
	var progress: Node = root.get_node("Progress")
	progress.save_path = "user://symbiont_armed_walk_capture.json"
	progress._defaults()
	progress.tutorial = true
	progress.settings["touch"] = false
	progress.settings["autofire"] = false
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await settle()
	game.ui.close()
	await game.start_mission(0)
	game.set_physics_process(false)
	for enemy: Node in get_nodes_in_group("enemies"):
		enemy.queue_free()
	game.player.invulnerable = 99999.0
	game.camera.position_smoothing_enabled = false
	game.camera.zoom = Vector2.ONE * 3.5
	game.ui.toast_time = 0
	for direction: int in 4:
		var facing: Vector2 = [Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT,Vector2.UP][direction]
		game.player.position = Vector2(1280,960)
		game.player.manual_aim = facing
		game.player.move_input = facing
		game.player.manual_fire = true
		game.player.shot_clock = 0
		game.player.set_physics_process(true)
		await physics_frame
		await physics_frame
		var first_frame: int = game.player.anim.frame
		var changed := false
		for tick: int in 16:
			await physics_frame
			if game.player.anim.frame != first_frame:
				changed = true
				break
		check(changed and game.player.armed_walk and game.player.anim.animation == "walk_%d" % direction,"native steps advance while shooting, direction %d" % direction)
		game.player.set_physics_process(false)
		game.player.anim.pause()
		game.player.anim.position = Vector2.ZERO
		game.camera.reset_smoothing()
		game.camera.force_update_scroll()
		await verify_pixels(direction)
		for phase: int in 2:
			game.player.anim.frame = phase
			await capture(["down","left","right","up"][direction]+"_%d" % phase)
		game.player.manual_fire = false
		game.player.move_input = Vector2.ZERO
		game.player._physics_process(0.01)
		check(game.player.anim.animation == "attack_%d" % direction and not game.player.armed_walk,"stopping restores stationary raised arm, direction %d" % direction)
	var audio: Node = root.get_node("Audio")
	for player: AudioStreamPlayer in audio._music_players + audio._effects_players:
		player.stop()
		player.stream = null
	if audio._ambient != null:
		audio._ambient.stop()
		audio._ambient.stream = null
	audio._cache.clear()
	await create_timer(0.2).timeout
	game.queue_free()
	await settle()
	print("ARMED_WALK_RENDER_CHECKS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures > 0 else 0)
