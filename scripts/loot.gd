class_name BioLoot
extends Node2D

var game: Node
var resource_type := 0
var amount := 1
var age := 0.0
var sprite: Sprite2D
var gathered := false
var drift := Vector2.ZERO

func _ready() -> void:
	resource_type = clampi(resource_type, 0, 3)
	amount = maxi(1, amount)
	sprite = BioVisual.sprite(self, "res://assets/art/resources.png", Vector2i(32, 32), Vector2i(resource_type, 0), 0.85)
	BioVisual.add_glow(self, [Color(0.2,0.8,0.4,0.35),Color(0.8,0.5,0.2,0.35),Color(0.2,0.7,1,0.35),Color(0.85,0.2,0.8,0.4)][resource_type], 50)
	add_to_group("loot")
	drift = Vector2.RIGHT.rotated(randf()*TAU) * 45

func _physics_process(delta: float) -> void:
	if gathered or not is_instance_valid(game.player) or game.player.dead:
		return
	age += delta
	sprite.position.y = sin(age * 3.5) * 2
	global_position += drift * delta
	drift = drift.move_toward(Vector2.ZERO, 100 * delta)
	var distance: float = global_position.distance_to(game.player.global_position)
	var pickup: float = float(Progress.player_stats().get("pickup_radius", 65))
	if game.has_mutation("magnet"):
		pickup *= 1.8
	if distance < pickup:
		global_position = global_position.move_toward(game.player.global_position, delta * (150 + (pickup - distance) * 4))
		distance = global_position.distance_to(game.player.global_position)
	if distance < 18 and age > 0.2:
		gathered = true
		game.collect(resource_type, amount)
		queue_free()
	elif age > 110:
		queue_free()
