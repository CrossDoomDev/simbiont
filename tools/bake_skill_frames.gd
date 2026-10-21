extends SceneTree
## Reproduce all 20 generated VFX frames as editable native SpriteFrames.
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var effect: Script = load("res://scripts/skill_effect.gd")
	var result := ResourceSaver.save(effect.frames(),"res://assets/animations/skills.tres")
	print("SKILL_FRAMES_BAKED: ",result)
	quit(0 if result == OK else 1)
