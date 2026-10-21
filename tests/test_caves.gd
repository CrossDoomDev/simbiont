extends SceneTree
## Actual scene bindings, clear cave exits and physical emergence on both maps.
var game: Node2D
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("CAVE_CHECK_FAILED: " + message)

func _clear() -> void:
	for enemy: Node in get_nodes_in_group("enemies"):
		enemy.queue_free()
	for shot: Node in get_nodes_in_group("projectiles"):
		shot.queue_free()
	await physics_frame
	await process_frame

func _run() -> void:
	var progress: Node = root.get_node("Progress")
	progress.save_path = "user://symbiont_cave_test.json"
	progress._defaults()
	progress.modules["heart"] = 2
	progress.settings["autofire"] = false
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.ui.close()
	check(game.world.caves.is_empty(), "the ship never gains enemy cave entrances")
	for biome: int in 2:
		await game.start_mission(biome)
		game.set_physics_process(false)
		game.player.set_physics_process(false)
		game.player.invulnerable = 9999.0
		await _clear()
		check(game.world.caves.size() == 12, "both baked maps restore twelve cave entrances")
		for cave: Node2D in game.world.caves:
			var mouth: Vector2 = cave.get_node("Mouth").global_position
			var exit_point: Vector2 = cave.get_node("Exit").global_position
			check(cave.get_node("RockEntrance").texture != null, "cave art survives scene serialization")
			check(game.world.is_walkable(mouth, 35) and game.world.is_walkable(exit_point, 35), "mouth and exit accommodate the widest normal enemy")
			var ray := PhysicsRayQueryParameters2D.create(mouth, exit_point, 1)
			check(game.get_world_2d().direct_space_state.intersect_ray(ray).is_empty(), "cave approach is clear of real wall and prop collisions")
		# Exercise actual wave selection and real emergence on every wall.
		for side: int in 4:
			var target: Node2D = game.world.caves[side * 3 + 1]
			var inward: Vector2 = target.get_meta("inward")
			game.player.position = target.position + inward * 240.0
			game.rng.seed = 7000 + biome * 100 + side
			var selected: Node2D
			for attempt: int in 50:
				await _clear()
				game._spawn_wave_enemy()
				for enemy: Node2D in get_nodes_in_group("enemies"):
					if enemy.get_meta("source_cave", NodePath()) == target.get_path():
						selected = enemy
				if selected != null:
					break
			check(selected != null, "a visible cave on each wall can release a real wave enemy")
			if selected == null:
				continue
			var start: Vector2 = selected.position
			check(start.distance_to(target.get_node("Mouth").global_position) <= 31.0 and selected.emergence_remaining > 0.0, "wave starts inside its marked cave mouth rather than beside the player")
			game.ui.open_pause()
			var paused: float = selected.emergence_remaining
			await create_timer(0.1).timeout
			check(selected.position == start and selected.emergence_remaining == paused, "pausing also freezes emergence")
			game.ui.close()
			await create_timer(0.8).timeout
			check((selected.position - start).dot(inward) > 50.0 and selected.modulate.a == 1.0 and selected.emergence_remaining == 0.0, "enemy visibly walks into the room through physical space before pursuing")
		await _clear()
		game.player.position = Vector2(150, 150)
		for attempt: int in 10:
			game._spawn_wave_enemy()
		for enemy: Node2D in get_nodes_in_group("enemies"):
			check(enemy.has_meta("source_cave") and game.world.is_walkable(enemy.position, enemy.radius + 6.0), "corner pressure still spawns exclusively at clear cave mouths")
	game.queue_free()
	await process_frame
	await process_frame
	print("CAVE_TESTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
