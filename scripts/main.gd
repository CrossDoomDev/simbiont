extends Node2D

var world: BioWorld
var player: BioActor
var camera: Camera2D
var ui: CanvasLayer
var near_organ: Node2D
var mode := "ship"
var modal := false
var transitioning := false
var mission_id := 0
var run_loot: Array = [0,0,0,0]
var run_time := 0.0
var run_id := ""
var nodes_destroyed := 0
var boss_spawned := false
var boss_defeated := false
var mutations: Array[String] = []
var fragments := 0
var next_mutation := 24
var spawn_clock := 2.0
var shake := 0.0
var fade_layer: CanvasLayer
var fade_rect: ColorRect
var recent_mouse := 0.0
var rng := RandomNumberGenerator.new()
var navigation_cache: AStarGrid2D

func _ready() -> void:
	rng.randomize()
	if "--capture" in OS.get_cmdline_user_args() or "--runtime-test" in OS.get_cmdline_user_args() or "--audio-test" in OS.get_cmdline_user_args():
		Progress.save_path = "user://symbiont_verification.json"
		Progress._defaults()
	_setup_world("ship")
	ui = load("res://scripts/ui.gd").new()
	ui.game = self
	add_child(ui)
	fade_layer = CanvasLayer.new()
	fade_layer.layer = 30
	add_child(fade_layer)
	fade_rect = ColorRect.new()
	fade_rect.color = Color(0.012,0.02,0.025,0)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade_layer.add_child(fade_rect)
	ui.open_title()
	if "--capture" in OS.get_cmdline_user_args():
		call_deferred("capture_screenshots")
	if "--runtime-test" in OS.get_cmdline_user_args():
		call_deferred("runtime_test")

func _setup_world(context: String) -> void:
	if is_instance_valid(world):
		remove_child(world)
		world.queue_free()
	near_organ = null
	mode = context
	var scene_path := "res://scenes/hub.tscn" if context == "ship" else ("res://scenes/forest.tscn" if mission_id == 0 else "res://scenes/swamp.tscn")
	world = load(scene_path).instantiate() as BioWorld
	world.name = "LivingShip" if context == "ship" else "AlienForest"
	add_child(world)
	player = BioActor.new()
	player.game = self
	player.kind = "host"
	player.position = world.spawn_point
	player.name = "HostAndSymbiont"
	world.entities.add_child(player)
	player.died.connect(_host_died)
	camera = Camera2D.new()
	camera.name = "FollowCamera"
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 9
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(world.bounds.end.x)
	camera.limit_bottom = int(world.bounds.end.y)
	player.add_child(camera)
	if context == "ship":
		camera.zoom = Vector2.ONE * 1.15
		camera.position.y = -140
	camera.make_current()
	camera.reset_smoothing()
	Audio.set_context("hub" if context == "ship" else "mission")
	if context == "ship":
		update_ship()

func _unhandled_input(event: InputEvent) -> void:
	if transitioning:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE:
			if ui.page in ["mutation","death"]:
				return
			if modal:
				ui.close()
			else:
				ui.open_pause()
			get_viewport().set_input_as_handled()
		elif event.physical_keycode == KEY_E and not modal:
			interact()
	if event is InputEventMouseMotion:
		recent_mouse = 2.0

func _physics_process(delta: float) -> void:
	if not is_instance_valid(player) or modal or transitioning or player.dead:
		return
	recent_mouse = maxf(0,recent_mouse-delta)
	var movement := Vector2(
		float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),
		float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))-float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
	if ui.touch.visible and ui.touch.left_value.length_squared()>0.01:
		movement = ui.touch.left_value
	player.move_input = movement
	player.manual_fire = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	player.manual_aim = Vector2.ZERO
	if player.manual_fire:
		player.manual_aim = get_global_mouse_position()-player.global_position
	if ui.touch.visible and ui.touch.right_value.length_squared()>0.06:
		player.manual_aim = ui.touch.right_value
		player.manual_fire = true
	shake = move_toward(shake,0,delta*16)
	camera.offset = Vector2(rng.randf_range(-shake,shake),rng.randf_range(-shake,shake))
	if mode == "ship":
		near_organ = null
		var best := 132.0
		for organ in world.organs:
			var distance := player.position.distance_to(organ.position)
			if distance<best:
				best = distance
				near_organ = organ
	else:
		run_time += delta
		spawn_clock -= delta
		if spawn_clock <= 0:
			spawn_clock = maxf(0.85,3.1-run_time/100)
			var amount := mini(5,1+int(run_time/70))
			for i in amount:
				_spawn_wave_enemy()
		if fragments>=next_mutation and mutations.size()<GameData.MUTATIONS.size() and not modal:
			_offer_mutation()

