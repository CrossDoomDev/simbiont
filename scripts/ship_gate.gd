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
		_add_generated_door()
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
	caption.position = Vector2(-190,-98 if (definition["rect"] as Rect2).size.x > (definition["rect"] as Rect2).size.y else -(definition["rect"] as Rect2).size.y*0.5-80)
	caption.size = Vector2(380,60)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_override("font",preload("res://assets/fonts/regular.tres"))
	caption.add_theme_font_size_override("font_size",16)
	caption.add_theme_color_override("font_color",Color("e5b3d0"))
	add_child(caption)
	_add_generated_door()
	refresh()

func refresh() -> void:
	var locked: bool = int(Progress.modules.get(definition.get("id",""),0)) <= 0
	visible = locked
	if is_instance_valid(shape):
		shape.set_deferred("disabled",not locked)

func _add_generated_door() -> void:
	if has_node("GeneratedMembrane"):
		return
	var art := Sprite2D.new()
	art.name = "GeneratedMembrane"
	var index: int = ["archive_door","refinery_door","quarantine_door"].find(str(definition["id"]))
	art.texture = preload("res://scripts/evolution_art.gd").cell(preload("res://assets/art/evolution/gates.png"),1,3,maxi(0,index))
	var extent: Vector2 = (definition["rect"] as Rect2).size
	var vertical := extent.y > extent.x
	art.rotation = PI*0.5 if vertical else 0.0
	art.scale = Vector2(maxf(extent.x,extent.y)+24,minf(extent.x,extent.y)+18)/art.texture.get_size()
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(art)
