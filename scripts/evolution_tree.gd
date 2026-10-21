extends VBoxContainer
## Native graph: pan with scrollbars/touch, zoom, real prerequisite edges and ranks.
const BioSkin = preload("res://scripts/ui_skin.gd")
var ui: CanvasLayer
var ship := false
var configs: Dictionary
var selected := ""
var zoom := 0.8
var node_buttons: Dictionary = {}
var node_labels: Dictionary = {}
var graph: Control
var scroll: ScrollContainer
var body: BoxContainer
var graph_panel: PanelContainer
var detail_panel: PanelContainer
var name_label: Label
var branch_label: Label
var description: Label
var requirements: Label
var preview: Label
var price: Label
var wallet: Label
var purchase: Button
var feedback: Label
var zoom_label: Label
var help_label: Label
var compact := false
var graph_offset := Vector2.ZERO
var dragging := false
const NODE_SIZE := Vector2(178,88)

class Veins extends Control:
	var tree: Node
	func _draw() -> void:
		var color := Color("4b2d57")
		for id: String in tree.configs:
			var node: Dictionary = tree.configs[id]
			var end: Vector2 = (node["position"]+Vector2(0,44))*tree.zoom+tree.graph_offset
			for parent: String in node.get("requires",{}):
				var begin: Vector2 = (tree.configs[parent]["position"]+Vector2(178,44))*tree.zoom+tree.graph_offset
				var path := PackedVector2Array()
				for tick: int in 25:
					var t: float = tick/24.0
					var p: Vector2 = begin.bezier_interpolate(begin+Vector2(60,0)*tree.zoom,end-Vector2(60,0)*tree.zoom,end,t)
					path.append(p)
				var levels: Dictionary = Progress.modules if tree.ship else Progress.upgrades
				var fed: bool = int(levels.get(parent,0)) >= int(node["requires"][parent])
				var tint: Color = node["color"] if fed else color
				draw_polyline(path,Color(tint,0.12),9*tree.zoom,true)
				var active: bool = id == tree.selected or parent == tree.selected
				draw_polyline(path,Color(tint,0.95 if active else (0.36 if fed else 0.16)),(3 if active else 2)*tree.zoom,true)
				var arrow := PackedVector2Array([end+Vector2(-8,-4)*tree.zoom,end,end+Vector2(-8,4)*tree.zoom])
				draw_polyline(arrow,Color(tint,0.8),1.5,true)
				var midpoint: Vector2 = path[12]
				draw_circle(midpoint,7.0,Color("211427"))
				draw_string(get_theme_default_font(),midpoint+Vector2(-3,3),str(node["requires"][parent]),HORIZONTAL_ALIGNMENT_LEFT,-1,9,Color("c6aecf"))

func _ready() -> void:
	name = "EvolutionTree"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation",14)
	configs = GameData.MODULES if ship else GameData.UPGRADES
	selected = "heart" if ship else "regeneration"
	var toolbar := HBoxContainer.new()
	toolbar.add_theme_constant_override("separation",8)
	add_child(toolbar)
	var legend: Label = ui.paragraph("ВЕТВИ КОРАБЛЯ" if ship else "ДРЕВО МУТАЦИЙ",16)
	legend.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(legend)
	toolbar.add_child(_small_button("−",func(): set_zoom(zoom-0.1)))
	zoom_label = ui.label("",14)
	toolbar.add_child(zoom_label)
	toolbar.add_child(_small_button("+",func(): set_zoom(zoom+0.1)))
	toolbar.add_child(_small_button("Обзор",fit))
	body = BoxContainer.new()
	body.add_theme_constant_override("separation",16)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(body)
	graph_panel = PanelContainer.new()
	graph_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	graph_panel.add_theme_stylebox_override("panel",_frame(Color("22152c"),Color("63416e")))
	body.add_child(graph_panel)
	scroll = ScrollContainer.new()
	scroll.name = "TreeScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	graph_panel.add_child(scroll)
	graph = Veins.new()
	graph.tree = self
	graph.mouse_filter = Control.MOUSE_FILTER_PASS
	scroll.add_child(graph)
	for id: String in configs:
		var b := Button.new()
		b.name = id
		b.clip_text = true
		b.add_theme_font_size_override("font_size",1)
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.pressed.connect(func(): select(id))
		graph.add_child(b)
		b.clip_contents = true
		var caption := Label.new()
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
		caption.clip_text = true
		b.add_child(caption)
		node_labels[id] = caption
		node_buttons[id] = b
	detail_panel = PanelContainer.new()
	detail_panel.add_theme_stylebox_override("panel",_frame(Color("211529"),Color("714377")))
	body.add_child(detail_panel)
	var detail_shell := VBoxContainer.new()
	detail_shell.add_theme_constant_override("separation",12)
	detail_panel.add_child(detail_shell)
	var detail_scroll := ScrollContainer.new()
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_shell.add_child(detail_scroll)
	var details := VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation",12)
	detail_scroll.add_child(details)
	branch_label = ui.paragraph("",14)
	name_label = ui.paragraph("",24,ui.TEXT)
	description = ui.paragraph("",17)
	requirements = ui.paragraph("",15)
	preview = ui.paragraph("",15)
	wallet = ui.paragraph("",14)
	price = ui.paragraph("",16)
	feedback = ui.paragraph("",15,Color("efadbf"))
	for l: Label in [branch_label,name_label,description,requirements,preview,wallet,feedback]:
		details.add_child(l)
	purchase = ui.button("Развить",buy,true)
	purchase.name = "BuyMutation"
	detail_shell.add_child(price)
	detail_shell.add_child(purchase)
	help_label = ui.paragraph("Связи требуют указанных рангов. Колесо / жест — прокрутка · СКМ — сдвиг · + / − — масштаб.",13)
	add_child(help_label)
	move_child(help_label,1)
	resized.connect(_arrange)
	Progress.changed.connect(refresh)
	_arrange()
	refresh()
	call_deferred("_focus_selected")

