extends SceneTree
## End-to-end cultivation, transactional fruit use and actual tree input events.
var checks := 0
var failures := 0
var progress: Node
var game: Node2D
var path := "user://symbiont_garden_test.json"

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("GARDEN_CHECK_FAILED: "+message)

func settle(count: int = 8) -> void:
	for i: int in count:
		await physics_frame
		await process_frame

func wheel(pointer: Vector2, button: int) -> void:
	var event := InputEventMouseButton.new()
	event.position = pointer
	event.global_position = pointer
	event.button_index = button
	event.pressed = true
	Input.parse_input_event(event)

func point_in_graph(tree: Node, point: Vector2) -> Vector2:
	return (point-tree.scroll.global_position+Vector2(tree.scroll.scroll_horizontal,tree.scroll.scroll_vertical)-tree.graph_offset)/tree.zoom

func _run() -> void:
	progress = root.get_node("Progress")
	progress.save_path = path
	progress._defaults()
	progress.bank = [1000,1000,1000,10]
	check(progress.garden_slots() == 0 and not progress.sow_garden(0,"vascular"),"locked garden cannot plant")
	progress.modules.archive_door = 1
	check(progress.garden_slots() == 2 and not progress.sow_garden(2,"vascular"),"garden starts with two unlocked beds")
	check(not progress.sow_garden(0,"unknown") and not progress.sow_garden(-1,"vascular"),"invalid planting is rejected")
	var bank: Array = progress.bank.duplicate()
	check(progress.sow_garden(0,"vascular") and progress.bank == [bank[0]-24,bank[1]-4,bank[2],bank[3]],"planting spends exact shared resources")
	check(not progress.sow_garden(0,"enzyme"),"occupied crop cannot be overwritten")
	check(progress.sow_garden(1,"enzyme"),"different cultures can grow simultaneously")
	check(not progress.harvest_garden(0),"unripe crop cannot be harvested")
	check(progress.deposit_run([0,0,0,0],false,"garden-defeat") and progress.garden_beds[0].growth == 0,"defeat never grows cultures")
	check(progress.deposit_run([0,0,0,0],true,"garden-win-1") and progress.garden_beds[0].growth == 3 and progress.garden_beds[1].growth == 3,"successful cleared nests grow both cultures")
	check(not progress.deposit_run([0,0,0,0],true,"garden-win-1") and progress.garden_beds[1].growth == 3,"duplicate mission cannot grow crops twice")
	check(progress.harvest_garden(0) and progress.fruit_stock.vascular == 1,"ripe harvest gives an actual persistent fruit")
	check(not progress.harvest_garden(0) and progress.fruit_stock.vascular == 1,"same harvest cannot be repeated")
	check(progress.deposit_run([0,0,0,0],true,"garden-win-2") and GardenData.stage(progress.garden_beds[1]) == 3,"longer culture matures after a second success")
	check(progress.harvest_garden(1),"second culture can be harvested")
	bank = progress.bank.duplicate()
	check(progress.digest_fruit("vascular") and progress.bank == [bank[0]+60,bank[1]+10,bank[2],bank[3]],"feeding the ship exchanges fruit for exact resources")
	check(not progress.digest_fruit("vascular"),"spent fruit cannot be eaten again")
	check(progress.prepare_lure("enzyme") and progress.fruit_stock.enzyme == 1,"preparing a lure reserves the choice without spending fruit")
	progress.load_game()
	check(progress.prepared_lure == "enzyme" and progress.fruit_stock.enzyme == 1,"fruit and prepared hunt survive reload")
	var launched: Dictionary = progress.launch_lure()
	check(launched.ok and launched.strain == "enzyme" and progress.fruit_stock.enzyme == 0 and progress.prepared_lure == "","launch spends one fruit and clears selection")
	check(progress.launch_lure().strain == "","second launch cannot reuse a consumed lure")
	progress.modules.blackbox = 1
	check(progress.garden_slots() == 3 and progress.sow_garden(2,"core"),"existing root-network investment unlocks third cultivation bed")
	for i: int in 3:
		check(progress.deposit_run([0,0,0,0],true,"core-grow-"+str(i)),"core cocoon receives successful growth")
	check(GardenData.stage(progress.garden_beds[2]) == 3,"core culture requires three full successful expeditions")
	check(progress.harvest_garden(2) and progress.prepare_lure("core"),"rare fruit can be prepared for a hunt")
	var stock: Dictionary = progress.fruit_stock.duplicate()
	progress.save_path = "user://garden_missing_folder/profile.json"
	check(not progress.launch_lure().ok and progress.fruit_stock == stock and progress.prepared_lure == "core","failed launch save rolls back stock and preparation")
	bank = progress.bank.duplicate()
	check(not progress.sow_garden(0,"vascular") and progress.bank == bank and progress.garden_beds[0].strain == "","failed planting save rolls back bed and resources")
	progress.garden_beds[0] = {"strain":"vascular","growth":3}
	check(not progress.harvest_garden(0) and progress.garden_beds[0].growth == 3,"failed harvest save retains the mature crop")
	progress.save_path = path
	progress._defaults()
	progress.modules.archive_door = 1
	progress.modules.blackbox = 1
	progress.settings.autofire = false
	progress.bank = [1000,1000,1000,10]
	progress.fruit_stock.enzyme = 1
	check(progress.prepare_lure("enzyme"),"test expedition prepares one real fruit")
	root.size = Vector2i(1280,720)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await settle()
	game.ui.close()
	game.set_physics_process(false)
	game.player.set_physics_process(false)
	for gate: Node2D in game.world.gates:
		var sprite := gate.get_node("GeneratedMembrane") as Sprite2D
		check(sprite != null and sprite.texture is AtlasTexture and sprite.texture.atlas == EvolutionArt.GATES,"packed door uses original generated texture")
	game.ui.open_garden()
	await settle()
	check(game.ui.page == "garden" and not _contains_log(game.ui.overlay_content),"garden is a cultivation interface without player activity logs")
	for ship: bool in [false,true]:
		game.ui.open_upgrades(ship)
		await settle()
		var tree: Node = game.ui.evolution_tree
		tree.set_zoom(0.8)
		await settle()
		tree.scroll.scroll_horizontal = 100
		tree.scroll.scroll_vertical = 250
		await settle()
		var pointer: Vector2 = tree.scroll.global_position+Vector2(170,110)
		var before := point_in_graph(tree,pointer)
		var selection: String = tree.selected
		wheel(pointer,MOUSE_BUTTON_WHEEL_UP)
		await settle()
		check(tree.zoom > 0.8 and before.distance_to(point_in_graph(tree,pointer)) < 3,"real wheel zoom anchors the graph point under cursor")
		check(tree.selected == selection,"wheel over a node cannot change selection")
		wheel(pointer,MOUSE_BUTTON_WHEEL_DOWN)
		await settle()
		check(is_equal_approx(tree.zoom,0.8),"wheel down reverses zoom")
		for tick: int in 3:
			wheel(pointer,MOUSE_BUTTON_WHEEL_UP)
		await settle()
		check(tree.zoom <= 1.2 and before.distance_to(point_in_graph(tree,pointer)) < 4,"burst wheel events preserve anchor and zoom limit")
		tree.set_zoom(0.8)
		await settle()
		tree.scroll.scroll_horizontal = 100
		tree.scroll.scroll_vertical = 250
		var start := Vector2(tree.scroll.scroll_horizontal,tree.scroll.scroll_vertical)
		var press := InputEventMouseButton.new()
		press.position = pointer
		press.button_index = MOUSE_BUTTON_MIDDLE
		press.pressed = true
		Input.parse_input_event(press)
		var motion := InputEventMouseMotion.new()
		motion.position = pointer-Vector2(45,30)
		motion.relative = Vector2(-45,-30)
		motion.button_mask = MOUSE_BUTTON_MASK_MIDDLE
		Input.parse_input_event(motion)
		await settle()
		check(Vector2(tree.scroll.scroll_horizontal,tree.scroll.scroll_vertical).distance_to(start+Vector2(45,30)) < 2,"holding middle button pans actual scroll view")
		press.pressed = false
		press.position = Vector2.ZERO
		Input.parse_input_event(press)
		await settle(2)
		check(not tree.dragging,"releasing middle button outside graph ends dragging")
		var generated: StyleBox = tree.node_buttons[selection].get_theme_stylebox("normal")
		check(generated is StyleBoxTexture and generated.texture is AtlasTexture and generated.texture.atlas == EvolutionArt.FRAMES,"tree nodes use newly generated frames")
	game.ui.close()
	await game.start_mission(0)
	game.set_physics_process(false)
	game.player.set_physics_process(false)
	check(game.run_lure == "enzyme" and progress.fruit_stock.enzyme == 0,"real mission launch consumes selected lure exactly once")
	var nest: Node2D = get_nodes_in_group("nests")[0]
	nest.take_damage(99999)
	await settle()
	var lures: Array[Node] = get_nodes_in_group("garden_lures")
	check(lures.size() == 1 and game.nodes_destroyed == 1 and get_nodes_in_group("nests").size() == 2,"first mandatory nest grows a separate optional lure")
	if not lures.is_empty():
		check(game.nearest_enemy(lures[0].position,100) != lures[0],"autofire never chooses the optional lure as a target")
		lures[0].take_damage(99999)
		await settle()
		var hunter: Node2D
		for enemy: Node2D in get_nodes_in_group("enemies"):
			if enemy.has_meta("garden_reward"):
				hunter = enemy
		check(is_instance_valid(hunter) and game.bosses_spawned == 0,"optional hunter does not replace or count as a mission guardian")
		if is_instance_valid(hunter):
			hunter.take_damage(99999)
			var bonus := false
			for loot: Node2D in get_nodes_in_group("loot"):
				bonus = bonus or (loot.resource_type == 2 and loot.amount == 30)
			check(bonus and game.nodes_destroyed == 1 and not game.objective_complete(),"hunter drops special real loot without completing mandatory objectives")
	game.queue_free()
	await settle()
	for suffix: String in ["",".bak",".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path+suffix))
	print("GARDEN_TESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func _contains_log(node: Node) -> bool:
	if node is Label and (node.text.contains("Последние вылазки") or node.text.contains("Доступно записей")):
		return true
	for child: Node in node.get_children():
		if _contains_log(child):
			return true
	return false
