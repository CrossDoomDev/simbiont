extends SceneTree
var checks := 0
var failures := 0
var game: Node2D
var progress: Node
var Projectile: Script
var Actor: Script

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("SKILL_CHECK_FAILED: "+message)

func settle(count: int = 6) -> void:
	for i: int in count:
		await physics_frame
		await process_frame

func disable_solids(node: Node) -> void:
	if node is TileMapLayer:
		node.collision_enabled = false
	if node is CollisionObject2D and not node is CharacterBody2D:
		node.collision_layer = 0
	for child: Node in node.get_children():
		disable_solids(child)

func enemy(point: Vector2, kind: String = "crawler") -> Node2D:
	var target: Node2D = Actor.new()
	target.game = game
	target.kind = kind
	target.position = point
	game.world.entities.add_child(target)
	target.set_physics_process(false)
	target.hp = 200
	target.max_hp = 200
	target.armor = 0
	return target

func bullet(point: Vector2, hostile: bool = false) -> Node2D:
	var shot: Node2D = Projectile.new()
	shot.game = game
	shot.position = point
	shot.direction = Vector2.RIGHT
	shot.hostile = hostile
	shot.speed = 1000
	shot.damage = 10
	shot.remaining_distance = 100
	game.world.entities.add_child(shot)
	shot.add_to_group("projectiles")
	shot.set_physics_process(false)
	return shot

func clear_targets() -> void:
	for group: String in ["enemies","nests","projectiles","skill_effects"]:
		for node: Node in get_nodes_in_group(group):
			node.queue_free()
	await settle(2)

func prepare() -> void:
	game.skills.reset()
	game.skills.energy = 100
	game.player.position = Vector2(1280,960)
	game.player.hp = game.player.max_hp
	game.player.invulnerable = 0

