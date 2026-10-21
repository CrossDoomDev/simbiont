class_name BioVisual
extends RefCounted

static var glow_texture: Texture2D

static func atlas(path: String, cell: Vector2i, coords: Vector2i) -> AtlasTexture:
	var tex := AtlasTexture.new()
	tex.atlas = load(path)
	tex.region = Rect2(Vector2(coords * cell), Vector2(cell))
	return tex

static func glow() -> Texture2D:
	if glow_texture == null:
		var image := Image.create(128, 128, false, Image.FORMAT_RGBA8)
		for y in 128:
			for x in 128:
				var distance := Vector2(x - 63.5, y - 63.5).length() / 64.0
				image.set_pixel(x, y, Color(1, 1, 1, pow(maxf(0.0, 1.0 - distance), 2.6)))
		glow_texture = ImageTexture.create_from_image(image)
	return glow_texture

static func add_glow(parent: Node2D, color: Color, size: float) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = glow()
	sprite.modulate = color
	sprite.scale = Vector2.ONE * size / 128.0
	sprite.z_index = -1
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	sprite.material = mat
	parent.add_child(sprite)
	return sprite

static func sprite(parent: Node2D, path: String, cell: Vector2i, coords: Vector2i, size: float = 1.0) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = atlas(path, cell, coords)
	s.scale = Vector2.ONE * size
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	parent.add_child(s)
	return s
