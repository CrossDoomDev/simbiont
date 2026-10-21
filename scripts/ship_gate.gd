extends StaticBody2D
## Physical seals are part of the editable ship scene, with live unlock binding.
@export var definition: Dictionary
var shape: CollisionShape2D
var caption: Label

func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	position = (definition["rect"] as Rect2).get_center()
	if has_node("MembraneShape"):
		shape = get_node("MembraneShape")
		caption = get_node("SealCaption")
		refresh()
		return
	shape = CollisionShape2D.new()
	shape.name = "MembraneShape"
	var rectangle := RectangleShape2D.new()
	rectangle.size = (definition["rect"] as Rect2).size
	shape.shape = rectangle
	add_child(shape)
	caption = Label.new()
	caption.name = "SealCaption"
	caption.text = definition["name"]+"\nВосстановите отсек в дереве корабля"
	caption.position = Vector2(-190,-70)
	caption.size = Vector2(380,60)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_override("font",preload("res://assets/fonts/regular.tres"))
	caption.add_theme_font_size_override("font_size",16)
	caption.add_theme_color_override("font_color",Color("e5b3d0"))
	add_child(caption)
	refresh()

func refresh() -> void:
	var locked: bool = int(Progress.modules.get(definition.get("id",""),0)) <= 0
	visible = locked
	if is_instance_valid(shape):
		shape.set_deferred("disabled",not locked)

func _draw() -> void:
	var area := Rect2(-(definition["rect"] as Rect2).size*0.5,(definition["rect"] as Rect2).size)
	draw_style_box(_membrane(),area)
	var vertical: bool = area.size.y > area.size.x
	for i: int in 11:
		var progress: float = (i+0.5)/11.0
		var p := Vector2(0,lerpf(area.position.y,area.end.y,progress)) if vertical else Vector2(lerpf(area.position.x,area.end.x,progress),0)
		var side := Vector2(27,0) if vertical else Vector2(0,27)
		draw_polyline(PackedVector2Array([p-side,p+Vector2(sin(i*2)*7,cos(i)*6),p+side]),Color("a65378"),3.0,true)

func _membrane() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color("321a31")
	box.border_color = Color("7b3d66")
	box.set_border_width_all(3)
	box.set_corner_radius_all(18)
	return box
