extends SceneTree
## Real purchase graphs, versioned saves, economics and native combat integration.
var checks := 0
var failures := 0
var progress: Node
var game: Node2D
var Actor: Script
var test_path := "user://symbiont_evolution_test.json"

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("EVOLUTION_CHECK_FAILED: "+message)

func settle(count: int = 3) -> void:
	for tick: int in count:
		await physics_frame
		await process_frame

func _stats_equal(a: Dictionary, b: Dictionary) -> bool:
	if a.size() != b.size():
		return false
	for key: String in a:
		if not b.has(key) or not is_equal_approx(float(a[key]),float(b[key])):
			return false
	return true

func graph_checks(nodes: Dictionary) -> void:
	var resolved := {}
	var all_links_valid := true
	for id: String in nodes:
		var data: Dictionary = nodes[id]
		for parent: String in data.get("requires",{}):
			all_links_valid = all_links_valid and nodes.has(parent) and int(data["requires"][parent]) > 0 and int(data["requires"][parent]) <= int(nodes[parent]["max_level"])
		check(data["costs"].size() == int(data["max_level"]),"every rank has a price: "+id)
		for cost: Array in data["costs"]:
			check(cost.size() == 4 and int(cost[0]) > 0,"positive resource price: "+id)
	for pass_index: int in nodes.size():
		for id: String in nodes:
			var ready := true
			for parent: String in nodes[id].get("requires",{}):
				ready = ready and resolved.has(parent)
			if ready:
				resolved[id] = true
	check(all_links_valid,"prerequisite ranks refer to existing valid nodes")
	check(resolved.size() == nodes.size(),"every branch is reachable without cycles")

func purchase_all(ship: bool) -> void:
	var configs: Dictionary = GameData.MODULES if ship else GameData.UPGRADES
	var levels: Dictionary = progress.modules if ship else progress.upgrades
	progress.bank = [999999,999999,999999,999999]
	for pass_index: int in configs.size():
		for id: String in configs:
			if not progress.requirements_met(id,ship):
				continue
			while int(levels[id]) < int(configs[id]["max_level"]):
				var ok: bool = progress.purchase_module(id) if ship else progress.purchase_upgrade(id)
				check(ok,"purchase eligible graph rank: "+id)
				if not ok:
					break
	for id: String in configs:
		check(int(levels[id]) == int(configs[id]["max_level"]),"all graph ranks can be reached: "+id)

func disable_solids(node: Node) -> void:
	if node is TileMapLayer:
		node.collision_enabled = false
	if node is CollisionObject2D and not node is CharacterBody2D:
		node.collision_layer = 0
	for child: Node in node.get_children():
		disable_solids(child)

func enemy(point: Vector2) -> Node2D:
	var actor: Node2D = Actor.new()
	actor.game = game
	actor.kind = "shell"
	actor.position = point
	game.world.entities.add_child(actor)
	actor.set_physics_process(false)
	actor.hp = 1000
	actor.max_hp = 1000
	actor.armor = 0
	return actor

