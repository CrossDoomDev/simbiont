extends SceneTree
var game: Node2D
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func settle() -> void:
	for i: int in 16:
		await process_frame

func hover(control: Control) -> void:
	await settle()
	var event := InputEventMouseMotion.new()
	event.position = control.get_global_rect().get_center()
	event.global_position = event.position
	root.warp_mouse(event.position)
	root.push_input(event,true)
	await settle()
	if not control.is_hovered():
		failures += 1
		push_error("Capture did not hover target button")

func capture(name: String) -> void:
	await settle()
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png("res://artifacts/screenshots/26_"+name+".png")
	if result != OK:
		failures += 1
	print("POSE_HOVER_CAPTURE: ",name," result=",result)

func _run() -> void:
	root.size = Vector2i(1280,720)
	var progress: Node = root.get_node("Progress")
	progress.save_path = "user://symbiont_pose_hover_capture.json"
	progress._defaults()
	progress.tutorial = true
	progress.settings["touch"] = false
	progress.settings["autofire"] = false
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await settle()
	game.set_physics_process(false)
	game.player.set_physics_process(false)
	game.ui.close()
	await hover(game.ui.toolbar_button)
	await capture("menu_hover")
	game.ui.open_pause()
	await settle()
	var close: Button = game.ui.overlay_header.get_child(1)
	await hover(close)
	await capture("close_hover")
	var click := InputEventMouseButton.new()
	click.position = close.get_global_rect().get_center()
	click.global_position = click.position
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	root.push_input(click,true)
	await capture("close_pressed")
	click.position = Vector2.ZERO
	click.global_position = Vector2.ZERO
	click.pressed = false
	root.push_input(click,true)
	game.ui.close()
	await game.start_mission(0)
	game.set_physics_process(false)
	game.player.set_physics_process(false)
	for enemy: Node in get_nodes_in_group("enemies"):
		enemy.queue_free()
	game.camera.position_smoothing_enabled = false
	game.camera.zoom = Vector2.ONE * 2.0
	game.camera.reset_smoothing()
	game.camera.force_update_scroll()
	game.player.manual_aim = Vector2.RIGHT
	game.player.manual_fire = true
	game.player._physics_process(0.01)
	await capture("shot_start")
	game.player.manual_fire = false
	game.player._physics_process(0.45)
	await capture("shot_hold")
	game.player._physics_process(0.56)
	await capture("shot_relaxed")
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
	print("POSE_HOVER_CAPTURES: %d failures" % failures)
	quit(1 if failures > 0 else 0)
