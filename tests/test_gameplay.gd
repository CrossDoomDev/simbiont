extends SceneTree
## Integration checks against real scenes, physics, UI button callbacks and saves.
## godot --headless --path . --script res://tests/test_gameplay.gd

var checks: int = 0
var failures: int = 0
var game: Node2D
var progress: Node
var scratch_path: String = "user://symbiont_gameplay_test.json"

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("GAMEPLAY_CHECK_FAILED: " + message)

func _frames(count: int = 2) -> void:
	for i: int in range(count):
		await physics_frame
		await process_frame

func _seconds(duration: float) -> void:
	await create_timer(duration).timeout

func _wait_for(predicate: Callable, timeout: float = 4.0) -> bool:
	var deadline: int = Time.get_ticks_msec() + int(timeout * 1000.0)
	while not bool(predicate.call()) and Time.get_ticks_msec() < deadline:
		await process_frame
	return bool(predicate.call())

func _buttons(node: Node, text: String, prefix: bool = false) -> Array[Button]:
	var result: Array[Button] = []
	if node is Button:
		var button: Button = node as Button
		if (button.text.begins_with(text) if prefix else button.text == text):
			result.append(button)
	for child: Node in node.get_children():
		result.append_array(_buttons(child, text, prefix))
	return result

func _click(text: String, index: int = 0, prefix: bool = false) -> bool:
	var matches: Array[Button] = _buttons(game.ui.modal_root, text, prefix)
	if index >= matches.size() or matches[index].disabled:
		check(false, "enabled UI button exists: " + text)
		return false
	matches[index].pressed.emit()
	return true

func _find_label(node: Node, text: String) -> Label:
	if node is Label and (node as Label).text == text:
		return node as Label
	for child: Node in node.get_children():
		var found: Label = _find_label(child, text)
		if found != null:
			return found
	return null

func _buy_card(name: String) -> bool:
	var label: Label = _find_label(game.ui.modal_root, name)
	if label == null:
		check(false, "upgrade card exists: " + name)
		return false
	var parent: Node = label.get_parent()
	while parent != null and not parent is PanelContainer:
		parent = parent.get_parent()
	var matches: Array[Button] = _buttons(parent, "Развить", true) if parent != null else []
	if matches.is_empty() or matches[0].disabled:
		check(false, "upgrade card can be bought: " + name)
		return false
	matches[0].pressed.emit()
	return true

func _clear(group: String) -> void:
	for node: Node in get_nodes_in_group(group):
		node.set_physics_process(false)
		node.queue_free()

func _scratch_cleanup() -> void:
	for suffix: String in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(scratch_path + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(scratch_path + suffix))

func _launch(index: int = 0) -> void:
	game.ui.open_map()
	check(_click("Начать миссию", index, true), "map launch callback fires")
	check(await _wait_for(func() -> bool: return game.mode == "mission" and not game.transitioning), "mission transition completes")
	game.set_physics_process(false)
	progress.settings["autofire"] = false
	_clear("enemies")
	_clear("projectiles")
	await _frames()

func _extract() -> void:
	game.ui.open_pause()
	var finishes: Array[Button] = _buttons(game.ui.modal_root, "Завершить миссию")
	check(finishes.size() == 1 and not finishes[0].disabled, "completed mission enables return button")
	_click("Завершить миссию")
	check(game.ui.page == "confirm_finish" and game.mode == "mission", "return requires explicit confirmation")
	var confirms: Array[Button] = _buttons(game.ui.modal_root, "Завершить миссию и вернуться")
	if not confirms.is_empty():
		# Two callbacks in one frame must commit one extraction.
		confirms[0].pressed.emit()
		confirms[0].pressed.emit()
	check(await _wait_for(func() -> bool: return game.mode == "ship" and game.ui.page == "results" and not game.transitioning), "confirmed extraction reaches ship results")

