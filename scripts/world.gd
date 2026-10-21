class_name BioWorld
extends Node2D

const ShipPlan = preload("res://scripts/ship_layout.gd")

@export var biome: String = "ship"
@export var bounds: Rect2 = Rect2(0, 0, 1536, 1152)
@export var obstacles: Array[Vector3] = []
var organs: Array[Node2D] = []
var caves: Array[Node2D] = []
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
	caves.clear()
	var cave_root := get_node_or_null("CaveEntrances")
	if cave_root != null:
		for cave: Node in cave_root.get_children():
			if cave is Node2D:
				caves.append(cave as Node2D)
	if decorations != null:
		for child: Node in decorations.get_children():
			if child is Node2D and child.has_meta("organ_id"):
				organs.append(child as Node2D)
	if biome == "ship":
		_restore_tissue_cache()
		refresh_organs()
		if not Progress.changed.is_connected(refresh_organs):
			Progress.changed.connect(refresh_organs)
	queue_redraw()

func _restore_tissue_cache() -> void:
	# World2D and the live viewport texture are runtime bindings; reconnect them
	# after loading the editable packed scene, before its first rendered frame.
	var cache := get_node_or_null("RibsMembranesAndVessels/StaticTissueCache") as SubViewport
	var image := get_node_or_null("RibsMembranesAndVessels/RenderedTissue") as Sprite2D
	if cache != null and image != null:
		cache.world_2d = World2D.new()
		cache.render_target_update_mode = SubViewport.UPDATE_ONCE
		image.texture = cache.get_texture()

func setup(context: String) -> void:
	biome = context
	bounds = Rect2(Vector2.ZERO, ShipPlan.SIZE) if biome == "ship" else Rect2(0,0,2560,1920)
	spawn_point = ShipPlan.SPAWN if biome == "ship" else Vector2(400,960)
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
	var ship_outline: PackedVector2Array = ShipPlan.footprint() if biome == "ship" else PackedVector2Array()
	for y in int(bounds.size.y/32):
		for x in int(bounds.size.x/32):
			var coord := Vector2i(x,y)
			if biome == "ship":
				if Geometry2D.is_point_in_polygon(Vector2(x * 32 + 16, y * 32 + 16), ship_outline):
					floor_map.set_cell(coord,0,Vector2i(rng.randi_range(0,5),1))
			else:
				floor_map.set_cell(coord,0,Vector2i(rng.randi_range(0,7),0))
				if x < 2 or y < 2 or x > 77 or y > 57:
					walls.set_cell(coord,0,Vector2i(rng.randi_range(4,5),2))
	if biome == "ship":
		# Collision follows the actual floor's edge, including every room divider
		# and vascular passage. Art uses the same silhouette without tiled rib seams.
		for cell: Vector2i in floor_map.get_used_cells():
			for offset: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN, Vector2i(-1,-1), Vector2i(1,-1), Vector2i(-1,1), Vector2i(1,1)]:
				var adjacent: Vector2i = cell + offset
				if floor_map.get_cell_source_id(adjacent) == -1:
					walls.set_cell(adjacent, 0, Vector2i(6, 1))
		walls.modulate.a = 0.0
		_build_ship(rng)
		refresh_organs()
		if not Progress.changed.is_connected(refresh_organs):
			Progress.changed.connect(refresh_organs)
	else:
		_build_forest(rng)
	queue_redraw()

