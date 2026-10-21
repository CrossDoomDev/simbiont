extends Node
## Durable progression. Transactions are rolled back if the save cannot be written.

signal changed

const Garden = preload("res://scripts/garden_data.gd")
const Data = preload("res://scripts/data.gd")
const SAVE_VERSION: int = 2
const DEFAULT_SETTINGS: Dictionary = {"music": 0.5, "sfx": 0.7, "autofire": true, "touch": false}

var bank: Array = [0, 0, 0, 0]
var upgrades: Dictionary = Data.default_levels(false)
var modules: Dictionary = Data.default_levels(true)
var settings: Dictionary = DEFAULT_SETTINGS.duplicate()
var history: Array = []
var completed: int = 0
var tutorial: bool = false
var story: int = 0
var save_path: String = "user://symbiont_save.json"
var load_report: String = ""
var _processed_runs: Dictionary = {}
var _transaction_busy: bool = false
var legacy_traits: Dictionary = {}
var protocol: String = "normal"
var garden_beds: Array = Garden.empty_beds()
var fruit_stock: Dictionary = {"vascular":0,"enzyme":0,"core":0}
var prepared_lure := ""

func _ready() -> void:
	load_game()

func _defaults() -> void:
	bank = [0, 0, 0, 0]
	upgrades = Data.default_levels(false)
	modules = Data.default_levels(true)
	settings = DEFAULT_SETTINGS.duplicate()
	history = []
	completed = 0
	tutorial = false
	story = 0
	_processed_runs = {}
	legacy_traits = {}
	protocol = "normal"
	garden_beds = Garden.empty_beds()
	fruit_stock = {"vascular":0,"enzyme":0,"core":0}
	prepared_lure = ""

func _safe_integer(value: Variant, fallback: int, minimum: int, maximum: int) -> int:
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		return fallback
	var number: float = float(value)
	if not is_finite(number):
		return fallback
	return int(clampf(floor(number), float(minimum), float(maximum)))

func _safe_volume(value: Variant, fallback: float) -> float:
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		return fallback
	var number: float = float(value)
	return clampf(number, 0.0, 1.0) if is_finite(number) else fallback

