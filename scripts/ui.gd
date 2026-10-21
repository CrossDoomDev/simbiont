extends CanvasLayer

const BioSkin = preload("res://scripts/ui_skin.gd")
const BG := Color("140e1b")
const BORDER := Color("68416f")
const TEXT := Color("e5eee6")
const MUTED := Color("b4a1b7")
const ACCENT := Color("dca7ec")
const RETICLE: Texture2D = preload("res://assets/art/ui/reticle.svg")
var battle_cursor_active := false
var selected_mission := 0
var navigation_map: Control
var map_biome: Label
var map_name: Label
var map_description: Label
var map_lock: Label
var map_launch: Button
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
var skill_bar: Control
var page := ""
var toast_time := 0.0
var automatic_touch := false
var overlay_content: VBoxContainer
var top_panel: PanelContainer
var hp_panel: PanelContainer
var task_panel: PanelContainer
var minimap: Control
var hud_title: Label
var overlay_panel: PanelContainer
var overlay_scroll: ScrollContainer
var overlay_header: HBoxContainer
var overlay_width := 980.0
var overlay_left := false
var upgrade_grid: GridContainer
var layout_dirty := true
var toolbar_button: Button
var last_layout_size := Vector2.ZERO
var last_touch_layout := false
var last_layout_mode := ""
var regular: Font = preload("res://assets/fonts/regular.tres")
var bold: Font = preload("res://assets/fonts/semibold.tres")
var display: Font = preload("res://assets/fonts/display.tres")

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
	theme.default_font_size = 20
	theme.set_color("font_color","Label",TEXT)
	BioSkin.apply(theme)
	root.theme = theme
	add_child(root)
	_build_hud()
	modal_root = Control.new()
	modal_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(modal_root)
	toast_label = label("",18,ACCENT)
	toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.add_theme_color_override("font_shadow_color",Color.BLACK)
	toast_label.add_theme_constant_override("shadow_outline_size",8)
	root.add_child(toast_label)
	Progress.changed.connect(refresh_hud)

