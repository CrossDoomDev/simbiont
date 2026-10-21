extends SceneTree
## Deferred loads check autoload references in the actual project context.
## Direct --check-only --script actor.gd does not register project autoloads.

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: int = 0
	var files: Array[String] = ["data", "progress", "audio", "visual", "actor", "projectile", "world", "loot", "nest", "main", "ui", "touch", "map_visual", "minimap"]
	for filename: String in files:
		var script: Script = load("res://scripts/" + filename + ".gd") as Script
		if script == null or not script.can_instantiate():
			push_error("SCRIPT_CHECK_FAILED: " + filename)
			failures += 1
	print("SCRIPT_CHECKS: %d files, %d failures" % [files.size(), failures])
	var audio: Node = root.get_node_or_null("Audio")
	if audio != null:
		audio.queue_free()
	await create_timer(0.05).timeout
	quit(0 if failures == 0 else 1)
