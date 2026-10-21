class_name BioActor
extends CharacterBody2D

signal died(actor: BioActor)

var game: Node
var kind := "host"
var hp := 100.0
var max_hp := 100.0
var speed := 175.0
var damage := 10.0
var armor := 0.0
var invulnerable := 0.0
var cooldown := 0.0
var shot_clock := 0.0
var age := 0.0
var aim := Vector2.DOWN
var dead := false
var row := 0
var radius := 14.0
var attack_interval := 0.42
var anim: AnimatedSprite2D
var body_shape: CollisionShape2D
var flash: Tween
var telegraph := 0.0
var target_point := Vector2.ZERO
var move_input := Vector2.ZERO
var manual_aim := Vector2.ZERO
var manual_fire := false
var detection_radius: float = 350.0
var permanent_regen: float = 0.0
var regen_delay_remaining: float = 0.0
var attack_range: float = 350.0
var windup_duration: float = 0.65
var enemy_attack_interval: float = 2.3
var _contact_clock: float = 0.0
var _separation_clock: float = 0.0
var _separation: Vector2 = Vector2.ZERO
var _directional_enemy_atlas: bool = false
var emergence_remaining: float = 0.0
var emergence_direction := Vector2.DOWN
var guardian_state: String = "stalk"
var guardian_attack: String = ""
var guardian_state_time: float = 0.0
var guardian_sequence: int = 0
var guardian_dash_direction: Vector2 = Vector2.DOWN
var guardian_dash_speed: float = 470.0
var guardian_attack_enraged: bool = false
var guardian_burst_clock: float = 0.0
var guardian_bursts_remaining: int = 0
var guardian_slam_flash: float = 0.0

func _ready() -> void:
	collision_layer = 2 if kind == "host" else 4
	collision_mask = 1
	if kind != "host":
		var config: Dictionary = GameData.ENEMIES[kind]
		max_hp = float(config.get("hp", 30))
		hp = max_hp
		speed = float(config.get("speed", 70))
		damage = float(config.get("damage", 8))
		armor = float(config.get("armor", 0))
		radius = float(config.get("radius", 16))
		attack_range = float(config.get("range", 350.0))
		windup_duration = float(config.get("telegraph", 0.65))
		enemy_attack_interval = float(config.get("cooldown", 2.3))
		row = ["crawler", "shell", "ranged", "guardian"].find(kind)
	else:
		apply_stats()
	body_shape = CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	body_shape.shape = circle
	add_child(body_shape)
	anim = AnimatedSprite2D.new()
	anim.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var sprite_path: String = "res://assets/art/hero.png" if kind == "host" else "res://assets/art/enemies.png"
	if kind == "host" and game != null and str(game.get("mode")) != "mission" and ResourceLoader.exists("res://assets/art/hero_base.png"):
		sprite_path = "res://assets/art/hero_base.png"
	if kind != "host":
		var enemy_texture: Texture2D = load(sprite_path) as Texture2D
		_directional_enemy_atlas = enemy_texture != null and enemy_texture.get_height() >= 1024
	var frames_path: String = "res://assets/animations/" + ("host_base" if sprite_path.ends_with("hero_base.png") else ("host_combat" if kind == "host" else "enemy_" + kind)) + ".tres"
	if ResourceLoader.exists(frames_path):
		anim.sprite_frames = load(frames_path) as SpriteFrames
	else:
		anim.sprite_frames = create_sprite_frames(sprite_path, kind)
	add_child(anim)
	if kind == "guardian":
		anim.scale = Vector2.ONE * 1.8
		BioVisual.add_glow(self, Color(0.85, 0.14, 0.3, 0.65), 230)
	elif kind == "host":
		BioVisual.add_glow(self, Color(0.22, 0.7, 0.64, 0.27), 150)
	anim.play("idle_0")
	add_to_group("host" if kind == "host" else "enemies")

