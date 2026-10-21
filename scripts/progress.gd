extends Node
## Durable progression. Transactions are rolled back if the save cannot be written.

signal changed

const Data = preload("res://scripts/data.gd")
const SAVE_VERSION: int = 1
const DEFAULT_UPGRADES: Dictionary = {"regeneration": 0, "muscle": 0, "resonator": 0, "receptor": 0}
const DEFAULT_MODULES: Dictionary = {"heart": 0, "navigation": 0, "regeneration": 0, "storage": 0}
const DEFAULT_SETTINGS: Dictionary = {"music": 0.5, "sfx": 0.7, "autofire": true, "touch": false}

var bank: Array = [0, 0, 0, 0]
var upgrades: Dictionary = DEFAULT_UPGRADES.duplicate()
var modules: Dictionary = DEFAULT_MODULES.duplicate()
var settings: Dictionary = DEFAULT_SETTINGS.duplicate()
var history: Array = []
var completed: int = 0
var tutorial: bool = false
var story: int = 0
var save_path: String = "user://symbiont_save.json"
var load_report: String = ""
var _processed_runs: Dictionary = {}
var _transaction_busy: bool = false

func _ready() -> void:
	load_game()

func _defaults() -> void:
	bank = [0, 0, 0, 0]
	upgrades = DEFAULT_UPGRADES.duplicate()
	modules = DEFAULT_MODULES.duplicate()
	settings = DEFAULT_SETTINGS.duplicate()
	history = []
	completed = 0
	tutorial = false
	story = 0
	_processed_runs = {}

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
	if _safe_integer(document.get("version", 0), 0, 0, 10000) != SAVE_VERSION:
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
			upgrades[id] = _safe_integer(raw_upgrades.get(id, 0), 0, 0, 3)
	var raw_modules: Variant = document.get("modules", {})
	if typeof(raw_modules) == TYPE_DICTIONARY:
		for id: String in modules:
			modules[id] = _safe_integer(raw_modules.get(id, 0), 0, 0, 4)
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
			if history.size() > 20:
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
	return {"version": SAVE_VERSION, "bank": bank.duplicate(), "upgrades": upgrades.duplicate(), "modules": modules.duplicate(), "settings": settings.duplicate(), "history": history.duplicate(true), "completed": completed, "tutorial": tutorial, "story": story, "processed_runs": _processed_runs.keys()}

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
	if not levels.has(id):
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

func deposit_run(loot: Array, success: bool, run_id: String) -> bool:
	if _transaction_busy or run_id.is_empty() or run_id.length() > 128 or _processed_runs.has(run_id) or loot.size() != 4:
		return false
	for value: Variant in loot:
		if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
			return false
		if not is_finite(float(value)) or float(value) < 0.0 or float(value) != floor(float(value)):
			return false
	_transaction_busy = true
	var old_document: Dictionary = _document()
	var credited: Array = [0, 0, 0, 0]
	for i: int in range(4):
		credited[i] = _safe_integer(float(loot[i]) * (1.0 if success else Data.DEATH_KEEP_RATIO), 0, 0, Data.RESOURCE_LIMIT)
		bank[i] = mini(int(bank[i]) + int(credited[i]), Data.RESOURCE_LIMIT)
	_processed_runs[run_id] = true
	if success:
		completed = mini(completed + 1, 999999)
		story = maxi(story, 1)
	history.append({"id": run_id, "success": success, "loot": credited, "time": int(Time.get_unix_time_from_system())})
	if history.size() > 20:
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
	var result: Dictionary = Data.stats(upgrades)
	result["damage"] = float(result["damage"]) * (1.0 + int(modules["heart"]) * 0.05)
	result["hp"] = float(result["hp"]) + int(modules["regeneration"]) * 5.0
	result["max_hp"] = result["hp"]
	result["regen"] = float(result["regen"]) + int(modules["regeneration"]) * float(Data.REGEN["module_rate"])
	result["detection_radius"] = float(result["detection_radius"]) + int(modules["navigation"]) * 25.0
	result["pickup_radius"] = float(result["pickup_radius"]) + int(modules["storage"]) * 8.0
	return result

func mission_unlocked(id: int) -> bool:
	return id >= 0 and id < Data.MISSIONS.size() and int(modules["heart"]) >= int(Data.MISSIONS[id]["heart_required"])