func _pressure_and_range_checks() -> void:
	_clear("enemies")
	_clear("projectiles")
	await _frames()
	# Find an unobstructed firing lane so range, rather than scenery, stops shots.
	var lane := Vector2.ZERO
	for y: int in range(300, 1600, 120):
		for x: int in range(300, 1800, 120):
			var start := Vector2(x, y)
			var end := start + Vector2(500, 0)
			if game.world.is_walkable(start, 30) and game.world.is_walkable(end, 30):
				var ray := PhysicsRayQueryParameters2D.create(start, end, 1)
				if game.get_world_2d().direct_space_state.intersect_ray(ray).is_empty():
					lane = start
					break
		if lane != Vector2.ZERO:
			break
	check(lane != Vector2.ZERO, "a clear lane exists for physical range checks")
	game.player.position = lane
	var close_enemy: Node2D = game.spawn_enemy("shell", lane + Vector2(290, 0))
	close_enemy.set_physics_process(false)
	await _frames()
	game.fire(game.player, Vector2.RIGHT, false)
	await _seconds(0.65)
	check(close_enemy.hp < close_enemy.max_hp, "a shot still damages a target inside the shorter range")
	_clear("enemies")
	_clear("projectiles")
	await _frames()
	var far_enemy: Node2D = game.spawn_enemy("shell", lane + Vector2(440, 0))
	far_enemy.set_physics_process(false)
	await _frames()
	game.fire(game.player, Vector2.RIGHT, false)
	var bullet: Node2D = get_nodes_in_group("projectiles")[0] as Node2D
	bullet.set_physics_process(false)
	var muzzle: Vector2 = bullet.position
	bullet._physics_process(1.0)
	check(bullet.position.distance_to(muzzle) <= 343.76 and bullet.is_queued_for_deletion(), "a long frame cannot carry a player shot past half its former 687.5px range")
	check(far_enemy.hp == far_enemy.max_hp, "a target beyond range receives no damage even during a long frame")
	_clear("enemies")
	await _frames()
	game.rng.seed = 4137
	game.player.position = Vector2(1280, 960)
	game.run_time = 0.0
	game.spawn_clock = 0.0
	game._physics_process(0.0)
	var early_count: int = get_nodes_in_group("enemies").size()
	var early_interval: float = game.spawn_clock
	check(early_count >= 3, "an early wave brings a group instead of one isolated enemy")
	_clear("enemies")
	await _frames()
	game.run_time = 210.0
	game.spawn_clock = 0.0
	game._physics_process(0.0)
	check(get_nodes_in_group("enemies").size() > early_count and game.spawn_clock < early_interval, "late waves produce more enemies at shorter intervals")
	check(game.wave_interval() >= 0.65 and game.wave_size() <= 10, "wave escalation has bounded density and timing")
	_clear("enemies")
	await _frames()
	# Reserve slots keep ordinary waves from consuming the nest population budget.
	for i: int in GameData.MAX_ENEMIES - 1:
		var enemy: Node2D = game.spawn_enemy("crawler", Vector2(2100, 1500))
		enemy.set_physics_process(false)
	var capped_count: int = get_nodes_in_group("enemies").size()
	game._spawn_wave_enemy()
	check(get_nodes_in_group("enemies").size() == capped_count, "ordinary waves respect reserved pack and boss slots")
	game.pending_nest_enemies.append({"origin": game.player.position, "kind": "crawler"})
	game._release_nest_enemies()
	check(game.pending_nest_enemies.size() == 1, "a full population queues the nest enemy instead of losing it")
	get_nodes_in_group("enemies")[0].queue_free()
	await _frames()
	game._release_nest_enemies()
	check(game.pending_nest_enemies.is_empty() and get_nodes_in_group("enemies").size() == capped_count, "a queued nest enemy spawns as soon as room becomes available")
	_clear("enemies")
	_clear("projectiles")
	await _frames()
	game.run_time = 0.0
	game.spawn_clock = 1.0
	game.player.position = game.world.spawn_point