func wall(point: Vector2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.position = point
	body.collision_layer = 1
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(16,180)
	shape.shape = rectangle
	body.add_child(shape)
	game.world.entities.add_child(body)
	return body

func _run() -> void:
	Actor = load("res://scripts/actor.gd")
	Projectile = load("res://scripts/projectile.gd")
	root.size = Vector2i(1280,720)
	progress = root.get_node("Progress")
	progress.save_path = "user://symbiont_skills_test.json"
	progress._defaults()
	progress.settings["autofire"] = false
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await settle()
	check(not game.skills.cast(0,Vector2.ZERO) and game.skills.energy == 0,"skills are blocked on ship")
	game.ui.close()
	await game.start_mission(0)
	game.set_physics_process(false)
	game.skills.set_physics_process(false)
	game.player.set_physics_process(false)
	await clear_targets()
	disable_solids(game.world)
	prepare()
	check(not game.skills.cast(-1,Vector2.ZERO) and not game.skills.cast(8,Vector2.ZERO),"invalid slot indexes cannot change game state")
	game.skills.energy = 0
	check(not game.skills.cast(0,game.player.position) and game.skills.cooldowns[0] == 0,"not enough energy does not start cooldown")
	var origin: Vector2 = game.player.position
	var target := enemy(origin+Vector2(50,0))
	target.armor = 0.2
	var shot := bullet(origin)
	await settle(2)
	shot._physics_process(0.05)
	check(is_equal_approx(target.hp,192.0) and is_equal_approx(game.skills.energy,3.6),"primary hits charge from actual damage after armor")
	shot._physics_process(0.05)
	check(is_equal_approx(game.skills.energy,3.6),"spent projectile cannot award energy twice")
	target.hp = 2
	var finishing := bullet(origin)
	await settle(2)
	finishing._physics_process(0.05)
	check(is_equal_approx(game.skills.energy,10.5),"overkill awards only remaining health plus one kill bonus")
	game.skills.gain_damage(99999,true)
	check(game.skills.energy == 100,"energy is capped at 100")
	await clear_targets()
	prepare()
	var near := enemy(origin+Vector2(50,0))
	var far := enemy(origin+Vector2(220,0))
	check(game.skills.cast(0,origin),"neural wave activates")
	check(is_equal_approx(near.hp,175) and far.hp == 200 and near.skill_slow_ratio < 1,"wave damages and suppresses only nearby enemies")
	check(game.skills.energy == 75 and game.skills.cooldowns[0] == 5,"wave spends its cost and sets its independent cooldown")
	near._physics_process(0.8)
	check(near.skill_slow_ratio == 1,"temporary suppression wears off")
	check(not game.skills.cast(0,origin) and game.skills.energy == 75,"cooldown blocks repeated casts without consuming energy")
	game.skills._physics_process(1)
	check(game.skills.cooldowns[0] == 4,"cooldowns tick during combat")
	game.ui.open_pause()
	game.skills._physics_process(1)
	check(game.skills.cooldowns[0] == 4,"pause freezes cooldowns")
	game.ui.close()
	var guarded := enemy(origin+Vector2(0,40),"guardian")
	guarded.apply_skill_control(2,0.1)
	check(guarded.skill_slow_ratio == 1,"boss telegraph speed is not altered by crowd control")
	await clear_targets()
	prepare()
	near = enemy(origin+Vector2(100,0))
	far = enemy(origin+Vector2(-150,0))
	check(game.skills.cast(1,origin+Vector2(100,0)),"spore area activates at aim point")
	var cloud: BioSkillEffect
	for effect: BioSkillEffect in get_nodes_in_group("skill_effects"):
		cloud = effect
	cloud.set_physics_process(false)
	var before: float = near.hp
	cloud._physics_process(0.5)
	check(near.hp < before and far.hp == 200,"spores apply periodic area damage")
	check(near.skill_slow_ratio < 1,"spores slow ordinary enemies")
	check(game.skills.energy == 65,"skill damage does not generate energy for itself")
	check(cloud.sprite.sprite_frames.get_frame_count("effect_1") == 4,"spores use four generated native animation frames")
	var after_tick: float = near.hp
	cloud._physics_process(4.0)
	check(cloud.is_queued_for_deletion() and near.hp == after_tick,"expired spore field cannot deal an extra tick")
	await clear_targets()
	prepare()
	check(game.skills.cast(2,origin),"chitin shield activates")
	check(game.skills.shield_strength == 55 and game.skills.shield_remaining == 6,"shield strength scales with maximum health")
	game.player.take_damage(20)
	check(game.player.hp == 100 and game.skills.shield_strength == 35,"shield absorbs incoming damage before health")
	game.player.invulnerable = 0
	game.player.take_damage(50)
	check(game.player.hp == 85 and game.skills.shield_strength == 0,"excess damage passes through broken shield")
	prepare()
	game.skills.cast(2,origin)
	game.skills._physics_process(6.1)
	check(game.skills.shield_strength == 0 and game.skills.shield_remaining == 0,"shield expires without leaving permanent protection")
	await clear_targets()
	prepare()
	near = enemy(origin+Vector2(90,0))
	check(game.skills.cast(3,origin+Vector2(200,0)),"predatory dash activates")
	check(game.player.position.x > origin.x+100 and near.hp == 182,"dash moves host and strikes along the actual path")
	check(game.player.invulnerable > 0 and game.skills.energy == 80,"dash grants short protection and consumes energy")
	await clear_targets()
	prepare()
	var barrier := wall(origin+Vector2(80,0))
	await settle(2)
	check(game.skills.cast(3,origin+Vector2(300,0)),"dash can travel the free part of a blocked path")
	check(game.player.position.x < barrier.position.x-14,"dash cannot cross solid walls")
	game.skills.cooldowns[3] = 0
	var remaining: float = game.skills.energy
	check(not game.skills.cast(3,origin+Vector2(300,0)) and game.skills.energy == remaining,"fully blocked dash is free and does not start cooldown")
	barrier.queue_free()
	await clear_targets()
	prepare()
	near = enemy(origin+Vector2(70,0))
	far = enemy(origin+Vector2(400,0))
	var hostile := bullet(origin+Vector2(100,30),true)
	var friendly := bullet(origin+Vector2(100,60))
	check(game.skills.cast(4,origin),"right-mouse ability spends a full charge")
	check(game.skills.energy == 0 and near.hp == 140 and far.hp == 200,"rupture applies high local damage without self recharge")
	check(hostile.is_queued_for_deletion() and not friendly.is_queued_for_deletion(),"rupture removes hostile projectiles and preserves friendly shots")
	await clear_targets()
	prepare()
	barrier = wall(origin+Vector2(65,0))
	near = enemy(origin+Vector2(120,0))
	await settle(2)
	game.skills.cast(0,origin)
	check(near.hp == 200,"area damage does not pass through a wall")
	barrier.queue_free()
	await clear_targets()
	prepare()
	game.player.dead = true
	check(not game.skills.cast(4,origin) and game.skills.energy == 100,"dead host cannot cast")
	game.player.dead = false
	# Input uses the actual viewport pipeline, not a direct cast call.
	var key := InputEventKey.new()
	key.physical_keycode = KEY_1
	key.keycode = KEY_1
	key.pressed = true
	root.push_input(key,true)
	check(game.skills.energy == 75,"physical key 1 activates the first slot")
	game.skills.energy = 100
	var mouse := InputEventMouseButton.new()
	mouse.position = Vector2(640,360)
	mouse.global_position = mouse.position
	mouse.button_index = MOUSE_BUTTON_RIGHT
	mouse.pressed = true
	root.push_input(mouse,true)
	check(game.skills.energy == 0 and game.skills.cooldowns[4] > 0,"right mouse activates the dedicated ability")
	for dimensions: Vector2i in [Vector2i(640,360),Vector2i(640,960),Vector2i(800,600),Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size = dimensions
		for touch: bool in [false,true]:
			progress.settings["touch"] = touch
			game.ui.automatic_touch = false
			await settle(3)
			var bar: Control = game.ui.skill_bar
			var rect := Rect2(Vector2.ZERO,Vector2(dimensions))
			check(rect.encloses(bar.get_global_rect()),"skill bar fits %s, touch=%s" % [dimensions,touch])
			var contained := true
			for b: Button in bar.buttons:
				contained = contained and bar.get_global_rect().encloses(b.get_global_rect())
			check(contained,"all five slots stay inside panel")
			check(not bar.get_global_rect().intersects(game.ui.hp_panel.get_global_rect()) and not bar.get_global_rect().intersects(game.ui.task_panel.get_global_rect()),"skills do not cover health or objective")
			if touch:
				var sticks: Control = game.ui.touch
				var free := true
				for center: Vector2 in [sticks.left_center,sticks.right_center]:
					free = free and not bar.get_global_rect().intersects(Rect2(center-Vector2.ONE*(sticks.radius+10),Vector2.ONE*(sticks.radius+10)*2))
				check(free,"skill buttons remain between touch sticks")
	root.size = Vector2i(640,360)
	progress.settings["touch"] = true
	game.skills.energy = 100
	game.skills.cooldowns[0] = 0
	await settle(3)
	var slot: Button = game.ui.skill_bar.buttons[0]
	var tap_point: Vector2 = slot.get_global_rect().position + Vector2(2,23)
	var finger := InputEventScreenTouch.new()
	finger.index = 0
	finger.position = root.get_screen_transform() * tap_point
	finger.pressed = true
	Input.parse_input_event(finger)
	Input.flush_buffered_events()
	await settle(2)
	check(game.ui.touch.left_id == -1 and game.ui.touch.right_id == -1,"touching a skill does not seize either movement/aim stick")
	finger = InputEventScreenTouch.new()
	finger.index = 0
	finger.position = root.get_screen_transform() * tap_point
	finger.pressed = false
	Input.parse_input_event(finger)
	Input.flush_buffered_events()
	await settle(2)
	check(game.skills.energy == 75,"native touchscreen tap activates the skill button")
	game.skills.energy = 100
	game.skills.cooldowns[0] = 0
	game.ui.skill_bar.buttons[0].pressed.emit()
	check(game.skills.energy == 75,"HUD slot also activates its ability")
	game._setup_world("ship")
	check(game.skills.energy == 0 and game.skills.shield_strength == 0 and game.skills.cooldowns[0] == 0,"returning to ship clears volatile combat state")
	game.queue_free()
	await settle(3)
	print("SKILL_TESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures > 0 else 0)
