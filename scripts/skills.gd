class_name SymbioteSkills
extends Node
## Volatile combat energy is independent of permanent upgrade resources.
const Effect = preload("res://scripts/skill_effect.gd")
const MAX_ENERGY := 100.0
const ENERGY_PER_DAMAGE := 0.1125
const ENERGY_PER_KILL := 1.5
const DEFINITIONS: Array[Dictionary] = [
	{"name":"Нейроволна","key":"1","cost":25.0,"cooldown":5.0,"description":"Удар вокруг носителя: 2,5× урона, краткое подавление обычных врагов.","color":Color("94f4bd")},
	{"name":"Ядовитые споры","key":"2","cost":35.0,"cooldown":9.0,"description":"Облако у прицела на 4 с. Наносит урон каждые 0,5 с и замедляет обычных врагов.","color":Color("b8d95d")},
	{"name":"Хитиновый кокон","key":"3","cost":30.0,"cooldown":12.0,"description":"Защитная оболочка на 6 с: поглощает 45 + 10% максимального здоровья.","color":Color("f2b36f")},
	{"name":"Хищный рывок","key":"4","cost":20.0,"cooldown":4.0,"description":"Рывок по направлению прицела с ударом вдоль пути. Стены останавливают рывок.","color":Color("77e5ef")},
	{"name":"Разрыв связи","key":"ПКМ","cost":100.0,"cooldown":24.0,"description":"Мощный выброс вокруг носителя: 6× урона и уничтожение вражеских снарядов.","color":Color("ed8ce2")},
]
var game: Node
var energy := 0.0
var cooldowns: Array[float] = [0.0,0.0,0.0,0.0,0.0]
var shield_strength := 0.0
var shield_remaining := 0.0
var shield_effect: Node2D

func reset() -> void:
	energy = 0.0
	cooldowns.assign([0.0,0.0,0.0,0.0,0.0])
	shield_strength = 0.0
	shield_remaining = 0.0
	if is_instance_valid(shield_effect):
		shield_effect.queue_free()
	shield_effect = null

func _physics_process(delta: float) -> void:
	if game.mode != "mission" or game.modal or game.transitioning or not is_instance_valid(game.player) or game.player.dead:
		return
	for i: int in cooldowns.size():
		cooldowns[i] = maxf(0.0,cooldowns[i]-delta)
	shield_remaining = maxf(0.0,shield_remaining-delta)
	if shield_remaining <= 0.0:
		_clear_shield()

func gain_damage(actual_damage: float, killed: bool) -> void:
	if game.mode == "mission" and not game.modal and actual_damage > 0.0 and is_finite(actual_damage):
		energy = clampf(energy + actual_damage*ENERGY_PER_DAMAGE + (ENERGY_PER_KILL if killed else 0.0),0.0,MAX_ENERGY)

func bonus(key: String) -> float:
	return float(game.player.traits.get(key,0.0)) if is_instance_valid(game.player) else 0.0

func cost(index: int) -> float:
	var reduction := bonus("skill_cost") + (0.2*bonus("nova_apex") if index == 4 else 0.0)
	return snappedf(float(DEFINITIONS[index]["cost"])*(1.0-minf(0.5,reduction)),0.1)

func recharge(index: int) -> float:
	var reduction := bonus("skill_cooldown") + (bonus("dash_cooldown") if index == 3 else 0.0)
	return float(DEFINITIONS[index]["cooldown"])*(1.0-minf(0.5,reduction))

func failure_reason(index: int) -> String:
	if index < 0 or index >= DEFINITIONS.size():
		return "Неизвестная способность"
	if game.mode != "mission" or game.modal or game.transitioning or not is_instance_valid(game.player) or game.player.dead:
		return "Способности доступны в бою"
	if cooldowns[index] > 0.0:
		return "Перезарядка: %.1f с" % cooldowns[index]
	if energy < cost(index):
		return "Нужно энергии: %.1f / %.1f" % [energy,cost(index)]
	return ""

