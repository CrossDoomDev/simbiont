extends SceneTree
## Guardian state transitions and healing balance in a real Godot physics world.
## The arena isolates combat from mission spawns, UI and personal save files.

class CombatArena extends Node2D:
	var mode: String = "mission"
	var player: Node2D
	var shots: Array[Vector2] = []
	var shake: float = 0.0

	func nearest_enemy(_point: Vector2, _distance: float) -> Node2D:
		return null

	func float_text(_point: Vector2, _text: String, _color: Color) -> void:
		pass

	func burst(_point: Vector2, _color: Color, _count: int = 4) -> void:
		pass

	func fire(_source: Node2D, direction: Vector2, hostile: bool) -> void:
		if hostile:
			shots.append(direction.normalized())

var checks: int = 0
var failures: int = 0
var arena: CombatArena
var progress: Node

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("COMBAT_CHECK_FAILED: " + message)

func _frames(count: int = 3) -> void:
	for i: int in range(count):
		await physics_frame
		await process_frame

func _actor(kind: String, point: Vector2) -> Node2D:
	var actor: Node2D = load("res://scripts/actor.gd").new() as Node2D
	actor.kind = kind
	actor.game = arena
	actor.position = point
	arena.add_child(actor)
	actor.set_physics_process(false)
	return actor

func _host_pose_checks() -> void:
	var host: Node2D = arena.player
	host.manual_fire = true
	host.manual_aim = Vector2.RIGHT
	host.shot_clock = 0.0
	host._physics_process(0.01)
	check(host.anim.animation == "attack_2" and is_equal_approx(host.attack_pose_remaining,1.0), "shot raises arm for one second")
	host.manual_fire = false
	host._physics_process(0.30)
	check(host.anim.animation == "attack_2" and not host.armed_walk, "stationary arm stays raised between ordinary shots")
	host.move_input = Vector2.DOWN
	host._physics_process(0.30)
	check(host.anim.animation == "walk_2" and host.armed_walk and host.velocity.y > 0.0, "moving host keeps armed pose without lowering arm")
	host.manual_fire = true
	host._physics_process(0.01)
	check(is_equal_approx(host.attack_pose_remaining,1.0), "next shot renews full hold duration")
	host.manual_fire = false
	host.manual_aim = Vector2.UP
	host._physics_process(0.30)
	check(host.anim.animation == "walk_3" and host.armed_walk, "held running pose follows changed aim")
	host._physics_process(0.71)
	check(host.anim.animation == "walk_3" and not host.armed_walk, "one second without shots releases running pose")
	host.move_input = Vector2.ZERO
	host._physics_process(0.01)
	check(host.anim.animation == "idle_3", "stationary host returns to idle after hold")
	host.manual_fire = true
	host.shot_clock = 0.0
	host._physics_process(0.01)
	arena.mode = "ship"
	host._physics_process(0.01)
	check(host.attack_pose_remaining == 0.0 and host.anim.animation == "idle_3", "ship immediately resets armed pose")
	arena.mode = "mission"
	host.manual_fire = false
	host.manual_aim = Vector2.ZERO
	host.position = Vector2.ZERO
	host.shot_clock = 0.0

func _gait_continuity_checks() -> void:
	var host: Node2D = arena.player
	host.move_input = Vector2.DOWN
	host.manual_fire = true
	host.shot_clock = 0.0
	var second_step_seen := false
	var phase_preserved := true
	for tick: int in 40:
		host.manual_aim = [Vector2.RIGHT,Vector2.UP,Vector2.LEFT,Vector2.DOWN][tick % 4]
		var previous_frame: int = host.anim.frame
		var previous_progress: float = host.anim.frame_progress
		var was_walking: bool = host.anim.animation.begins_with("walk_")
		host._physics_process(1.0 / 60.0)
		if was_walking:
			phase_preserved = phase_preserved and host.anim.frame == previous_frame and is_equal_approx(host.anim.frame_progress,previous_progress)
		await physics_frame
		await process_frame
		second_step_seen = second_step_seen or host.anim.frame == 1
	check(second_step_seen, "steps keep advancing when aiming direction switches every physics tick")
	check(phase_preserved, "all four aim changes preserve both gait frame and fractional progress")
	host.manual_fire = false
	host.manual_aim = Vector2.ZERO
	host.move_input = Vector2.ZERO
	host.position = Vector2.ZERO
	host.attack_pose_remaining = 0.0
	host.shot_clock = 0.0

