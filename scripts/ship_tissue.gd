extends Node2D
## Detailed orthographic living tissue over the shared native collision footprint.
## Atlas sources and their repeatable assembly are kept alongside the game art.

const Layout = preload("res://scripts/ship_layout.gd")
var _outline: PackedVector2Array
var _tissue_atlas: Texture2D

func _ready() -> void:
	_outline = Layout.footprint()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if ResourceLoader.exists("res://assets/art/ship_tissue.png"):
		_tissue_atlas = load("res://assets/art/ship_tissue.png") as Texture2D
	queue_redraw()

func _stroke(points: PackedVector2Array, color: Color, width: float) -> void:
	if points.size() > 1:
		draw_polyline(points, color, width, true)

func _smooth(points: PackedVector2Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for i: int in range(points.size() - 1):
		var a: Vector2 = points[maxi(0,i - 1)]
		var b: Vector2 = points[i]
		var c: Vector2 = points[i + 1]
		var d: Vector2 = points[mini(points.size() - 1,i + 2)]
		for step: int in 14:
			var t: float = float(step) / 14.0
			result.append(0.5 * ((2.0*b) + (-a+c)*t + (2.0*a-5.0*b+4.0*c-d)*t*t + (-a+3.0*b-3.0*c+d)*t*t*t))
	result.append(points[-1])
	return result

func _vessel(points: PackedVector2Array, color: Color, width: float) -> void:
	var path: PackedVector2Array = _smooth(points)
	_stroke(path, Color(0.025,0.025,0.04,0.7), width + 5)
	# Veins are mottled flesh with a thin wet highlight, not colored conduits.
	var flesh: Color = Color("6e344d").lerp(color.darkened(0.65), 0.28)
	_stroke(path, flesh, width)
	var highlight := PackedVector2Array()
	for point: Vector2 in path:
		highlight.append(point + Vector2(-1,-2))
	_stroke(highlight, Color(color.lightened(0.1), 0.16), maxf(0.6,width * 0.12))

func _art(index: int, point: Vector2, size: float, rotation_angle: float = 0.0, tint: Color = Color.WHITE) -> void:
	if _tissue_atlas == null:
		return
	draw_set_transform(point, rotation_angle, Vector2.ONE * size)
	var source := Rect2(Vector2(index % 3, index / 3) * 256.0, Vector2.ONE * 256.0)
	draw_texture_rect_region(_tissue_atlas, Rect2(-128,-128,256,256), source, tint)
	draw_set_transform(Vector2.ZERO)

func _draw() -> void:
	if _outline.is_empty():
		return
	var closed: PackedVector2Array = _outline.duplicate()
	closed.append(closed[0])
	# Dark cutaway flesh under overlapping shaded wall masses. No bright outline
	# or repeating rib ladder: the outside falls into shadow like a thick hull.
	_stroke(closed, Color("1c111d"), 107)
	_draw_floor_vessels()
	for room: Dictionary in Layout.ROOMS:
		_draw_chamber(room)
	_draw_wall_tissue()

func _draw_floor_vessels() -> void:
	for index: int in Layout.CORRIDORS.size():
		var path: PackedVector2Array = Layout.CORRIDORS[index]
		var tint: Color = Layout.ROOMS[index + 1].color
		for side: float in [-1.0, 1.0]:
			var vessel := PackedVector2Array()
			for i: int in path.size():
				var tangent: Vector2 = (path[mini(i + 1,path.size()-1)] - path[maxi(0,i-1)]).normalized()
				vessel.append(path[i] + tangent.orthogonal() * (side * 59.0 + sin(i * 2.1) * 9.0))
			_vessel(vessel, tint, 5.0)
		# Fine irregular fibers bridge tissue plates; never cross the whole passage
		# with a bright repeating stripe.
		var rng := RandomNumberGenerator.new()
		rng.seed = 700 + index
		var smooth_path: PackedVector2Array = _smooth(path)
		for i: int in range(0,smooth_path.size() - 1,3):
			var p: Vector2 = smooth_path[i]
			var normal: Vector2 = (smooth_path[i+1] - p).normalized().orthogonal()
			var side: float = -1.0 if rng.randf() < 0.5 else 1.0
			var fiber := PackedVector2Array([p + normal * side * 70, p + normal * side * 49 + Vector2(7,-3), p + normal * side * 31 + Vector2(14,5)])
			_stroke(_smooth(fiber), Color(0.35,0.18,0.25,0.34), 1)

func _draw_chamber(room: Dictionary) -> void:
	var center: Vector2 = room.center
	var radii: Vector2 = room.radii
	var color: Color = room.color
	var organ: Vector2 = room.organ
	var rng := RandomNumberGenerator.new()
	rng.seed = int(center.x * 14 + center.y)
	var chamber: PackedVector2Array = Layout.room_polygon(room, 25)
	# Irregular translucent tissue membranes and hairline scars keep walking
	# ground readable while removing the mechanical hex-grid appearance.
	for i: int in 52:
		var p: Vector2 = center + Vector2(rng.randf_range(-radii.x * 0.8,radii.x * 0.8),rng.randf_range(-radii.y * 0.8,radii.y * 0.8))
		if not Geometry2D.is_point_in_polygon(p,chamber):
			continue
		var size: float = rng.randf_range(12,35)
		var membrane := PackedVector2Array()
		for j: int in 9:
			var theta: float = float(j) * TAU / 9.0
			var pulse: float = rng.randf_range(0.65,1.2)
			membrane.append(p + Vector2(cos(theta),sin(theta)) * Vector2(size,size*0.56) * pulse)
		draw_colored_polygon(membrane, Color(color.darkened(0.75),rng.randf_range(0.04,0.1)))
		var scar := PackedVector2Array([p + Vector2(-size,0), p + Vector2(-size*.4,-4), p + Vector2(size*.25,3), p + Vector2(size*.7,1)])
		_stroke(_smooth(scar),Color(0.12,0.07,0.12,0.3),1)
	# An asymmetrical root bed grows out of the upper wall into the organ. No
	# regular ring/platform sits beneath it; its tissue is continuous with hull.
	_art(1,organ + Vector2(-46,-48),0.94,-0.36,Color(0.72,0.61,0.66))
	_art(1,organ + Vector2(64,-45),0.80,1.03,Color(0.65,0.55,0.60))
	for branch: int in 9:
		var theta: float = PI + (float(branch) + rng.randf_range(-0.25,0.25)) * PI / 8.0
		var end: Vector2 = center + Vector2(cos(theta) * radii.x * .85,sin(theta) * radii.y * .85)
		var offset: Vector2 = end - organ
		var side: Vector2 = offset.normalized().orthogonal()
		var points := PackedVector2Array([organ + Vector2(rng.randf_range(-20,20),-15),organ + offset*.3 + side*rng.randf_range(-35,35),organ + offset*.68 + side*rng.randf_range(-24,24),end])
		_vessel(points,color,rng.randf_range(3.0,7.0))
		var twig := PackedVector2Array([points[2],points[2]+side*27+offset*.06,end+side*40])
		_vessel(twig,color,2.0)
	# Shaded tissue sacs inhabit the chamber's upper membrane. Navigation has
	# cold memory vesicles; storage has separate resource-colored living sacs.
	var node_count: int = 5 if room.id == "storage" else 3
	for node: int in node_count:
		var theta: float = PI + (float(node)+0.55) * PI / float(node_count)
		var p: Vector2 = center + Vector2(cos(theta)*radii.x*.78,sin(theta)*radii.y*.78)
		var atlas_index: int = 2 if room.id == "symbiont" else (4 if room.id == "navigation" else (5 if room.id == "storage" else 3))
		var tint := Color(0.85,0.77,0.83)
		if room.id == "storage":
			tint = [Color("d17c96"),Color("e7b77a"),Color("83c5de"),Color("c191dc"),Color("8fbe97")][node]
		_art(atlas_index,p,0.38+rng.randf()*.12,rng.randf_range(-.3,.3),tint)
	# Delicate luminous spores sit in sheltered corners, leaving the broad
	# central walking approach free of decorative objects and false obstacles.
	for i: int in 18:
		var theta: float = rng.randf_range(0,TAU)
		var p: Vector2 = center + Vector2(cos(theta)*radii.x*.82,sin(theta)*radii.y*.82)
		draw_circle(p,rng.randf_range(1.2,2.6),Color(color,0.38))

func _draw_wall_tissue() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 74185
	var carried: float = 0.0
	for edge: int in _outline.size():
		var a: Vector2 = _outline[edge]
		var b: Vector2 = _outline[(edge+1) % _outline.size()]
		var tangent: Vector2 = (b-a).normalized()
		var normal: Vector2 = tangent.orthogonal()
		if not Geometry2D.is_point_in_polygon((a+b)*.5+normal*8,_outline):
			normal = -normal
		var length: float = a.distance_to(b)
		while carried < length:
			var p: Vector2 = a + tangent*carried
			# Broken cadence, varying thickness and overlapping roots create a
			# substantial cutaway wall instead of repeated drawn pink lines.
			var angle: float = tangent.angle()+rng.randf_range(-.23,.23)
			var scale_factor: float = rng.randf_range(.48,.70)
			_art(0,p-normal*12,scale_factor,angle,Color(rng.randf_range(.62,.82),.57,.68))
			if rng.randf() < .43:
				_art(1,p-normal*24,scale_factor*.82,angle+rng.randf_range(-1.2,1.2),Color(.66,.51,.60))
			# Thin uneven capillaries connect the textured wall masses.
			var fiber := PackedVector2Array([p-normal*33-tangent*18,p-normal*7,p+normal*12+tangent*21])
			_stroke(_smooth(fiber),Color(.39,.13,.24,.55),rng.randf_range(1,2.8))
			carried += rng.randf_range(44.0,72.0)
		carried -= length
