extends SceneTree
## Rebuild native, editable crop regions from source atlas gutter metadata.
func _initialize() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/art/evolution/manifest.json"))
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for entry: Dictionary in manifest["files"]:
		if entry["key"] != "garden":
			continue
		for row: int in 3:
			var key: String = ["vascular","enzyme","core"][row]
			frames.add_animation(key)
			frames.set_animation_loop(key,false)
			frames.set_animation_speed(key,1.0)
			for column: int in 4:
				var region: Array = entry["native_regions"][row*4+column]
				var atlas := AtlasTexture.new()
				atlas.atlas = load("res://assets/art/evolution/garden.png")
				atlas.region = Rect2(float(region[0]),float(region[1]),float(region[2]),float(region[3]))
				atlas.filter_clip = true
				frames.add_frame(key,atlas)
	var error := ResourceSaver.save(frames,"res://assets/animations/garden.tres")
	print("GARDEN_FRAMES_BAKED: ",error)
	quit(0 if error == OK else 1)
