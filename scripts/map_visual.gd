extends Control

var selected := 0
var time := 0.0

func _ready() -> void:
	custom_minimum_size = Vector2(360,340)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	time += delta
	queue_redraw()

func _draw() -> void:
	var center := size * 0.5
	var radius := minf(size.x,size.y)*0.39
	draw_circle(center,radius+25,Color(0.08,0.2,0.24,0.35))
	draw_circle(center,radius,Color("102a30"))
	for i in 7:
		var y := -radius+float(i+1)*radius/4
		if absf(y)<radius:
			var half_width := sqrt(radius*radius-y*y)
			draw_line(center+Vector2(-half_width,y),center+Vector2(half_width,y),Color(0.3,0.7,0.65,0.13),1)
	for i in 5:
		draw_set_transform(center,0,Vector2(0.2+i*0.19,1))
		draw_arc(Vector2.ZERO,radius,0,TAU,64,Color(0.3,0.7,0.65,0.13),1)
	draw_set_transform(Vector2.ZERO)
	for i in 30:
		var angle := float(i)*2.399
		var p := center+Vector2(cos(angle),sin(angle))*radius*(0.15+fmod(i*0.173,0.74))
		var q := p+Vector2(sin(i*4.2),cos(i*2.1))*15
		draw_line(p,q,Color(0.23,0.5,0.39,0.55),8)
	var first := center+Vector2(-43,-20)
	var second := center+Vector2(65,48)
	draw_dashed_line(first,second,Color(0.52,0.65,0.62,0.5),1,5)
	for i in 2:
		var p := first if i == 0 else second
		var col := Color("87dec2") if i == selected else Color("e1a1c7")
		draw_circle(p,14,Color(col,0.12))
		draw_arc(p,17+sin(time*2)*2,0,TAU,32,Color(col,0.6),1.5)
		draw_circle(p,5,col)
	draw_arc(center,radius+3,0,TAU,96,Color("5a9a94"),1)
	draw_arc(center,radius+18,-PI/3,PI/3,32,Color("86bcb0"),2)