func cast(index: int, target: Vector2) -> bool:
	var reason := failure_reason(index)
	if reason != "":
		if is_instance_valid(game.ui) and not game.modal:
			game.ui.skill_bar.show_notice(reason)
		return false
	var origin: Vector2 = game.player.global_position
	var direction: Vector2 = (target-origin).normalized()
	if direction.is_zero_approx():
		direction = game.player.aim
	var dash_motion := direction * 160.0 * (1.0+bonus("dash_length"))
	if index == 3:
		var collision := KinematicCollision2D.new()
		if game.player.test_move(game.player.global_transform,dash_motion,collision):
			dash_motion = collision.get_travel()
		if dash_motion.length() < 8.0:
			game.ui.skill_bar.show_notice("Путь рывка перекрыт")
			return false
	energy -= cost(index)
	cooldowns[index] = recharge(index)
	game.player.attack_pose_remaining = 1.0
	var power: float = game.player.damage*(1.0+bonus("skill_power"))
	game.player.hp = minf(game.player.max_hp,game.player.hp+bonus("cast_heal"))
	match index:
		0:
			var reach := 155.0*(1.0+bonus("wave_radius"))
			damage_area(origin,reach,power*2.5,0.22)
			spawn_effect(0,origin,reach,0.55)
			game.shake = maxf(game.shake,4.0)
		1:
			var point := origin + (target-origin).limit_length(220.0)
			var query := PhysicsRayQueryParameters2D.create(origin,point,1)
			var hit: Dictionary = game.player.get_world_2d().direct_space_state.intersect_ray(query)
			if not hit.is_empty():
				point = origin + direction * maxf(0.0,origin.distance_to(hit["position"])-24.0)
			var cloud := spawn_effect(1,point,95.0,4.0+bonus("spore_duration"))
			cloud.power = power*0.55*(1.0+bonus("spore_power"))
		2:
			_clear_shield()
			shield_strength = (45.0 + game.player.max_hp*0.1)*(1.0+bonus("shield_power"))
			shield_remaining = 6.0+bonus("shield_duration")
			shield_effect = spawn_effect(2,origin,52.0,shield_remaining)
			shield_effect.anchor = game.player
		3:
			game.player.move_and_collide(dash_motion)
			var finish: Vector2 = game.player.global_position
			for target_node: Node2D in _targets():
				var point := Geometry2D.get_closest_point_to_segment(target_node.global_position,origin,finish)
				if point.distance_to(target_node.global_position) <= 38.0*(1.0+bonus("dash_apex")*0.5) and _visible(point,target_node):
					target_node.take_damage(power*1.8*(1.0+bonus("dash_apex")))
			game.player.invulnerable = maxf(game.player.invulnerable,0.25)
			var trail := spawn_effect(3,(origin+finish)*0.5,maxf(50.0,origin.distance_to(finish)*0.6),0.5)
			trail.rotation = direction.angle()
		4:
			var reach := 260.0*(1.0+0.25*bonus("nova_apex"))
			damage_area(origin,reach,power*6.0,0.3)
			for bullet: Node2D in get_tree().get_nodes_in_group("projectiles"):
				if bullet.hostile and origin.distance_to(bullet.global_position) <= reach:
					bullet.queue_free()
			spawn_effect(4,origin,reach,0.6)
			game.shake = maxf(game.shake,8.0)
	Audio.play_sfx(["skill_wave","skill_spores","skill_shield","skill_dash","skill_rupture"][index])
	return true

func spawn_effect(index: int, point: Vector2, radius: float, duration: float) -> BioSkillEffect:
	var effect := Effect.new()
	effect.controller = self
	effect.skill_index = index
	effect.radius = radius
	effect.duration = duration
	effect.position = point
	game.world.entities.add_child(effect)
	return effect

func _targets() -> Array[Node2D]:
	var result: Array[Node2D] = []
	for node: Node2D in get_tree().get_nodes_in_group("enemies") + get_tree().get_nodes_in_group("nests"):
		if is_instance_valid(node) and not node.is_queued_for_deletion() and not node.dead:
			result.append(node)
	return result

func _visible(origin: Vector2, target: Node2D) -> bool:
	var query := PhysicsRayQueryParameters2D.create(origin,target.global_position,1)
	if target is CollisionObject2D:
		query.exclude = [target.get_rid()]
	return game.player.get_world_2d().direct_space_state.intersect_ray(query).is_empty()

func damage_area(origin: Vector2, radius: float, damage: float, slow: float = 1.0) -> void:
	for target: Node2D in _targets():
		if origin.distance_to(target.global_position) <= radius and _visible(origin,target):
			target.take_damage(damage)
			if slow < 1.0 and target.has_method("apply_skill_control"):
				target.apply_skill_control(0.7,slow)

func absorb_damage(amount: float) -> float:
	if shield_remaining <= 0.0 or shield_strength <= 0.0:
		return amount
	var absorbed := minf(amount,shield_strength)
	shield_strength -= absorbed
	if shield_strength <= 0.0:
		_clear_shield()
		if bonus("shield_burst") > 0:
			damage_area(game.player.global_position,130.0,game.player.damage*3.0*(1.0+bonus("skill_power")))
			spawn_effect(0,game.player.global_position,130.0,0.5)
	return amount-absorbed

func _clear_shield() -> void:
	shield_strength = 0.0
	shield_remaining = 0.0
	if is_instance_valid(shield_effect):
		shield_effect.queue_free()
	shield_effect = null
