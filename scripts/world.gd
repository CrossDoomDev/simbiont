class_name BioWorld
extends Node2D

@export var biome: String = "ship"
@export var bounds: Rect2 = Rect2(0, 0, 1536, 1152)
@export var obstacles: Array[Vector3] = []
var organs: Array[Node2D] = []
@export var nest_positions: Array[Vector2] = []
@export var spawn_point: Vector2 = Vector2(768, 660)
var floor_map: TileMapLayer
var walls: TileMapLayer
var decorations: Node2D
var entities: Node2D
var clock := 0.0

func _ready() -> void:
	if has_node("Ground"):
		restore_bindings()

func restore_bindings() -> void:
	# Packed editor scenes retain native TileMapLayer/TileSet and animation nodes.
	floor_map = get_node_or_null("Ground") as TileMapLayer
	walls = get_node_or_null("OrganicWalls" if biome == "ship" else "RockBoundary") as TileMapLayer
	decorations = get_node_or_null("BiologicalDecorations") as Node2D
	entities = get_node_or_null("Actors") as Node2D
	organs.clear()
	if decorations != null:
		for child: Node in decorations.get_children():
			if child is Node2D and child.has_meta("organ_id"):
				organs.append(child as Node2D)
	if biome == "ship":
		refresh_organs()
		if not Progress.changed.is_connected(refresh_organs):
			Progress.changed.connect(refresh_organs)
	queue_redraw()

func setup(context: String) -> void:
	biome = context
	bounds = Rect2(0,0,1536,1152) if biome == "ship" else Rect2(0,0,2560,1920)
	spawn_point = Vector2(768,660) if biome == "ship" else Vector2(400,960)
	var tileset := TileSet.new()
	tileset.tile_size = Vector2i(32,32)
	tileset.add_physics_layer()
	tileset.set_physics_layer_collision_layer(0,1)
	var atlas := TileSetAtlasSource.new()
	atlas.texture = load("res://assets/art/tiles.png")
	atlas.texture_region_size = Vector2i(32,32)
	for y in 3:
		for x in 8:
			atlas.create_tile(Vector2i(x,y))
	tileset.add_source(atlas,0)
	for cell in [Vector2i(6,1),Vector2i(7,1),Vector2i(4,2),Vector2i(5,2),Vector2i(6,2),Vector2i(7,2)]:
		var data := atlas.get_tile_data(cell,0)
		data.set_collision_polygons_count(0,1)
		data.set_collision_polygon_points(0,0,PackedVector2Array([Vector2(-16,-16),Vector2(16,-16),Vector2(16,16),Vector2(-16,16)]))
	floor_map = TileMapLayer.new()
	floor_map.name = "Ground"
	floor_map.tile_set = tileset
	floor_map.z_index = -2
	if biome == "swamp":
		floor_map.modulate = Color(0.91, 0.59, 0.78)
	add_child(floor_map)
	walls = TileMapLayer.new()
	walls.name = "OrganicWalls" if biome == "ship" else "RockBoundary"
	walls.tile_set = tileset
	walls.z_index = 1
	add_child(walls)
	decorations = Node2D.new()
	decorations.name = "BiologicalDecorations"
	decorations.y_sort_enabled = true
	add_child(decorations)
	entities = Node2D.new()
	entities.name = "Actors"
	entities.y_sort_enabled = true
	entities.z_index = 2
	add_child(entities)
	var rng := RandomNumberGenerator.new()
	rng.seed = 48291 if biome == "ship" else (91741 if biome == "swamp" else 81729)
	for y in int(bounds.size.y/32):
		for x in int(bounds.size.x/32):
			var coord := Vector2i(x,y)
			if biome == "ship":
				var d := Vector2((x*32+16-768)/660.0,(y*32+16-576)/454.0).length()
				if d < 1.0:
					floor_map.set_cell(coord,0,Vector2i(rng.randi_range(0,5),1))
				if d >= 0.93 and d < 1.12:
					walls.set_cell(coord,0,Vector2i(rng.randi_range(6,7),1))
			else:
				floor_map.set_cell(coord,0,Vector2i(rng.randi_range(0,7),0))
				if x < 2 or y < 2 or x > 77 or y > 57:
					walls.set_cell(coord,0,Vector2i(rng.randi_range(4,5),2))
	if biome == "ship":
		_build_ship(rng)
		refresh_organs()
		if not Progress.changed.is_connected(refresh_organs):
			Progress.changed.connect(refresh_organs)
	else:
		_build_forest(rng)
	queue_redraw()