func _focus_selected() -> void:
	scroll.ensure_control_visible(node_buttons[selected])

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not is_instance_valid(scroll):
		return
	var inside := scroll.get_global_rect().has_point(get_global_mouse_position())
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_MIDDLE:
		dragging = event.pressed and inside
		if inside:
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and dragging:
		scroll.scroll_horizontal -= roundi(event.relative.x)
		scroll.scroll_vertical -= roundi(event.relative.y)
		get_viewport().set_input_as_handled()
	elif event is InputEventMagnifyGesture and inside:
		set_zoom(zoom*event.factor)
		get_viewport().set_input_as_handled()

func _small_button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(42,34)
	for state: String in ["normal","hover","pressed","hover_pressed","focus","disabled"]:
		b.add_theme_stylebox_override(state,_frame(Color("44244b") if state != "normal" else Color("28192f"),Color("8a5b92"),8))
	b.pressed.connect(action)
	return b

func _frame(bg: Color, border: Color, pad: int = 18) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_corner_radius_all(12)
	box.set_border_width_all(1)
	box.content_margin_left = pad
	box.content_margin_right = pad
	box.content_margin_top = pad
	box.content_margin_bottom = pad
	return box

func _arrange() -> void:
	if not is_instance_valid(body):
		return
	compact = size.x < 870
	help_label.visible = ui.root.size.y >= 520
	body.vertical = compact
	detail_panel.custom_minimum_size.x = 0 if compact else 306
	detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL if compact else Control.SIZE_FILL
	var height := clampf(ui.root.size.y-330.0,280.0,650.0)
	graph_panel.custom_minimum_size = Vector2(0,(180 if ui.root.size.y < 520 else 300) if compact else height)
	detail_panel.custom_minimum_size.y = 350 if compact else 0
	graph_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

func set_zoom(value: float) -> void:
	zoom = clampf(value,0.22,1.2)
	refresh()

func fit() -> void:
	var extent := _extent()
	set_zoom(minf((scroll.size.x-20)/extent.x,(scroll.size.y-20)/extent.y))
	scroll.scroll_horizontal = 0
	scroll.scroll_vertical = 0

func _extent() -> Vector2:
	var extent := Vector2.ZERO
	for node: Dictionary in configs.values():
		extent = extent.max(node["position"]+NODE_SIZE+Vector2(40,40))
	return extent

func _node_title(text: String) -> String:
	var result := ""
	var line := ""
	for word: String in text.replace("Венец: ","✦ ").split(" "):
		if line.length()+word.length() > 17:
			result += line.strip_edges()+"\n"
			line = ""
		line += word+" "
	return result+line.strip_edges()

func select(id: String) -> void:
	selected = id
	feedback.text = ""
	refresh()
	scroll.ensure_control_visible(node_buttons[id])