func _read_document(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > 16000000:
		return {}
	var parser: JSON = JSON.new()
	var result: Error = parser.parse(file.get_as_text())
	file.close()
	if result != OK or typeof(parser.data) != TYPE_DICTIONARY:
		return {}
	var document: Dictionary = parser.data
	if _safe_integer(document.get("version", 0), 0, 0, 10000) not in [1,SAVE_VERSION]:
		return {}
	return document

func load_game() -> void:
	_defaults()
	load_report = ""
	var document: Dictionary = _read_document(save_path)
	if document.is_empty():
		document = _read_document(save_path + ".bak")
		if not document.is_empty():
			load_report = "Сохранение восстановлено из резервной копии."
		elif FileAccess.file_exists(save_path):
			load_report = "Сохранение повреждено. Создан новый профиль."
	if not document.is_empty():
		_apply_document(document)
	changed.emit()

func _apply_document(document: Dictionary) -> void:
	var raw_bank: Variant = document.get("bank", [])
	if typeof(raw_bank) == TYPE_ARRAY:
		for i: int in range(mini(raw_bank.size(), 4)):
			bank[i] = _safe_integer(raw_bank[i], 0, 0, Data.RESOURCE_LIMIT)
	var raw_upgrades: Variant = document.get("upgrades", {})
	if typeof(raw_upgrades) == TYPE_DICTIONARY:
		for id: String in upgrades:
			upgrades[id] = _safe_integer(raw_upgrades.get(id, 0), 0, 0, int(Data.UPGRADES[id]["max_level"]))
	var raw_modules: Variant = document.get("modules", {})
	if typeof(raw_modules) == TYPE_DICTIONARY:
		for id: String in modules:
			modules[id] = _safe_integer(raw_modules.get(id, 0), 0, 0, int(Data.MODULES[id]["max_level"]))
	# Transfer already-paid v1 ship combat bonuses into inherited character genes.
	# Buying ship systems in v2 never adds character power.
	if int(document.get("version",1)) == 1:
		legacy_traits = {"damage_bonus":int(modules["heart"])*0.05,"hp_flat":int(modules["regeneration"])*5.0,"regen_flat":int(modules["regeneration"])*0.025,"detection_flat":int(modules["navigation"])*25.0,"pickup_flat":int(modules["storage"])*8.0}
	else:
		var raw_legacy: Variant = document.get("legacy_traits",{})
		if raw_legacy is Dictionary:
			for key: String in ["damage_bonus","hp_flat","regen_flat","detection_flat","pickup_flat"]:
				var value: Variant = raw_legacy.get(key,0.0)
				if (value is float or value is int) and is_finite(float(value)):
					var limit: float = {"damage_bonus":0.2,"hp_flat":20.0,"regen_flat":0.1,"detection_flat":100.0,"pickup_flat":32.0}[key]
					legacy_traits[key] = clampf(float(value),0.0,limit)
	var saved_protocol := str(document.get("protocol","normal"))
	protocol = saved_protocol if saved_protocol == "normal" or int(modules.get(saved_protocol+"_protocol",0)) > 0 else "normal"
	var raw_beds: Variant = document.get("garden_beds",[])
	if raw_beds is Array:
		for i: int in mini(3,raw_beds.size()):
			if raw_beds[i] is Dictionary:
				var strain := str(raw_beds[i].get("strain",""))
				if Garden.CULTURES.has(strain):
					garden_beds[i] = {"strain":strain,"growth":_safe_integer(raw_beds[i].get("growth",0),0,0,int(Garden.CULTURES[strain]["growth"]))}
	var raw_fruit: Variant = document.get("fruit_stock",{})
	if raw_fruit is Dictionary:
		for strain: String in fruit_stock:
			fruit_stock[strain] = _safe_integer(raw_fruit.get(strain,0),0,0,99)
	var saved_lure := str(document.get("prepared_lure",""))
	prepared_lure = saved_lure if Garden.CULTURES.has(saved_lure) and int(fruit_stock.get(saved_lure,0)) > 0 and garden_slots() > 0 else ""
	var raw_settings: Variant = document.get("settings", {})
	if typeof(raw_settings) == TYPE_DICTIONARY:
		settings["music"] = _safe_volume(raw_settings.get("music"), 0.5)
		settings["sfx"] = _safe_volume(raw_settings.get("sfx"), 0.7)
		for key: String in ["autofire", "touch"]:
			if typeof(raw_settings.get(key)) == TYPE_BOOL:
				settings[key] = raw_settings[key]
	completed = _safe_integer(document.get("completed", 0), 0, 0, 999999)
	story = _safe_integer(document.get("story", 0), 0, 0, 100)
	if typeof(document.get("tutorial")) == TYPE_BOOL:
		tutorial = document["tutorial"]
	var raw_history: Variant = document.get("history", [])
	if typeof(raw_history) == TYPE_ARRAY:
		for entry: Variant in raw_history:
			if typeof(entry) != TYPE_DICTIONARY:
				continue
			var clean: Dictionary = {"id": str(entry.get("id", "")).left(128), "success": entry.get("success") == true, "loot": [0, 0, 0, 0], "time": _safe_integer(entry.get("time", 0), 0, 0, 9999999999)}
			var raw_loot: Variant = entry.get("loot", [])
			if typeof(raw_loot) == TYPE_ARRAY:
				for i: int in range(mini(raw_loot.size(), 4)):
					clean["loot"][i] = _safe_integer(raw_loot[i], 0, 0, Data.RESOURCE_LIMIT)
			history.append(clean)
			if history.size() > history_limit():
				history.pop_front()
	var raw_runs: Variant = document.get("processed_runs", [])
	if typeof(raw_runs) == TYPE_ARRAY:
		for run_id: Variant in raw_runs:
			if typeof(run_id) == TYPE_STRING and not run_id.is_empty() and run_id.length() <= 128:
				_processed_runs[run_id] = true
	# Older v1 saves can still retain protection through their visible history.
	for entry: Dictionary in history:
		if not str(entry["id"]).is_empty():
			_processed_runs[entry["id"]] = true

func _document() -> Dictionary:
	return {"garden_beds":garden_beds.duplicate(true),"fruit_stock":fruit_stock.duplicate(),"prepared_lure":prepared_lure,"version": SAVE_VERSION, "legacy_traits": legacy_traits.duplicate(), "protocol":protocol, "bank": bank.duplicate(), "upgrades": upgrades.duplicate(), "modules": modules.duplicate(), "settings": settings.duplicate(), "history": history.duplicate(true), "completed": completed, "tutorial": tutorial, "story": story, "processed_runs": _processed_runs.keys()}

func save_game() -> bool:
	var temporary: String = save_path + ".tmp"
	var file: FileAccess = FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		push_warning("Не удалось записать сохранение: " + str(FileAccess.get_open_error()))
		return false
	file.store_string(JSON.stringify(_document()))
	file.flush()
	var write_error: Error = file.get_error()
	file.close()
	if write_error != OK:
		return false
	# A malformed primary never replaces the last healthy backup.
	if not _read_document(save_path).is_empty():
		var copy_error: Error = DirAccess.copy_absolute(ProjectSettings.globalize_path(save_path), ProjectSettings.globalize_path(save_path + ".bak"))
		if copy_error != OK:
			return false
	var replace_error: Error = DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(save_path))
	if replace_error != OK:
		push_warning("Не удалось заменить сохранение: " + str(replace_error))
		return false
	return true

