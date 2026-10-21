extends SceneTree
## Resize the actual Window; verify generated nine-patch UI and reachable menus.
var checks := 0
var failures := 0
var game: Node2D

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("UI_LAYOUT_CHECK_FAILED: " + message)

func _settle() -> void:
	for i: int in 10:
		await process_frame

func _buttons(node: Node) -> Array[Button]:
	var result: Array[Button] = []
	if node is Button:
		result.append(node as Button)
	for child: Node in node.get_children():
		result.append_array(_buttons(child))
	return result

func _inside(control: Control, area: Rect2) -> bool:
	var rect: Rect2 = control.get_global_rect()
	return area.grow(2).encloses(rect)

func _run() -> void:
	var progress: Node = root.get_node("Progress")
	progress.save_path = "user://symbiont_ui_layout.json"
	progress._defaults()
	progress.bank = [999999,999999,999999,999999]
	progress.modules.archive_door = 1
	progress.modules.blackbox = 1
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await _settle()
	# Close and toolbar buttons are styled before parenting; prevent native gray fallback.
	game.ui.open_pause()
	await _settle()
	for control: Button in [game.ui.toolbar_button,_buttons(game.ui.overlay_header)[0]]:
		for state: String in ["hover","hover_pressed","focus"]:
			var skin: StyleBox = control.get_theme_stylebox(state)
			check(skin is StyleBoxTexture and skin.texture == preload("res://assets/art/ui/button.png"), "toolbar/close %s uses organic texture before and after click" % state)
	game.set_physics_process(false)
	game.player.set_physics_process(false)
	for dimensions: Vector2i in [Vector2i(1280,720), Vector2i(800,600), Vector2i(640,360), Vector2i(640,960), Vector2i(1920,1080)]:
		root.size = dimensions
		await _settle()
		check(game.ui.root.size == Vector2(dimensions), "interface follows actual window size %s" % dimensions)
		var area := Rect2(Vector2.ZERO,Vector2(dimensions))
		for mode: String in ["title", "map", "upgrades", "modules", "settings", "storage", "heart", "pause", "garden"]:
			match mode:
				"title": game.ui.open_title()
				"map": game.ui.open_map()
				"upgrades": game.ui.open_upgrades(false)
				"modules": game.ui.open_upgrades(true)
				"settings": game.ui.open_settings()
				"storage": game.ui.open_storage()
				"heart": game.ui.open_heart()
				"pause": game.ui.open_pause()
				"garden": game.ui.open_garden()
			await _settle()
			check(_inside(game.ui.overlay_panel, area), "%s panel stays inside %s" % [mode, dimensions])
			check(game.ui.overlay_panel.get_theme_stylebox("panel") is StyleBoxTexture, "%s uses generated stretchable chitin" % mode)
			check(game.ui.overlay_content.size.x <= game.ui.overlay_scroll.size.x + 1.0, "%s never needs horizontal scrolling" % mode)
			if mode in ["upgrades","modules"] and dimensions.y <= 360:
				var graph_view: Rect2 = game.ui.evolution_tree.scroll.get_global_rect().intersection(game.ui.overlay_scroll.get_global_rect())
				check(graph_view.size.y >= 80,"short window initially exposes the actual tree graph")
			game.ui.overlay_scroll.scroll_vertical = 1000000
			await _settle()
			var buttons: Array[Button] = _buttons(game.ui.overlay_content)
			if not buttons.is_empty():
				check(_inside(buttons[-1],game.ui.overlay_scroll.get_global_rect()), "%s final action is reachable by vertical scrolling at %s" % [mode,dimensions])
			if mode in ["upgrades", "modules"]:
				check(game.ui.evolution_tree.body.vertical == (game.ui.evolution_tree.size.x < 870), "tree and detail panel stack at narrow widths")
		game.ui.close()
		for touch_enabled: bool in [false,true]:
			progress.settings["touch"] = touch_enabled
			game.ui.automatic_touch = false
			await _settle()
			check(_inside(game.ui.top_panel,area) and _inside(game.ui.hp_panel,area) and _inside(game.ui.task_panel,area), "HUD fits with maximum resources and touch=%s at %s" % [touch_enabled,dimensions])
			if game.ui.minimap.visible:
				check(_inside(game.ui.minimap,area), "organic minimap stays inside viewport")
			if touch_enabled:
				var controls: Control = game.ui.touch
				for point: Vector2 in [controls.left_center,controls.right_center]:
					check(area.encloses(Rect2(point-Vector2.ONE*(controls.radius+10),Vector2.ONE*(controls.radius+10)*2)), "organic stick fits resized viewport")
	game.queue_free()
	await process_frame
	await process_frame
	print("UI_LAYOUT_TESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures > 0 else 0)
