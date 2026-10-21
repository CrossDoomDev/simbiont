extends SceneTree
## Run: godot --headless --path . --script res://tests/test_progress.gd
const ProgressScript = preload("res://scripts/progress.gd")
const Data = preload("res://scripts/data.gd")
var checks: int = 0
var failures: int = 0
var profile: Node
var test_path: String = "user://symbiont_progress_test.json"

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("CHECK FAILED: " + message)

func _write_raw(text: String) -> void:
	var file: FileAccess = FileAccess.open(test_path, FileAccess.WRITE)
	check(file != null, "test file opens")
	if file != null:
		file.store_string(text)
		file.close()

func _remove_files() -> void:
	for suffix: String in ["", ".bak", ".tmp"]:
		var path: String = test_path + suffix
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _run() -> void:
	_remove_files()
	profile = ProgressScript.new()
	profile.save_path = test_path
	root.add_child(profile)
	check(profile.bank == [0, 0, 0, 0], "fresh profile starts empty")
	check(profile.mission_unlocked(0), "first mission is open")
	check(not profile.mission_unlocked(1), "second biome is locked")
	check(not profile.mission_unlocked(-1), "invalid mission is locked")
	check(not profile.can_afford([-1, 0, 0, 0]), "negative costs are rejected")
	check(not profile.can_afford([0, 0, 0]), "short costs are rejected")
	check(not profile.purchase_upgrade("resonator"), "cannot buy without resources")
	check(profile.bank == [0, 0, 0, 0] and profile.upgrades.resonator == 0, "failed purchase changes nothing")
	check(not profile.purchase_upgrade("unknown"), "invalid upgrade rejected")
	profile.bank = [30, 0, 0, 0]
	check(not profile.purchase_upgrade("resonator"), "insufficient tissue rejects purchase")
	check(profile.bank == [30, 0, 0, 0], "no partial resource withdrawal")
	profile.bank = [1000, 1000, 1000, 1000]
	var initial_damage: float = profile.player_stats().damage
	for level: int in range(3):
		var before: Array = profile.bank.duplicate()
		var cost: Array = Data.upgrade_cost("resonator", level)
		check(profile.purchase_upgrade("resonator"), "upgrade level %d buys" % (level + 1))
		for i: int in range(4):
			check(profile.bank[i] == before[i] - cost[i], "exact upgrade cost resource %d" % i)
	var capped_bank: Array = profile.bank.duplicate()
	check(not profile.purchase_upgrade("resonator"), "upgrade cap rejects fourth purchase")
	check(profile.bank == capped_bank and profile.upgrades.resonator == 3, "cap does not charge")
	check(profile.player_stats().damage > initial_damage and profile.player_stats().fire_interval < 0.4, "upgrade changes next-run stats")
	for level: int in range(4):
		check(profile.purchase_module("heart"), "heart stage %d buys" % (level + 1))
		check(profile.mission_unlocked(1) == (level >= 1), "heart II controls biome access")
	capped_bank = profile.bank.duplicate()
	check(not profile.purchase_module("heart"), "ship module cap enforced")
	check(profile.bank == capped_bank, "capped ship purchase does not charge")
	profile.settings = {"music": 0.2, "sfx": 0.3, "autofire": false, "touch": true}
	profile.tutorial = true
	check(profile.save_game(), "settings persist")
	var saved_bank: Array = profile.bank.duplicate()
	profile.bank = [0, 0, 0, 0]
	profile.upgrades.resonator = 0
	profile.load_game()
	check(profile.bank == saved_bank and profile.upgrades.resonator == 3 and profile.modules.heart == 4, "reload preserves levels and bank")
	check(is_equal_approx(float(profile.settings.music), 0.2) and profile.settings.touch and not profile.settings.autofire and profile.tutorial, "reload preserves settings and tutorial")
	var old_completed: int = profile.completed
	check(profile.deposit_run([11, 7, 5, 3], false, "death-test"), "death credits salvage")
	for i: int in range(4):
		check(profile.bank[i] == saved_bank[i] + [5, 3, 2, 1][i], "death retains floor of 50 percent resource %d" % i)
	check(profile.completed == old_completed, "failed mission does not count completed")
	var death_bank: Array = profile.bank.duplicate()
	check(not profile.deposit_run([11, 7, 5, 3], false, "death-test"), "same run cannot deposit twice")
	check(profile.bank == death_bank, "duplicate deposit changes nothing")
	profile.load_game()
	check(not profile.deposit_run([99, 99, 99, 99], true, "death-test"), "duplicate protection survives reload")
	check(profile.deposit_run([10, 4, 3, 1], true, "success-test"), "successful extraction deposits")
	check(profile.completed == old_completed + 1, "successful extraction increments completion")
	check(profile.bank == [death_bank[0] + 10, death_bank[1] + 4, death_bank[2] + 3, death_bank[3] + 1], "successful extraction retains all loot")
	var success_bank: Array = profile.bank.duplicate()
	check(not profile.deposit_run([-1, 0, 0, 0], true, "bad-loot"), "invalid loot is rejected")
	check(profile.bank == success_bank, "invalid loot does not affect bank")
	# Force an unwritable destination and ensure purchases and deposits roll back.
	profile.save_path = "user://symbiont_missing_directory/profile.json"
	var old_level: int = profile.upgrades.muscle
	check(not profile.purchase_upgrade("muscle"), "failed disk write rejects purchase")
	check(profile.bank == success_bank and profile.upgrades.muscle == old_level, "failed write rolls back upgrade and cost")
	check(not profile.deposit_run([9, 9, 9, 9], true, "disk-failure"), "failed disk write rejects deposit")
	check(profile.bank == success_bank and profile.completed == old_completed + 1, "failed write rolls back extraction")
	profile.save_path = test_path
	check(profile.deposit_run([1, 1, 1, 1], true, "disk-failure"), "rolled back run remains depositable")
	# Store a clean current backup, corrupt the main file, then recover it.
	check(profile.save_game(), "second save creates healthy backup")
	var recovery_bank: Array = profile.bank.duplicate()
	_write_raw("{ definitely broken JSON")
	profile.load_game()
	check(profile.bank == recovery_bank, "malformed JSON recovers previous healthy save")
	check(not profile.load_report.is_empty(), "recovery reports backup use")
	check(profile.save_game(), "recovered profile can save over broken primary")
	# One malformed field never discards unrelated progress. Numeric bounds are clamped.
	_write_raw(JSON.stringify({"version": 1, "bank": [42, "broken", -10, 1e30], "upgrades": {"resonator": 99, "muscle": "broken", "regeneration": 2}, "modules": {"heart": 2}, "settings": {"music": -1, "sfx": "broken", "autofire": false, "touch": true}, "completed": 7, "tutorial": true, "story": 3, "history": ["bad", {"id": "safe", "loot": [3, "bad", 0, 0], "success": true}]}))
	profile.load_game()
	check(profile.bank == [42, 0, 0, Data.RESOURCE_LIMIT], "resource fields validate independently and clamp overflow")
	check(profile.upgrades.resonator == 3 and profile.upgrades.muscle == 0 and profile.upgrades.regeneration == 2, "upgrade fields validate independently")
	check(profile.modules.heart == 2 and profile.completed == 7 and profile.story == 3 and profile.tutorial, "unrelated valid progress survives malformed fields")
	check(profile.settings.music == 0.0 and profile.settings.sfx == 0.7 and profile.settings.touch, "settings validate separately")
	check(profile.history.size() == 1 and profile.history[0].loot == [3, 0, 0, 0], "malformed history entries cannot poison profile")
	check(profile.mission_unlocked(1), "restored heart still unlocks biome")
	profile.reset_progress()
	profile.load_game()
	check(profile.bank == [0, 0, 0, 0] and profile.completed == 0 and profile.upgrades.resonator == 0 and profile.modules.heart == 0, "reset persists clean profile")
	_write_raw("null")
	profile.load_game()
	check(profile.bank == [0, 0, 0, 0] and profile.completed == 0, "reset backup cannot resurrect old resources")
	_remove_files()
	profile.queue_free()
	print("PROGRESS_TESTS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