func set_modal(value: bool) -> void:
	modal = value
	if is_instance_valid(world):
		world.process_mode = Node.PROCESS_MODE_DISABLED if value else Node.PROCESS_MODE_INHERIT
	if is_instance_valid(player):
		player.move_input = Vector2.ZERO
		player.velocity = Vector2.ZERO
		player.manual_fire = false

func interact() -> void:
	if modal or not is_instance_valid(near_organ):
		return
	Audio.play_sfx("organ")
	var organ_id: String = near_organ.get_meta("organ_id")
	# A short native Line2D tendril establishes contact without separating the symbiote.
	var line := Line2D.new()
	line.width = 4
	line.default_color = Color("bb82d9")
	line.add_point(player.global_position)
	line.add_point(player.global_position.lerp(near_organ.global_position,0.5)+Vector2(10,-10))
	line.add_point(near_organ.global_position)
	line.z_index = 8
	add_child(line)
	var tween := create_tween()
	tween.tween_property(line,"modulate:a",0.0,0.6)
	tween.tween_callback(line.queue_free)
	match organ_id:
		"navigation": ui.open_map()
		"symbiont": ui.open_upgrades(false)
		"heart": ui.open_heart()
		"feeding": ui.open_upgrades(true)
		"storage": ui.open_storage()

func start_mission(id: int) -> void:
	if transitioning or not Progress.mission_unlocked(id):
		return
	mission_id = id
	transitioning = true
	ui.clear_overlay()
	ui.page = ""
	await _fade(1)
	_setup_world("mission")
	run_loot = [0,0,0,0]
	run_time = 0
	nodes_destroyed = 0
	boss_spawned = false
	boss_defeated = false
	mutations.clear()
	fragments = 0
	next_mutation = 24
	spawn_clock = 2.5
	run_id = "%s_%s" % [Time.get_unix_time_from_system(),rng.randi()]
	for i in int(GameData.MISSIONS[id]["nodes"]):
		var nest := BioNest.new()
		nest.game = self
		nest.index = i
		nest.position = world.nest_positions[i]
		nest.max_hp = float(GameData.MISSIONS[id]["node_hp"])
		nest.hp = nest.max_hp
		world.entities.add_child(nest)
	for i in 9:
		_spawn_wave_enemy()
	set_modal(false)
	await _fade(0)
	transitioning = false
	ui.toast("Цель: уничтожьте три гнездовых узла. Автоогонь активен.")

func _fade(alpha: float) -> void:
	fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	var tween := create_tween()
	tween.tween_property(fade_rect,"color:a",alpha,0.5)
	await tween.finished
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE if alpha == 0 else Control.MOUSE_FILTER_STOP

func objective_complete() -> bool:
	return nodes_destroyed>=int(GameData.MISSIONS[mission_id]["nodes"]) and (mission_id==0 or boss_defeated)

func finish_mission(success: bool) -> void:
	if mode != "mission" or transitioning or (success and not objective_complete()):
		return
	transitioning = true
	set_modal(true)
	var earned: Array = run_loot.duplicate()
	if not success:
		for i in 4:
			earned[i] = int(floor(float(earned[i])*GameData.DEATH_KEEP_RATIO))
	if not Progress.deposit_run(run_loot,success,run_id):
		transitioning = false
		ui.toast("Не удалось сохранить добычу. Повторите возвращение.")
		return
	var duration := run_time
	ui.clear_overlay()
	await _fade(1)
	_setup_world("ship")
	run_loot = [0,0,0,0]
	mutations.clear()
	set_modal(true)
	await _fade(0)
	transitioning = false
	Audio.play_sfx("success" if success else "organ")
	ui.open_results(success,earned,duration)

func return_to_fresh_ship() -> void:
	ui.clear_overlay()
	_setup_world("ship")
	run_loot = [0,0,0,0]
	mutations.clear()
	ui.open_title()