func _build_ship(rng: RandomNumberGenerator) -> void:
	_make_organ("navigation", "Навигационный узел", Vector2(414,470),0,Color("55d9d5"))
	_make_organ("symbiont", "Регенеративное ложе", Vector2(1110,470),1,Color("bc83ec"))
	_make_organ("heart", "Энергетическое сердце", Vector2(768,340),2,Color("ffa359"))
	_make_organ("feeding", "Питающая камера", Vector2(480,790),3,Color("f69458"))
	_make_organ("storage", "Биохранилище", Vector2(1056,790),4,Color("8ed68d"))
	for i in 24:
		var theta := TAU * i / 24.0
		var p := Vector2(768,576)+Vector2(cos(theta)*590,sin(theta)*392)
		var prop := BioVisual.sprite(decorations,"res://assets/art/props.png",Vector2i(64,64),Vector2i(6+i%2,0),rng.randf_range(0.8,1.5))
		prop.position = p
		prop.modulate = Color("9e617d")
		prop.rotation = theta + PI/2
	# Veins are decorative native Line2D nodes, with traversable open space.
	for organ in organs:
		var vein := Line2D.new()
		vein.width = 5
		vein.default_color = Color(0.38,0.16,0.24,0.45)
		var destination := organ.position
		var origin := Vector2(768,570)
		for j in 18:
			var t := float(j)/17
			var p := origin.lerp(destination,t)
			p += (destination-origin).normalized().orthogonal()*sin(t*PI*4)*12
			vein.add_point(p)
		vein.z_index = -1
		add_child(vein)

