extends SceneTree
var game: Node2D
var progress: Node
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("GARDEN_RENDER_FAILED: "+message)

func settle(count: int = 10) -> void:
	for i: int in count:
		await process_frame

func capture(name: String) -> void:
	await settle()
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://artifacts/screenshots/32_"+name+".png") == OK,"save "+name)

func focus(point: Vector2, zoom: float) -> void:
	game.player.position = point
	game.camera.position = Vector2.ZERO
	game.camera.position_smoothing_enabled = false
	game.camera.zoom = Vector2.ONE*zoom
	game.camera.force_update_scroll()

func _run() -> void:
	root.size = Vector2i(1280,720)
	progress = root.get_node("Progress")
	progress.save_path = "user://symbiont_garden_capture.json"
	progress._defaults()
	progress.tutorial = true
	progress.settings.autofire = false
	progress.bank = [530,110,90,5]
	progress.modules.heart = 2
	progress.modules.navigation = 2
	progress.modules.storage = 1
	progress.modules.regeneration = 2
	progress.modules.archive_door = 1
	progress.modules.blackbox = 1
	progress.garden_beds = [{"strain":"vascular","growth":3},{"strain":"enzyme","growth":3},{"strain":"core","growth":6}]
	progress.fruit_stock = {"vascular":2,"enzyme":1,"core":1}
	progress.upgrades.regeneration = 2
	progress.upgrades.resonator = 2
	progress.upgrades.serration = 2
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await settle()
	game.ui.close()
	game.set_physics_process(false)
	game.player.set_physics_process(false)
	game.ui.open_upgrades(false)
	await settle()
	var tree: Node = game.ui.evolution_tree
	tree.select("serration")
	check(tree.node_buttons.serration.get_theme_stylebox("normal") is StyleBoxTexture,"mutation node draws generated art")
	await capture("symbiote_tree_art")
	var pointer: Vector2 = tree.scroll.get_global_rect().get_center()
	var event := InputEventMouseButton.new()
	event.position = pointer
	event.button_index = MOUSE_BUTTON_WHEEL_UP
	event.pressed = true
	Input.parse_input_event(event)
	await settle()
	check(tree.zoom > 0.8,"actual wheel event zooms rendered graph")
	await capture("wheel_zoom")
	game.ui.open_upgrades(true)
	await settle()
	game.ui.evolution_tree.select("archive_door")
	await capture("ship_tree_art")
	game.ui.open_garden()
	await capture("xenogarden")
	game.ui.overlay_scroll.scroll_vertical = 1000000
	await capture("garden_fruit_choices")
	game.ui.close()
	game.ui.root.visible = false
	focus(Vector2(2410,550),1.15)
	await capture("garden_chamber")
	for gate: Node2D in game.world.gates:
		if gate.definition.id in ["refinery_door","quarantine_door"]:
			focus(gate.position+Vector2(0,110),1.7)
			game.camera.position = Vector2(0,-110)
			game.camera.force_update_scroll()
			check(gate.get_node("GeneratedMembrane").texture is AtlasTexture,"door is generated sprite")
			await capture(str(gate.definition.id)+"_art")
	progress.modules.archive_door = 0
	game.world.refresh_organs()
	for gate: Node2D in game.world.gates:
		if gate.definition.id == "archive_door":
			focus(gate.position+Vector2(-110,0),1.7)
			game.camera.position = Vector2(110,0)
			game.camera.force_update_scroll()
			await capture("garden_door_vertical_art")
	progress.modules.archive_door = 1
	game.world.refresh_organs()
	game.ui.root.visible = true
	for dimensions: Vector2i in [Vector2i(640,360),Vector2i(640,960),Vector2i(1920,1080)]:
		root.size = dimensions
		game.ui.open_upgrades(false)
		await settle(15)
		check(Rect2(Vector2.ZERO,Vector2(dimensions)).grow(1).encloses(game.ui.overlay_panel.get_global_rect()),"tree fits "+str(dimensions))
		await capture("tree_"+str(dimensions.x)+"x"+str(dimensions.y))
		if dimensions.x == 640 and dimensions.y == 960:
			game.ui.open_garden()
			await capture("garden_portrait")
	root.size = Vector2i(1280,720)
	game.ui.close()
	progress.prepared_lure = "core"
	await game.start_mission(0)
	game.set_physics_process(false)
	game.player.set_physics_process(false)
	var nest: Node2D = get_nodes_in_group("nests")[0]
	nest.take_damage(99999)
	await settle()
	for enemy: Node in get_nodes_in_group("enemies"):
		enemy.queue_free()
	await settle()
	var lure: Node2D = get_nodes_in_group("garden_lures")[0]
	focus(lure.position+Vector2(-140,80),1.3)
	await capture("garden_lure_in_battle")
	lure.take_damage(99999)
	for enemy: Node in get_nodes_in_group("enemies"):
		enemy.set_physics_process(false)
	await capture("garden_hunter")
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
	print("GARDEN_RENDER_CHECKS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