func update_ship() -> void:
	if mode != "ship" or not is_instance_valid(world):
		return
	for organ in world.organs:
		var id: String = organ.get_meta("organ_id")
		var level: int = int(Progress.modules.get({"heart":"heart","navigation":"navigation","symbiont":"regeneration","feeding":"storage","storage":"storage"}[id],0))
		var visual: Node2D = organ.get_node("LivingTissue")
		visual.modulate = Color.WHITE * (0.95+level*0.07)
		visual.modulate.a = 1
		var sprite: Sprite2D = visual.get_node("OrganSprite")
		sprite.scale = Vector2.ONE*(1.9+level*0.075 if id == "heart" else 1.45+level*0.04)
	if is_instance_valid(player):
		player.apply_stats()

func fire(source: BioActor, aim: Vector2, hostile: bool) -> void:
	if get_tree().get_nodes_in_group("projectiles").size()>=GameData.MAX_PROJECTILES:
		return
	var directions: Array[Vector2] = [aim]
	if not hostile and has_mutation("multishot"):
		directions = [aim.rotated(-0.09),aim.rotated(0.09)]
	for direction in directions:
		var bullet := BioProjectile.new()
		bullet.game = self
		bullet.direction = direction.normalized()
		bullet.hostile = hostile
		bullet.damage = source.damage
		bullet.speed = float(GameData.ENEMIES[source.kind].get("projectile_speed", 135.0)) if hostile else 550.0
		bullet.life = 5.5 if hostile else 1.25
		bullet.position = source.global_position + direction*(source.radius+12)
		world.entities.add_child(bullet)
		bullet.add_to_group("projectiles")
	if not hostile:
		Audio.play_sfx("shoot")
		burst(source.position+aim*30,Color("afffd5"),2)

func nearest_enemy(point: Vector2, detection: float) -> Node2D:
	var target: Node2D
	var best := detection*detection
	var nodes: Array = get_tree().get_nodes_in_group("enemies")+get_tree().get_nodes_in_group("nests")
	for enemy: Node2D in nodes:
		if enemy.dead:
			continue
		var distance := point.distance_squared_to(enemy.global_position)
		if distance<best:
			var ray := PhysicsRayQueryParameters2D.create(point,enemy.global_position,1)
			var hit := get_world_2d().direct_space_state.intersect_ray(ray)
			if hit.is_empty() or hit.get("collider") == enemy:
				target = enemy
				best = distance
	return target

func _spawn_wave_enemy() -> void:
	if get_tree().get_nodes_in_group("enemies").size()>=GameData.MAX_ENEMIES:
		return
	for attempt in 16:
		var direction := Vector2.RIGHT.rotated(rng.randf()*TAU)
		var point := player.position+direction*rng.randf_range(790,1050)
		if not world.is_walkable(point,35):
			continue
		var kinds: Array[String] = ["crawler","crawler","shell","ranged"]
		var enemy_kind := kinds[rng.randi_range(0,3)]
		if run_time<20 and rng.randf()<0.6:
			enemy_kind = "crawler"
		spawn_enemy(enemy_kind,point)
		return

func spawn_enemy(kind: String, point: Vector2) -> BioActor:
	var enemy := BioActor.new()
	enemy.game = self
	enemy.kind = kind
	enemy.position = point
	world.entities.add_child(enemy)
	enemy.died.connect(_enemy_died)
	if mission_id==1:
		enemy.hp *= 1.3
		enemy.max_hp *= 1.3
	if kind == "guardian" and mode == "mission":
		Audio.set_context("boss")
	return enemy

func _enemy_died(enemy: BioActor) -> void:
	Audio.play_sfx("enemy_die")
	burst(enemy.position,Color("bb617b"),8)
	var loot: Array = GameData.ENEMIES[enemy.kind]["loot"]
	_drop_loot(enemy.position,loot)
	if enemy.kind == "guardian":
		boss_defeated = true
		if mode == "mission":
			Audio.set_context("mission")
		Audio.play_sfx("objective")
		ui.toast("Страж уничтожен. Органическое ядро выпало на землю.")
		if objective_complete():
			ui.toast("Цель выполнена. Вернуться: Esc → Завершить миссию.")

