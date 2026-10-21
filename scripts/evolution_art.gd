class_name EvolutionArt
extends RefCounted
## Unmodified image-generator output; native atlas regions and texture layout only.
const FRAMES: Texture2D = preload("res://assets/art/evolution/frames.png")
const BACKDROP: Texture2D = preload("res://assets/art/evolution/backdrop.png")
const GATES: Texture2D = preload("res://assets/art/evolution/gates.png")
const CROPS: SpriteFrames = preload("res://assets/animations/garden.tres")
const GARDEN: Texture2D = preload("res://assets/art/evolution/garden.png")

static func cell(texture: Texture2D, columns: int, rows: int, index: int) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	var x: float = floorf(float(index % columns)*texture.get_width()/columns)
	var y: float = floorf(float(index / columns)*texture.get_height()/rows)
	atlas.region = Rect2(x,y,floorf(float(index % columns+1)*texture.get_width()/columns)-x,floorf(float(index / columns+1)*texture.get_height()/rows)-y)
	atlas.filter_clip = true
	return atlas

static func frame(index: int, padding: float = 8.0) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = cell(FRAMES,2,3,index)
	box.set_content_margin_all(padding)
	return box

static func plant(strain: int, stage: int) -> AtlasTexture:
	return CROPS.get_frame_texture(["vascular","enzyme","core"][clampi(strain,0,2)],clampi(stage,0,3)) as AtlasTexture
