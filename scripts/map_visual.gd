extends Control
## Native focusable point controls over a procedural alien planet.
signal mission_selected(index: int)
const BioSkin = preload("res://scripts/ui_skin.gd")
var selected := 0
var time := 0.0
var point_buttons: Array[Button] = []

func _ready() -> void:
	custom_minimum_size = Vector2(280,340)
	mouse_filter = Control.MOUSE_FILTER_PASS
	for i: int in GameData.MISSIONS.size():
		var point := Button.new()
		point.name = "LandingPoint%d" % i
		point.tooltip_text = str(GameData.MISSIONS[i]["name"])
		point.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		point.custom_minimum_size = Vector2(48,48)
		for state: String in ["normal","hover","pressed","disabled"]:
			point.add_theme_stylebox_override(state,StyleBoxEmpty.new())
		var focus := StyleBoxFlat.new()
		focus.bg_color = Color(0.7,0.9,0.8,0.12)
		focus.border_color = Color("b9ffe5")
		focus.set_border_width_all(2)
		focus.set_corner_radius_all(24)
		point.add_theme_stylebox_override("focus",focus)
		point.pressed.connect(func(): mission_selected.emit(i))
		point.focus_entered.connect(queue_redraw)
		point.mouse_entered.connect(queue_redraw)
		point.mouse_exited.connect(queue_redraw)
		add_child(point)
		point_buttons.append(point)
	resized.connect(_layout_points)
	_layout_points()

func _inner() -> Rect2:
	return Rect2(Vector2(40,40),size-Vector2(80,80))

func landing_point(index: int) -> Vector2:
	var inner := _inner()
	var center := inner.get_center() - Vector2(0,12)
	var radius: float = minf(inner.size.x,inner.size.y) * 0.43
	return center + Vector2(-0.40,-0.35) * radius if index == 0 else center + Vector2(0.46,0.28) * radius

func _layout_points() -> void:
	for i: int in point_buttons.size():
		point_buttons[i].position = landing_point(i) - Vector2(24,24)
		point_buttons[i].size = Vector2(48,48)
	queue_redraw()

func select_mission(index: int) -> void:
	selected = index
	queue_redraw()

func _process(delta: float) -> void:
	time += delta
	queue_redraw()

func _draw() -> void:
	draw_style_box(BioSkin.panel(),Rect2(Vector2.ZERO,size))
	var inner := _inner()
	var center := inner.get_center() - Vector2(0,12)
	var radius: float = minf(inner.size.x,inner.size.y) * 0.43
	draw_circle(center,radius+7,Color("30213f"))
	draw_circle(center,radius+3,Color("75517d"))
	draw_circle(center,radius,Color("172d32"))
	# Irregular membranes suggest continents and bioluminescent tissue.
	for region: int in 5:
		var points := PackedVector2Array()
		var angle: float = region * TAU / 5.0 + 0.2
		var origin := center + Vector2.from_angle(angle) * radius * 0.48
		for vertex: int in 64:
			var phase: float = vertex * TAU / 64.0
			var length: float = radius * (0.24 + sin(phase * 3.0 + region) * 0.045 + cos(phase * 5.0 + region) * 0.025)
			points.append(origin+Vector2.from_angle(phase)*length)
		draw_colored_polygon(points,Color("314b48") if region % 2 == 0 else Color("4c354c"))
	draw_arc(center,radius*0.89,3.5,5.1,40,Color("78b7a5"),2,true)
	for i: int in point_buttons.size():
		var point := landing_point(i)
		var unlocked: bool = Progress.mission_unlocked(i)
		var color := Color("9fe6c7") if unlocked else Color("a58aa9")
		if i == selected:
			draw_circle(point,21,Color(color,0.12))
			draw_arc(point,18+sin(time*2)*1.2,0,TAU,40,color,2,true)
		if point_buttons[i].is_hovered():
			draw_circle(point,15,Color(color,0.25))
		draw_circle(point,10,Color("140d1d"))
		draw_circle(point,6,color)
		if not unlocked:
			draw_line(point+Vector2(-4,4),point+Vector2(4,-4),Color("261d2c"),2,true)
	var font := get_theme_default_font()
	var caption := "ТОЧКИ ВЫСАДКИ"
	var width: float = font.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,14).x
	draw_string(font,Vector2((size.x-width)*0.5,size.y-42),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("b4a1b7"))