func _drop_loot(point: Vector2, loot: Array) -> void:
	for i in mini(4,loot.size()):
		if int(loot[i])<=0:
			continue
		var drop := BioLoot.new()
		drop.game = self
		drop.resource_type = i
		drop.amount = int(loot[i])
		drop.position = point+Vector2(rng.randf_range(-20,20),rng.randf_range(-20,20))
		world.entities.add_child(drop)

func collect(type: int, amount: int) -> void:
	run_loot[type] += amount
	fragments += amount
	Audio.play_sfx("pickup")
	float_text(player.position+Vector2(0,-38),"+%d" % amount,GameData.RESOURCES[type]["color"])

func nest_destroyed(nest: BioNest) -> void:
	nodes_destroyed += 1
	burst(nest.position,Color("e68c8a"),18)
	Audio.play_sfx("objective")
	shake = 8
	_drop_loot(nest.position,[12,3,4,0])
	if nodes_destroyed>=2 and not boss_spawned:
		boss_spawned = true
		var position := nest.position+Vector2(170,100)
		if not world.is_walkable(position,55):
			position = nest.position
		spawn_enemy("guardian",position)
		Audio.play_sfx("boss")
		ui.toast("Искажённый страж услышал разрушение гнезда.")
	if objective_complete():
		ui.toast("Цель выполнена. Продолжайте сбор или вернитесь через Esc.")
	else:
		ui.toast("Гнездовой узел уничтожен  ·  %d / 3" % nodes_destroyed)

func _host_died(_actor: BioActor) -> void:
	Audio.play_sfx("death")
	ui.open_death()

func has_mutation(id: String) -> bool:
	return mutations.has(id)

func mutation_factor(id: String) -> float:
	if id == "fire_rate":
		return 1.0
	return 1.0

func _offer_mutation() -> void:
	var available: Array = []
	for mutation: Dictionary in GameData.MUTATIONS:
		if not mutations.has(mutation["id"]):
			available.append(mutation)
	available.shuffle()
	ui.open_mutations(available.slice(0,3))
	next_mutation += 35+mutations.size()*12

func select_mutation(id: String) -> void:
	if not has_mutation(id):
		mutations.append(id)
	Audio.play_sfx("upgrade")
	ui.close()
	ui.toast("Адаптация принята. Действует до возвращения.")

func chain_hit(source: Node2D, amount: float) -> void:
	var best: Node2D
	var distance := 150.0
	for target: Node2D in get_tree().get_nodes_in_group("enemies"):
		if target == source or target.dead:
			continue
		var d := source.global_position.distance_to(target.global_position)
		if d<distance:
			distance = d
			best = target
	if best != null:
		var line := Line2D.new()
		line.width = 2
		line.default_color = Color("9ed9ee")
		line.points = PackedVector2Array([source.global_position,source.global_position.lerp(best.global_position,0.5)+Vector2(0,-8),best.global_position])
		world.entities.add_child(line)
		line.z_index = 6
		best.take_damage(amount)
		var tween := create_tween()
		tween.tween_property(line,"modulate:a",0,0.18)
		tween.tween_callback(line.queue_free)

func burst(point: Vector2, color: Color, count: int) -> void:
	if get_tree().get_nodes_in_group("effects").size()>110:
		return
	for i in count:
		var sprite := Sprite2D.new()
		sprite.texture = BioVisual.glow()
		sprite.position = point
		sprite.scale = Vector2.ONE*rng.randf_range(0.04,0.09)
		sprite.modulate = color
		sprite.z_index = 6
		world.entities.add_child(sprite)
		sprite.add_to_group("effects")
		var tween := sprite.create_tween().set_parallel(true)
		tween.tween_property(sprite,"position",point+Vector2.RIGHT.rotated(rng.randf()*TAU)*rng.randf_range(12,65),0.35)
		tween.tween_property(sprite,"modulate:a",0.0,0.35)
		tween.chain().tween_callback(sprite.queue_free)