func can_afford(cost: Array) -> bool:
	if cost.size() != 4 or bank.size() != 4:
		return false
	for i: int in range(4):
		if typeof(cost[i]) != TYPE_INT and typeof(cost[i]) != TYPE_FLOAT:
			return false
		if not is_finite(float(cost[i])) or float(cost[i]) < 0.0 or float(cost[i]) != floor(float(cost[i])):
			return false
		if int(bank[i]) < int(cost[i]):
			return false
	return true

func purchase_upgrade(id: String) -> bool:
	return _purchase(id, false)

func purchase_module(id: String) -> bool:
	return _purchase(id, true)

func _purchase(id: String, ship_module: bool) -> bool:
	if _transaction_busy:
		return false
	var levels: Dictionary = modules if ship_module else upgrades
	if not levels.has(id) or not requirements_met(id,ship_module):
		return false
	var level: int = int(levels[id])
	var cost: Array = Data.module_cost(id, level) if ship_module else Data.upgrade_cost(id, level)
	if not can_afford(cost):
		return false
	_transaction_busy = true
	var old_bank: Array = bank.duplicate()
	var old_story: int = story
	for i: int in range(4):
		bank[i] = int(bank[i]) - int(cost[i])
	levels[id] = level + 1
	if ship_module and id == "heart":
		story = maxi(story, level + 1)
	if not save_game():
		bank = old_bank
		levels[id] = level
		story = old_story
		_transaction_busy = false
		return false
	_transaction_busy = false
	changed.emit()
	return true

func deposit_run(loot: Array, success: bool, run_id: String, run_protocol: String = "normal", cleared_nests: int = 3) -> bool:
	if _transaction_busy or run_id.is_empty() or run_id.length() > 128 or _processed_runs.has(run_id) or loot.size() != 4:
		return false
	for value: Variant in loot:
		if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
			return false
		if not is_finite(float(value)) or float(value) < 0.0 or float(value) != floor(float(value)):
			return false
	_transaction_busy = true
	var old_document: Dictionary = _document()
	var credited: Array = credited_loot(loot,success,run_protocol)
	for i: int in range(4):
		bank[i] = mini(int(bank[i]) + int(credited[i]), Data.RESOURCE_LIMIT)
	_processed_runs[run_id] = true
	if success:
		for bed: Dictionary in garden_beds:
			if Garden.CULTURES.has(bed["strain"]):
				bed["growth"] = mini(int(Garden.CULTURES[bed["strain"]]["growth"]),int(bed["growth"])+clampi(cleared_nests,0,3))
		completed = mini(completed + 1, 999999)
		story = maxi(story, 1)
	history.append({"id": run_id, "success": success, "loot": credited, "time": int(Time.get_unix_time_from_system())})
	if history.size() > history_limit():
		history.pop_front()
	if not save_game():
		_defaults()
		_apply_document(old_document)
		_transaction_busy = false
		return false
	_transaction_busy = false
	changed.emit()
	return true

