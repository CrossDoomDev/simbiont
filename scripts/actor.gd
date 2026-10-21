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
var attack_range: float = 350.0
var windup_duration: float = 0.65
var enemy_attack_interval: float = 2.3
var _contact_clock: float = 0.0
var _separation_clock: float = 0.0
var _separation: Vector2 = Vector2.ZERO
var _directional_enemy_atlas: bool = false

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
	velocity = move_input.limit_length() * speed
	if game.mode != "mission":
		if velocity.length_squared() > 1:
			aim = velocity.normalized()
		return
	if game.has_mutation("speed"):
		velocity *= 1.18
	var shoot := manual_fire
	if manual_aim.length_squared() > 0.1:
		aim = manual_aim.normalized()
	elif bool(Progress.settings.get("autofire", true)):
		var nearest: Node2D = game.nearest_enemy(global_position, detection_radius)
		if is_instance_valid(nearest) and not bool(nearest.get("dead")):
			aim = (nearest.global_position - global_position).normalized()
			shoot = true
	if shoot and shot_clock <= 0:
		shot_clock = attack_interval * float(game.mutation_factor("fire_rate"))
		game.fire(self, aim, false)
	if game.has_mutation("regen"):
		hp = minf(max_hp, hp + 1.5 * delta)
	hp = minf(max_hp, hp + permanent_regen * delta)

func _enemy_tick(delta: float) -> void:
	if not is_instance_valid(game.player) or game.player.dead:
		velocity = Vector2.ZERO
		return
	var offset: Vector2 = game.player.global_position - global_position
	var distance := offset.length()
	aim = offset.normalized()
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
	elif kind == "guardian":
		if distance < 230:
			desire *= 0.25
		if cooldown <= 0 and distance < attack_range + 150.0:
			telegraph += delta
			if telegraph >= windup_duration:
				for i in 10:
					game.fire(self, Vector2.RIGHT.rotated(TAU * i / 10.0 + age), true)
				telegraph = 0
				cooldown = enemy_attack_interval
				shot_clock = attack_interval
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

func take_damage(amount: float) -> void:
	if dead or invulnerable > 0 or not is_finite(amount) or amount <= 0.0:
		return
	var dealt := maxf(1.0, amount * (1.0 - clampf(armor, 0.0, 0.75)))
	if kind == "host" and game.has_mutation("armor"):
		dealt *= 0.8
	hp -= dealt
	game.float_text(global_position + Vector2(0, -30), str(int(ceil(dealt))), Color("fa7a86") if kind == "host" else Color("e9e7ba"))
	if is_instance_valid(flash):
		flash.kill()
	anim.modulate = Color(3, 0.6, 0.7)
	flash = create_tween()
	flash.tween_property(anim, "modulate", Color.WHITE, 0.16)
	if kind == "host":
		invulnerable = 0.55
		Audio.play_sfx("hurt")
		game.shake = 5.0
	else:
		Audio.play_sfx("hit")
	if hp <= 0:
		dead = true
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
	if kind == "host" and game.mode == "mission":
		draw_line(aim * 24, aim * 34, Color(0.45, 1.0, 0.78, 0.55), 2)

func draw_ellipse_shadow() -> void:
	draw_set_transform(Vector2(0, 15), 0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, radius + 4, Color(0, 0, 0, 0.3))
	draw_set_transform(Vector2.ZERO)