func float_text(point: Vector2, value: String, color: Color) -> void:
	if get_tree().get_nodes_in_group("float_text").size()>32:
		return
	var label := Label.new()
	label.text = value
	label.position = point-Vector2(15,15)
	label.z_index = 8
	label.add_theme_font_override("font",load("res://assets/fonts/semibold.tres"))
	label.add_theme_font_size_override("font_size",17)
	label.add_theme_color_override("font_color",color)
	label.add_theme_color_override("font_shadow_color",Color.BLACK)
	label.add_theme_constant_override("shadow_outline_size",4)
	world.entities.add_child(label)
	label.add_to_group("float_text")
	var tween := label.create_tween().set_parallel(true)
	tween.tween_property(label,"position:y",point.y-65,0.65)
	tween.tween_property(label,"modulate:a",0,0.65)
	tween.chain().tween_callback(label.queue_free)

func capture_screenshots() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(0.3).timeout
	await _capture("01_main_menu")
	ui.close()
	await _capture("02_living_ship")
	ui.open_map()
	await _capture("03_neural_map")
	ui.open_upgrades(false)
	await _capture("04_symbiont_upgrades")
	await start_mission(0)
	player.position = Vector2(930,430)
	camera.reset_smoothing()
	for i in 5:
		spawn_enemy(["crawler","shell","ranged"][i%3],player.position+Vector2(180+i*65,randf_range(-180,180)))
	await get_tree().create_timer(1.5).timeout
	await _capture("05_forest_combat")
	set_modal(true)
	ui.open_mutations(GameData.MUTATIONS.slice(0,3))
	await _capture("06_mutation")
	ui.close()
	# Capture verified mission completion UI while preserving normal return rules.
	for nest: BioNest in get_tree().get_nodes_in_group("nests"):
		nest.take_damage(9999)
	ui.open_pause()
	await _capture("07_objective_complete")
	await finish_mission(true)
	await _capture("08_mission_results")
	print("SCREENSHOTS_OK: 8 actual Godot viewport captures")
	_end_verification(0)

func _capture(name: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path := "res://artifacts/screenshots/"+name+".png"
	get_viewport().get_texture().get_image().save_png(path)
	print("CAPTURE: "+path)

func runtime_test() -> void:
	var failures := 0
	ui.close()
	await get_tree().physics_frame
	if world.floor_map.get_used_cells().size()<500: failures+=1
	if world.organs.size()!=5: failures+=1
	if not player.anim is AnimatedSprite2D: failures+=1
	if not world.walls.tile_set.get_physics_layers_count()>0: failures+=1
	var start := player.position
	player.move_input = Vector2.RIGHT
	# Root input controls are bypassed by placing modal flag while leaving world active.
	modal = true
	await get_tree().create_timer(0.3).timeout
	if player.position.distance_to(start)<20: failures+=1
	player.move_input = Vector2.ZERO
	modal = false
	await start_mission(0)
	if objective_complete(): failures+=1
	var before: Array = Progress.bank.duplicate()
	await finish_mission(true)
	if mode != "mission": failures+=1
	if Progress.bank != before: failures+=1
	var enemy := spawn_enemy("crawler",player.position+Vector2(120,0))
	var enemy_hp := enemy.hp
	player.manual_fire = true
	player.manual_aim = Vector2.RIGHT
	modal = true
	await get_tree().create_timer(1.8).timeout
	if is_instance_valid(enemy) and enemy.hp>=enemy_hp: failures+=1
	modal = false
	for nest: BioNest in get_tree().get_nodes_in_group("nests"):
		nest.take_damage(9999)
	if not objective_complete(): failures+=1
	if nodes_destroyed!=3: failures+=1
	collect(0,20)
	collect(2,6)
	var loot_before: Array = run_loot.duplicate()
	await finish_mission(true)
	if mode!="ship": failures+=1
	for i in 4:
		if Progress.bank[i]!=before[i]+loot_before[i]: failures+=1
	if not mutations.is_empty(): failures+=1
	ui.close()
	await start_mission(0)
	player.take_damage(10000)
	if ui.page!="death": failures+=1
	if not modal: failures+=1
	await finish_mission(false)
	if mode!="ship": failures+=1
	print("RUNTIME_TESTS: 21 checks, %d failures" % failures)
	_end_verification(1 if failures>0 else 0)

func _end_verification(exit_code: int) -> void:
	set_process(false)
	set_physics_process(false)
	var tree := get_tree()
	var shutdown := tree.create_tween()
	shutdown.tween_callback(queue_free)
	shutdown.tween_interval(0.3)
	shutdown.tween_callback(func(): tree.quit(exit_code))
