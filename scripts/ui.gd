extends CanvasLayer

const BG := Color("0d1921")
const BORDER := Color("29414a")
const TEXT := Color("e5eee6")
const MUTED := Color("91aaa9")
const ACCENT := Color("99e5c4")
var game: Node
var root: Control
var hud: Control
var modal_root: Control
var toast_label: Label
var resource_labels: Array[Label] = []
var hp_label: Label
var hp_bar: ProgressBar
var objective_label: Label
var status_label: Label
var hint_label: Label
var interact_button: Button
var touch: Control
var page := ""
var toast_time := 0.0
var automatic_touch := false
var overlay_content: VBoxContainer
var regular: Font = preload("res://assets/fonts/regular.tres")
var bold: Font = preload("res://assets/fonts/semibold.tres")

func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	automatic_touch = OS.has_feature("mobile") or DisplayServer.is_touchscreen_available()
	if OS.has_feature("web") and Engine.has_singleton("JavaScriptBridge"):
		var bridge: Object = Engine.get_singleton("JavaScriptBridge")
		automatic_touch = automatic_touch or bool(bridge.call("eval", "navigator.maxTouchPoints > 0", true))
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme := Theme.new()
	theme.default_font = regular
	theme.default_font_size = 18
	theme.set_color("font_color","Label",TEXT)
	root.theme = theme
	add_child(root)
	_build_hud()
	modal_root = Control.new()
	modal_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(modal_root)
	toast_label = label("",18,ACCENT)
	toast_label.position = Vector2(340,105)
	toast_label.size = Vector2(600,42)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.add_theme_color_override("font_shadow_color",Color.BLACK)
	toast_label.add_theme_constant_override("shadow_outline_size",8)
	root.add_child(toast_label)
	Progress.changed.connect(refresh_hud)

