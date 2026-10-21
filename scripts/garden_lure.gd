class_name GardenLure
extends StaticBody2D
## Optional planted encounter, separate from all mandatory nests and boss counts.
var game: Node
var strain := "vascular"
var hp := 120.0
var max_hp := 120.0
var dead := false
var sprite: Sprite2D

func _ready() -> void:
	collision_layer = 4
	collision_mask = 0
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 26
	shape.shape = circle
	add_child(shape)
	sprite = Sprite2D.new()
	sprite.texture = EvolutionArt.plant(int(GardenData.CULTURES[strain]["row"]),3)
	sprite.scale = Vector2.ONE*0.32
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(sprite)
	var caption := Label.new()
	caption.text = "Приманка ксеносада\nРазбейте, чтобы начать охоту"
	caption.position = Vector2(-160,-93)
	caption.size = Vector2(320,48)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_override("font",preload("res://assets/fonts/regular.tres"))
	caption.add_theme_font_size_override("font_size",15)
	caption.add_theme_color_override("font_color",Color("c2efe3"))
	add_child(caption)
	add_to_group("garden_lures")

func take_damage(amount: float) -> void:
	if dead or not is_finite(amount) or amount <= 0:
		return
	hp -= amount
	game.float_text(position+Vector2(0,-55),str(ceili(amount)),Color("9fdacc"))
	if hp <= 0:
		dead = true
		collision_layer = 0
		game.open_garden_lure(strain,global_position)
		queue_free()