func _run() -> void:
	progress = root.get_node("Progress")
	var original_path: String = progress.save_path
	var original_document: Dictionary = progress.call("_document")
	_scratch_cleanup()
	progress.save_path = scratch_path
	progress.reset_progress()
	progress.settings["autofire"] = false
	progress.settings["touch"] = false
	var main_scene: PackedScene = load("res://scenes/main.tscn") as PackedScene
	game = main_scene.instantiate() as Node2D
	root.add_child(game)
	await _frames()
	game.set_physics_process(false)
	check(game.ui.page == "title" and game.modal, "fresh startup opens title and freezes world")
	_click("Установить связь")
	check(game.ui.page == "tutorial", "first launch opens tutorial")
	_click("Я слышу тебя")
	check(progress.tutorial and not game.modal, "tutorial callback saves completion and releases control")
	check(game.world.organs.size() == 5, "ship has all five organic interactions")
	check(game.world.floor_map is TileMapLayer and game.world.walls is TileMapLayer, "ship uses native tilemap layers")
	check(game.player.anim is AnimatedSprite2D and game.player.anim.sprite_frames.get_frame_count("walk_0") == 2, "host uses native two-frame walk animation")
	await _frames()
	var start: Vector2 = game.player.position
	game.player.move_input = Vector2.RIGHT
	await _seconds(0.2)
	check(game.player.position.distance_to(start) > 20.0, "host moves through ship with real physics ticks (distance %.2f)" % game.player.position.distance_to(start))
	game.player.move_input = Vector2.ZERO
	game.player.position = Vector2(1024, 380)
	game.player.move_input = Vector2.UP
	await _seconds(0.8)
	check(game.player.position.y > 300.0 and game.player.position.y < 370.0, "native wall collision stops host at the heart hall membrane")
	game.player.move_input = Vector2.ZERO
	var expected_pages: Dictionary = {"navigation": "map", "symbiont": "upgrades", "heart": "heart", "feeding": "modules", "storage": "storage"}
	for organ: Node2D in game.world.organs:
		var id: String = str(organ.get_meta("organ_id"))
		game.player.position = organ.position + Vector2(0, 100)
		game.near_organ = organ
		game.interact()
		check(game.ui.page == expected_pages[id] and game.modal, id + " opens correct UI through interaction")
		check(game.world.process_mode == Node.PROCESS_MODE_DISABLED, id + " freezes world while open")
		_click("×")
		check(not game.modal and game.ui.page == "", id + " close callback restores control")
	game.ui.open_map()
	var locked: Array[Button] = _buttons(game.ui.modal_root, "Закрыто", true)
	check(locked.size() == 1 and locked[0].disabled and not progress.mission_unlocked(1), "second biome displays its heart II lock")
	game.ui.close()
	progress.bank = [100, 20, 20, 2]
	game.ui.open_upgrades(false)
	_buy_card("Регенеративная ткань")
	check(progress.upgrades.regeneration == 1 and progress.bank[0] == 88, "real upgrade button atomically buys correct branch")
	check(game.player.max_hp == 115.0, "purchased upgrade refreshes host stats")
	game.ui.close()
	await _launch()
	check(game.world.nest_positions.size() == 3 and get_nodes_in_group("nests").size() == 3, "mission spawns exactly three mandatory objectives")
	check(not game.objective_complete(), "mission starts incomplete")
	game.ui.open_pause()
	var unavailable: Array[Button] = _buttons(game.ui.modal_root, "Завершить миссию")
	check(unavailable.size() == 1 and unavailable[0].disabled, "return button is disabled before objective")
	var before_blocked: Array = progress.bank.duplicate()
	await game.finish_mission(true)
	check(game.mode == "mission" and progress.bank == before_blocked and not game.transitioning, "direct premature return cannot credit loot")
	_click("Продолжить")
	var nest: Node2D = get_nodes_in_group("nests")[0] as Node2D
	game.player.position = nest.position - Vector2(130, 0)
	await _frames()
	check(game.nearest_enemy(game.player.position, 300.0) == nest, "auto-targeting sees a solid nest through its own collision")
	game.player.move_input = Vector2.RIGHT
	await _seconds(0.6)
	check(game.player.position.distance_to(nest.position) >= 53.0, "nest physically blocks host at its visible body")
	game.player.move_input = Vector2.ZERO
	game.player.position = game.world.spawn_point
	var target: Node2D = game.spawn_enemy("crawler", game.player.position + Vector2(140, 0))
	target.set_physics_process(false)
	await _frames()
	var enemy_health: float = target.hp
	game.fire(game.player, Vector2.RIGHT, false)
	await _seconds(0.35)
	check(target.hp < enemy_health, "bioimpulse ray actually damages enemy")
	target.take_damage(9999.0)
	await _frames()
	var drops: Array[Node] = get_nodes_in_group("loot")
	check(not drops.is_empty(), "enemy death physically drops loot")
	if not drops.is_empty():
		game.player.position = (drops[0] as Node2D).position
	await _seconds(0.35)
	check(game.run_loot[0] >= 3, "magnetic pickup transfers physical biomass into run inventory")
	_clear("loot")
	game.player.position = game.world.spawn_point
	var shooter: Node2D = game.spawn_enemy("ranged", game.player.position + Vector2(160, 0))
	shooter.set_physics_process(false)
	await _frames()
	game.player.invulnerable = 0.0
	var host_health: float = game.player.hp
	game.fire(shooter, Vector2.LEFT, true)
	await _seconds(1.25)
	check(game.player.hp < host_health - 5.0, "hostile projectile mask damages host")
	_clear("enemies")
	_clear("projectiles")
	await _frames()
	# Resources cannot interrupt a mission or buy ship upgrades in the field.
	var before_collect: int = game.run_loot[0]
	game.collect(0, 200)
	game.set_physics_process(true)
	await _frames(3)
	check(game.run_loot[0] == before_collect + 200 and not game.modal and game.ui.page == "", "collecting resources never opens a three-choice upgrade panel")
	game.ui.open_upgrades(false)
	check(not game.modal and game.ui.page == "", "host upgrades can only be opened aboard the ship")
	game.ui.open_upgrades(true)
	check(not game.modal and game.ui.page == "", "ship restoration cannot be opened in combat")
	game.set_physics_process(false)
	await _pressure_and_range_checks()
	# A pause must freeze host, enemy, projectile and elapsed mission time together.
	var paused_enemy: Node2D = game.spawn_enemy("crawler", game.player.position + Vector2(170, 0))
	game.fire(paused_enemy, Vector2.UP, true)
	await _frames()
	game.ui.open_pause()
	game.set_physics_process(true)
	var paused_player_position: Vector2 = game.player.position
	var paused_enemy_position: Vector2 = paused_enemy.position
	var paused_time: float = game.run_time
	var paused_spawn_clock: float = game.spawn_clock
	var projectile: Node2D = get_nodes_in_group("projectiles")[0] as Node2D
	var paused_projectile_position: Vector2 = projectile.position
	var paused_projectile_life: float = projectile.life
	await _seconds(0.25)
	check(game.player.position == paused_player_position and paused_enemy.position == paused_enemy_position, "pause freezes all actors")
	check(projectile.position == paused_projectile_position and is_equal_approx(projectile.life, paused_projectile_life), "pause freezes projectile movement and lifetime")
	check(is_equal_approx(game.run_time, paused_time) and is_equal_approx(game.spawn_clock, paused_spawn_clock), "pause freezes mission and spawn clocks")
	_click("Продолжить")
	game.set_physics_process(false)
	_clear("enemies")
	_clear("projectiles")
	await _frames()
	# Kill real mission objectives and return through both confirmation callbacks.
	for objective: Node in get_nodes_in_group("nests"):
		var enemies_before: int = get_nodes_in_group("enemies").size() + game.pending_nest_enemies.size()
		objective.take_damage(9999.0)
		var released: int = get_nodes_in_group("enemies").size() + game.pending_nest_enemies.size() - enemies_before
		check(released == (1 if game.nodes_destroyed == 2 else 9 + game.mission_id * 3), "destroyed nest releases exactly one boss or a full ordinary pack")
	check(game.nodes_destroyed == 3 and game.objective_complete(), "three destroyed nests complete first mission")
	check(game.mode == "mission" and game.ui.page == "", "completed objective leaves mission running")
	check(game.boss_spawned and not game.boss_defeated, "second nest awakens optional first-biome guardian")
	game.run_loot = [10, 4, 3, 1]
	var success_id: String = game.run_id
	var success_before: Array = progress.bank.duplicate()
	await _extract()
	check(progress.bank == [success_before[0] + 10, success_before[1] + 4, success_before[2] + 3, success_before[3] + 1], "double return callback credits successful loot exactly once")
	check(progress.completed == 1 and game.pending_nest_enemies.is_empty(), "success persists completion and clears pending nest packs")
	check(not progress.deposit_run([99, 99, 99, 99], true, success_id), "completed run cannot be deposited again")
	_click("Почувствовать корабль")
	await _launch()
	game.run_loot = [11, 7, 5, 3]
	var death_id: String = game.run_id
	var death_before: Array = progress.bank.duplicate()
	game.player.invulnerable = 0.0
	game.player.take_damage(99999.0)
	check(game.ui.page == "death" and game.modal and game.player.dead, "lethal damage opens frozen death return screen")
	var death_returns: Array[Button] = _buttons(game.ui.modal_root, "Вернуться на корабль")
	if not death_returns.is_empty():
		death_returns[0].pressed.emit()
		death_returns[0].pressed.emit()
	check(await _wait_for(func() -> bool: return game.mode == "ship" and game.ui.page == "results" and not game.transitioning), "death return callback restores host in ship")
	check(progress.bank == [death_before[0] + 5, death_before[1] + 3, death_before[2] + 2, death_before[3] + 1], "death retains floor of half loot exactly once")
	check(progress.completed == 1 and not progress.deposit_run([11, 7, 5, 3], false, death_id), "death cannot increase completion or deposit twice")
	check(not game.player.dead and game.player.hp == game.player.max_hp, "ship restores host health after death")
	_click("Почувствовать корабль")
	progress.bank = [200, 30, 50, 3]
	game.ui.open_upgrades(true)
	_buy_card("Энергетическое сердце")
	check(progress.modules.heart == 1 and not progress.mission_unlocked(1), "heart I preserves second-biome lock")
	_buy_card("Энергетическое сердце")
	check(progress.modules.heart == 2 and progress.mission_unlocked(1), "heart II UI purchase unlocks second biome")
	game.ui.close()
	await _launch(1)
	check(game.mission_id == 1, "second unlocked map button launches correct biome")
	for objective: Node in get_nodes_in_group("nests"):
		var enemies_before: int = get_nodes_in_group("enemies").size() + game.pending_nest_enemies.size()
		objective.take_damage(9999.0)
		var released: int = get_nodes_in_group("enemies").size() + game.pending_nest_enemies.size() - enemies_before
		check(released == (1 if game.nodes_destroyed == 2 else 9 + game.mission_id * 3), "destroyed nest releases exactly one boss or a full ordinary pack")
	check(game.nodes_destroyed == 3 and not game.objective_complete(), "second biome still requires guardian after three nodes")
	game.ui.open_pause()
	unavailable = _buttons(game.ui.modal_root, "Завершить миссию")
	check(unavailable.size() == 1 and unavailable[0].disabled, "second-biome return remains locked while guardian lives")
	game.ui.close()
	for guardian: Node in get_nodes_in_group("enemies"):
		if str(guardian.kind) == "guardian":
			guardian.take_damage(99999.0)
	check(game.boss_defeated and game.objective_complete(), "guardian death completes second-biome objective")
	var core_dropped: bool = false
	for drop: Node in get_nodes_in_group("loot"):
		if int(drop.resource_type) == 3 and int(drop.amount) >= 1:
			core_dropped = true
	check(core_dropped, "guardian physically drops rare organic core")
	game.run_loot = [0, 0, 0, 0]
	await _extract()
	check(progress.completed == 2 and progress.history.size() == 3, "both successful biomes and failed run persist separate history")
	# Release the complete scene before restoring the user's untouched profile.
	game.set_process(false)
	game.set_physics_process(false)
	game.world.process_mode = Node.PROCESS_MODE_DISABLED
	game.queue_free()
	await _frames()
	game = null
	main_scene = null
	progress.call("_defaults")
	progress.call("_apply_document", original_document)
	progress.save_path = original_path
	_scratch_cleanup()
	print("GAMEPLAY_TESTS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
