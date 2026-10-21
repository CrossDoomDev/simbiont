extends SceneTree

func _initialize() -> void:
	var base: FontFile = load("res://assets/fonts/Manrope.ttf")
	var axes: Dictionary = base.get_supported_variation_list()
	print("FONT_AXES: ", axes)
	for key: String in ["regular", "semibold"]:
		var font := FontVariation.new()
		font.base_font = base
		font.variation_opentype = {2003265652: 450.0 if key == "regular" else 700.0}
		ResourceSaver.save(font, "res://assets/fonts/"+key+".tres")
		print("FONT_SAVED: ", key, " ", font.variation_opentype)
	quit()
