class_name BioProjectile
extends Node2D

var game: Node
var direction := Vector2.RIGHT
var speed := 550.0
var damage := 10.0
var hostile := false
var life := 1.8
var previous := Vector2.ZERO
var pierce := 0
var execute_bonus := 0.0
var boss_bonus := 0.0
var hit_ids: Array[RID] = []
var remaining_distance: float = INF

func _ready() -> void:
	direction = direction.normalized()
	previous = global_position
	z_index = 4
	rotation = direction.angle()
	BioVisual.add_glow(self, Color(1, 0.2, 0.4, 0.7) if hostile else Color(0.25, 1, 0.7, 0.7), 40)

func _physics_process(delta: float) -> void:
	if is_queued_for_deletion():
		return
	var travel: float = minf(speed * minf(delta, maxf(0.0, life)), remaining_distance)
	life -= delta
	if travel <= 0.0:
		queue_free()
		return
	var finish: Vector2 = global_position + direction * travel
	# Resolve all penetrated bodies along this tick; walls always stop the shot.
	for pass_index: int in 6:
		var query := PhysicsRayQueryParameters2D.create(global_position,finish,3 if hostile else 5)
		query.exclude = hit_ids
		var collision: Dictionary = get_world_2d().direct_space_state.intersect_ray(query)
		if collision.is_empty():
			break
		var target := collision["collider"] as Node2D
		var penetrable := false
		if is_instance_valid(target) and target.has_method("take_damage") and not bool(target.get("dead")):
			var before_hp: float = float(target.get("hp"))
			var impact_damage := damage
			if not hostile:
				if before_hp < float(target.get("max_hp"))*0.35:
					impact_damage *= 1.0+execute_bonus
				if target.get("kind") == "guardian":
					impact_damage *= 1.0+boss_bonus
			if hostile and target is BioActor:
				target.take_damage(impact_damage,true)
			else:
				target.take_damage(impact_damage)
			if not hostile and game.has_method("gain_combat_energy"):
				var actual_damage: float = maxf(0.0,before_hp-maxf(0.0,float(target.get("hp"))))
				game.gain_combat_energy(actual_damage,bool(target.get("dead")))
			penetrable = not hostile and pierce > 0
		game.burst(collision["position"],Color("f56b8b") if hostile else Color("91f0a2"),4)
		if penetrable:
			pierce -= 1
			hit_ids.append(collision["rid"])
			global_position = collision["position"]
		else:
			queue_free()
			return
	global_position = finish
	remaining_distance = maxf(0.0, remaining_distance - travel)
	if remaining_distance <= 0.0 or life <= 0.0:
		queue_free()
	queue_redraw()

func _draw() -> void:
	var color := Color("fa6e8c") if hostile else Color("a1ffd2")
	draw_line(Vector2(-13, 0), Vector2(4, 0), Color(color, 0.3), 6)
	draw_line(Vector2(-9, 0), Vector2(5, 0), color, 3)
	draw_circle(Vector2(5, 0), 2, Color("f5ffe8"))
