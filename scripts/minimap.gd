extends Control

const BioSkin = preload("res://scripts/ui_skin.gd")
var game: Node

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(160,124)

func _process(_delta: float) -> void:
	visible = not game.modal and not bool(get_meta("compact_hidden", false))
	queue_redraw()

func _draw() -> void:
	if not visible or not is_instance_valid(game.world) or not is_instance_valid(game.player):
		return
	var box := Rect2(Vector2.ZERO,size)
	draw_style_box(_panel(),box)
	var inner := Rect2(24,24,size.x-48,size.y-48)
	if game.mode == "ship":
		var map_scale: Vector2 = inner.size / game.world.bounds.size
		for cell: Vector2i in game.world.floor_map.get_used_cells():
			var p: Vector2 = inner.position + Vector2(cell) * 32.0 * map_scale
			draw_rect(Rect2(p, Vector2.ONE * 32.0 * map_scale + Vector2.ONE * 0.3), Color("593547"))
		for organ: Node2D in game.world.organs:
			if not organ.visible:
				continue
			var p: Vector2 = inner.position + organ.position * map_scale
			draw_circle(p, 3.3, organ.get_meta("color", Color.WHITE))
		for gate: Dictionary in ShipLayout.GATES:
			if int(Progress.modules.get(gate["id"],0)) <= 0:
				var p: Vector2 = inner.position + (gate["rect"] as Rect2).get_center()*map_scale
				draw_circle(p,2.8,Color("b56581"))
		var host: Vector2 = inner.position + game.player.global_position * map_scale
		draw_circle(host, 3.0, Color("d9ffe6"))
		draw_arc(host, 6.0, 0, TAU, 16, Color(0.65,1.0,0.8,0.6), 1.0)
		return
	if int(Progress.modules.get("cave_echo",0)) > 0:
		for cave: Node2D in game.world.caves:
			var p: Vector2 = inner.position+cave.global_position/game.world.bounds.size*inner.size
			draw_circle(p,2.5,Color("85c2c0"))
	if int(Progress.modules.get("threat_echo",0)) > 0:
		for enemy: Node2D in get_tree().get_nodes_in_group("enemies"):
			if not enemy.dead and (int(Progress.modules.get("survey",0)) > 0 or enemy.global_position.distance_to(game.player.global_position) <= 400):
				var p: Vector2 = inner.position+enemy.global_position/game.world.bounds.size*inner.size
				draw_circle(p,2.2,Color("eb785f"))
	for i in 4:
		var x := inner.position.x+inner.size.x*float(i)/3
		draw_line(Vector2(x,inner.position.y),Vector2(x,inner.end.y),Color(0.3,0.55,0.55,0.1),1)
	for nest: Node2D in get_tree().get_nodes_in_group("nests"):
		var p: Vector2 = inner.position+nest.global_position/game.world.bounds.size*inner.size
		draw_circle(p,4,Color("f5839f"))
	var host: Vector2 = inner.position+game.player.global_position/game.world.bounds.size*inner.size
	draw_circle(host,4,Color("b0ffe1"))
	draw_arc(host,8,0,TAU,16,Color(0.5,0.9,0.75,0.4),1)

func _panel() -> StyleBox:
	return BioSkin.panel(0.96)
