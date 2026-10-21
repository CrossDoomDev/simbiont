extends Control
## A living neural map; positions and vessels are relative to available space.
const BioSkin = preload("res://scripts/ui_skin.gd")
var selected := 0
var time := 0.0

func _ready() -> void:
	custom_minimum_size = Vector2(280,300)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	time += delta
	queue_redraw()

func _vessel(a: Vector2, b: Vector2, color: Color, phase: float) -> void:
	var points := PackedVector2Array()
	var side := (b - a).normalized().orthogonal()
	for i: int in 24:
		var t: float = float(i) / 23.0
		points.append(a.lerp(b,t) + side * sin(t * PI) * sin(t * 5.0 + phase) * 17.0)
	draw_polyline(points, Color("160e1c"), 11, true)
	draw_polyline(points, color.darkened(0.65), 6, true)
	draw_polyline(points, Color(color,0.55), 1.5, true)
	var pulse: float = fposmod(time * 0.18 + phase, 1.0)
	draw_circle(a.lerp(b,pulse) + side * sin(pulse * PI) * sin(pulse * 5.0 + phase) * 17.0, 2.5, color)

func _draw() -> void:
	draw_style_box(BioSkin.panel(), Rect2(Vector2.ZERO,size))
	var inner := Rect2(Vector2(24,24), size - Vector2(48,48))
	draw_texture_rect_region(BioSkin.BACKDROP, inner, Rect2(600,0,900,900), Color(0.6,0.4,0.65))
	draw_rect(inner, Color(0.025,0.008,0.04,0.52))
	var origin := inner.position + inner.size * Vector2(0.2,0.72)
	var destinations: Array[Vector2] = [inner.position + inner.size * Vector2(0.45,0.25), inner.position + inner.size * Vector2(0.78,0.60)]
	for i: int in 2:
		var point: Vector2 = destinations[i]
		var color := Color("8be1c8") if i == 0 else Color("d78ae7")
		if i == 1 and not Progress.mission_unlocked(1):
			color = Color("827086")
		_vessel(origin, point, color, float(i) * 0.7)
		for branch: int in 5:
			var angle: float = TAU * branch / 5.0 + i
			var end: Vector2 = point + Vector2(cos(angle),sin(angle)) * 29.0
			draw_line(point,end,Color(color,0.23),1.5,true)
			draw_circle(end,2.0,Color(color,0.5))
		draw_circle(point,18.0 + sin(time * 2.0) * 1.5,Color(color,0.12))
		draw_circle(point,9.0,Color("281431"))
		draw_arc(point,13.0,0,TAU,32,Color(color,0.75),2,true)
		draw_circle(point,5.0,color)
		draw_string(get_theme_default_font(),point + Vector2(-22,43),"ЛЕС" if i == 0 else "ТОПИ",HORIZONTAL_ALIGNMENT_LEFT,-1,13,color)
	draw_circle(origin,8.0,Color("efb77e"))
	draw_arc(origin,13.0,0,TAU,32,Color("c68876"),1.5,true)
	draw_string(get_theme_default_font(),origin + Vector2(-24,32),"КОРАБЛЬ",HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("d0b8be"))
