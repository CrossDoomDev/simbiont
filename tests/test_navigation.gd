extends SceneTree
var checks := 0
var failures := 0
var game: Node2D

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("NAVIGATION_CHECK_FAILED: " + message)

func settle() -> void:
	for i: int in 12:
		await process_frame

func click_point(index: int) -> void:
	var button: Button = game.ui.navigation_map.point_buttons[index]
	var point: Vector2 = button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	root.push_input(motion,true)
	await process_frame
	for pressed: bool in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event,true)
		await process_frame
	await settle()

func _run() -> void:
	root.size = Vector2i(1280,720)
	var progress: Node = root.get_node("Progress")
	progress.save_path = "user://symbiont_navigation_test.json"
	progress._defaults()
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await settle()
	game.set_physics_process(false)
	game.player.set_physics_process(false)
	game.ui.open_map()
	await settle()
	check(game.ui.navigation_map.point_buttons.size() == 2, "both landing points have native input controls")
	check(game.ui.map_launch.text == "Переместиться" and not game.ui.map_launch.disabled, "one travel action for initial forest point")
	await click_point(1)
	check(game.ui.selected_mission == 1 and game.ui.navigation_map.selected == 1, "actual pointer click selects swamp point")
	check(game.mode == "ship" and game.ui.page == "map", "selecting point does not launch mission")
	check(game.ui.map_name.text == GameData.MISSIONS[1]["name"] and game.ui.map_description.text.begins_with(GameData.MISSIONS[1]["description"]) and game.ui.map_description.text.contains("Протокол:"), "details follow selected point")
	check(game.ui.map_launch.disabled and game.ui.map_lock.visible, "locked landing point explains heart requirement")
	await click_point(0)
	check(game.ui.selected_mission == 0 and not game.ui.map_launch.disabled and not game.ui.map_lock.visible, "forest selection restores available travel action")
	progress.modules["heart"] = 2
	await click_point(1)
	check(not game.ui.map_launch.disabled and not game.ui.map_lock.visible, "restored heart unlocks selected swamp point")
	for dimensions: Vector2i in [Vector2i(640,360),Vector2i(640,960),Vector2i(1280,720)]:
		root.size = dimensions
		await settle()
		var map: Control = game.ui.navigation_map
		for button: Button in map.point_buttons:
			check(Rect2(Vector2.ZERO,map.size).grow(-24).encloses(Rect2(button.position,button.size)), "landing target stays clear of map frame at %s" % dimensions)
	game.ui.close()
	game.mode = "mission"
	game.ui.automatic_touch = false
	progress.settings["touch"] = false
	await settle()
	check(game.ui.battle_cursor_active, "mouse combat uses symbiote cursor")
	game.ui.open_pause()
	await settle()
	check(not game.ui.battle_cursor_active, "pause restores menu pointer")
	game.ui.close()
	progress.settings["touch"] = true
	await settle()
	check(not game.ui.battle_cursor_active, "touch controls do not use combat mouse cursor")
	progress.settings["touch"] = false
	game.mode = "ship"
	await settle()
	check(not game.ui.battle_cursor_active, "ship restores ordinary cursor")
	game.queue_free()
	await process_frame
	await process_frame
	print("NAVIGATION_TESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures > 0 else 0)