func label(value: String, font_size: int = 18, color: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = value
	l.add_theme_font_size_override("font_size",font_size + (3 if font_size >= 30 else 2))
	l.add_theme_color_override("font_color",color)
	if font_size >= 21:
		l.add_theme_font_override("font",display)
	return l

func paragraph(value: String, font_size: int = 18, color: Color = MUTED) -> Label:
	var l := label(value,font_size,color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l

func style(color: Color = BG, _border: Color = BORDER, _corner: int = 10) -> StyleBox:
	return BioSkin.panel(color.a)

func button(value: String, callback: Callable, primary: bool = false) -> Button:
	var b := Button.new()
	b.text = value
	b.clip_text = true
	b.custom_minimum_size = Vector2(minf(320, bold.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,19).x + 88),64)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	# Buttons are not parented yet; get_theme_stylebox would read Godot's defaults.
	for state: String in ["normal","hover","pressed","hover_pressed","disabled","focus"]:
		b.add_theme_stylebox_override(state,root.theme.get_stylebox(state,"Button").duplicate())
	b.add_theme_stylebox_override("normal", BioSkin.button(Color(1.16, 1.03, 1.2) if primary else Color.WHITE))
	if value == "×":
		b.custom_minimum_size.x = 58
		for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
			var close_style: StyleBox = b.get_theme_stylebox(state).duplicate()
			close_style.content_margin_left = 16
			close_style.content_margin_right = 16
			b.add_theme_stylebox_override(state,close_style)
	b.add_theme_font_override("font",bold)
	b.add_theme_font_size_override("font_size",19)
	b.add_theme_color_override("font_color",TEXT)
	b.add_theme_color_override("font_disabled_color",Color("837189"))
	b.pressed.connect(func():
		Audio.play_sfx("ui")
		callback.call())
	return b

func _box(parent: Node, separation: int = 18) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation",separation)
	parent.add_child(v)
	return v

func _hud_style() -> StyleBoxTexture:
	var box := BioSkin.panel(0.96)
	box.content_margin_left = 32
	box.content_margin_right = 32
	box.content_margin_top = 24
	box.content_margin_bottom = 24
	return box

func _build_hud() -> void:
	hud = Control.new()
	hud.name = "SymbioteHUD"
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hud)
	top_panel = PanelContainer.new()
	top_panel.name = "ResourceMembrane"
	top_panel.add_theme_stylebox_override("panel", _hud_style())
	hud.add_child(top_panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",12)
	top_panel.add_child(row)
	hud_title = label("СИМБИОНТ",21,ACCENT)
	hud_title.custom_minimum_size.x = 172
	row.add_child(hud_title)
	for i: int in 4:
		var resource := HBoxContainer.new()
		resource.add_theme_constant_override("separation",5)
		resource.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(resource)
		var icon := TextureRect.new()
		icon.texture = BioVisual.atlas("res://assets/art/resources.png",Vector2i(32,32),Vector2i(i,0))
		icon.custom_minimum_size = Vector2(24,24)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.tooltip_text = GameData.RESOURCES[i]["name"]
		resource.add_child(icon)
		var count := label("0",17,GameData.RESOURCES[i]["color"])
		count.custom_minimum_size.x = 34
		resource.add_child(count)
		resource_labels.append(count)
	var menu_button := button("Ⅱ Меню",func(): open_pause())
	toolbar_button = menu_button
	menu_button.tooltip_text = "Меню / пауза"
	menu_button.custom_minimum_size = Vector2(138,54)
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		var toolbar_style: StyleBox = menu_button.get_theme_stylebox(state).duplicate()
		toolbar_style.content_margin_left = 28
		toolbar_style.content_margin_right = 28
		toolbar_style.content_margin_top = 15
		toolbar_style.content_margin_bottom = 15
		menu_button.add_theme_stylebox_override(state,toolbar_style)
	row.add_child(menu_button)
	hp_panel = PanelContainer.new()
	hp_panel.name = "HostVitals"
	hp_panel.add_theme_stylebox_override("panel", _hud_style())
	hud.add_child(hp_panel)
	var hp_box := _box(hp_panel,6)
	hp_label = label("НОСИТЕЛЬ     100 / 100",14)
	hp_box.add_child(hp_label)
	hp_bar = ProgressBar.new()
	hp_bar.custom_minimum_size = Vector2(0,9)
	hp_bar.show_percentage = false
	hp_bar.add_theme_stylebox_override("background", BioSkin.fluid(Color("311b36")))
	hp_bar.add_theme_stylebox_override("fill", BioSkin.fluid(Color("d17baf")))
	hp_box.add_child(hp_bar)
	task_panel = PanelContainer.new()
	task_panel.name = "NeuralObjective"
	task_panel.add_theme_stylebox_override("panel", _hud_style())
	hud.add_child(task_panel)
	var task_box := _box(task_panel,5)
	status_label = label("ЖИВОЙ КОРАБЛЬ",12,ACCENT)
	task_box.add_child(status_label)
	objective_label = paragraph("Найдите навигационный узел",16,TEXT)
	task_box.add_child(objective_label)
	hint_label = label("WASD — движение   ·   E — контакт",14,MUTED)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.add_theme_color_override("font_shadow_color",Color.BLACK)
	hint_label.add_theme_constant_override("shadow_outline_size",8)
	hud.add_child(hint_label)
	interact_button = button("E   Коснуться органа",func(): game.interact(),true)
	interact_button.visible = false
	hud.add_child(interact_button)
	minimap = load("res://scripts/minimap.gd").new()
	minimap.name = "NeuralMinimap"
	minimap.game = game
	hud.add_child(minimap)
	touch = load("res://scripts/touch.gd").new()
	touch.game = game
	hud.add_child(touch)
	skill_bar = preload("res://scripts/skill_bar.gd").new()
	skill_bar.game = game
	hud.add_child(skill_bar)

func _layout() -> void:
	var view: Vector2 = root.size
	var edge: float = 16.0 if view.x < 900 else 24.0
	top_panel.position = Vector2(edge, 12)
	top_panel.size = Vector2(view.x - edge * 2, 104)
	hud_title.visible = view.x >= 1040
	toolbar_button.text = "Ⅱ" if view.x < 760 else "Ⅱ Меню"
	toolbar_button.custom_minimum_size.x = 64 if view.x < 760 else 138
	var compact: bool = view.y < 520
	status_label.visible = not compact
	hp_panel.size = Vector2(228 if view.x < 900 else 278, 88)
	hp_panel.position = Vector2(edge, 128 if game.mode == "mission" or (touch.visible and compact) else view.y - (280 if touch.visible else 100))
	task_panel.size = Vector2(250 if view.x < 900 else 330, 94 if compact else 136)
	task_panel.position = Vector2(view.x - edge - task_panel.size.x, 128)
	hint_label.visible = game.mode == "ship" and not touch.visible and view.x >= 1100 and view.y >= 600
	hint_label.position = Vector2((view.x - 610) * 0.5, view.y - 52)
	hint_label.size = Vector2(610,30)
	var action_width: float = view.x - (372.0 if touch.visible and view.x < 900 else edge * 2.0)
	interact_button.size = Vector2(minf(350, action_width),50)
	interact_button.position = Vector2((view.x - interact_button.size.x) * 0.5, view.y - 125)
	minimap.size = Vector2(180,148)
	minimap.position = Vector2(view.x - edge - minimap.size.x, view.y - (368 if touch.visible else 190))
	minimap.set_meta("compact_hidden", compact or (game.mode == "mission" and view.x < 1100))
	toast_label.position = Vector2(edge + 12, 97)
	toast_label.size = Vector2(view.x - edge * 2 - 24, 52)
	touch.layout_for_view(view)
	skill_bar.layout_for_view(view,touch)
	_fit_overlay()
	last_layout_size = view
	last_touch_layout = touch.visible
	last_layout_mode = game.mode

func _fit_overlay() -> void:
	if not is_instance_valid(overlay_panel) or not is_instance_valid(overlay_content):
		return
	var view: Vector2 = root.size
	var width: float = minf(overlay_width, view.x - 32.0)
	if is_instance_valid(upgrade_grid):
		upgrade_grid.columns = 1 if width < 790.0 else 2
	var header_height: float = overlay_header.get_combined_minimum_size().y + 20.0 if is_instance_valid(overlay_header) else 0.0
	var height: float = minf(overlay_content.get_combined_minimum_size().y + overlay_panel.get_theme_stylebox("panel").get_minimum_size().y + header_height, view.y - 32.0)
	overlay_panel.size = Vector2(width, maxf(100.0,height))
	overlay_panel.position = Vector2(24 if overlay_left and view.x >= 1000 else (view.x - width) * 0.5, (view.y - overlay_panel.size.y) * 0.5)

func _request_layout() -> void:
	layout_dirty = true

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
		objective_label.text = "Узлы   %d / 3" % game.nodes_destroyed
		if game.mission_id == 1:
			objective_label.text += "   ·   Стражи %d / 3" % game.bosses_defeated
		if game.objective_complete():
			objective_label.text = "Цель выполнена  ·  Esc → выход"
		elif game.mission_id == 1 and game.nodes_destroyed == 3:
			objective_label.text = "Стражи   %d / 3" % game.bosses_defeated
		hint_label.text = "WASD — движение    ·    Мышь — огонь    ·    Esc — меню"
	else:
		status_label.text = ("КОРАБЛЬ · СЕРДЦЕ %d / IV" if root.size.x < 900 else "ЖИВОЙ КОРАБЛЬ    ·    СЕРДЦЕ %d / IV") % Progress.modules.get("heart",0)
		objective_label.text = "Восстановите связь с кораблём"
		hint_label.text = "WASD — движение   ·   E — контакт   ·   Esc — меню"
	interact_button.visible = not game.modal and game.mode == "ship" and is_instance_valid(game.near_organ)
	if interact_button.visible:
		interact_button.text = "E   " + str(game.near_organ.get_meta("label"))
	touch.visible = (automatic_touch or bool(Progress.settings.get("touch",false))) and not game.modal
	_update_battle_cursor()
	if layout_dirty or last_layout_size != root.size or last_touch_layout != touch.visible or last_layout_mode != game.mode:
		layout_dirty = false
		_layout()
	toast_time -= delta
	toast_label.visible = toast_time>0 and not game.modal

func toast(text: String) -> void:
	toast_label.text = text
	toast_time = 4.2

func clear_overlay() -> void:
	overlay_panel = null
	overlay_scroll = null
	overlay_header = null
	overlay_content = null
	upgrade_grid = null
	overlay_left = false
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
	overlay_width = width
	var dim := ColorRect.new()
	dim.color = Color(0.025,0.01,0.035,0.79)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal_root.add_child(dim)
	overlay_panel = PanelContainer.new()
	overlay_panel.name = "OrganicMenu"
	overlay_panel.add_theme_stylebox_override("panel",BioSkin.panel())
	modal_root.add_child(overlay_panel)
	var shell := _box(overlay_panel,20)
	overlay_scroll = ScrollContainer.new()
	overlay_scroll.name = "MenuScroll"
	overlay_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	overlay_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	overlay_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shell.add_child(overlay_scroll)
	var scroll_inset := MarginContainer.new()
	scroll_inset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_inset.add_theme_constant_override("margin_right",12)
	overlay_scroll.add_child(scroll_inset)
	overlay_content = _box(scroll_inset,20)
	overlay_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	overlay_content.minimum_size_changed.connect(_request_layout)
	if title != "":
		var header := HBoxContainer.new()
		overlay_header = header
		shell.add_child(header)
		shell.move_child(header,0)
		var heading := paragraph(title,30,TEXT)
		header.add_child(heading)
		if page not in ["title", "death"]:
			header.add_child(button("×",func(): close()))
	if subtitle != "":
		overlay_content.add_child(paragraph(subtitle,16))
	layout_dirty = true
	return overlay_content

func open_title() -> void:
	page = "title"
	var v := overlay("", "",560)
	overlay_left = true
	var background := TextureRect.new()
	background.name = "LivingMembraneBackdrop"
	background.texture = BioSkin.BACKDROP
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modal_root.add_child(background)
	modal_root.move_child(background,0)
	modal_root.get_child(1).color = Color(0.02,0.005,0.025,0.24)
	v.add_child(paragraph("О Д Н А   С В Я З Ь .   Д В Е   Ж И З Н И .",13,ACCENT))
	v.add_child(label("СИМБИОНТ",54))
	v.add_child(paragraph("Чужая планета. Раненый корабль.\nВы — его последний шанс проснуться.",20,TEXT))
	v.add_child(button("Продолжить связь" if Progress.completed>0 else "Установить связь",func():
		close()
		if not Progress.tutorial:
			open_tutorial(),true))
	v.add_child(button("Настройки",func(): open_settings(true)))
	v.add_child(paragraph("ВЫЖИВАНИЕ / ВОССТАНОВЛЕНИЕ / СВЯЗЬ",12,MUTED))
	v.add_child(paragraph("Носитель и симбионт неразделимы.",15,MUTED))

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
	var v := overlay("Нейронная карта", "Выберите точку на поверхности планеты.")
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation",20)
	row.add_theme_constant_override("v_separation",20)
	v.add_child(row)
	navigation_map = load("res://scripts/map_visual.gd").new()
	navigation_map.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(navigation_map)
	navigation_map.mission_selected.connect(_select_map_mission)
	var card := PanelContainer.new()
	card.custom_minimum_size.x = 340
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(card)
	var box := _box(card,16)
	map_biome = label("",12,ACCENT)
	map_name = paragraph("",24,TEXT)
	map_description = paragraph("",16)
	map_lock = paragraph("",15,Color("dca7b6"))
	map_launch = button("Переместиться",func(): game.start_mission(selected_mission),true)
	for control: Control in [map_biome,map_name,map_description,map_lock,map_launch]:
		box.add_child(control)
	_select_map_mission(selected_mission)

func _select_map_mission(index: int) -> void:
	selected_mission = clampi(index,0,GameData.MISSIONS.size()-1)
	navigation_map.select_mission(selected_mission)
	var data: Dictionary = GameData.MISSIONS[selected_mission]
	map_biome.text = data["biome"]
	map_name.text = data["name"]
	map_description.text = data["description"]
	var available: bool = Progress.mission_unlocked(selected_mission)
	map_lock.text = "Для доступа восстановите сердце корабля до II стадии."
	map_lock.visible = not available
	map_launch.disabled = not available
	layout_dirty = true

func _update_battle_cursor() -> void:
	var active: bool = game.mode == "mission" and not game.modal and not touch.visible
	if active != battle_cursor_active:
		battle_cursor_active = active
		Input.set_custom_mouse_cursor(RETICLE if active else null,Input.CURSOR_ARROW,Vector2(24,24) if active else Vector2.ZERO)

func _exit_tree() -> void:
	if battle_cursor_active:
		Input.set_custom_mouse_cursor(null)


func open_pause() -> void:
	page = "pause"
	var v := overlay("Связь приостановлена", "Игровое время остановлено.",650)
	v.add_child(button("Продолжить",func(): close(),true))
	if game.mode == "mission":
		var finish := button("Завершить миссию",func(): open_finish_confirmation())
		finish.disabled = not game.objective_complete()
		v.add_child(finish)
		if finish.disabled:
			v.add_child(paragraph("Для возвращения уничтожьте все гнездовые узлы" + (" и всех трёх стражей." if game.mission_id==1 else "."),16))
	v.add_child(button("Настройки",func(): open_settings()))
	if game.mode == "ship":
		v.add_child(button("Главное меню",func(): open_title()))

func open_finish_confirmation() -> void:
	page = "confirm_finish"
	var v := overlay("Вернуться на корабль?", "Собранная добыча будет передана в биохранилище. На корабле её можно потратить на улучшения.",650)
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
	if game.mode != "ship":
		return
	page = "modules" if ship else "upgrades"
	var v := overlay("Пробуждение корабля" if ship else "Анатомия симбионта", "Ресурсы хранилища общие для корабля и носителя. Изменения сохраняются сразу.")
	var grid := GridContainer.new()
	upgrade_grid = grid
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
		card.custom_minimum_size = Vector2(230,0)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_theme_stylebox_override("panel",style(Color("15262f"),Color(data["color"],0.4)))
		grid.add_child(card)
		var box := _box(card,12)
		box.add_child(paragraph(data["name"],21,data["color"]))
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
		toggle.custom_minimum_size.y = 48
		toggle.clip_text = true
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
