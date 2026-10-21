extends VBoxContainer
## Playable cultivation choices; no activity log or passive character bonuses.
var ui: CanvasLayer
var beds_grid: GridContainer
var seeds_grid: GridContainer
var fruits_grid: GridContainer
var feedback: Label

func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation",20)
	add_child(ui.paragraph("Растения питаются уничтоженными узлами после успешного возвращения. Одна вылазка даёт до трёх единиц роста. Поражение роста не даёт.",17))
	beds_grid = _grid()
	for index: int in 3:
		var card := _card(beds_grid)
		var bed: Dictionary = Progress.garden_beds[index]
		var strain := str(bed["strain"])
		var unlocked := index < Progress.garden_slots()
		var data: Dictionary = GardenData.CULTURES.get(strain,{})
		card.add_child(ui.paragraph("Колыбель %d" % (index+1),20))
		var image := TextureRect.new()
		image.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		image.texture = EvolutionArt.plant(int(data.get("row",0)),GardenData.stage(bed))
		image.custom_minimum_size = Vector2(0,115)
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image.modulate.a = 1 if strain != "" and unlocked else 0.35
		card.add_child(image)
		if not unlocked:
			card.add_child(ui.paragraph("Закрыта · восстановите Корневую сеть в дереве корабля.",16))
		elif strain == "":
			card.add_child(ui.paragraph("Свободна. Выберите культуру ниже.",16))
		else:
			card.add_child(ui.paragraph(data["name"],18,data["color"]))
			card.add_child(ui.paragraph("Рост: %d / %d узлов" % [bed["growth"],data["growth"]],16))
			var harvest: Button = ui.button("Собрать плод",func(): _result(Progress.harvest_garden(index)))
			harvest.disabled = GardenData.stage(bed) < 3
			card.add_child(harvest)
	add_child(ui.label("Вырастить культуру",23))
	seeds_grid = _grid()
	for id: String in GardenData.CULTURES:
		var data: Dictionary = GardenData.CULTURES[id]
		var card := _card(seeds_grid)
		card.add_child(ui.paragraph(data["name"],20,data["color"]))
		card.add_child(ui.paragraph("Созревает за %d узлов. Посадка: %s" % [data["growth"],ui.costs(data["cost"])],16))
		var seed: Button = ui.button("Посадить",func():
			for index: int in Progress.garden_slots():
				if Progress.garden_beds[index]["strain"] == "":
					_result(Progress.sow_garden(index,id))
					return
			feedback.text = "Все колыбели заняты. Дождитесь созревания и соберите плод.")
		seed.disabled = not Progress.can_afford(data["cost"])
		card.add_child(seed)
	add_child(ui.label("Плоды: питание или охота",23))
	add_child(ui.paragraph("Питание сразу даёт ресурсы. Приманка расходует один плод при отправлении: после первого узла вырастет необязательный кокон. Разбейте его, победите пришедшего стража и подберите добычу. Приманку можно оставить нетронутой и выполнить обычную цель.",17))
	fruits_grid = _grid()
	for id: String in GardenData.CULTURES:
		var data: Dictionary = GardenData.CULTURES[id]
		var card := _card(fruits_grid)
		card.add_child(ui.paragraph("%s · плодов %d" % [data["name"],Progress.fruit_stock[id]],19,data["color"]))
		card.add_child(ui.paragraph("Питание: "+ui.costs(data["digest"])+"\nДобыча охоты: "+ui.costs(data["hunt"])+" + обычная добыча стража.",15))
		var digest: Button = ui.button("Накормить корабль",func(): _result(Progress.digest_fruit(id)))
		digest.disabled = int(Progress.fruit_stock[id]) <= 0
		card.add_child(digest)
		var prepare: Button = ui.button("✓ Приманка выбрана" if Progress.prepared_lure == id else "Взять на охоту",func(): _result(Progress.prepare_lure(id)),true)
		prepare.disabled = int(Progress.fruit_stock[id]) <= 0
		card.add_child(prepare)
	if Progress.prepared_lure != "":
		add_child(ui.paragraph("На следующую вылазку: "+str(GardenData.CULTURES[Progress.prepared_lure]["name"]),18))
		add_child(ui.button("Отложить приманку",func(): _result(Progress.prepare_lure(""))))
	feedback = ui.paragraph("",16,Color("eeb9d6"))
	add_child(feedback)
	add_child(ui.button("Развить ксеносад",func():
		ui.open_upgrades(true)
		ui.evolution_tree.select("blackbox")))
	resized.connect(_layout_grids)
	_layout_grids()

func _result(ok: bool) -> void:
	if ok:
		Audio.play_sfx("upgrade")
		ui.open_garden()
	else:
		feedback.text = "Действие не выполнено. Проверьте ресурсы, зрелость культуры и доступность сохранения."

func _grid() -> GridContainer:
	var grid := GridContainer.new()
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation",16)
	grid.add_theme_constant_override("v_separation",16)
	add_child(grid)
	return grid

func _card(parent: GridContainer) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var skin: StyleBoxTexture = ui.BioSkin.panel()
	skin.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel",skin)
	parent.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation",14)
	panel.add_child(box)
	return box

func _layout_grids() -> void:
	var columns := 3 if size.x >= 1020 else (2 if size.x >= 700 else 1)
	for grid: GridContainer in [beds_grid,seeds_grid,fruits_grid]:
		if is_instance_valid(grid):
			grid.columns = columns
