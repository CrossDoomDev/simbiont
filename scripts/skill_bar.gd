extends Control
## A responsive native HUD: four keys and the right-mouse ability at the right.
const Skills = preload("res://scripts/skills.gd")
const Effect = preload("res://scripts/skill_effect.gd")
const BioSkin = preload("res://scripts/ui_skin.gd")
var game: Node
var buttons: Array[Button] = []
var icons: Array[TextureRect] = []
var keys: Array[Label] = []
var statuses: Array[Label] = []
var energy_label: Label
var energy_bar: ProgressBar
var compact := false
var notice := ""
var notice_time := 0.0

func _ready() -> void:
	name = "SymbioteAbilities"
	mouse_filter = Control.MOUSE_FILTER_PASS
	energy_label = Label.new()
	energy_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(energy_label)
	energy_bar = ProgressBar.new()
	energy_bar.max_value = 100
	energy_bar.show_percentage = false
	energy_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	energy_bar.add_theme_stylebox_override("background",BioSkin.fluid(Color("37233d")))
	energy_bar.add_theme_stylebox_override("fill",BioSkin.fluid(Color("bd7fe0")))
	add_child(energy_bar)
	for i: int in 5:
		var data: Dictionary = Skills.DEFINITIONS[i]
		var b := Button.new()
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.focus_mode = Control.FOCUS_NONE
		for state: String in ["normal","hover","pressed","hover_pressed","disabled"]:
			var box := BioSkin.fluid(Color("211329") if state != "hover" else Color("412044"),10)
			box.border_color = Color(data["color"],0.24 if state == "disabled" else 0.65)
			box.set_border_width_all(1 if state != "hover" else 2)
			b.add_theme_stylebox_override(state,box)
		b.pressed.connect(func(): game.cast_skill(i,true))
		add_child(b)
		buttons.append(b)
		var icon := TextureRect.new()
		icon.texture = Effect.icon(i)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(icon)
		icons.append(icon)
		var key := Label.new()
		key.text = data["key"]
		key.mouse_filter = Control.MOUSE_FILTER_IGNORE
		key.add_theme_color_override("font_color",Color("e9f8ef"))
		key.add_theme_color_override("font_shadow_color",Color.BLACK)
		key.add_theme_constant_override("shadow_outline_size",4)
		b.add_child(key)
		keys.append(key)
		var status := Label.new()
		status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		status.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(status)
		statuses.append(status)

func layout_for_view(view: Vector2, touch: Control) -> void:
	compact = view.x < 900
	var width: float = minf(600,view.x-32)
	if touch.visible:
		width = minf(600,view.x-2*(110+touch.radius+10)-24)
	var short: bool = view.y < 520
	size = Vector2(maxf(230,width),120 if short else 136)
	position = Vector2((view.x-size.x)*0.5,view.y-size.y-10)
	var narrow: bool = size.x < 350
	var pad: float = 14 if narrow else 24
	energy_label.position = Vector2(pad,22)
	energy_label.size = Vector2(size.x-pad*2,20)
	energy_label.add_theme_font_size_override("font_size",13 if narrow else 16)
	energy_bar.position = Vector2(pad,42 if short else 46)
	energy_bar.size = Vector2(size.x-pad*2,5)
	var gap := 5.0
	var slot_width: float = (size.x-pad*2-gap*4)/5
	for i: int in 5:
		buttons[i].position = Vector2(pad+i*(slot_width+gap),52 if short else 58)
		buttons[i].size = Vector2(slot_width,46 if short else 54)
		icons[i].position = Vector2(3,2)
		icons[i].size = Vector2(slot_width-6,29 if short else 36)
		keys[i].position = Vector2(4,0)
		keys[i].add_theme_font_size_override("font_size",11 if narrow else 13)
		statuses[i].position = Vector2(1,29 if short else 37)
		statuses[i].size = Vector2(slot_width-2,17)
		statuses[i].add_theme_font_size_override("font_size",11 if narrow else 13)
	queue_redraw()

func pointer_inside() -> bool:
	return is_visible_in_tree() and get_global_rect().has_point(get_global_mouse_position())

func show_notice(message: String) -> void:
	notice = message
	notice_time = 1.7

func _process(delta: float) -> void:
	notice_time = maxf(0.0,notice_time-delta)
	visible = game.mode == "mission" and not game.modal and not game.transitioning and is_instance_valid(game.player) and not game.player.dead
	if not visible:
		return
	var skills: Node = game.skills
	energy_bar.value = skills.energy
	energy_label.text = "ЭНЕРГИЯ  %d / 100" % int(skills.energy)
	if skills.shield_strength > 0 and size.x >= 350:
		energy_label.text += "   ·   ЩИТ %d" % int(ceil(skills.shield_strength))
	if notice_time > 0:
		energy_label.text = notice
	energy_label.add_theme_color_override("font_color",Color("f2b8d0") if notice_time > 0 else Color("e5eee6"))
	for i: int in 5:
		var data: Dictionary = Skills.DEFINITIONS[i]
		var reason: String = skills.failure_reason(i)
		buttons[i].disabled = reason != ""
		icons[i].modulate = Color(1,1,1,0.38 if reason != "" else 1.0)
		statuses[i].text = "%.1fс" % skills.cooldowns[i] if skills.cooldowns[i] > 0 else (("%d Э" % skills.cost(i)) if is_equal_approx(skills.cost(i),roundf(skills.cost(i))) else ("%.1f Э" % skills.cost(i)))
		statuses[i].add_theme_color_override("font_color",Color("bba8c8") if reason != "" else data["color"])
		buttons[i].tooltip_text = "%s · %s\n%s\nЭнергия: %.1f. Перезарядка: %.1f с.%s" % [data["key"],data["name"],data["description"],skills.cost(i),skills.recharge(i),"\n"+reason if reason != "" else ""]

func _draw() -> void:
	draw_style_box(BioSkin.panel(0.98),Rect2(Vector2.ZERO,size))
