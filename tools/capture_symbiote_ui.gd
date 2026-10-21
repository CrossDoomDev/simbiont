extends SceneTree
## Real viewport captures of the responsive theme and all three swamp bosses.
var game: Node2D
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _settle() -> void:
	for i: int in 16:
		await process_frame

func _capture(name: String) -> void:
	await _settle()
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png("res://artifacts/screenshots/" + name + ".png")
	if result != OK:
		failures += 1
	print("SYMBIOTE_UI_CAPTURE: ", name, " result=", result)

func _run() -> void:
	var progress: Node = root.get_node("Progress")
	progress.save_path = "user://symbiont_theme_capture.json"
	progress._defaults()
	progress.modules["heart"] = 2
	progress.bank = [120,40,50,3]
	progress.settings["autofire"] = false
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await _settle()
	game.set_physics_process(false)
	game.player.set_physics_process(false)
	await _capture("22_symbiote_title")
	game.ui.open_map()
	await _capture("22_neural_map")
	game.ui.open_upgrades(false)
	await _capture("22_symbiote_upgrades")
	root.size = Vector2i(640,960)
	await _settle()
	await _capture("22_upgrades_portrait")
	root.size = Vector2i(640,360)
	game.ui.open_settings()
	await _capture("22_settings_compact")
	game.ui.close()
	progress.settings["touch"] = true
	await _capture("22_touch_compact")
	progress.settings["touch"] = false
	root.size = Vector2i(1920,1080)
	await _capture("22_hud_wide")
	root.size = Vector2i(1280,720)
	game.ui.close()
	await game.start_mission(1)
	game.set_physics_process(false)
	game.player.set_physics_process(false)
	game.player.invulnerable = 9999.0
	for enemy: Node in get_nodes_in_group("enemies"):
		enemy.queue_free()
	await process_frame
	for nest: Node in get_nodes_in_group("nests"):
		nest.take_damage(99999.0)
	for boss: Node2D in get_nodes_in_group("enemies"):
		boss.set_physics_process(false)
	game.player.position = Vector2(1280,960)
	game.camera.position = Vector2.ZERO
	game.camera.zoom = Vector2.ONE * 0.4
	game.camera.position_smoothing_enabled = false
	game.camera.reset_smoothing()
	game.camera.force_update_scroll()
	game.ui.toast_time = 0.0
	await _capture("22_three_swamp_guardians")
	# Release queued audio voices before closing the graphics verification run.
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
	await process_frame
	await process_frame
	print("SYMBIOTE_UI_CAPTURES: %d failures" % failures)
	quit(1 if failures > 0 else 0)