func label(value: String, font_size: int = 18, color: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = value
	l.add_theme_font_size_override("font_size",font_size)
	l.add_theme_color_override("font_color",color)
	if font_size >= 25:
		l.add_theme_font_override("font",bold)
	return l

func paragraph(value: String, font_size: int = 18, color: Color = MUTED) -> Label:
	var l := label(value,font_size,color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l

func style(color: Color = BG, border: Color = BORDER, corner: int = 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(corner)
	s.set_content_margin_all(18)
	return s

func button(value: String, callback: Callable, primary: bool = false) -> Button:
	var b := Button.new()
	b.text = value
	b.custom_minimum_size = Vector2(0,46)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_stylebox_override("normal",style(Color("244b43") if primary else Color("172a32"),Color("659c83") if primary else BORDER,7))
	b.add_theme_stylebox_override("hover",style(Color("355b51"),Color("9ce3c5"),7))
	b.add_theme_stylebox_override("pressed",style(Color("406e5a"),ACCENT,7))
	b.add_theme_stylebox_override("disabled",style(Color("15222a"),Color("23323a"),7))
	for state in ["normal","hover","pressed","disabled"]:
		var box: StyleBoxFlat = b.get_theme_stylebox(state).duplicate()
		box.content_margin_top = 9
		box.content_margin_bottom = 9
		b.add_theme_stylebox_override(state,box)
	b.add_theme_color_override("font_color",TEXT)
	b.add_theme_color_override("font_disabled_color",Color("566c71"))
	b.add_theme_font_size_override("font_size",17)
	b.pressed.connect(func():
		Audio.play_sfx("ui")
		callback.call())
	return b

func _box(parent: Node, separation: int = 12) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation",separation)
	parent.add_child(v)
	return v

func _build_hud() -> void:
	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hud)
	var top := PanelContainer.new()
	top.position = Vector2(24,20)
	top.size = Vector2(1232,65)
	var top_style := style(Color(0.035,0.075,0.09,0.92))
	top_style.content_margin_top = 9
	top_style.content_margin_bottom = 9
	top.add_theme_stylebox_override("panel",top_style)
	hud.add_child(top)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",22)
	top.add_child(row)
	var title := label("С И М Б И О Н Т",21,ACCENT)
	title.custom_minimum_size.x = 220
	row.add_child(title)
	for i in 4:
		var icon := TextureRect.new()
		icon.texture = BioVisual.atlas("res://assets/art/resources.png",Vector2i(32,32),Vector2i(i,0))
		icon.custom_minimum_size = Vector2(27,27)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.tooltip_text = GameData.RESOURCES[i]["name"]
		row.add_child(icon)
		var count := label("0",20,GameData.RESOURCES[i]["color"])
		count.custom_minimum_size.x = 56
		row.add_child(count)
		resource_labels.append(count)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	row.add_child(button("Ⅱ  Меню",func(): open_pause()))
	var hp_panel := PanelContainer.new()
	hp_panel.position = Vector2(24,621)
	hp_panel.size = Vector2(278,75)
	hp_panel.add_theme_stylebox_override("panel",style(Color(0.035,0.075,0.09,0.93)))
	hud.add_child(hp_panel)
	var hp_box := _box(hp_panel,6)
	hp_label = label("НОСИТЕЛЬ     100 / 100",14)
	hp_box.add_child(hp_label)
	hp_bar = ProgressBar.new()
	hp_bar.custom_minimum_size = Vector2(240,8)
	hp_bar.show_percentage = false
	for pair in [["background",Color("352c39")],["fill",Color("ce6478")]]:
		var bar_style := style(pair[1],Color.TRANSPARENT,4)
		bar_style.set_content_margin_all(0)
		hp_bar.add_theme_stylebox_override(pair[0],bar_style)
	hp_box.add_child(hp_bar)
	var task_panel := PanelContainer.new()
	task_panel.position = Vector2(935,103)
	task_panel.size = Vector2(320,92)
	task_panel.add_theme_stylebox_override("panel",style(Color(0.035,0.075,0.09,0.88)))
	hud.add_child(task_panel)
	var task_box := _box(task_panel,5)
	status_label = label("ЖИВОЙ КОРАБЛЬ",12,ACCENT)
	task_box.add_child(status_label)
	objective_label = label("Найдите навигационный узел",17)
	task_box.add_child(objective_label)
	hint_label = label("WASD — движение   ·   E — контакт",14,MUTED)
	hint_label.position = Vector2(353,666)
	hint_label.size = Vector2(570,30)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.add_theme_color_override("font_shadow_color",Color.BLACK)
	hint_label.add_theme_constant_override("shadow_outline_size",8)
	hud.add_child(hint_label)
	interact_button = button("E   Коснуться органа",func(): game.interact(),true)
	interact_button.position = Vector2(467,595)
	interact_button.size = Vector2(350,50)
	interact_button.visible = false
	hud.add_child(interact_button)
	var minimap: Control = load("res://scripts/minimap.gd").new()
	minimap.game = game
	minimap.position = Vector2(1080,532)
	minimap.size = Vector2(174,136)
	hud.add_child(minimap)
	touch = load("res://scripts/touch.gd").new()
	touch.game = game
	hud.add_child(touch)

func refresh_hud() -> void:
	if not is_instance_valid(game) or not is_instance_valid(game.player):
		return
	var on_mission: bool = game.mode == "mission"
	var resources: Array = game.run_loot if on_mission else Progress.bank
	for i in 4:
		resource_labels[i].text = str(resources[i]) if i < resource_labels.size() else ""

func _process(delta: float) -> void:
	if not is_instance_valid(game.player):
		return
	refresh_hud()
	hud.visible = page != "title"
	if game.mode == "ship":
		for organ: Node2D in game.world.organs:
			for child: Node in organ.get_children():
				if child is Label:
					child.visible = page != "title"
	var host: BioActor = game.player
	hp_label.text = "НОСИТЕЛЬ     %d / %d" % [maxf(0,host.hp),host.max_hp]
	hp_bar.max_value = host.max_hp
	hp_bar.value = host.hp
	if game.mode == "mission":
		status_label.text = "%s    ·    %02d:%02d" % ["ЛЕС" if game.mission_id == 0 else "ТОПИ",int(game.run_time)/60,int(game.run_time)%60]
		objective_label.text = "Гнездовые узлы   %d / 3" % game.nodes_destroyed
		if game.objective_complete():
			objective_label.text = "Цель выполнена  ·  Esc → выход"
		elif game.mission_id == 1 and game.nodes_destroyed == 3:
			objective_label.text = "Уничтожьте стража"
		hint_label.text = "WASD — движение    ·    Мышь — огонь    ·    Esc — меню"
	else:
		status_label.text = "ЖИВОЙ КОРАБЛЬ    ·    СЕРДЦЕ %d / IV" % Progress.modules.get("heart",0)
		objective_label.text = "Восстановите связь с кораблём"
		hint_label.text = "WASD — движение   ·   E — контакт   ·   Esc — меню"
	interact_button.visible = not game.modal and game.mode == "ship" and is_instance_valid(game.near_organ)
	if interact_button.visible:
		interact_button.text = "E   " + str(game.near_organ.get_meta("label"))
	touch.visible = (automatic_touch or bool(Progress.settings.get("touch",false))) and not game.modal
	if touch.visible:
		hint_label.visible = false
		hp_label.get_parent().get_parent().position = Vector2(24,440)
		hud.get_child(hud.get_child_count()-2).position = Vector2(1080,352)
	else:
		hint_label.visible = true
		hp_label.get_parent().get_parent().position = Vector2(24,621)
		hud.get_child(hud.get_child_count()-2).position = Vector2(1080,532)
	toast_time -= delta
	toast_label.visible = toast_time>0 and not game.modal

func toast(text: String) -> void:
	toast_label.text = text
	toast_time = 4.2

func clear_overlay() -> void:
	for child in modal_root.get_children():
		modal_root.remove_child(child)
		child.queue_free()

func close() -> void:
	clear_overlay()
	page = ""
	game.set_modal(false)

func overlay(title: String, subtitle: String = "", width: float = 980) -> VBoxContainer:
	clear_overlay()
	game.set_modal(true)
	var dim := ColorRect.new()
	dim.color = Color(0.015,0.025,0.04,0.82)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal_root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal_root.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(width,0)
	panel.add_theme_stylebox_override("panel",style(Color("0d1b24"),Color("37505a"),14))
	center.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",12)
	margin.add_theme_constant_override("margin_right",12)
	margin.add_theme_constant_override("margin_top",10)
	margin.add_theme_constant_override("margin_bottom",10)
	panel.add_child(margin)
	overlay_content = _box(margin,14)
	var header := HBoxContainer.new()
	overlay_content.add_child(header)
	var heading := label(title,30)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	if page not in ["title", "mutation", "death"]:
		header.add_child(button("×",func(): close()))
	if subtitle != "":
		overlay_content.add_child(paragraph(subtitle,16))
	return overlay_content

func open_title() -> void:
	page = "title"
	clear_overlay()
	game.set_modal(true)
	var shade := ColorRect.new()
	shade.color = Color(0.01,0.025,0.035,0.76)
	shade.position = Vector2(0,0)
	shade.size = Vector2(680,720)
	modal_root.add_child(shade)
	var v := VBoxContainer.new()
	v.position = Vector2(72,137)
	v.size = Vector2(500,490)
	v.add_theme_constant_override("separation",18)
	modal_root.add_child(v)
	v.add_child(label("О Д Н А   С В Я З Ь .   Д В Е   Ж И З Н И .",13,ACCENT))
	v.add_child(label("СИМБИОНТ",64))
	v.add_child(paragraph("Чужая планета. Раненый корабль.\nВы — его последний шанс проснуться.",22,Color("c0d0ca")))
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 20
	v.add_child(spacer)
	v.add_child(button("Продолжить связь" if Progress.completed>0 else "Установить связь",func():
		close()
		if not Progress.tutorial:
			open_tutorial(),true))
	v.add_child(button("Настройки",func(): open_settings(true)))
	v.add_child(label("ВЫЖИВАНИЕ   /   ВОССТАНОВЛЕНИЕ   /   СВЯЗЬ",12,MUTED))
	var foot := label("Носитель и симбионт неразделимы.",15,MUTED)
	foot.position = Vector2(72,668)
	modal_root.add_child(foot)

func open_tutorial() -> void:
	page = "tutorial"
	var v := overlay("Корабль чувствует ваше присутствие", "Симбионт переводит его низкий, живой пульс.",760)
	v.add_child(paragraph("Двигайтесь WASD. Подойдите к бирюзовому навигационному органу и нажмите E. В лесу уничтожьте три гнездовых узла. Автоогонь включён; мышью можно прицеливаться вручную.",20,TEXT))
	v.add_child(paragraph("Завершённая цель позволяет вернуться через меню Esc. Одни и те же ресурсы питают вашу броню и органы корабля — выбирайте, кого усилить первым.",18))
	v.add_child(button("Я слышу тебя",func():
		Progress.tutorial = true
		Progress.save_game()
		close(),true))

func open_map() -> void:
	page = "map"
	var v := overlay("Нейронная карта", "Сигналы планеты, воспринятые через симбионта. Выберите точку вылазки.")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",24)
	v.add_child(row)
	var map: Control = load("res://scripts/map_visual.gd").new()
	row.add_child(map)
	var missions := _box(row,14)
	missions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for i in 2:
		var data: Dictionary = GameData.MISSIONS[i]
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel",style(Color("152831")))
		missions.add_child(card)
		var box := _box(card,7)
		box.add_child(label("0%d  /  %s" % [i+1,data["biome"]],12,ACCENT if i == 0 else Color("d49bbf")))
		box.add_child(label(data["name"],24))
		box.add_child(paragraph(data["description"],15))
		var available: bool = Progress.mission_unlocked(i)
		var launch := button("Начать миссию  →" if available else "Закрыто · сердце корабля II",func(): game.start_mission(i),available)
		launch.disabled = not available
		box.add_child(launch)

func open_pause() -> void:
	page = "pause"
	var v := overlay("Связь приостановлена", "Игровое время остановлено.",650)
	v.add_child(button("Продолжить",func(): close(),true))
	if game.mode == "mission":
		var finish := button("Завершить миссию",func(): open_finish_confirmation())
		finish.disabled = not game.objective_complete()
		v.add_child(finish)
		if finish.disabled:
			v.add_child(paragraph("Для возвращения уничтожьте все гнездовые узлы" + (" и стража." if game.mission_id==1 else "."),16))
	v.add_child(button("Настройки",func(): open_settings()))
	if game.mode == "ship":
		v.add_child(button("Главное меню",func(): open_title()))

func open_finish_confirmation() -> void:
	page = "confirm_finish"
	var v := overlay("Вернуться на корабль?", "Собранная добыча будет передана в биохранилище. Временные мутации исчезнут.",650)
	v.add_child(button("Завершить миссию и вернуться",func(): game.finish_mission(true),true))
	v.add_child(button("Остаться в лесу",func(): close()))

func costs(cost: Array) -> String:
	if cost.is_empty():
		return "Максимальное развитие"
	var parts: PackedStringArray = []
	for i in mini(4,cost.size()):
		if int(cost[i])>0:
			parts.append("%d %s" % [int(cost[i]),["биомассы","ткани","фермента","ядер"][i]])
	return " · ".join(parts)

func open_upgrades(ship: bool = false) -> void:
	page = "modules" if ship else "upgrades"
	var v := overlay("Пробуждение корабля" if ship else "Анатомия симбионта", "Ресурсы хранилища общие для корабля и носителя. Изменения сохраняются сразу.")
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation",16)
	grid.add_theme_constant_override("v_separation",14)
	v.add_child(grid)
	var configs: Dictionary = GameData.MODULES if ship else GameData.UPGRADES
	for id: String in configs:
		var data: Dictionary = configs[id]
		var levels: Dictionary = Progress.modules if ship else Progress.upgrades
		var level: int = int(levels[id])
		var max_level: int = int(data["max_level"])
		var cost: Array = GameData.module_cost(id,level) if ship else GameData.upgrade_cost(id,level)
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(445,0)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_theme_stylebox_override("panel",style(Color("15262f"),Color(data["color"],0.4)))
		grid.add_child(card)
		var box := _box(card,7)
		box.add_child(label(data["name"],21,data["color"]))
		box.add_child(label("● ".repeat(level) + "○ ".repeat(max_level-level),17,data["color"]))
		box.add_child(paragraph(data["description"],15))
		box.add_child(paragraph(costs(cost),14,MUTED))
		var buy := button("Развить  ·  уровень %d" % (level+1) if level<max_level else "Развитие завершено",func():
			var ok: bool = Progress.purchase_module(id) if ship else Progress.purchase_upgrade(id)
			if ok:
				Audio.play_sfx("upgrade")
				game.update_ship()
				open_upgrades(ship)
			else:
				toast("Недостаточно ресурсов или сохранение недоступно"),true)
		buy.disabled = level>=max_level or not Progress.can_afford(cost)
		box.add_child(buy)

func open_storage() -> void:
	page = "storage"
	var v := overlay("Биохранилище", "Живая ткань удерживает всё, что вы принесли домой.",760)
	for i in 4:
		v.add_child(label("%s     %d" % [GameData.RESOURCES[i]["name"],Progress.bank[i]],21,GameData.RESOURCES[i]["color"]))
	v.add_child(label("Последние вылазки",22))
	if Progress.history.is_empty():
		v.add_child(paragraph("Корабль ждёт вашего первого возвращения.",17))
	else:
		for item: Dictionary in Progress.history.slice(-3):
			v.add_child(paragraph(("Успешное возвращение" if bool(item.get("success",false)) else "Связь восстановлена после поражения")+"  ·  "+costs(item.get("loot",[0,0,0,0])),15))

func open_heart() -> void:
	page = "heart"
	var stage := int(Progress.modules.get("heart",0))
	var v := overlay("Оно ещё живо", "Стадия восстановления сердца: %d / IV" % stage,700)
	var messages: Array[String] = ["«Я помню падение. Помню холод. Принеси мне жизнь снаружи — и мы вспомним дорогу вместе.»","«Сосуды снова несут тепло. Я чувствую лес. Под ним дышит что-то чужое.»","«Связь крепнет. Багровая низина отозвалась. Её ядра помогут мне восстановиться.»","«Мои ткани срастаются. Твой пульс стал частью моего.»","«Я проснулся. Мы остаёмся здесь — но теперь у нас есть будущее.»"]
	v.add_child(paragraph(messages[clampi(stage,0,4)],23,Color("e6c3a8")))
	v.add_child(button("Открыть восстановление органов",func(): open_upgrades(true),true))

func open_mutations(choices: Array) -> void:
	page = "mutation"
	var v := overlay("Нестабильная адаптация", "Фрагменты перестраивают симбионта. Выберите одну мутацию до конца этой вылазки.")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",16)
	v.add_child(row)
	for mutation: Dictionary in choices:
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(292,270)
		card.add_theme_stylebox_override("panel",style(Color("172730"),mutation["color"]))
		row.add_child(card)
		var box := _box(card,18)
		box.add_child(label("АДАПТАЦИЯ",12,mutation["color"]))
		box.add_child(paragraph(mutation["name"],24,mutation["color"]))
		box.add_child(paragraph(mutation["description"],18))
		box.add_child(button("Принять мутацию",func(): game.select_mutation(mutation["id"]),true))

func open_results(success: bool, loot: Array, elapsed: float) -> void:
	page = "results"
	var v := overlay("Связь сохранена" if success else "Симбионт вернул вас", "Вылазка завершена за %02d:%02d. %s" % [int(elapsed)/60,int(elapsed)%60,"Добыча передана кораблю." if success else "Сохранено 50% ресурсов этой вылазки."],720)
	for i in 4:
		v.add_child(label("+ %d     %s" % [loot[i],GameData.RESOURCES[i]["name"]],22,GameData.RESOURCES[i]["color"]))
	v.add_child(button("Почувствовать корабль",func(): close(),true))

func open_death() -> void:
	page = "death"
	var v := overlay("Связь угасает", "Симбионт защитил носителя. При возвращении сохранится половина добычи этой вылазки.",680)
	v.add_child(button("Вернуться на корабль",func(): game.finish_mission(false),true))

func open_settings(from_title: bool = false) -> void:
	page = "settings"
	var v := overlay("Настройки связи", "Параметры сохраняются на этом устройстве.",700)
	for pair in [["music","Музыка и атмосфера"],["sfx","Звуки действий"]]:
		var volume_heading := HBoxContainer.new()
		var volume_name := label(pair[1],18)
		volume_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		volume_heading.add_child(volume_name)
		var percentage := label("%d%%" % roundi(float(Progress.settings.get(pair[0],0.5))*100.0),18,ACCENT)
		volume_heading.add_child(percentage)
		v.add_child(volume_heading)
		var slider := HSlider.new()
		slider.name = str(pair[0]) + "_volume"
		slider.min_value = 0
		slider.max_value = 1
		slider.step = 0.05
		slider.value = float(Progress.settings.get(pair[0],0.5))
		slider.custom_minimum_size.y = 26
		slider.value_changed.connect(func(value: float):
			percentage.text = "%d%%" % roundi(value*100.0)
			Progress.settings[pair[0]] = value
			Progress.save_game()
			Audio.update_volumes())
		v.add_child(slider)
	for pair in [["autofire","Автоматический огонь по ближайшей цели"],["touch","Показывать сенсорные стики"]]:
		var toggle := CheckButton.new()
		toggle.text = pair[1]
		toggle.button_pressed = bool(Progress.settings.get(pair[0],false))
		toggle.custom_minimum_size.y = 38
		toggle.toggled.connect(func(value: bool):
			Progress.settings[pair[0]] = value
			Progress.save_game())
		v.add_child(toggle)
	v.add_child(button("Сбросить прогресс…",func(): open_reset()))
	v.add_child(button("Назад",func(): open_title() if from_title else open_pause(),true))

func open_reset() -> void:
	page = "reset"
	var v := overlay("Сбросить всю связь?", "Ресурсы, улучшения и история вылазок будут удалены с этого устройства.",680)
	v.add_child(button("Отмена",func(): open_settings(),true))
	v.add_child(button("Удалить прогресс",func():
		Progress.reset_progress()
		game.return_to_fresh_ship()))
