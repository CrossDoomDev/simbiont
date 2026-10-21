extends Control

var game: Node

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(174,136)

func _process(_delta: float) -> void:
	visible = game.mode == "mission" and not game.modal
	queue_redraw()

func _draw() -> void:
	if not visible or not is_instance_valid(game.world):
		return
	var box := Rect2(Vector2.ZERO,size)
	draw_style_box(_panel(),box)
	var inner := Rect2(12,12,size.x-24,size.y-24)
	for i in 4:
		var x := inner.position.x+inner.size.x*float(i)/3
		draw_line(Vector2(x,inner.position.y),Vector2(x,inner.end.y),Color(0.3,0.55,0.55,0.1),1)
	for nest: Node2D in get_tree().get_nodes_in_group("nests"):
		var p: Vector2 = inner.position+nest.global_position/game.world.bounds.size*inner.size
		draw_circle(p,4,Color("f5839f"))
	var host: Vector2 = inner.position+game.player.global_position/game.world.bounds.size*inner.size
	draw_circle(host,4,Color("b0ffe1"))
	draw_arc(host,8,0,TAU,16,Color(0.5,0.9,0.75,0.4),1)

func _panel() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.025,0.065,0.08,0.88)
	s.border_color = Color("29434a")
	s.set_border_width_all(1)
	s.set_corner_radius_all(8)
	return s
