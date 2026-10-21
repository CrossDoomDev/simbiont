extends SceneTree
## Actual runtime viewports of the two graphs and the expanded living ship.
var game: Node2D
var progress: Node
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("EVOLUTION_RENDER_FAILED: "+message)

func settle(count: int = 8) -> void:
	for i: int in count:
		await process_frame

func capture(name: String) -> void:
	await settle()
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://artifacts/screenshots/31_"+name+".png") == OK,"save "+name)

func _run() -> void:
	root.size = Vector2i(1280,720)
	progress = root.get_node("Progress")
	progress.save_path = "user://symbiont_evolution_capture.json"
	progress._defaults()
	progress.tutorial = true
	progress.settings.autofire = false
	progress.bank = [640,170,120,9]
	progress.upgrades.regeneration = 2
	progress.upgrades.resonator = 2
	progress.upgrades.muscle = 1
	progress.upgrades.receptor = 2
	progress.upgrades.serration = 2
	progress.upgrades.cadence = 1
	progress.upgrades.neuron = 2
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await settle()
	game.ui.close()
	game.set_physics_process(false)
	game.player.set_physics_process(false)
	game.ui.open_upgrades(false)
	await settle()
	var tree: Control = game.ui.evolution_tree
	check(tree.node_buttons.size() == 40,"actual host tree contains forty native selectable nodes")
	tree.node_buttons["serration"].pressed.emit()
	check(tree.selected == "serration" and not tree.purchase.disabled,"native node selection exposes an eligible purchase")
	await capture("symbiote_tree")
	tree.fit()
	await capture("symbiote_overview")
	tree.node_buttons["apex_barrage"].pressed.emit()
	check(tree.purchase.disabled and tree.requirements.text.contains("Сквозной шип") and tree.requirements.text.contains("Последний укус"),"unavailable capstone explains its own dependencies")
	await capture("mutation_capstone")
	game.ui.open_upgrades(true)
	await settle()
	tree = game.ui.evolution_tree
	tree.select("refinery_door")
	await capture("ship_branch")
	tree.fit()
	check(tree.node_buttons.size() == 22,"actual ship tree contains twenty-two systems")
	await capture("ship_tree")
	game.ui.close()
	game.ui.root.visible = false
	game.player.position = game.world.bounds.get_center()
	game.camera.position = Vector2.ZERO
	game.camera.position_smoothing_enabled = false
	game.camera.zoom = Vector2.ONE*0.27
	game.camera.force_update_scroll()
	await capture("ship_sealed")
	for gate: Node2D in game.world.gates:
		check(gate.visible,"initial physical membrane visible")
	progress.modules.heart = 2
	progress.modules.navigation = 1
	progress.modules.storage = 1
	progress.modules.regeneration = 2
	progress.modules.archive_door = 1
	progress.modules.refinery_door = 1
	progress.modules.quarantine_door = 1
	progress.modules.converter = 1
	progress.modules.efficient_conversion = 2
	progress.modules.cave_echo = 1
	progress.modules.threat_echo = 1
	progress.modules.swarm_protocol = 1
	progress.modules.predator_protocol = 1
	game.world.refresh_organs()
	await settle()
	for gate: Node2D in game.world.gates:
		check(not gate.visible and gate.shape.disabled,"restoration removes rendered and physical seal")
	await capture("ship_opened")
	game.ui.root.visible = true
	game.ui.open_refinery()
	check(game.ui.page == "refinery","new refinery opens its functional recipes")
	await capture("refinery")
	game.ui.open_quarantine()
	check(game.ui.page == "quarantine","quarantine opens real protocol selection")
	await capture("quarantine")
	for dimensions: Vector2i in [Vector2i(640,360),Vector2i(640,960),Vector2i(1920,1080)]:
		root.size = dimensions
		game.ui.open_upgrades(false)
		await settle(15)
		tree = game.ui.evolution_tree
		if dimensions.y < 520:
			check(tree.scroll.get_global_rect().intersection(game.ui.overlay_scroll.get_global_rect()).size.y >= 80,"initial compact viewport shows graph content")
		var area := Rect2(Vector2.ZERO,Vector2(dimensions))
		check(area.grow(1).encloses(game.ui.overlay_panel.get_global_rect()),"tree fits window "+str(dimensions))
		check(tree.body.vertical == (tree.size.x < 870),"detail layout follows available width")
		for node: Button in tree.node_buttons.values():
			check(Rect2(Vector2.ZERO,tree.graph.size).grow(1).encloses(node.get_rect()),"zoomed node stays within scrollable graph")
		if dimensions.x > 1000:
			tree.fit()
		else:
			game.ui.overlay_scroll.scroll_vertical = 0
		await capture("tree_"+str(dimensions.x)+"x"+str(dimensions.y))
	var audio: Node = root.get_node("Audio")
	for player: AudioStreamPlayer in audio._music_players+audio._effects_players:
		player.stop()
		player.stream = null
	if audio._ambient != null:
		audio._ambient.stop()
		audio._ambient.stream = null
	audio._cache.clear()
	await create_timer(0.2).timeout
	game.queue_free()
	await settle()
	print("EVOLUTION_RENDER_CHECKS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