func reset_progress() -> void:
	var old_document: Dictionary = _document()
	_defaults()
	if not save_game():
		_apply_document(old_document)
		return
	# Reset also replaces the backup, so old progress cannot reappear on recovery.
	DirAccess.copy_absolute(ProjectSettings.globalize_path(save_path), ProjectSettings.globalize_path(save_path + ".bak"))
	changed.emit()

func player_stats() -> Dictionary:
	return stats_for_upgrades(upgrades)

func stats_for_upgrades(levels: Dictionary) -> Dictionary:
	var result: Dictionary = Data.stats(levels)
	result["damage"] *= 1.0 + float(legacy_traits.get("damage_bonus",0))
	result["max_hp"] += float(legacy_traits.get("hp_flat",0))
	result["hp"] = result["max_hp"]
	result["regen"] += float(legacy_traits.get("regen_flat",0))
	result["detection_radius"] += float(legacy_traits.get("detection_flat",0))
	result["pickup_radius"] += float(legacy_traits.get("pickup_flat",0))
	return result

func requirements_met(id: String, ship: bool) -> bool:
	var configs: Dictionary = Data.MODULES if ship else Data.UPGRADES
	var levels: Dictionary = modules if ship else upgrades
	if not configs.has(id):
		return false
	for parent: String in configs[id].get("requires",{}):
		if int(levels.get(parent,0)) < int(configs[id]["requires"][parent]):
			return false
	return true

func history_limit() -> int:
	return 50 if int(modules.get("blackbox",0)) > 0 else 20

func death_keep_ratio() -> float:
	return minf(0.8,Data.DEATH_KEEP_RATIO + int(modules.get("salvage",0))*0.05 + int(modules.get("memory_vault",0))*0.1)

func credited_loot(loot: Array, success: bool, run_protocol: String = "normal") -> Array:
	var result: Array = [0,0,0,0]
	for i: int in 4:
		var factor := 1.0 if success else death_keep_ratio()
		if success and i < 3:
			factor += int(modules.get("victory_dividend",0))*0.05
			if run_protocol == "swarm":
				factor += 0.25
			elif run_protocol == "predator" and i in [1,2]:
				factor += 0.5
			if i == 0 and int(modules.get("living_legacy",0)) > 0:
				factor += 0.2
		result[i] = _safe_integer(floorf(float(loot[i])*factor+0.000001),0,0,Data.RESOURCE_LIMIT)
	if success:
		result[0] = mini(Data.RESOURCE_LIMIT,int(result[0])+int(modules.get("logistics",0))*5)
		result[1] = mini(Data.RESOURCE_LIMIT,int(result[1])+int(modules.get("recycler",0))*2)
	return result

func set_protocol(value: String) -> bool:
	if _transaction_busy or (value != "normal" and int(modules.get(value+"_protocol",0)) <= 0):
		return false
	var previous := protocol
	protocol = value
	if not save_game():
		protocol = previous
		return false
	changed.emit()
	return true

func recipes() -> Array[Dictionary]:
	if int(modules.get("converter",0)) <= 0:
		return []
	var biomass := 12-int(modules.get("efficient_conversion",0))*2
	var result: Array[Dictionary] = [
		{"id":"tissue","name":"Вырастить ткань","cost":[biomass,0,0,0],"output":[0,1,0,0]},
		{"id":"enzyme","name":"Выделить фермент","cost":[biomass,0,0,0],"output":[0,0,1,0]},
	]
	if int(modules.get("core_synthesis",0)) > 0:
		result.append({"id":"core","name":"Собрать ядро","cost":[80,30,20,0],"output":[0,0,0,1]})
	return result