func _run() -> void:
	progress = root.get_node("Progress")
	progress.save_path = test_path
	progress._defaults()
	Actor = load("res://scripts/actor.gd")
	check(GameData.UPGRADES.size() == 40 and GameData.MODULES.size() == 22,"two substantial graphs contain 40 mutations and 22 ship systems")
	graph_checks(GameData.UPGRADES)
	graph_checks(GameData.MODULES)
	progress.bank = [9999,9999,9999,9999]
	var bank_before: Array = progress.bank.duplicate()
	check(not progress.purchase_upgrade("apex_barrage") and progress.bank == bank_before,"capstone cannot bypass prerequisites or spend resources")
	check(not progress.purchase_module("core_synthesis"),"ship synthesis requires both connected prerequisites")
	progress.modules.converter = 1
	check(not progress.purchase_module("core_synthesis"),"one AND prerequisite is insufficient")
	progress.modules.heart = 2
	check(progress.purchase_module("core_synthesis"),"all prerequisites permit purchase")
	var before_stats: Dictionary = progress.player_stats()
	purchase_all(true)
	check(progress.player_stats() == before_stats,"all ship investments leave every character stat unchanged")
	check(is_equal_approx(progress.death_keep_ratio(),0.8),"completed salvage branches keep 80 percent after defeat")
	check(progress.garden_slots() == 3,"root network opens the third playable garden bed")
	check(progress.credited_loot([100,100,100,3],false) == [80,80,80,2],"defeat payout is floored once with salvage ratio")
	check(progress.credited_loot([100,100,100,3],true) == [150,121,115,3],"victory bonuses apply to ordinary resources and never multiply cores")
	check(progress.credited_loot([100,100,100,3],true,"swarm") == [175,146,140,3],"swarm successful payout includes economic bonuses")
	check(progress.set_protocol("predator") and progress.protocol == "predator","unlocked quarantine protocol can be saved")
	check(not progress.set_protocol("unknown"),"unknown protocol cannot be saved")
	var recipe_before: Array = progress.bank.duplicate()
	check(progress.convert("tissue") and progress.bank[0] == recipe_before[0]-6 and progress.bank[1] == recipe_before[1]+1,"efficient refinery exchanges exact resources")
	check(progress.convert("core"),"core synthesis recipe works after unlock")
	progress.save_path = "user://evolution_missing_folder/profile.json"
	bank_before = progress.bank.duplicate()
	check(not progress.convert("enzyme") and progress.bank == bank_before,"failed recipe save rolls back every resource")
	check(not progress.set_protocol("swarm") and progress.protocol == "predator","failed protocol save rolls back selection")
	progress.save_path = test_path
	progress._defaults()
	check(not progress.set_protocol("swarm") and not progress.convert("tissue"),"fresh profile cannot use locked protocol or refinery")
	purchase_all(false)
	var grown: Dictionary = progress.player_stats()
	var base := GameData.stats({})
	var crit_factor: float = 1.0+float(grown.get("crit_chance",0))*(0.5+float(grown.get("crit_power",0)))
	var grown_dps: float = float(grown.damage)/float(grown.fire_interval)*1.95*crit_factor*(1.0+float(grown.get("moving_damage",0)))
	check(grown_dps > float(base.damage)/float(base.fire_interval)*5.0,"small ranks accumulate into more than fivefold moving weapon DPS at full development")
	check(grown.max_hp >= 185 and grown.armor >= 0.1,"survival branches accumulate health and mitigation")
	check(grown.regen_delay < base.regen_delay and grown.speed > base.speed,"mobility and recovery are real derived stats")
	bank_before = progress.bank.duplicate()
	check(not progress.purchase_upgrade("leech") and progress.bank == bank_before,"rank cap never spends resources")
	check(progress.save_game(),"expanded tree saves")
	progress.load_game()
	check(progress.upgrades.apex_barrage == 1 and progress.upgrades.marrow == 5,"all new ranks survive reload without old rank-three clamp")
	# A real v1 file migrates without discarding paid ship combat bonuses.
	var old := {"version":1,"bank":[77,22,11,2],"upgrades":{"regeneration":2,"resonator":1},"modules":{"heart":2,"regeneration":3,"navigation":2,"storage":1},"completed":7,"tutorial":true}
	var file := FileAccess.open(test_path,FileAccess.WRITE)
	file.store_string(JSON.stringify(old))
	file.close()
	progress.load_game()
	var inherited: Dictionary = progress.player_stats()
	check(progress.bank == [77,22,11,2] and progress.completed == 7 and progress.modules.heart == 2,"v1 migration retains bank, history counters and ship purchases")
	check(is_equal_approx(inherited.damage,12.1) and inherited.max_hp == 145 and is_equal_approx(inherited.regen,0.175),"v1 migration preserves paid combat power as inherited genes")
	check(progress.save_game(),"migrated profile writes version two")
	progress.load_game()
	check(_stats_equal(progress.player_stats(),inherited),"second load never duplicates inherited bonuses")
	progress.bank = [999,999,999,999]
	check(progress.purchase_module("heart") and _stats_equal(progress.player_stats(),inherited),"later ship purchases do not increase inherited genes")
	progress._defaults()
	progress.settings.autofire = false
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await settle()
	game.ui.close()
	game.set_physics_process(false)
	game.player.set_physics_process(false)
	for gate: Node2D in game.world.gates:
		var rect: Rect2 = gate.definition["rect"]
		var axis := Vector2.RIGHT if rect.size.y > rect.size.x else Vector2.DOWN
		var half: float = (rect.size.x if axis == Vector2.RIGHT else rect.size.y)*0.5
		game.player.position = gate.position-axis*(half+60)
		var collision: KinematicCollision2D = game.player.move_and_collide(axis*(half*2+120))
		check(collision != null and collision.get_collider() == gate,"sealed chamber stops the real player body: "+str(gate.definition["id"]))
		progress.modules[gate.definition["id"]] = 1
	game.world.refresh_organs()
	await settle()
	for gate: Node2D in game.world.gates:
		var rect: Rect2 = gate.definition["rect"]
		var axis := Vector2.RIGHT if rect.size.y > rect.size.x else Vector2.DOWN
		var half: float = (rect.size.x if axis == Vector2.RIGHT else rect.size.y)*0.5
		game.player.position = gate.position-axis*(half+60)
		check(game.player.move_and_collide(axis*(half*2+120)) == null,"restored chamber lets the real player pass: "+str(gate.definition["id"]))
	await game.start_mission(0)
	game.set_physics_process(false)
	game.player.set_physics_process(false)
	game.skills.set_physics_process(false)
	for group: String in ["enemies","nests","projectiles"]:
		for node: Node in get_nodes_in_group(group):
			node.queue_free()
	await settle()
	disable_solids(game.world)
	game.run_protocol = "normal"
	var interval: float = game.wave_interval()
	game.run_protocol = "swarm"
	check(is_equal_approx(game.wave_interval(),interval*0.8),"swarm protocol increases actual wave frequency")
	game.run_protocol = "predator"
	var predator: Node2D = game.spawn_enemy("shell",Vector2(1400,1300))
	check(is_equal_approx(predator.max_hp,GameData.ENEMIES["shell"]["hp"]*1.25),"predator protocol changes real spawned enemy health")
	predator.queue_free()
	game.run_protocol = "normal"
	game.player.position = Vector2(1000,900)
	game.player.traits = {"pierce":3}
	var targets: Array[Node2D] = []
	for offset: int in [60,120,180,300]:
		targets.append(enemy(game.player.position+Vector2(offset,0)))
	var wall := StaticBody2D.new()
	wall.position = game.player.position+Vector2(240,0)
	wall.collision_layer = 1
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(16,150)
	shape.shape = rect
	wall.add_child(shape)
	game.world.entities.add_child(wall)
	await settle()
	game.fire(game.player,Vector2.RIGHT,false)
	var shot: Node2D = get_nodes_in_group("projectiles")[0]
	shot.set_physics_process(false)
	shot._physics_process(0.65)
	check(targets[0].hp == 990 and targets[1].hp == 990 and targets[2].hp == 990,"penetrating shot damages three distinct native physics bodies in one tick")
	check(targets[3].hp == 1000,"piercing cannot pass through a wall")
	check(is_equal_approx(game.skills.energy,3.375),"piercing charges only actual damage at the existing slow energy rate")
	await settle()
	game.player.traits = {"multishot":1,"crit_chance":1.0,"crit_power":0.5}
	game.fire(game.player,Vector2.RIGHT,false)
	var pellets: Array[Node] = get_nodes_in_group("projectiles")
	check(pellets.size() == 3,"apex weapon emits three real projectiles")
	check(is_equal_approx(pellets[0].damage,13.0) and pellets[0].direction != pellets[2].direction,"critical damage and multishot coefficient apply to the actual spread")
	for node: Node in pellets:
		node.queue_free()
	game.player.traits = {"lifesteal":0.1}
	game.player.hp = 50
	game.gain_combat_energy(12,false)
	check(is_equal_approx(game.player.hp,51.2),"lifesteal restores health from actual primary damage")
	game.player.traits = {"skill_cost":0.1,"skill_cooldown":0.15,"dash_cooldown":0.15,"nova_apex":1}
	check(is_equal_approx(game.skills.cost(0),22.5) and game.skills.cost(4) == 70,"real skill prices include efficiency and ultimate capstone")
	check(is_equal_approx(game.skills.recharge(3),2.8),"dash and global recharge reductions stack with a safe cap")
	game.player.traits = {"skill_power":0.2,"spore_duration":1.5,"spore_power":0.24,"shield_power":0.24,"shield_duration":1.2,"shield_burst":1,"cast_heal":3}
	game.skills.energy = 100
	check(game.skills.cast(1,game.player.position+Vector2(0,100)),"mutated spore cast activates")
	var cloud: Node2D
	for effect: Node2D in get_nodes_in_group("skill_effects"):
		if effect.skill_index == 1:
			cloud = effect
	check(is_instance_valid(cloud) and is_equal_approx(cloud.duration,5.5) and is_equal_approx(cloud.power,10*1.2*0.55*1.24),"spore potency and lifetime mutate the actual field")
	cloud.set_physics_process(false)
	game.player.hp = 50
	check(game.skills.cast(2,game.player.position) and game.player.hp == 53,"casting heal applies to actual host HP")
	check(is_equal_approx(game.skills.shield_strength,55*1.24) and is_equal_approx(game.skills.shield_remaining,7.2),"shield ranks modify actual strength and duration")
	var target_hp: float = targets[0].hp
	var charge_before: float = game.skills.energy
	game.skills.absorb_damage(1000)
	check(is_equal_approx(target_hp-targets[0].hp,36) and game.skills.energy == charge_before,"broken shield retaliates without generating energy")
	game.player.traits = {"projectile_ward":0.09}
	game.player.hp = game.player.max_hp
	game.player.armor = 0.1
	game.player.invulnerable = 0
	game.player.take_damage(100,true)
	check(is_equal_approx(game.player.hp,game.player.max_hp-81.9),"projectile ward and normal armor reduce a real incoming hit")
	game.player.armor = 0
	game.player.traits = {"revive":1}
	game.player.hp = 10
	game.player.invulnerable = 0
	game.player.take_damage(1000)
	check(not game.player.dead and game.player.hp == game.player.max_hp*0.25 and game.player.revive_used,"second heart survives one real lethal hit")
	game.player.died.disconnect(game._host_died)
	game.player.invulnerable = 0
	game.player.take_damage(1000)
	check(game.player.dead,"second lethal hit cannot reuse the capstone")
	game.queue_free()
	await settle()
	for suffix: String in ["",".bak",".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path+suffix))
	print("EVOLUTION_TESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