func _regen_checks() -> void:
	var host: Node2D = arena.player
	progress.upgrades["regeneration"] = 3
	progress.modules["regeneration"] = 4
	host.apply_stats()
	check(is_equal_approx(host.max_hp, 165.0), "existing permanent health upgrades retain their maximum HP benefit")
	check(is_equal_approx(host.permanent_regen, 0.25), "fully developed permanent healing is only 0.25 HP/s")
	host.hp = 100.0
	host._host_tick(10.0)
	check(is_equal_approx(host.hp, 102.5), "ten undamaged seconds restore 2.5 HP with all permanent upgrades")
	host.invulnerable = 0.0
	host.take_damage(10.0)
	var hurt_hp: float = host.hp
	host._host_tick(4.9)
	check(is_equal_approx(host.hp, hurt_hp), "healing stays disabled throughout the five-second after-hit delay")
	host._host_tick(0.3)
	check(is_equal_approx(host.hp, hurt_hp + 0.05), "a frame crossing the delay heals only its undamaged remainder")
	for i: int in range(3):
		host.invulnerable = 0.0
		host.take_damage(2.0)
		var health_after_hit: float = host.hp
		host._host_tick(2.0)
		check(is_equal_approx(host.hp, health_after_hit), "repeated attacks restart the healing delay, hit %d" % i)
	host.regen_delay_remaining = 0.0
	host.hp = host.max_hp - 0.1
	host._host_tick(10.0)
	check(is_equal_approx(host.hp, host.max_hp), "slow healing never exceeds maximum health")
	host.dead = true
	host.hp = 0.0
	host._physics_process(20.0)
	check(host.hp == 0.0, "a dead actor cannot regenerate")
	host.dead = false
	host.hp = host.max_hp
	host.invulnerable = 0.0

func _begin_attack(boss: Node2D, sequence: int) -> void:
	boss.guardian_sequence = sequence
	boss.cooldown = 0.0
	boss._start_guardian_attack()

func _release_windup(boss: Node2D) -> void:
	boss._guardian_tick(boss.guardian_state_time + 0.001, arena.player.position - boss.position)