func _build_ship(rng: RandomNumberGenerator) -> void:
	var surface := Node2D.new()
	surface.name = "RibsMembranesAndVessels"
	surface.z_index = -1
	add_child(surface)
	# The tissue is static. Keep its editable procedural source, but render it
	# once so thousands of fine vascular strokes do not run through every frame.
	var tissue_view := SubViewport.new()
	tissue_view.name = "StaticTissueCache"
	tissue_view.size = Vector2i(ShipPlan.SIZE)
	tissue_view.transparent_bg = true
	tissue_view.disable_3d = true
	tissue_view.world_2d = World2D.new()
	tissue_view.render_target_update_mode = SubViewport.UPDATE_ONCE
	surface.add_child(tissue_view)
	var membrane: Node2D = load("res://scripts/ship_tissue.gd").new() as Node2D
	membrane.name = "EditableTissueSource"
	tissue_view.add_child(membrane)
	var cached_tissue := Sprite2D.new()
	cached_tissue.name = "RenderedTissue"
	cached_tissue.centered = false
	cached_tissue.texture = tissue_view.get_texture()
	cached_tissue.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	surface.add_child(cached_tissue)
	var atlas_indices: Dictionary = {"navigation": 0, "symbiont": 1, "heart": 2, "feeding": 3, "storage": 4}
	for room: Dictionary in ShipPlan.ROOMS:
		_make_organ(room.id, room.label, room.organ, int(atlas_indices[room.id]), room.color)
		# Shaded roots are drawn by the shared tissue renderer. Low diffuse
		# light anchors the organ into the membrane without symmetric prop pairs.
		for side: float in [-1.0, 1.0]:
			var light: Sprite2D = BioVisual.add_glow(surface, Color(room.color, 0.17), 410)
			light.position = room.organ + Vector2(side * 94, -35)
	# A branching vascular spine, visible through the heart hall. There is no
	# decorative circular platform beneath the host.
	var spine := Line2D.new()
	spine.name = "HeartArtery"
	spine.points = PackedVector2Array([Vector2(1024,354),Vector2(1000,400),Vector2(1024,470)])
	spine.width = 13
	spine.default_color = Color("8e3b50")
	spine.z_index = -1
	add_child(spine)

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
	var sprite := BioVisual.sprite(visual,"res://assets/art/organs.png",Vector2i(128,128),Vector2i(index,0),1.9 if id == "heart" else 1.45)
	sprite.name = "OrganSprite"
	var glow: Sprite2D = BioVisual.add_glow(visual,Color(color,0.55),350 if id == "heart" else 280)
	glow.name = "Bioluminescence"
	glow.set_meta("base_color", glow.modulate)
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 61 if id == "heart" else 46
	shape.shape = circle
	organ.add_child(shape)
	var title := Label.new()
	title.text = label
	title.position = Vector2(-160,112 if id == "heart" else 98)
	title.size = Vector2(320,30)
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
	_build_caves()
	for i in 155:
		var point := Vector2(rng.randf_range(120,2440),rng.randf_range(120,1800))
		var clear := point.distance_to(spawn_point)<210
		# Keep the mouth and approach clear for real collision-based exits.
		for cave: Node2D in caves:
			var inside: Vector2 = cave.position + Vector2(cave.get_meta("inward")) * 250.0
			if point.distance_to(Geometry2D.get_closest_point_to_segment(point, cave.position, inside)) < 145.0:
				clear = true
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

func _build_caves() -> void:
	var entrance_root := Node2D.new()
	entrance_root.name = "CaveEntrances"
	entrance_root.z_index = 1
	add_child(entrance_root)
	for side: int in 4:
		for index: int in 3:
			var inward: Vector2 = [Vector2.DOWN, Vector2.LEFT, Vector2.UP, Vector2.RIGHT][side]
			var point: Vector2
			match side:
				0: point = Vector2(480 + index * 800, 80)
				1: point = Vector2(bounds.size.x - 80, 384 + index * 576)
				2: point = Vector2(480 + index * 800, bounds.size.y - 80)
				3: point = Vector2(80, 384 + index * 576)
			var cave := Node2D.new()
			cave.name = "Cave_%d_%d" % [side, index]
			cave.position = point
			cave.set_meta("inward", inward)
			entrance_root.add_child(cave)
			var sprite := Sprite2D.new()
			sprite.name = "RockEntrance"
			sprite.texture = load("res://assets/art/cave_entrance.png")
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			sprite.rotation = inward.angle() - PI * 0.5
			if biome == "swamp":
				sprite.modulate = Color(1.0, 0.70, 0.86)
			cave.add_child(sprite)
			var mouth := Marker2D.new()
			mouth.name = "Mouth"
			mouth.position = inward * 56.0
			cave.add_child(mouth)
			var exit := Marker2D.new()
			exit.name = "Exit"
			exit.position = inward * 118.0
			cave.add_child(exit)
			caves.append(cave)

func is_walkable(point: Vector2, clearance: float = 25) -> bool:
	if biome == "ship":
		if floor_map == null or floor_map.get_cell_source_id(floor_map.local_to_map(point)) == -1:
			return false
		var reach: int = ceili(maxf(0.0, clearance) / 32.0) + 1
		var cell: Vector2i = floor_map.local_to_map(point)
		for y: int in range(cell.y - reach, cell.y + reach + 1):
			for x: int in range(cell.x - reach, cell.x + reach + 1):
				if walls.get_cell_source_id(Vector2i(x,y)) == -1:
					continue
				var wall_rect := Rect2(Vector2(x,y) * 32.0, Vector2.ONE * 32.0)
				var nearest := point.clamp(wall_rect.position, wall_rect.end)
				if point.distance_squared_to(nearest) < clearance * clearance:
					return false
	elif not bounds.grow(-90).has_point(point):
		return false
	for item in obstacles:
		if point.distance_squared_to(Vector2(item.x,item.y)) < pow(item.z+clearance,2):
			return false
	return true
