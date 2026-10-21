extends SceneTree
## Verify runtime/editor south attack selection and capture the actual viewport.
## Run with a graphics context: godot --path . --audio-driver Dummy --script res://tools/capture_south_attack.gd

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var progress = root.get_node("Progress")
	progress.save_path = "user://attack_verification.json"
	progress._defaults()
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.ui.close()
	game.set_physics_process(false)
	game.player.set_physics_process(false)
	game.player.aim = Vector2.DOWN
	game.player.shot_clock = game.player.attack_interval
	game.player._physics_process(0.0)
	if game.player.anim.animation != &"attack_0":
		push_error("South firing did not select attack_0")
		quit(1)
		return
	var live = game.player.anim.sprite_frames.get_frame_texture("attack_0", 0)
	var baked = load("res://assets/animations/host_base.tres").get_frame_texture("attack_0", 0)
	if live.region != Rect2(192, 0, 64, 64) or baked.region != live.region:
		push_error("Runtime and editor attack atlas regions differ")
		quit(1)
		return
	game.camera.zoom = Vector2.ONE * 3.5
	game.camera.position = Vector2.ZERO
	game.camera.position_smoothing_enabled = false
	game.camera.reset_smoothing()
	game.camera.force_update_scroll()
	await create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	var image = root.get_texture().get_image()
	var error = image.save_png("res://artifacts/screenshots/17_host_south_attack.png")
	print("SOUTH_ATTACK_VIEWPORT: ", error, "; runtime and editor use new south attack")
	live = null
	baked = null
	game.queue_free()
	await process_frame
	await process_frame
	quit(0 if error == OK else 1)
