extends SceneTree
## Room topology and actual native wall collision, using the generated ship.

var checks: int = 0
var failures: int = 0
var world: Node2D

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("SHIP_CHECK_FAILED: " + message)

func _path(destination: Vector2) -> Array[Vector2i]:
	var start: Vector2i = world.floor_map.local_to_map(world.spawn_point)
	var goal: Vector2i = world.floor_map.local_to_map(destination)
	var frontier: Array[Vector2i] = [start]
	var parents: Dictionary = {start: start}
	var cursor: int = 0
	while cursor < frontier.size():
		var cell: Vector2i = frontier[cursor]
		cursor += 1
		if cell == goal:
			var path: Array[Vector2i] = [goal]
			while path[-1] != start:
				path.append(parents[path[-1]])
			path.reverse()
			return path
		for step: Vector2i in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
			var next: Vector2i = cell + step
			if parents.has(next) or not world.is_walkable(world.floor_map.map_to_local(next), 16):
				continue
			parents[next] = cell
			frontier.append(next)
	return []

func _run() -> void:
	world = load("res://scripts/world.gd").new() as Node2D
	root.add_child(world)
	world.setup("ship")
	world.floor_map.update_internals()
	world.walls.update_internals()
	await physics_frame
	await physics_frame
	check(world.bounds.size == Vector2(2048,1536), "ship retains the multi-chamber footprint")
	check(world.floor_map.get_used_cells().size() >= 1000, "ship has a substantial editable native floor")
	check(world.walls.get_used_cells().size() > 200, "all chamber and corridor boundaries have native collision tiles")
	check(world.organs.size() == 5, "all five functional organs survive redesign")
	check(world.is_walkable(world.spawn_point, 25), "spawn has full player clearance")
	check(world.is_walkable(world.spawn_point + Vector2(70,0), 25), "initial rightward movement is open")
	check(not world.is_walkable(Vector2(1024,1100), 0), "hull gap between lower chambers is solid")
	check(not world.is_walkable(Vector2(850,240), 0), "upper chamber partitions are solid")
	var texture_path: String = "res://assets/art/ship_tissue.png"
	check(ResourceLoader.exists(texture_path), "detailed ship tissue atlas is installed and imported")
	if ResourceLoader.exists(texture_path):
		var texture: Texture2D = load(texture_path) as Texture2D
		check(texture != null and texture.get_size() == Vector2(768,512), "ship atlas keeps six editable 256px cells")
		if texture != null:
			var source: Image = texture.get_image()
			for cell: int in 6:
				var region: Image = source.get_region(Rect2i(Vector2i(cell % 3,cell / 3) * 256,Vector2i(256,256)))
				check(region.get_used_rect().has_area(), "ship tissue cell %d contains visible material" % cell)
		var membrane: Node = world.get_node_or_null("RibsMembranesAndVessels/StaticTissueCache/EditableTissueSource")
		check(membrane != null and membrane.get("_tissue_atlas") is Texture2D, "live ship renderer uses the detailed tissue atlas")
	var cache: SubViewport = world.get_node_or_null("RibsMembranesAndVessels/StaticTissueCache") as SubViewport
	check(cache != null and cache.size == Vector2i(world.bounds.size) and cache.render_target_update_mode == SubViewport.UPDATE_ONCE, "static tissue is cached once at full world resolution")
	check(cache != null and cache.world_2d != world.get_world_2d(), "tissue cache has an independent canvas and cannot render itself")
	var surface: Sprite2D = world.get_node_or_null("RibsMembranesAndVessels/RenderedTissue") as Sprite2D
	check(surface != null and surface.texture is ViewportTexture and not surface.centered, "cached tissue stays aligned with native world coordinates")
	var body := CharacterBody2D.new()
	body.collision_layer = 2
	body.collision_mask = 1
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 14.0
	shape.shape = circle
	body.add_child(shape)
	world.entities.add_child(body)
	await physics_frame
	for organ: Node2D in world.organs:
		var destination: Vector2 = organ.position + Vector2(0, 100)
		check(world.is_walkable(destination, 16), str(organ.get_meta("organ_id")) + " interaction approach is open")
		check(not world.is_walkable(organ.position, 16), str(organ.get_meta("organ_id")) + " remains a solid organ")
		var path: Array[Vector2i] = _path(destination)
		check(not path.is_empty(), str(organ.get_meta("organ_id")) + " can be reached through connected corridors")
		if path.is_empty():
			continue
		body.position = world.floor_map.map_to_local(path[0])
		var blocked: bool = false
		for cell: Vector2i in path:
			var movement: Vector2 = world.floor_map.map_to_local(cell) - body.position
			if body.move_and_collide(movement) != null:
				blocked = true
				break
		check(not blocked, str(organ.get_meta("organ_id")) + " route passes real physics collision with a player-sized body")
		check(body.position.distance_to(destination) < 24, str(organ.get_meta("organ_id")) + " route reaches interaction range")
	var wall_tested: bool = false
	for cell: Vector2i in world.walls.get_used_cells():
		for offset: Vector2i in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var point: Vector2 = world.floor_map.map_to_local(cell + offset)
			if not world.is_walkable(point, 15):
				continue
			body.position = point
			var collision: KinematicCollision2D = body.move_and_collide(-Vector2(offset) * 96.0)
			check(collision != null, "visible hull membrane blocks a real CharacterBody2D")
			check(body.position.distance_to(point) < 19.0, "collision stops the body at the floor edge")
			wall_tested = true
			break
		if wall_tested:
			break
	check(wall_tested, "physical hull collision was exercised")
	world.free()
	var restored: Node2D = load("res://scenes/hub.tscn").instantiate() as Node2D
	root.add_child(restored)
	var restored_cache := restored.get_node("RibsMembranesAndVessels/StaticTissueCache") as SubViewport
	var restored_image := restored.get_node("RibsMembranesAndVessels/RenderedTissue") as Sprite2D
	check(restored_cache.world_2d != restored.get_world_2d(), "packed ship restores an independent tissue canvas")
	check(restored_image.texture == restored_cache.get_texture(), "packed ship reconnects its cached tissue texture")
	restored.free()
	var audio: Node = root.get_node_or_null("Audio")
	if audio != null:
		audio.queue_free()
	await process_frame
	print("SHIP_TESTS: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)
