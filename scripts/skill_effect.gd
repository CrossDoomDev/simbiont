class_name BioSkillEffect
extends Node2D
## Generated four-frame art, animated natively in the actual paused game world.
const EDGE_SHADER: Shader = preload("res://assets/shaders/skill_vfx.gdshader")
const ART: Texture2D = preload("res://assets/art/skills/effects.png")
static var cached_frames: SpriteFrames
var controller: Node
var skill_index := 0
var duration := 0.6
var age := 0.0
var radius := 100.0
var power := 0.0
var anchor: Node2D
var sprite: AnimatedSprite2D
var damage_clock := 0.0

static func frames() -> SpriteFrames:
	if cached_frames != null:
		return cached_frames
	if ResourceLoader.exists("res://assets/animations/skills.tres") and "--rebuild-skills" not in OS.get_cmdline_user_args():
		cached_frames = load("res://assets/animations/skills.tres")
		return cached_frames
	cached_frames = SpriteFrames.new()
	cached_frames.remove_animation("default")
	for row: int in 5:
		var key := "effect_%d" % row
		cached_frames.add_animation(key)
		cached_frames.set_animation_speed(key,8.0)
		cached_frames.set_animation_loop(key,row == 1)
		for column: int in 4:
			var region := AtlasTexture.new()
			region.atlas = ART
			var x := floorf(column * ART.get_width() / 4.0)
			var y := floorf(row * ART.get_height() / 5.0)
			region.region = Rect2(x,y,floorf((column+1)*ART.get_width()/4.0)-x,floorf((row+1)*ART.get_height()/5.0)-y)
			region.filter_clip = true
			cached_frames.add_frame(key,region)
	return cached_frames

static func icon(index: int) -> Texture2D:
	return frames().get_frame_texture("effect_%d" % index,2)

func _ready() -> void:
	add_to_group("skill_effects")
	z_index = 5 if skill_index != 1 else -1
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = frames()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var edge_material := ShaderMaterial.new()
	edge_material.shader = EDGE_SHADER
	sprite.material = edge_material
	sprite.scale = Vector2.ONE * (radius * 2.0 / (ART.get_width()/4.0))
	add_child(sprite)
	sprite.play("effect_%d" % skill_index)

func _physics_process(delta: float) -> void:
	age += delta
	if age >= duration:
		queue_free()
		return
	if is_instance_valid(anchor):
		global_position = anchor.global_position
	if skill_index == 1:
		damage_clock -= delta
		if damage_clock <= 0.0:
			damage_clock += 0.5
			controller.damage_area(global_position,radius,power,0.65)
	if skill_index == 2 and age > 0.25 and age < duration-0.25:
		sprite.pause()
		sprite.frame = 2
		sprite.modulate.a = 0.82 + sin(age*5.0)*0.12
		rotation += delta * 0.10
	modulate.a = clampf((duration-age)/0.22,0.0,1.0)
	if age >= duration:
		queue_free()
	queue_redraw()

func _draw() -> void:
	if skill_index == 1:
		draw_circle(Vector2.ZERO,radius,Color(0.35,0.7,0.2,0.06))
		draw_arc(Vector2.ZERO,radius,0,TAU,64,Color(0.6,0.85,0.25,0.25),1.5,true)
