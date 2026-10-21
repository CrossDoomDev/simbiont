extends SceneTree
## Real native ScreenTouch/ScreenDrag input through the complete viewport pipeline.
var checks: int = 0
var failures: int = 0
var game: Node2D
var progress: Node
var scratch_path: String = "user://symbiont_touch_test.json"

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("TOUCH_CHECK_FAILED: " + message)

func _frames(count: int = 3) -> void:
	for i: int in range(count):
		await physics_frame
		await process_frame

func _touch(index: int, position: Vector2, pressed: bool, canceled: bool = false) -> void:
	var event: InputEventScreenTouch = InputEventScreenTouch.new()
	event.index = index
	# parse_input_event accepts physical Window coordinates; our cases use 1280x720
	# viewport coordinates. Headless Windows can be only 64x64 with letterboxing.
	event.position = root.get_screen_transform() * position
	event.pressed = pressed
	event.canceled = canceled
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _drag(index: int, position: Vector2, relative: Vector2) -> void:
	var event: InputEventScreenDrag = InputEventScreenDrag.new()
	event.index = index
	event.position = root.get_screen_transform() * position
	event.relative = root.get_screen_transform().basis_xform(relative)
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _cleanup_files() -> void:
	for suffix: String in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(scratch_path + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(scratch_path + suffix))

func _run() -> void:
	progress = root.get_node("Progress")
	var original_path: String = progress.save_path
	var original_document: Dictionary = progress.call("_document")
	_cleanup_files()
	progress.save_path = scratch_path
	progress.reset_progress()
	progress.settings["autofire"] = false
	progress.settings["touch"] = false
	var scene: PackedScene = load("res://scenes/main.tscn") as PackedScene
	game = scene.instantiate() as Node2D
	root.add_child(game)
	await _frames()
	game.ui.close()
	game.ui.automatic_touch = true
	await _frames()
	var controls: Control = game.ui.touch
	check(game.ui.hud.visible and controls.is_visible_in_tree(), "automatic touch displays controls after title closes")
	var start: Vector2 = game.player.position
	_touch(0, Vector2(110, 600), true)
	_drag(0, Vector2(160, 600), Vector2(50, 0))
	await _frames()
	check(controls.left_id == 0 and controls.left_value.x > 0.7, "native input captures left finger and drag")
	await create_timer(0.25).timeout
	check(game.player.position.x > start.x + 15.0, "left touch drag moves actual host right")
	_touch(0, Vector2(160, 600), false)
	await _frames()
	check(controls.left_id == -1 and controls.left_value == Vector2.ZERO, "left release resets capture and direction")
	check(game.player.move_input == Vector2.ZERO and game.player.velocity.length() < 0.01, "released stick stops host movement")
	# Cancellation must allow the same browser finger index to be captured again.
	_touch(0, Vector2(110, 600), true)
	_drag(0, Vector2(145, 580), Vector2(35, -20))
	_touch(0, Vector2(145, 580), false, true)
	await _frames()
	check(controls.left_id == -1 and controls.left_value == Vector2.ZERO, "canceled pointer resets left stick")
	_touch(0, Vector2(110, 600), true)
	_drag(0, Vector2(160, 600), Vector2(50, 0))
	await _frames()
	check(controls.left_id == 0 and controls.left_value.x > 0.7, "released pointer index can start a new gesture")
	_touch(0, Vector2(160, 600), false)
	await game.start_mission(0)
	game.spawn_clock = 9999.0
	for enemy: Node in get_nodes_in_group("enemies"):
		enemy.queue_free()
	await _frames()
	check(controls.is_visible_in_tree() and game.mode == "mission", "touch controls remain active in mission")
	_touch(1, Vector2(1170, 600), true)
	_drag(1, Vector2(1210, 600), Vector2(40, 0))
	await create_timer(0.25).timeout
	check(controls.right_id == 1 and controls.right_value.x > 0.5, "right finger independently captures aim stick")
	check(game.player.manual_fire and game.player.aim.x > 0.9, "right drag sets actual firing direction")
	check(not get_nodes_in_group("projectiles").is_empty(), "right touch stick creates real bioimpulse projectiles")
	_touch(0, Vector2(110, 600), true)
	_drag(0, Vector2(160, 580), Vector2(50, -20))
	await _frames()
	check(controls.left_id == 0 and controls.right_id == 1, "both fingers can operate sticks simultaneously")
	game.ui.open_pause()
	await _frames()
	check(not controls.is_visible_in_tree() and game.modal, "pause hides controls and freezes gameplay")
	check(controls.left_id == -1 and controls.right_id == -1 and controls.left_value == Vector2.ZERO and controls.right_value == Vector2.ZERO, "pause cancels both finger ids and vectors without release events")
	_touch(0, Vector2(160, 580), false)
	_touch(1, Vector2(1210, 600), false)
	game.ui.close()
	await _frames()
	var resumed: Vector2 = game.player.position
	await create_timer(0.15).timeout
	check(game.player.position.distance_to(resumed) < 0.1 and not game.player.manual_fire, "resume cannot revive stale movement or firing")
	game.ui.automatic_touch = false
	progress.settings["touch"] = false
	await _frames()
	check(not controls.is_visible_in_tree(), "desktop hides touch controls when setting is disabled")
	var desktop: Vector2 = game.player.position
	_touch(0, Vector2(110, 600), true)
	_drag(0, Vector2(160, 600), Vector2(50, 0))
	await create_timer(0.2).timeout
	check(controls.left_value == Vector2.ZERO and controls.left_id == -1 and game.player.position.distance_to(desktop) < 0.1, "hidden desktop controls reject native touch movement")
	_touch(0, Vector2(160, 600), false)
	# A hidden ancestor must cancel even when the touch node itself is locally visible.
	game.ui.automatic_touch = true
	await _frames()
	_touch(0, Vector2(110, 600), true)
	_drag(0, Vector2(160, 600), Vector2(50, 0))
	game.ui.open_title()
	await _frames()
	check(not controls.is_visible_in_tree() and controls.left_id == -1 and controls.left_value == Vector2.ZERO, "title HUD hiding clears active pointer capture")
	_touch(0, Vector2(160, 600), false)
	game.queue_free()
	await _frames()
	game = null
	scene = null
	progress.call("_defaults")
	progress.call("_apply_document", original_document)
	progress.save_path = original_path
	_cleanup_files()
	print("TOUCH_TESTS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
