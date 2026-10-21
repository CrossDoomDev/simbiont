class_name BioProjectile
extends Node2D

var game: Node
var direction := Vector2.RIGHT
var speed := 550.0
var damage := 10.0
var hostile := false
var life := 1.8
var previous := Vector2.ZERO

func _ready() -> void:
	direction = direction.normalized()
	previous = global_position
	z_index = 4
	rotation = direction.angle()
	BioVisual.add_glow(self, Color(1, 0.2, 0.4, 0.7) if hostile else Color(0.25, 1, 0.7, 0.7), 40)

func _physics_process(delta: float) -> void:
	life -= delta
	if life <= 0:
		queue_free()
		return
	var finish: Vector2 = global_position + direction * speed * delta
	# World=1, host=2, enemies and mission objectives=4.
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(global_position, finish, 3 if hostile else 5)
	var collision: Dictionary = get_world_2d().direct_space_state.intersect_ray(query)
	if not collision.is_empty():
		var target: Node2D = collision["collider"] as Node2D
		if is_instance_valid(target) and target.has_method("take_damage") and not bool(target.get("dead")):
			target.take_damage(damage)
			if not hostile and game.has_mutation("chain") and is_instance_valid(target):
				game.chain_hit(target, damage * 0.45)
		game.burst(collision["position"], Color("f56b8b") if hostile else Color("91f0a2"), 4)
		queue_free()
		return
	global_position = finish
	queue_redraw()

func _draw() -> void:
	var color := Color("fa6e8c") if hostile else Color("a1ffd2")
	draw_line(Vector2(-13, 0), Vector2(4, 0), Color(color, 0.3), 6)
	draw_line(Vector2(-9, 0), Vector2(5, 0), color, 3)
	draw_circle(Vector2(5, 0), 2, Color("f5ffe8"))