func _guardian_checks() -> void:
	var host: Node2D = arena.player
	var boss: Node2D = _actor("guardian", Vector2(200, 400))
	check(boss.speed >= 130.0 and boss.enemy_attack_interval <= 1.35, "guardian pursues twice as fast and starts attacks more frequently")
	host.position = Vector2(500, 400)
	host.regen_delay_remaining = 0.0
	host.hp = host.max_hp
	_begin_attack(boss, 0)
	check(boss.guardian_state == "windup" and boss.guardian_attack == "dash", "guardian announces its charge before moving")
	check(boss.guardian_state_time >= 0.75 and boss.velocity.is_zero_approx(), "charge leaves a readable stationary dodge window")
	var locked_target: Vector2 = boss.target_point
	var locked_direction: Vector2 = boss.guardian_dash_direction
	host.position += Vector2(0, 160)
	boss._guardian_tick(0.4, host.position - boss.position)
	check(boss.target_point == locked_target and boss.guardian_dash_direction == locked_direction, "charge locks its direction so sideways movement can evade it")
	_release_windup(boss)
	check(boss.guardian_state == "dash" and boss.velocity.length() > host.speed * 2.0, "telegraphed charge accelerates far beyond normal pursuit speed")
	var health_before_dodge: float = host.hp
	boss.set_physics_process(true)
	await create_timer(0.8).timeout
	boss.set_physics_process(false)
	check(host.hp == health_before_dodge and boss.position.x > 450.0 and absf(boss.position.y - 400.0) < 1.0, "a real sideways dodge avoids the fast charge without homing correction")
	check(boss.guardian_state == "recovery" and boss.velocity.is_zero_approx(), "charge ends with a punishable recovery window")
	# A full collision layer blocks the charge; it cannot teleport through scenery.
	var wall := StaticBody2D.new()
	wall.position = Vector2(350, 700)
	wall.collision_layer = 1
	var wall_shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(16, 240)
	wall_shape.shape = rectangle
	wall.add_child(wall_shape)
	arena.add_child(wall)
	boss.position = Vector2(200, 700)
	host.position = Vector2(600, 700)
	await _frames()
	_begin_attack(boss, 0)
	_release_windup(boss)
	boss.set_physics_process(true)
	await create_timer(0.5).timeout
	boss.set_physics_process(false)
	check(boss.position.x < 310.0, "real wall physics stops the charge before its solid boundary")
	check(boss.guardian_state == "recovery" and boss.velocity.is_zero_approx(), "a blocked charge enters recovery instead of sliding along the wall")
	wall.queue_free()
	await _frames()
	# Charge contact must hurt more than normal pursuit, and grace prevents stacking.
	boss.position = Vector2(200, 1000)
	boss.velocity = Vector2.ZERO
	boss.move_and_slide()
	host.position = Vector2(410, 1000)
	host.invulnerable = 0.0
	host.hp = host.max_hp
	boss._contact_clock = 0.0
	_begin_attack(boss, 0)
	_release_windup(boss)
	var charge_health: float = host.hp
	boss.set_physics_process(true)
	await create_timer(0.65).timeout
	boss.set_physics_process(false)
	check(is_equal_approx(charge_health - host.hp, 30.0), "an unevaded real charge deals its configured 30 damage exactly once (damage %.2f, position %s, state %s)" % [charge_health - host.hp, boss.position, boss.guardian_state])
	# Fan attacks keep distinct aim gaps and deliver multiple separated bursts.
	boss.position = Vector2(200, 400)
	host.position = Vector2(500, 400)
	arena.shots.clear()
	_begin_attack(boss, 1)
	check(boss.guardian_attack == "fan" and arena.shots.is_empty(), "fan attack warns before releasing projectiles")
	_release_windup(boss)
	boss._guardian_tick(0.01, host.position - boss.position)
	check(arena.shots.size() == 7 and absf(arena.shots[0].angle_to(arena.shots[6])) > 1.0, "first fan sends seven genuinely distinct projectile directions")
	boss._guardian_tick(0.30, host.position - boss.position)
	boss._guardian_tick(0.21, host.position - boss.position)
	check(arena.shots.size() == 21 and boss.guardian_state == "recovery", "normal fan fires three separated bursts then exposes the boss")
	# The ground slam has a finite radius and a distinct radial projectile pattern.
	arena.shots.clear()
	host.position = boss.position + Vector2(130, 0)
	host.invulnerable = 0.0
	var slam_health: float = host.hp
	_begin_attack(boss, 2)
	check(boss.guardian_attack == "slam" and boss.guardian_state_time >= 1.0, "ground slam gives the longest visible escape warning")
	_release_windup(boss)
	check(is_equal_approx(slam_health - host.hp, 28.0), "remaining in the slam area causes configured burst damage")
	check(arena.shots.size() == 14 and arena.shots[0].dot(arena.shots[7]) < -0.99, "slam emits a full radial wave rather than another aimed fan")
	host.position = boss.position + Vector2(180, 0)
	host.invulnerable = 0.0
	var safe_health: float = host.hp
	_begin_attack(boss, 2)
	_release_windup(boss)
	check(host.hp == safe_health, "leaving the marked slam radius prevents its direct damage")
	# Crossing the phase threshold must never invalidate an already shown warning.
	boss.hp = boss.max_hp * 0.75
	_begin_attack(boss, 0)
	var warned_dash_speed: float = boss.guardian_dash_speed
	var warned_dash_reach: float = warned_dash_speed * float(GameData.GUARDIAN_ATTACKS["dash"]["duration"])
	boss._guardian_tick(0.3, host.position - boss.position)
	boss.hp = boss.max_hp * 0.5
	boss._guardian_tick(0.1, host.position - boss.position)
	check(not boss.guardian_attack_enraged and boss.guardian_dash_speed == warned_dash_speed, "crossing half health during charge warning preserves its announced speed")
	_release_windup(boss)
	check(is_equal_approx(boss.velocity.length() * boss.guardian_state_time, warned_dash_reach), "charge keeps its originally warned reach when phase changes during windup")
	boss.hp = boss.max_hp * 0.75
	_begin_attack(boss, 0)
	_release_windup(boss)
	boss._guardian_tick(0.1, host.position - boss.position)
	var remaining_dash_time: float = boss.guardian_state_time
	boss.hp = boss.max_hp * 0.5
	boss._guardian_tick(0.1, host.position - boss.position)
	check(is_equal_approx(boss.velocity.length(), warned_dash_speed) and is_equal_approx(boss.guardian_state_time, remaining_dash_time - 0.1), "crossing half health mid-charge changes neither speed nor remaining charge duration")
	arena.shots.clear()
	boss.hp = boss.max_hp * 0.75
	_begin_attack(boss, 1)
	boss.hp = boss.max_hp * 0.5
	_release_windup(boss)
	for i: int in range(3):
		boss._guardian_tick(0.3, host.position - boss.position)
	check(arena.shots.size() == 21, "crossing half health during fan warning does not add an unannounced fourth burst")
	arena.shots.clear()
	boss.hp = boss.max_hp * 0.75
	_begin_attack(boss, 1)
	_release_windup(boss)
	boss._guardian_tick(0.1, host.position - boss.position)
	boss.hp = boss.max_hp * 0.5
	for i: int in range(2):
		boss._guardian_tick(0.3, host.position - boss.position)
	check(arena.shots.size() == 21, "crossing half health mid-volley preserves the announced three-burst pattern")
	# The second phase is more aggressive while retaining a dodgeable windup.
	boss.hp = boss.max_hp * 0.5
	_begin_attack(boss, 0)
	check(boss.guardian_attack_enraged and boss.guardian_dash_speed > warned_dash_speed, "a new attack adopts the second phase only after the previous warning has finished")
	check(boss.guardian_enraged() and boss.guardian_state_time >= 0.70 and boss.guardian_state_time < 0.85, "half health triggers faster but still readable second-phase warnings")
	_release_windup(boss)
	check(boss.velocity.length() > 470.0, "second phase increases charge pressure")
	arena.shots.clear()
	_begin_attack(boss, 1)
	_release_windup(boss)
	for i: int in range(4):
		boss._guardian_tick(0.3, host.position - boss.position)
	check(arena.shots.size() == 28 and boss.guardian_state == "recovery", "second phase adds a fourth fan burst")
	# Use actual process disabling, as the game's pause applies to the whole world.
	_begin_attack(boss, 0)
	boss.set_physics_process(true)
	host.hp = 100.0
	host.regen_delay_remaining = 3.0
	host.set_physics_process(true)
	arena.process_mode = Node.PROCESS_MODE_DISABLED
	var paused_warning: float = boss.guardian_state_time
	await create_timer(0.15).timeout
	check(boss.guardian_state_time == paused_warning and host.hp == 100.0 and host.regen_delay_remaining == 3.0, "pause freezes boss warnings and healing delay together")
	boss.set_physics_process(false)
	host.set_physics_process(false)
	arena.process_mode = Node.PROCESS_MODE_INHERIT
	host.dead = true
	boss._enemy_tick(0.1)
	check(boss.guardian_state == "stalk" and boss.guardian_attack.is_empty() and boss.velocity.is_zero_approx(), "player death cancels any queued boss attack")
	host.dead = false
	_begin_attack(boss, 1)
	boss.take_damage(99999.0)
	var shots_at_death: int = arena.shots.size()
	boss._physics_process(2.0)
	check(boss.dead and boss.guardian_attack.is_empty() and arena.shots.size() == shots_at_death, "boss death clears queued attacks and prevents posthumous volleys")

func _run() -> void:
	progress = root.get_node("Progress")
	var original_document: Dictionary = progress.call("_document")
	progress.call("_defaults")
	progress.settings["autofire"] = false
	arena = CombatArena.new()
	root.add_child(arena)
	arena.player = _actor("host", Vector2(500, 400))
	await _frames()
	_host_pose_checks()
	await _gait_continuity_checks()
	_regen_checks()
	await _guardian_checks()
	arena.queue_free()
	await _frames()
	progress.call("_defaults")
	progress.call("_apply_document", original_document)
	print("COMBAT_TESTS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