func _make_organ(id: String, label: String, pos: Vector2, index: int, color: Color) -> void:
	var organ := StaticBody2D.new()
	organ.name = id.capitalize()
	organ.position = pos
	organ.collision_layer = 1
	organ.collision_mask = 0
	organ.set_meta("organ_id",id)
	organ.set_meta("label",label)
	organ.set_meta("color",color)
	decorations.add_child(organ)
	var visual := Node2D.new()
	visual.name = "LivingTissue"
	organ.add_child(visual)
	var sprite := BioVisual.sprite(visual,"res://assets/art/organs.png",Vector2i(128,128),Vector2i(index,0),1.28 if id == "heart" else 1.0)
	sprite.name = "OrganSprite"
	var glow: Sprite2D = BioVisual.add_glow(visual,Color(color,0.55),250 if id == "heart" else 200)
	glow.name = "Bioluminescence"
	glow.set_meta("base_color", glow.modulate)
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 42 if id == "heart" else 34
	shape.shape = circle
	organ.add_child(shape)
	var title := Label.new()
	title.text = label
	title.position = Vector2(-130,80)
	title.size = Vector2(260,30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font",load("res://assets/fonts/regular.tres"))
	title.add_theme_font_size_override("font_size",16)
	title.modulate = color.lightened(0.3)
	organ.add_child(title)
	# Native AnimationPlayer: editable scale and modulate tracks.
	var player := AnimationPlayer.new()
	player.name = "PulseAnimation"
	var library := AnimationLibrary.new()
	var animation := Animation.new()
	animation.length = 2.6
	animation.loop_mode = Animation.LOOP_LINEAR
	var track := animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(track,NodePath("LivingTissue:scale"))
	animation.track_insert_key(track,0.0,Vector2.ONE*0.98)
	animation.track_insert_key(track,1.3,Vector2.ONE*1.025)
	animation.track_insert_key(track,2.6,Vector2.ONE*0.98)
	library.add_animation("heartbeat",animation)
	player.add_animation_library("",library)
	player.autoplay = "heartbeat"
	organ.add_child(player)
	organs.append(organ)
	obstacles.append(Vector3(pos.x,pos.y,circle.radius))

func refresh_organs() -> void:
	for organ: Node2D in organs:
		if not is_instance_valid(organ):
			continue
		var id: String = str(organ.get_meta("organ_id", ""))
		var stage: int = int(Progress.modules.get(id, 0))
		if id == "symbiont":
			var total: int = 0
			for value: Variant in Progress.upgrades.values():
				total += int(value)
			stage = mini(4, ceili(total / 3.0))
		elif id == "feeding":
			stage = int(Progress.modules.get("regeneration", 0))
		organ.set_meta("stage", stage)
		var sprite: Sprite2D = organ.get_node("LivingTissue/OrganSprite") as Sprite2D
		var glow: Sprite2D = organ.get_node("LivingTissue/Bioluminescence") as Sprite2D
		var vitality: float = 0.65 + stage * 0.0875
		sprite.modulate = Color(0.55, 0.43, 0.52).lerp(Color.WHITE, vitality)
		var color: Color = glow.get_meta("base_color", Color.WHITE)
		color.a *= 0.8 + stage * 0.09
		glow.modulate = color

func _build_forest(rng: RandomNumberGenerator) -> void:
	nest_positions = [Vector2(1110,430),Vector2(2080,960),Vector2(1370,1570)]
	for i in 155:
		var point := Vector2(rng.randf_range(120,2440),rng.randf_range(120,1800))
		var clear := point.distance_to(spawn_point)<210
		for nest in nest_positions:
			if point.distance_to(nest)<170:
				clear = true
		# Clear broad routes between starting zone and every objective.
		for nest: Vector2 in nest_positions:
			if point.distance_to(Geometry2D.get_closest_point_to_segment(point,spawn_point,nest)) < 90:
				clear = true
		if clear:
			continue
		var index := rng.randi_range(0,7)
		var prop := BioVisual.sprite(decorations,"res://assets/art/props.png",Vector2i(64,64),Vector2i(index,0),rng.randf_range(1.0,1.85))
		prop.position = point
		if biome == "swamp":
			prop.modulate = Color(1.0, 0.73, 0.86)
		if index < 4:
			var body := StaticBody2D.new()
			body.position = point + Vector2(0,10)
			body.collision_layer = 1
			body.collision_mask = 0
			var shape := CollisionShape2D.new()
			var circle := CircleShape2D.new()
			circle.radius = (17.0 if index < 2 else 23.0) * prop.scale.x
			shape.shape = circle
			body.add_child(shape)
			decorations.add_child(body)
			obstacles.append(Vector3(body.position.x,body.position.y,circle.radius))
		elif index in [4,5]:
			BioVisual.add_glow(prop,Color(0.2,0.65,0.85,0.22) if index == 4 else Color(0.5,0.2,0.75,0.2),105)
	for i in 90:
		var decal := Sprite2D.new()
		decal.texture = BioVisual.glow()
		decal.position = Vector2(rng.randf_range(100,2460),rng.randf_range(100,1820))
		decal.scale = Vector2(rng.randf_range(1,3),rng.randf_range(0.7,1.6))
		decal.modulate = Color(0.1,0.48,0.38,0.09)
		decorations.add_child(decal)

func is_walkable(point: Vector2, clearance: float = 25) -> bool:
	if biome == "ship":
		if Vector2((point.x-768)/600.0,(point.y-576)/397.0).length()>0.97:
			return false
	elif not bounds.grow(-90).has_point(point):
		return false
	for item in obstacles:
		if point.distance_squared_to(Vector2(item.x,item.y)) < pow(item.z+clearance,2):
			return false
	return true

func _draw() -> void:
	if biome == "ship":
		draw_arc(Vector2(768,576),210,0,TAU,96,Color(0.42,0.23,0.35,0.32),3)
		draw_arc(Vector2(768,576),218,0,TAU,96,Color(0.42,0.23,0.35,0.15),1)
