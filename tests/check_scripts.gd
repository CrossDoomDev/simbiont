extends SceneTree
## Deferred loads check autoload references in the actual project context.
## Direct --check-only --script actor.gd does not register project autoloads.

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: int = 0
	var files: Array[String] = []
	for filename: String in DirAccess.get_files_at("res://scripts"):
		if filename.ends_with(".gd"):
			files.append(filename.trim_suffix(".gd"))
	files.sort()
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