static func create_sprite_frames(sprite_path: String, actor_kind: String) -> SpriteFrames:
	var frames: SpriteFrames = SpriteFrames.new()
	frames.remove_animation("default")
	var kind_row: int = ["crawler", "shell", "ranged", "guardian"].find(actor_kind)
	var enemy_texture: Texture2D = load(sprite_path) as Texture2D
	var expanded: bool = actor_kind != "host" and enemy_texture != null and enemy_texture.get_height() >= 1024
	for direction: int in range(4):
		for state: String in ["idle", "walk", "attack"]:
			var key: String = "%s_%d" % [state, direction]
			frames.add_animation(key)
			frames.set_animation_speed(key, 8.0)
			var columns: Array = [0] if state == "idle" else ([1, 2] if state == "walk" else [3])
			if actor_kind != "host" and not expanded:
				columns = [3] if state == "attack" else [[0, 2, 1, 0][direction]]
			for column: int in columns:
				var sprite_row: int = direction if actor_kind == "host" else (kind_row * 4 + direction if expanded else kind_row)
				frames.add_frame(key, BioVisual.atlas(sprite_path, Vector2i(64, 64), Vector2i(column, sprite_row)))
	return frames

func apply_stats() -> void:
	var stats: Dictionary = Progress.player_stats()
	max_hp = float(stats.get("max_hp", 100))
	hp = max_hp
	speed = float(stats.get("speed", 175))
	damage = float(stats.get("damage", 10))
	attack_interval = float(stats.get("fire_interval", 0.42))
	armor = float(stats.get("armor", 0))
	detection_radius = float(stats.get("detection_radius", 350.0))
	permanent_regen = float(stats.get("regen", 0.0))

func _physics_process(delta: float) -> void:
	if dead:
		return
	age += delta
	invulnerable = maxf(0.0, invulnerable - delta)
	cooldown = maxf(0.0, cooldown - delta)
	shot_clock = maxf(0.0, shot_clock - delta)
	_contact_clock = maxf(0.0, _contact_clock - delta)
	if kind == "host":
		_host_tick(delta)
	else:
		_enemy_tick(delta)
	move_and_slide()
	var direction: Vector2 = aim
	var facing := 0
	if absf(direction.x) > absf(direction.y):
		facing = 2 if direction.x > 0 else 1
	elif direction.y < 0:
		facing = 3
	var state := "walk" if velocity.length_squared() > 4 else "idle"
	if shot_clock > attack_interval - 0.12:
		state = "attack"
	anim.play("%s_%d" % [state, facing])
	anim.position.y = sin(age * (6.0 if state == "walk" else 2.4)) * (1.2 if kind == "host" else 1.8)
	queue_redraw()

func _host_tick(delta: float) -> void:
	if dead:
		return
	velocity = move_input.limit_length() * speed
	if game.mode != "mission":
		if velocity.length_squared() > 1:
			aim = velocity.normalized()
		return
	var shoot := manual_fire
	if manual_aim.length_squared() > 0.1:
		aim = manual_aim.normalized()
	elif bool(Progress.settings.get("autofire", true)):
		var nearest: Node2D = game.nearest_enemy(global_position, minf(detection_radius, GameData.PLAYER_SHOT_RANGE + radius + 12.0))
		if is_instance_valid(nearest) and not bool(nearest.get("dead")):
			aim = (nearest.global_position - global_position).normalized()
			shoot = true
	if shoot and shot_clock <= 0:
		shot_clock = attack_interval
		game.fire(self, aim, false)
	# Only the portion of this tick after the damage lockout can heal.
	var healing_delta: float = maxf(0.0, delta - regen_delay_remaining)
	regen_delay_remaining = maxf(0.0, regen_delay_remaining - delta)
	var healing_rate: float = permanent_regen
	hp = minf(max_hp, hp + healing_rate * healing_delta)

