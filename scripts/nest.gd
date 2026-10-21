class_name BioNest
extends StaticBody2D

var game: Node
var hp := 210.0
var max_hp := 210.0
var dead := false
var index := 0
var age := 0.0
var sprite: Sprite2D
var flash: Tween

func _ready() -> void:
	# Solid world obstacle and damageable mission objective.
	collision_layer = 5
	collision_mask = 0
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 40
	shape.shape = circle
	add_child(shape)
	sprite = Sprite2D.new()
	sprite.texture = load("res://assets/art/nest.png")
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2.ONE*1.18
	add_child(sprite)
	BioVisual.add_glow(self, Color(0.9,0.08,0.3,0.7), 240)
	add_to_group("nests")

func _process(delta: float) -> void:
	age += delta
	sprite.scale = Vector2.ONE * (1.18 + sin(age * 2) * 0.025)
	queue_redraw()

func take_damage(amount: float) -> void:
	if dead or not is_finite(amount) or amount <= 0.0:
		return
	hp -= amount
	sprite.modulate = Color(2,0.65,0.75)
	if flash != null and flash.is_valid():
		flash.kill()
	flash = create_tween()
	flash.tween_property(sprite,"modulate",Color.WHITE,0.15)
	game.float_text(global_position + Vector2(randf_range(-20,20),-45),str(int(ceil(amount))),Color("fbc6b6"))
	Audio.play_sfx("hit")
	if hp <= 0:
		dead = true
		collision_layer = 0
		game.nest_destroyed(self)
		queue_free()

func _draw() -> void:
	draw_arc(Vector2.ZERO,55,0,TAU,48,Color(0.9,0.2,0.4,0.35),1)
	draw_rect(Rect2(-42,-67,84,5),Color("191b24"))
	draw_rect(Rect2(-42,-67,84*maxf(0,hp)/max_hp,5),Color("e56386"))
