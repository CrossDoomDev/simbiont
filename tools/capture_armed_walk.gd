extends SceneTree
## Render two independent body layers, including actual keyboard/mouse gameplay.
var game: Node2D
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("HOST_LAYERS_RENDER_FAILED: "+message)

func settle() -> void:
	for i: int in 10:
		await process_frame

func capture(name: String) -> void:
	await settle()
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://artifacts/screenshots/29_host_layers_"+name+".png") == OK,"save "+name)

func verify_pixels(direction: int) -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(64,64)
	viewport.transparent_bg = true
	viewport.world_2d = World2D.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var lower := Sprite2D.new()
	var upper := Sprite2D.new()
	for sprite: Sprite2D in [lower,upper]:
		sprite.position = Vector2(32,32)
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		viewport.add_child(sprite)
	lower.material = game.player.legs_anim.material
	upper.material = game.player.anim.material
	upper.texture = game.player.anim.sprite_frames.get_frame_texture("attack_%d" % direction,0)
	var samples: Array[Image] = []
	for phase: int in 2:
		lower.texture = game.player.legs_anim.sprite_frames.get_frame_texture("walk_%d" % direction,phase)
		await settle()
		await RenderingServer.frame_post_draw
		samples.append(viewport.get_texture().get_image())
	var changed_legs := 0
	var changed_upper := 0
	for y: int in 64:
		for x: int in 64:
			if samples[0].get_pixel(x,y) != samples[1].get_pixel(x,y):
				if y < 40:
					changed_upper += 1
				else:
					changed_legs += 1
	check(changed_upper == 0,"upper body is independent of both leg frames, direction %d" % direction)
	check(changed_legs > 8,"lower body visibly steps, direction %d" % direction)
	viewport.queue_free()
	await process_frame

func key(pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_D
	event.keycode = KEY_D
	event.pressed = pressed
	Input.parse_input_event(event)

func fire(pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = Vector2(900,400)
	event.global_position = event.position
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	Input.parse_input_event(event)

func verify_real_input() -> void:
	game.player.position = Vector2(1280,960)
	key(true)
	fire(true)
	var first := false
	var second := false
	var upper_firing := false
	for tick: int in 48:
		root.warp_mouse([Vector2(300,360),Vector2(980,360),Vector2(640,280),Vector2(640,500)][tick % 4])
		await physics_frame
		await process_frame
		first = first or game.player.legs_anim.frame == 0
		second = second or game.player.legs_anim.frame == 1
		upper_firing = upper_firing or game.player.anim.animation.begins_with("attack_")
	check(Input.is_physical_key_pressed(KEY_D) and game.player.velocity.x > 0,"actual D key drives movement through main.gd")
	check(first and second and game.player.legs_anim.animation == "walk_2","actual keyboard and mouse input keeps both leg phases advancing")
	check(upper_firing,"actual mouse button raises upper-body weapon while legs run")
	key(false)
	await physics_frame
	await physics_frame
	check(game.player.legs_anim.animation.begins_with("idle_") and game.player.anim.animation.begins_with("attack_"),"stopping legs does not stop upper-body fire")
	await capture("stationary_firing")
	fire(false)
	await create_timer(1.1).timeout
	check(game.player.anim.animation.begins_with("idle_") and game.player.legs_anim.animation.begins_with("idle_"),"released inputs leave both independent layers at rest")
	await capture("stationary_relaxed")

func _run() -> void:
	root.size = Vector2i(1280,720)
	var progress: Node = root.get_node("Progress")
	progress.save_path = "user://symbiont_host_layers_capture.json"
	progress._defaults()
	progress.tutorial = true
	progress.settings["touch"] = false
	progress.settings["autofire"] = false
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await settle()
	game.ui.close()
	await game.start_mission(0)
	for enemy: Node in get_nodes_in_group("enemies"):
		enemy.queue_free()
	game.player.invulnerable = 99999.0
	game.camera.position_smoothing_enabled = false
	game.camera.zoom = Vector2.ONE * 3.5
	game.ui.toast_time = 0
	await verify_real_input()
	game.set_physics_process(false)
	game.player.set_physics_process(false)
	for enemy: Node in get_nodes_in_group("enemies"):
		enemy.queue_free()
	await process_frame
	for direction: int in 4:
		var facing: Vector2 = [Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT,Vector2.UP][direction]
		game.player.position = Vector2(1280,960)
		game.player.manual_aim = facing
		game.player.move_input = facing
		game.player.manual_fire = true
		game.player.shot_clock = 0
		game.player._physics_process(0.01)
		game.player.host_visual.position = Vector2.ZERO
		game.player.anim.position = Vector2.ZERO
		game.camera.reset_smoothing()
		game.camera.force_update_scroll()
		await verify_pixels(direction)
		for phase: int in 2:
			game.player.legs_anim.frame = phase
			await capture(["down","left","right","up"][direction]+"_%d" % phase)
	# Show strafing: the legs face the run, upper body faces the shot.
	game.player.move_input = Vector2.RIGHT
	game.player.manual_aim = Vector2.UP
	game.player._physics_process(0.01)
	await capture("strafe")
	game.player.manual_fire = false
	game.player.attack_pose_remaining = 0
	game.player._physics_process(0.01)
	await capture("walking_relaxed")
	var audio: Node = root.get_node("Audio")
	for player: AudioStreamPlayer in audio._music_players + audio._effects_players:
		player.stop()
		player.stream = null
	if audio._ambient != null:
		audio._ambient.stop()
		audio._ambient.stream = null
	audio._cache.clear()
	await create_timer(0.2).timeout
	game.queue_free()
	await settle()
	print("HOST_LAYERS_RENDER_CHECKS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures > 0 else 0)