func _enemy_tick(delta: float) -> void:
	if dead:
		velocity = Vector2.ZERO
		return
	if not is_instance_valid(game.player) or game.player.dead:
		velocity = Vector2.ZERO
		if kind == "guardian":
			_cancel_guardian_attack()
		return
	if emergence_remaining > 0.0:
		# Walk from the black mouth into the room before targeting or attacking.
		# This runs in physics with the world, so pause also freezes the exit.
		var step: float = minf(delta, emergence_remaining)
		emergence_remaining = maxf(0.0, emergence_remaining - delta)
		velocity = emergence_direction * (96.0 * step / delta if delta > 0.0 else 96.0)
		aim = emergence_direction
		modulate.a = clampf(1.0 - emergence_remaining / 0.35, 0.0, 1.0)
		return
	var offset: Vector2 = game.player.global_position - global_position
	var distance := offset.length()
	aim = offset.normalized()
	if kind == "guardian":
		_guardian_tick(delta, offset)
		if distance < radius + game.player.radius + 8 and _contact_clock <= 0:
			var contact_damage: float = float(GameData.GUARDIAN_ATTACKS["dash"]["damage"]) if guardian_state == "dash" else damage
			game.player.take_damage(contact_damage)
			_contact_clock = 0.9
		return
	var desire := aim
	if kind == "ranged":
		if distance < attack_range * 0.72:
			desire = -aim
		elif distance < attack_range:
			desire = aim.orthogonal() * sin(age * 0.8)
		if cooldown <= 0 and distance < attack_range + 120.0:
			if telegraph <= 0.0:
				target_point = game.player.global_position
			telegraph += delta
			if telegraph >= windup_duration:
				game.fire(self, (target_point - global_position).normalized(), true)
				shot_clock = attack_interval
				telegraph = 0
				cooldown = enemy_attack_interval
		else:
			telegraph = 0.0
	# Separation changes slowly; refresh it eight times per second instead of 60.
	_separation_clock -= delta
	if _separation_clock <= 0.0:
		_separation_clock = 0.12
		_separation = Vector2.ZERO
		for candidate: Node in get_tree().get_nodes_in_group("enemies"):
			var other: BioActor = candidate as BioActor
			if other == null or other == self or other.dead:
				continue
			var apart: Vector2 = global_position - other.global_position
			var minimum_distance: float = radius + other.radius + 8.0
			if apart.length_squared() < minimum_distance * minimum_distance and apart.length_squared() > 0.01:
				_separation += apart.normalized() * 0.6
	velocity = (desire + _separation).limit_length() * speed
	if is_on_wall():
		velocity += aim.orthogonal() * speed * sin(age * 0.5 + row)
	if distance < radius + game.player.radius + 8 and _contact_clock <= 0:
		game.player.take_damage(damage)
		_contact_clock = 0.9

func guardian_enraged() -> bool:
	return hp <= max_hp * float(GameData.GUARDIAN_ATTACKS["enrage_threshold"])

func _start_guardian_attack() -> void:
	# Target and direction are locked at the start of the visible windup.
	var sequence: Array[String] = ["dash", "fan", "slam"]
	guardian_attack = sequence[guardian_sequence % sequence.size()]
	guardian_sequence += 1
	guardian_state = "windup"
	target_point = game.player.global_position
	guardian_dash_direction = (target_point - global_position).normalized()
	if guardian_dash_direction.is_zero_approx():
		guardian_dash_direction = Vector2.DOWN
	guardian_attack_enraged = guardian_enraged()
	guardian_dash_speed = float(GameData.GUARDIAN_ATTACKS["dash"]["speed"]) * (float(GameData.GUARDIAN_ATTACKS["enrage_speed"]) if guardian_attack_enraged else 1.0)
	windup_duration = float(GameData.GUARDIAN_ATTACKS[guardian_attack]["windup"])
	if guardian_attack_enraged:
		windup_duration *= float(GameData.GUARDIAN_ATTACKS["enrage_windup"])
	guardian_state_time = windup_duration
	telegraph = 0.001
	velocity = Vector2.ZERO

func _finish_guardian_attack() -> void:
	guardian_state = "recovery"
	guardian_state_time = float(GameData.GUARDIAN_ATTACKS[guardian_attack]["recovery"])
	cooldown = enemy_attack_interval * (float(GameData.GUARDIAN_ATTACKS["enrage_cooldown"]) if guardian_attack_enraged else 1.0)
	telegraph = 0.0
	velocity = Vector2.ZERO

func _cancel_guardian_attack() -> void:
	guardian_state = "stalk"
	guardian_attack = ""
	guardian_bursts_remaining = 0
	guardian_state_time = 0.0
	guardian_slam_flash = 0.0
	telegraph = 0.0
	velocity = Vector2.ZERO

func _guardian_fan() -> void:
	var config: Dictionary = GameData.GUARDIAN_ATTACKS["fan"]
	var count: int = int(config["projectiles"])
	var spread: float = float(config["spread"])
	# Alternating fans move the gaps without tracking the player's new position.
	var stagger: float = 0.07 if guardian_bursts_remaining % 2 == 0 else -0.07
	for index: int in range(count):
		var angle: float = lerpf(-spread, spread, float(index) / float(count - 1)) + stagger
		game.fire(self, guardian_dash_direction.rotated(angle), true)
	shot_clock = attack_interval