func refresh() -> void:
	if not is_instance_valid(graph):
		return
	var levels: Dictionary = Progress.modules if ship else Progress.upgrades
	zoom_label.text = "%d%%" % roundi(zoom*100)
	graph_offset = ((scroll.size-Vector2(16,16)-_extent()*zoom)*0.5).max(Vector2.ZERO)
	graph.custom_minimum_size = _extent()*zoom+graph_offset*2.0
	for id: String in configs:
		var data: Dictionary = configs[id]
		var b: Button = node_buttons[id]
		var level := int(levels.get(id,0))
		var available: bool = Progress.requirements_met(id,ship)
		var color: Color = data["color"]
		b.position = data["position"]*zoom+graph_offset
		b.size = NODE_SIZE*zoom
		var caption: Label = node_labels[id]
		caption.position = Vector2(3,2)
		caption.text = (_node_title(data["name"]) if zoom >= 0.5 else str(data["name"]).left(13))+"\n"+str(level)+" / "+str(data["max_level"])+( "  ◆" if level == int(data["max_level"]) else ("  ◇" if available else "  ·"))
		if zoom < 0.45:
			caption.text = "%d/%d" % [level,data["max_level"]]
		caption.add_theme_font_size_override("font_size",maxi(8,roundi(17*zoom)))
		caption.add_theme_color_override("font_color",color.lightened(0.2) if available or level > 0 else Color("97849f"))
		b.tooltip_text = data["name"]+"\n"+data["description"]
		for state: String in ["normal","hover","pressed","hover_pressed","focus","disabled"]:
			var tint := Color("3b2547") if state != "normal" or id == selected else (Color("292333") if level > 0 else Color("1a1423"))
			var box := _frame(tint,color if id == selected else Color(color,0.5 if available else 0.2),3)
			box.set_border_width_all(2 if id == selected else 1)
			b.add_theme_stylebox_override(state,box)
		b.size = NODE_SIZE*zoom
		caption.size = b.size-Vector2(6,4)
	graph.queue_redraw()
	var node: Dictionary = configs[selected]
	var rank := int(levels.get(selected,0))
	name_label.text = str(node["name"])+"  ·  %d/%d" % [rank,node["max_level"]]
	var branches: Dictionary = GameData.Evolution.HOST_BRANCHES
	branch_label.text = ("ВОССТАНОВЛЕНИЕ ОТСЕКОВ" if ship else str(branches.get(node.get("branch",""),{}).get("name","Симбиоз")).to_upper())
	branch_label.add_theme_color_override("font_color",node["color"])
	description.text = node["description"]
	var req: PackedStringArray = []
	for parent: String in node.get("requires",{}):
		req.append("%s %s · %d/%d" % ["✓" if int(levels.get(parent,0)) >= int(node["requires"][parent]) else "○",configs[parent]["name"],levels.get(parent,0),node["requires"][parent]])
	requirements.text = "Нужны связи:\n"+"\n".join(req) if not req.is_empty() else "Начальный узел · доступен без связей"
	preview.text = _preview(rank)
	wallet.text = "В хранилище: "+ui.costs(Progress.bank)
	var cost: Array = GameData.module_cost(selected,rank) if ship else GameData.upgrade_cost(selected,rank)
	price.text = ui.costs(cost)
	purchase.text = "Развить · ранг %d" % (rank+1) if not cost.is_empty() else "Развитие завершено"
	purchase.disabled = cost.is_empty() or not Progress.requirements_met(selected,ship) or not Progress.can_afford(cost)

func _preview(rank: int) -> String:
	if ship:
		return "Системы корабля меняют отсеки и условия вылазок. Боевые характеристики носителя здесь не повышаются."
	var before := Progress.player_stats()
	var next := Progress.upgrades.duplicate()
	next[selected] = mini(rank+1,int(configs[selected]["max_level"]))
	var after: Dictionary = Progress.stats_for_upgrades(next)
	var current := before
	var names := {"max_hp":"Здоровье","damage":"Урон шипа","fire_interval":"Интервал огня, с","speed":"Скорость","armor":"Броня","regen":"Регенерация, HP/с","regen_delay":"Пауза лечения, с","pickup_radius":"Подбор","detection_radius":"Обнаружение","crit_chance":"Шанс крита","crit_power":"Добавка к криту","pierce":"Пробитие целей","lifesteal":"Вампиризм","skill_power":"Усиление навыков","skill_cost":"Экономия энергии","skill_cooldown":"Ускорение навыков","shield_power":"Усиление щита","shield_duration":"Время щита, +с","dash_length":"Длина рывка","dash_cooldown":"Ускорение рывка","spore_duration":"Жизнь спор, +с","spore_power":"Урон спор","wave_radius":"Радиус волны","hurt_grace":"Защита после удара, +с","projectile_bonus":"Скорость шипов","execute_bonus":"Добивание","moving_damage":"Урон в движении","boss_damage":"Урон стражам","projectile_ward":"Защита от снарядов","cast_heal":"Лечение навыком, HP"}
	var lines: PackedStringArray = []
	for key: String in names:
		if not is_equal_approx(float(current.get(key,0)),float(after.get(key,0))):
			var percentage: bool = key in ["armor","crit_chance","lifesteal","skill_power","skill_cost","skill_cooldown","shield_power","dash_length","dash_cooldown","spore_power","wave_radius","projectile_bonus","execute_bonus","moving_damage","boss_damage","projectile_ward"]
			var factor := 100.0 if percentage else 1.0
			var unit := "%" if percentage else ""
			lines.append("%s: %.2f%s → %.2f%s" % [names[key],float(current.get(key,0))*factor,unit,float(after.get(key,0))*factor,unit])
	if lines.is_empty():
		return "Новая форма поведения описана выше." if rank == 0 else "Мутация освоена."
	return "Следующий ранг:\n"+"\n".join(lines)+"\n\nСейчас: %d HP · %.1f урона · %.2f с/выстрел" % [before["max_hp"],before["damage"],before["fire_interval"]]

func buy() -> void:
	if ui.game.mode != "ship":
		return
	var ok: bool = Progress.purchase_module(selected) if ship else Progress.purchase_upgrade(selected)
	if ok:
		Audio.play_sfx("upgrade")
		ui.game.update_ship()
		feedback.text = "Связь укреплена. Изменения сохранены."
	else:
		feedback.text = "Покупка не выполнена: проверьте связи, ресурсы и доступность сохранения."
	refresh()
