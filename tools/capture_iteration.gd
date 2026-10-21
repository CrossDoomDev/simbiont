extends SceneTree
## Capture the actual rendered game after the ship/combat iteration.
## Requires an X11/Wayland graphics context; do not use --headless.
## godot --path . --script res://tools/capture_iteration.gd

var game: Node2D
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _capture(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var path := "res://artifacts/screenshots/" + name + ".png"
	if image == null or image.is_empty() or image.save_png(path) != OK:
		push_error("ITERATION_CAPTURE_FAILED: " + path)
		failures += 1
	else:
		print("ITERATION_CAPTURE: " + path)

func _look_at(point: Vector2) -> void:
	game.player.position = point
	game.camera.reset_smoothing()
	game.camera.force_update_scroll()
	await process_frame

func _run() -> void:
	var progress := root.get_node("Progress")
	progress.save_path = "user://symbiont_iteration_capture.json"
	progress._defaults()
	progress.tutorial = true
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.ui.close()
	game.set_physics_process(false)
	game.player.set_physics_process(false)
	game.camera.position_smoothing_enabled = false
	game.player.anim.play("idle_3")
	await _look_at(game.world.spawn_point)
	await create_timer(1.2).timeout
	await _capture("11_ship_heart_hall")
	print("SHIP_VIEWPORT_FPS: ", Performance.get_monitor(Performance.TIME_FPS))
	for organ: Node2D in game.world.organs:
		var id: String = str(organ.get_meta("organ_id"))
		if id == "heart":
			continue
		await _look_at(organ.position + Vector2(0, 145))
		await _capture("12_ship_" + id)
	game.camera.zoom = Vector2.ONE * 0.47
	game.camera.position = Vector2.ZERO
	game.ui.hud.visible = false
	game.ui.set_process(false)
	await _look_at(game.world.bounds.get_center())
	await _capture("13_ship_overview")
	game.ui.set_process(true)
	game.ui.hud.visible = true
	# Verify actual AnimatedSprite playback while the real host moves in physics.
	game.camera.zoom = Vector2.ONE * 2.3
	game.camera.position = Vector2(0, -20)
	for facing: int in range(4):
		game.player.position = game.world.spawn_point
		game.player.move_input = [Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT, Vector2.UP][facing]
		game.player.set_physics_process(true)
		await physics_frame
		await physics_frame
		var first_frame: int = game.player.legs_anim.frame
		var changed: bool = false
		for tick: int in range(20):
			await physics_frame
			if game.player.legs_anim.frame != first_frame:
				changed = true
				break
		if not changed or game.player.legs_anim.animation != "walk_%d" % facing or game.player.legs_anim.flip_h:
			push_error("WALK_VIEWPORT_FAILED: direction " + str(facing))
			failures += 1
		await _capture("16_host_walk_" + ["down", "left", "right", "up"][facing])
		game.player.move_input = Vector2.ZERO
		game.player.set_physics_process(false)
	print("WALK_VIEWPORT_CHECKS: 4 moving directions verified")
	await game.start_mission(0)
	game.player.set_physics_process(false)
	game.camera.position_smoothing_enabled = false
	game.player.position = Vector2(700, 960)
	game.player.anim.play("idle_2")
	var guardian: Node2D = game.spawn_enemy("guardian", Vector2(955, 940))
	guardian.set_physics_process(false)
	guardian.anim.play("attack_1")
	game.camera.force_update_scroll()
	await _capture("14_guardian_encounter")
	for sequence: int in range(3):
		guardian.guardian_sequence = sequence
		guardian._start_guardian_attack()
		guardian.telegraph = guardian.windup_duration * 0.7
		guardian.queue_redraw()
		await _capture("14_guardian_" + ["dash", "fan", "slam"][sequence])
	game.ui.open_settings()
	await _capture("15_audio_settings")
	print("ITERATION_CAPTURES: %d failures" % failures)
	game.queue_free()
	await process_frame
	game = null
	var audio := root.get_node_or_null("Audio")
	if audio != null:
		audio.queue_free()
	await create_timer(0.4).timeout
	quit(0 if failures == 0 else 1)