func _guardian_slam() -> void:
	var config: Dictionary = GameData.GUARDIAN_ATTACKS["slam"]
	var blast_radius: float = float(config["radius"])
	guardian_slam_flash = 0.32
	game.burst(global_position, Color("ff8c69"), 22)
	if game.player.global_position.distance_to(global_position) <= blast_radius + game.player.radius:
		game.player.take_damage(float(config["damage"]))
	var count: int = int(config["projectiles"])
	for index: int in range(count):
		game.fire(self, Vector2.RIGHT.rotated(TAU * index / count), true)
	shot_clock = attack_interval

func _guardian_tick(delta: float, offset: Vector2) -> void:
	guardian_slam_flash = maxf(0.0, guardian_slam_flash - delta)
	if guardian_state in ["windup", "dash", "volley"]:
		aim = guardian_dash_direction
	var speed_factor: float = float(GameData.GUARDIAN_ATTACKS["enrage_speed"]) if guardian_enraged() else 1.0
	if guardian_state == "dash":
		guardian_state_time -= delta
		velocity = guardian_dash_direction * guardian_dash_speed
		if guardian_state_time <= 0.0 or is_on_wall():
			_finish_guardian_attack()
		return
	if guardian_state == "recovery":
		velocity = Vector2.ZERO
		guardian_state_time -= delta
		if guardian_state_time <= 0.0:
			guardian_state = "stalk"
		return
	if guardian_state == "volley":
		velocity = Vector2.ZERO
		guardian_burst_clock -= delta
		if guardian_burst_clock <= 0.0:
			_guardian_fan()
			guardian_bursts_remaining -= 1
			guardian_burst_clock = float(GameData.GUARDIAN_ATTACKS["fan"]["burst_interval"])
			if guardian_bursts_remaining <= 0:
				_finish_guardian_attack()
		return
	if guardian_state == "windup":
		velocity = Vector2.ZERO
		telegraph += delta
		guardian_state_time -= delta
		if guardian_state_time <= 0.0:
			telegraph = 0.0
			if guardian_attack == "dash":
				guardian_state = "dash"
				guardian_state_time = float(GameData.GUARDIAN_ATTACKS["dash"]["duration"])
				velocity = guardian_dash_direction * guardian_dash_speed
			elif guardian_attack == "fan":
				guardian_state = "volley"
				guardian_bursts_remaining = int(GameData.GUARDIAN_ATTACKS["fan"]["bursts"]) + (1 if guardian_attack_enraged else 0)
				guardian_burst_clock = 0.0
			else:
				_guardian_slam()
				_finish_guardian_attack()
		return
	velocity = offset.normalized() * speed * speed_factor
	if cooldown <= 0.0 and offset.length() < attack_range + 150.0:
		_start_guardian_attack()

func take_damage(amount: float) -> void:
	if dead or invulnerable > 0 or not is_finite(amount) or amount <= 0.0:
		return
	var dealt := maxf(1.0, amount * (1.0 - clampf(armor, 0.0, 0.75)))
	hp -= dealt
	game.float_text(global_position + Vector2(0, -30), str(int(ceil(dealt))), Color("fa7a86") if kind == "host" else Color("e9e7ba"))
	if is_instance_valid(flash):
		flash.kill()
	anim.modulate = Color(3, 0.6, 0.7)
	flash = create_tween()
	flash.tween_property(anim, "modulate", Color.WHITE, 0.16)
	if kind == "host":
		invulnerable = 0.55
		regen_delay_remaining = float(GameData.REGEN["damage_delay"])
		Audio.play_sfx("hurt")
		game.shake = 5.0
	else:
		Audio.play_sfx("hit")
	if hp <= 0:
		dead = true
		if kind == "guardian":
			_cancel_guardian_attack()
		velocity = Vector2.ZERO
		collision_layer = 0
		died.emit(self)
		if kind != "host":
			var tween := create_tween()
			tween.tween_property(anim, "modulate:a", 0.0, 0.22)
			tween.tween_callback(queue_free)

