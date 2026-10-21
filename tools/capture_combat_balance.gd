extends SceneTree
## Staged runtime captures of nest packs, guardian warnings and dense waves.
## Requires graphics; uses an isolated save and invulnerability for the captures.
var game: Node2D

func _initialize() -> void:
	call_deferred("_run")

func _view(point: Vector2) -> void:
	game.player.position = point
	game.camera.reset_smoothing()
	game.camera.force_update_scroll()
	await process_frame

func _capture(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png("res://artifacts/screenshots/" + name + ".png")
	if result != OK:
		push_error("COMBAT_CAPTURE_FAILED: " + name)
		quit(1)
	print("COMBAT_CAPTURE: ", name)

func _run() -> void:
	var progress: Node = root.get_node("Progress")
	progress.save_path = "user://combat_balance_capture.json"
	progress._defaults()
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.ui.close()
	await game.start_mission(0)
	game.set_physics_process(false)
	game.player.invulnerable = 9999.0
	game.camera.position_smoothing_enabled = false
	var nests: Array[Node] = get_nodes_in_group("nests")
	await _view(nests[0].position + Vector2(0, 180))
	nests[0].take_damage(99999.0)
	await create_timer(0.35).timeout
	await _capture("18_nest_enemy_pack")
	await _view(nests[1].position + Vector2(-220, 0))
	nests[1].take_damage(99999.0)
	for enemy: Node2D in get_nodes_in_group("enemies"):
		if enemy.kind == "guardian":
			enemy.set_physics_process(false)
			enemy.guardian_sequence = 1
			enemy._start_guardian_attack()
			enemy.telegraph = enemy.windup_duration * 0.5
	await _capture("19_faster_guardian")
	for enemy: Node2D in get_nodes_in_group("enemies"):
		enemy.set_physics_process(true)
	await _view(Vector2(1280, 960))
	game.run_time = 210.0
	game.rng.seed = 1061
	for wave: int in 20:
		for i: int in game.wave_size():
			game._spawn_wave_enemy()
	await create_timer(4.0).timeout
	await _capture("20_growing_horde")
	print("COMBAT_BALANCE_VIEWPORT: enemies=", get_nodes_in_group("enemies").size(), "; fps=", Performance.get_monitor(Performance.TIME_FPS))
	game.queue_free()
	await process_frame
	await process_frame
	quit()
