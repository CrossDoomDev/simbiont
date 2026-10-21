class_name ShipLayout
extends RefCounted
## Shared footprint for the editable TileMap, membrane artwork and navigation.
## Coordinates describe tissue chambers, not a circular arena with five props.

const SIZE := Vector2(2816, 2176)
const SPAWN := Vector2(1024, 770)
const ROOMS: Array[Dictionary] = [
	{"id": "heart", "label": "Сердечный зал", "center": Vector2(1024, 650), "radii": Vector2(322, 310), "organ": Vector2(1024, 470), "color": Color("ed6d53")},
	{"id": "symbiont", "label": "Камера симбиоза", "center": Vector2(410, 382), "radii": Vector2(270, 228), "organ": Vector2(370, 300), "color": Color("b975dd")},
	{"id": "navigation", "label": "Память пути", "center": Vector2(1640, 415), "radii": Vector2(265, 245), "organ": Vector2(1660, 325), "color": Color("4ec8de")},
	{"id": "feeding", "label": "Восстановительный узел", "center": Vector2(390, 1150), "radii": Vector2(270, 232), "organ": Vector2(360, 1065), "color": Color("efa15b")},
	{"id": "storage", "label": "Ресурсные мешки", "center": Vector2(1625, 1130), "radii": Vector2(290, 258), "organ": Vector2(1640, 1055), "color": Color("78cba4")},
	{"id":"archive","label":"Архив отпечатков","center":Vector2(2410,550),"radii":Vector2(270,240),"organ":Vector2(2450,480),"color":Color("70cbdc"),"unlock":"archive_door"},
	{"id":"refinery","label":"Камера переработки","center":Vector2(1740,1820),"radii":Vector2(300,260),"organ":Vector2(1770,1740),"color":Color("b3d487"),"unlock":"refinery_door"},
	{"id":"quarantine","label":"Карантинная камера","center":Vector2(500,1800),"radii":Vector2(285,250),"organ":Vector2(480,1725),"color":Color("c18ce0"),"unlock":"quarantine_door"},
]
const GATES: Array[Dictionary] = [
	{"id":"archive_door","rect":Rect2(2055,330,64,280),"name":"АРХИВ · ЗАПЕЧАТАН"},
	{"id":"refinery_door","rect":Rect2(1570,1470,280,64),"name":"ПЕРЕРАБОТКА · ЗАПЕЧАТАНА"},
	{"id":"quarantine_door","rect":Rect2(330,1460,280,64),"name":"КАРАНТИН · ЗАПЕЧАТАН"},
]
static var CORRIDORS: Array[PackedVector2Array] = [
	PackedVector2Array([Vector2(820, 570), Vector2(700, 565), Vector2(620, 505), Vector2(600, 415), Vector2(465, 405)]),
	PackedVector2Array([Vector2(1260, 575), Vector2(1370, 545), Vector2(1390, 430), Vector2(1500, 415), Vector2(1590, 440)]),
	PackedVector2Array([Vector2(840, 820), Vector2(740, 875), Vector2(695, 1020), Vector2(580, 1135), Vector2(440, 1150)]),
	PackedVector2Array([Vector2(1220, 815), Vector2(1360, 870), Vector2(1420, 1015), Vector2(1530, 1120), Vector2(1610, 1130)]),
	PackedVector2Array([Vector2(1830,440),Vector2(2020,450),Vector2(2160,490),Vector2(2300,550)]),
	PackedVector2Array([Vector2(1640,1310),Vector2(1680,1440),Vector2(1720,1600),Vector2(1740,1750)]),
	PackedVector2Array([Vector2(420,1300),Vector2(460,1410),Vector2(470,1590),Vector2(500,1730)]),
]
const CORRIDOR_RADII: Array[float] = [96.0, 96.0, 100.0, 104.0,96.0,100.0,100.0]

static func room_polygon(room: Dictionary, inset: float = 0.0) -> PackedVector2Array:
	var polygon := PackedVector2Array()
	var center: Vector2 = room.center
	var radii: Vector2 = room.radii - Vector2.ONE * inset
	for i: int in 80:
		var theta: float = TAU * float(i) / 80.0
		var tissue: float = 1.0 + 0.045 * sin(theta * 3.0 + center.x) + 0.025 * cos(theta * 5.0)
		polygon.append(center + Vector2(cos(theta), sin(theta)) * radii * tissue)
	return polygon

static func footprint() -> PackedVector2Array:
	var polygon: PackedVector2Array = room_polygon(ROOMS[0])
	for i: int in CORRIDORS.size():
		var corridor: Array[PackedVector2Array] = Geometry2D.offset_polyline(CORRIDORS[i], CORRIDOR_RADII[i], Geometry2D.JOIN_ROUND, Geometry2D.END_ROUND)
		var union: Array[PackedVector2Array] = Geometry2D.merge_polygons(polygon, corridor[0])
		if union.size() == 1:
			polygon = union[0]
		union = Geometry2D.merge_polygons(polygon, room_polygon(ROOMS[i + 1]))
		if union.size() == 1:
			polygon = union[0]
	return polygon

static func room_for(id: String) -> Dictionary:
	for room: Dictionary in ROOMS:
		if room.id == id:
			return room
	return ROOMS[0]