func _draw() -> void:
	if dead:
		return
	draw_ellipse_shadow()
	if kind != "host" and hp < max_hp:
		var y := -38.0 if kind != "guardian" else -65.0
		draw_rect(Rect2(-23, y, 46, 4), Color("101d24"))
		draw_rect(Rect2(-23, y, 46 * hp / max_hp, 4), Color("e15b81"))
	if telegraph > 0:
		draw_arc(Vector2.ZERO, 30 + telegraph * 10, 0, TAU, 32, Color(1.0, 0.35, 0.35, telegraph * 0.8), 2)
		if kind == "ranged":
			var warning_direction: Vector2 = (target_point - global_position).normalized()
			draw_line(warning_direction * 24.0, warning_direction * 115.0, Color(1.0, 0.35, 0.35, 0.45), 2.0)
	if kind == "guardian":
		_draw_guardian_warning()
	if kind == "host" and game.mode == "mission":
		draw_line(aim * 24, aim * 34, Color(0.45, 1.0, 0.78, 0.55), 2)

func _draw_guardian_warning() -> void:
	if guardian_enraged():
		draw_arc(Vector2.ZERO, radius + 9.0, age * 1.5, age * 1.5 + TAU * 0.8, 40, Color(1.0, 0.22, 0.12, 0.7), 3.0)
	if guardian_slam_flash > 0.0:
		var radius_slam: float = float(GameData.GUARDIAN_ATTACKS["slam"]["radius"])
		draw_arc(Vector2.ZERO, radius_slam * (1.0 - guardian_slam_flash / 0.5), 0.0, TAU, 64, Color(1.0, 0.65, 0.25, guardian_slam_flash * 2.5), 6.0)
	if guardian_state != "windup":
		return
	var strength: float = clampf(telegraph / windup_duration, 0.0, 1.0)
	var warning: Color = Color(1.0, 0.3, 0.2, 0.35 + strength * 0.55)
	if guardian_attack == "dash":
		var dash_length: float = guardian_dash_speed * float(GameData.GUARDIAN_ATTACKS["dash"]["duration"])
		var endpoint: Vector2 = guardian_dash_direction * dash_length
		# The lane represents danger to the host's center, including body clearance.
		var danger_radius: float = radius + game.player.radius + 8.0
		var side: Vector2 = guardian_dash_direction.orthogonal() * danger_radius
		draw_colored_polygon(PackedVector2Array([side, endpoint + side, endpoint - side, -side]), Color(warning, 0.10 + strength * 0.08))
		draw_circle(Vector2.ZERO, danger_radius, Color(warning, 0.10 + strength * 0.08))
		draw_circle(endpoint, danger_radius, Color(warning, 0.10 + strength * 0.08))
		draw_arc(endpoint, danger_radius, guardian_dash_direction.angle() - PI * 0.5, guardian_dash_direction.angle() + PI * 0.5, 32, warning, 2.0)
		draw_line(side, endpoint + side, warning, 2.0)
		draw_line(-side, endpoint - side, warning, 2.0)
		draw_line(endpoint - guardian_dash_direction * 24.0 + side * 0.5, endpoint, warning, 3.0)
		draw_line(endpoint - guardian_dash_direction * 24.0 - side * 0.5, endpoint, warning, 3.0)
	elif guardian_attack == "slam":
		var slam_radius: float = float(GameData.GUARDIAN_ATTACKS["slam"]["radius"])
		draw_circle(Vector2.ZERO, slam_radius, Color(warning, 0.08 + strength * 0.12))
		draw_arc(Vector2.ZERO, slam_radius, 0.0, TAU, 64, warning, 3.0)
		draw_arc(Vector2.ZERO, slam_radius * strength, 0.0, TAU, 64, Color(warning, 0.5), 2.0)
	else:
		var spread: float = float(GameData.GUARDIAN_ATTACKS["fan"]["spread"])
		for angle: float in [-spread, 0.0, spread]:
			var direction: Vector2 = guardian_dash_direction.rotated(angle)
			draw_line(direction * radius, direction * 230.0, warning, 2.0)

func draw_ellipse_shadow() -> void:
	draw_set_transform(Vector2(0, 15), 0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, radius + 4, Color(0, 0, 0, 0.3))
	draw_set_transform(Vector2.ZERO)
