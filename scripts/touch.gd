extends Control

const BioSkin = preload("res://scripts/ui_skin.gd")
var game: Node
var left_id := -1
var right_id := -1
var left_value := Vector2.ZERO
var right_value := Vector2.ZERO
var left_center := Vector2(110,600)
var right_center := Vector2(1170,600)
var radius := 65.0

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visibility_changed.connect(_cancel_if_inactive)

func layout_for_view(view: Vector2) -> void:
	var compact: bool = view.y < 600
	var new_left := Vector2(110, view.y - (72 if compact else 120))
	var new_right := Vector2(view.x - 110, new_left.y)
	if new_left != left_center or new_right != right_center:
		cancel_touches()
	radius = 54.0 if compact else 65.0
	left_center = Vector2(110, view.y - (72 if compact else 120))
	right_center = Vector2(view.x - 110, left_center.y)
	queue_redraw()

func cancel_touches() -> void:
	left_id = -1
	right_id = -1
	left_value = Vector2.ZERO
	right_value = Vector2.ZERO
	queue_redraw()

func _cancel_if_inactive() -> void:
	if not is_visible_in_tree() or not is_instance_valid(game) or game.modal:
		cancel_touches()

func _process(_delta: float) -> void:
	# Menus can hide the controls without delivering another pointer event.
	_cancel_if_inactive()

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not is_instance_valid(game) or game.modal:
		cancel_touches()
		return
	if event is InputEventScreenTouch:
		var point: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
		if event.pressed and not event.canceled:
			if is_instance_valid(game.ui.skill_bar) and game.ui.skill_bar.is_visible_in_tree() and game.ui.skill_bar.get_global_rect().has_point(event.position):
				return
			if event.index == left_id or event.index == right_id:
				return
			if point.distance_to(left_center)<radius*1.8 and left_id<0:
				left_id = event.index
				left_value = (point-left_center).limit_length(radius)/radius
			elif point.distance_to(right_center)<radius*1.8 and right_id<0:
				right_id = event.index
				right_value = (point-right_center).limit_length(radius)/radius
		else:
			if event.index == left_id:
				left_id = -1
				left_value = Vector2.ZERO
			if event.index == right_id:
				right_id = -1
				right_value = Vector2.ZERO
	elif event is InputEventScreenDrag:
		var point: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
		if event.index == left_id:
			left_value = (point-left_center).limit_length(radius)/radius
		elif event.index == right_id:
			right_value = (point-right_center).limit_length(radius)/radius
	queue_redraw()

func _draw() -> void:
	for i in 2:
		var c := left_center if i == 0 else right_center
		var v := left_value if i == 0 else right_value
		draw_style_box(BioSkin.panel(0.66),Rect2(c-Vector2.ONE*(radius+10),Vector2.ONE*(radius+10)*2))
		draw_circle(c,radius,Color(0.12,0.04,0.16,0.38))
		draw_arc(c,radius,0,TAU,48,Color(0.8,0.5,0.9,0.5),1.5)
		draw_circle(c+v*radius*0.7,23,Color(0.83,0.55,0.95,0.4))
		if i == 1:
			draw_arc(c,10,0,TAU,20,Color(0.95,0.7,0.98,0.85),1)
