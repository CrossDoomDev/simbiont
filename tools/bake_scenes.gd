extends SceneTree
## Run after asset import: godot --headless --path . --script res://tools/bake_scenes.gd
## Produces editable native scenes and reusable SpriteFrames resources.
## For focused changes, append: -- --ship-only or -- --missions-only

func _initialize() -> void:
	call_deferred("_run")

func _assign_owner(node: Node, scene_root: Node) -> void:
	for child: Node in node.get_children():
		child.owner = scene_root
		_assign_owner(child, scene_root)

func _run() -> void:
	var failures: int = 0
	var ship_only: bool = "--ship-only" in OS.get_cmdline_user_args()
	var contexts: Array[String] = ["ship", "forest", "swamp"]
	var frame_keys: Array[String] = ["host_combat", "host_base", "enemy_crawler", "enemy_shell", "enemy_ranged", "enemy_guardian"]
	if ship_only:
		contexts = ["ship"]
		frame_keys.clear()
	if "--missions-only" in OS.get_cmdline_user_args():
		contexts = ["forest", "swamp"]
		frame_keys.clear()
	var world_script: Script = load("res://scripts/world.gd") as Script
	var actor_script: Script = load("res://scripts/actor.gd") as Script
	if world_script == null or actor_script == null:
		push_error("BAKE_FAILED: gameplay scripts unavailable")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/animations"))
	var progress: Node = root.get_node("Progress")
	var original_modules: Dictionary = progress.modules.duplicate()
	var original_upgrades: Dictionary = progress.upgrades.duplicate()
	for key: String in progress.modules:
		progress.modules[key] = 0
	for key: String in progress.upgrades:
		progress.upgrades[key] = 0
	for context: String in contexts:
		var world: Node2D = world_script.new() as Node2D
		world.name = {"ship": "ShipHub", "forest": "Forest", "swamp": "SporeMarsh"}[context]
		root.add_child(world)
		world.setup(context)
		world.floor_map.update_internals()
		world.walls.update_internals()
		_assign_owner(world, world)
		var scene: PackedScene = PackedScene.new()
		var result: Error = scene.pack(world)
		var path: String = "res://scenes/" + ("hub" if context == "ship" else context) + ".tscn"
		if result == OK:
			result = ResourceSaver.save(scene, path)
		if result != OK:
			push_error("BAKE_FAILED: " + path + " error " + str(result))
			failures += 1
		else:
			print("BAKED_SCENE: ", path, " tiles=", world.floor_map.get_used_cells().size(), " obstacles=", world.obstacles.size())
		world.free()
		# Check that exported layout data and native resources survive serialization.
		if result == OK:
			var loaded_scene: PackedScene = load(path) as PackedScene
			var restored: Node2D = loaded_scene.instantiate() as Node2D
			root.add_child(restored)
			if restored.floor_map == null or restored.walls == null or restored.entities == null or restored.obstacles.is_empty() or (context == "ship" and restored.organs.size() != 5):
				push_error("BAKE_RESTORE_FAILED: " + path)
				failures += 1
			restored.free()
	for key: String in frame_keys:
		var kind: String = "host" if key.begins_with("host") else key.trim_prefix("enemy_")
		var texture_path: String = "res://assets/art/" + ("hero_base.png" if key == "host_base" else ("hero.png" if kind == "host" else "enemies.png"))
		var frames: SpriteFrames = actor_script.create_sprite_frames(texture_path, kind)
		var frames_path: String = "res://assets/animations/" + key + ".tres"
		var result: Error = ResourceSaver.save(frames, frames_path)
		if result != OK:
			push_error("BAKE_FRAMES_FAILED: " + frames_path)
			failures += 1
		else:
			print("BAKED_FRAMES: ", frames_path, " animations=", frames.get_animation_names().size())
	progress.modules = original_modules
	progress.upgrades = original_upgrades
	print("BAKE_FINISHED: %d scenes, %d SpriteFrames, %d failures" % [contexts.size(), frame_keys.size(), failures])
	quit(0 if failures == 0 else 1)