func convert(recipe_id: String) -> bool:
	if _transaction_busy:
		return false
	for recipe: Dictionary in recipes():
		if recipe["id"] != recipe_id or not can_afford(recipe["cost"]):
			continue
		var previous := bank.duplicate()
		for i: int in 4:
			if int(bank[i])+int(recipe["output"][i]) > Data.RESOURCE_LIMIT:
				return false
		_transaction_busy = true
		for i: int in 4:
			bank[i] += int(recipe["output"][i])-int(recipe["cost"][i])
		if not save_game():
			bank = previous
			_transaction_busy = false
			return false
		_transaction_busy = false
		changed.emit()
		return true
	return false

func mission_unlocked(id: int) -> bool:
	return id >= 0 and id < Data.MISSIONS.size() and int(modules["heart"]) >= int(Data.MISSIONS[id]["heart_required"])

func garden_slots() -> int:
	if int(modules.get("archive_door",0)) == 0:
		return 0
	return 3 if int(modules.get("blackbox",0)) > 0 else 2

func garden_finish(previous: Dictionary) -> bool:
	if not save_game():
		_defaults()
		_apply_document(previous)
		_transaction_busy = false
		return false
	_transaction_busy = false
	changed.emit()
	return true

func sow_garden(index: int, strain: String) -> bool:
	if _transaction_busy or index < 0 or index >= garden_slots() or not Garden.CULTURES.has(strain):
		return false
	if garden_beds[index]["strain"] != "" or not can_afford(Garden.CULTURES[strain]["cost"]):
		return false
	var previous := _document()
	_transaction_busy = true
	for i: int in 4:
		bank[i] -= int(Garden.CULTURES[strain]["cost"][i])
	garden_beds[index] = {"strain":strain,"growth":0}
	return garden_finish(previous)

func harvest_garden(index: int) -> bool:
	if _transaction_busy or index < 0 or index >= garden_slots() or Garden.stage(garden_beds[index]) != 3:
		return false
	var strain: String = garden_beds[index]["strain"]
	if int(fruit_stock.get(strain,0)) >= 99:
		return false
	var previous := _document()
	_transaction_busy = true
	fruit_stock[strain] += 1
	garden_beds[index] = {"strain":"","growth":0}
	return garden_finish(previous)

func digest_fruit(strain: String) -> bool:
	if _transaction_busy or garden_slots() == 0 or not Garden.CULTURES.has(strain) or int(fruit_stock.get(strain,0)) <= 0:
		return false
	var reward: Array = Garden.CULTURES[strain]["digest"]
	for i: int in 4:
		if int(bank[i])+int(reward[i]) > Data.RESOURCE_LIMIT:
			return false
	var previous := _document()
	_transaction_busy = true
	fruit_stock[strain] -= 1
	if prepared_lure == strain and fruit_stock[strain] == 0:
		prepared_lure = ""
	for i: int in 4:
		bank[i] += int(reward[i])
	return garden_finish(previous)

func prepare_lure(strain: String) -> bool:
	if _transaction_busy or garden_slots() == 0 or (strain != "" and (not Garden.CULTURES.has(strain) or int(fruit_stock.get(strain,0)) <= 0)):
		return false
	var previous := _document()
	_transaction_busy = true
	prepared_lure = strain
	return garden_finish(previous)

func launch_lure() -> Dictionary:
	if prepared_lure == "":
		return {"ok":true,"strain":""}
	if _transaction_busy or garden_slots() == 0 or int(fruit_stock.get(prepared_lure,0)) <= 0:
		return {"ok":false,"strain":""}
	var previous := _document()
	var strain := prepared_lure
	_transaction_busy = true
	fruit_stock[strain] -= 1
	prepared_lure = ""
	return {"ok":garden_finish(previous),"strain":strain}
