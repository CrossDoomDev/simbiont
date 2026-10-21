extends SceneTree
## Actual rendered cave emergence; staged camera, isolated save, no player damage.
var game: Node2D
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _clear() -> void:
	for enemy: Node in get_nodes_in_group("enemies"):
		enemy.queue_free()
	await physics_frame
	await process_frame

func _capture(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png("res://artifacts/screenshots/" + name + ".png")
	if result != OK:
		failures += 1
	print("CAVE_CAPTURE: ", name, " result=", result)

func _run() -> void:
	var progress: Node = root.get_node("Progress")
	progress.save_path = "user://symbiont_cave_capture.json"
	progress._defaults()
	progress.modules["heart"] = 2
	progress.settings["autofire"] = false
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.ui.close()
	for biome: int in 2:
		await game.start_mission(biome)
		game.set_physics_process(false)
		game.player.invulnerable = 9999.0
		game.camera.position_smoothing_enabled = false
		game.camera.zoom = Vector2.ONE * 1.35
		game.ui.toast_time = 0.0
		for side: int in ([0, 3] if biome == 0 else [1, 2]):
			var target: Node2D = game.world.caves[side * 3 + 1]
			var inward: Vector2 = target.get_meta("inward")
			game.player.position = target.position + inward * 220.0
			game.camera.position = -inward * 90.0
			game.camera.reset_smoothing()
			game.camera.force_update_scroll()
			game.rng.seed = 4520 + biome * 100 + side
			var selected: Node2D
			for attempt: int in 50:
				await _clear()
				game._spawn_wave_enemy()
				for enemy: Node2D in get_nodes_in_group("enemies"):
					if enemy.get_meta("source_cave", NodePath()) == target.get_path():
						selected = enemy
				if selected != null:
					break
			if selected == null:
				failures += 1
				continue
			await create_timer(0.6).timeout
			await _capture("21_cave_%s_%s" % [["forest", "swamp"][biome], ["north", "east", "south", "west"][side]])
	game.queue_free()
	await process_frame
	await process_frame
	print("CAVE_CAPTURES: %d failures" % failures)
	quit(1 if failures > 0 else 0)
