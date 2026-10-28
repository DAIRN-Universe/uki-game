extends SceneTree
var checks := 0
var failures := 0
var game: Node2D

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

func _init() -> void:
	OS.set_environment("UKI_META_PROXY_URL", "")
	call_deferred("run")

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	check(game.state != null, "offline game scene starts")
	check(game.uki.position == HexGrid.center(game.state.position), "Uki centered")
	check(game.camera.position_smoothing_enabled, "camera smoothing enabled")
	check(game.state.discovered.size() == 7, "initial fog is local")
	check(not "256" in game.hud.text and not "%" in game.hud.text and not "16×16" in game.hud.text, "HUD hides world dimensions and percentage")
	var origin: Vector2i = game.state.position
	var destination: Vector2i = origin
	for direction in HexGrid.DIRECTIONS:
		if SteppeRules.can_move(game.state.world, origin, origin + direction, false):
			destination = origin + direction
			break
	game._attempt(destination, false)
	check(game.moving, "movement starts interpolation")
	check(game.uki.position != HexGrid.center(destination), "movement is not a teleport")
	await create_timer(0.08).timeout
	check(game.uki.position.distance_to(HexGrid.center(origin)) > 0.0, "Uki interpolates between centers")
	await create_timer(0.4).timeout
	check(not game.moving and game.uki.position.is_equal_approx(HexGrid.center(destination)), "movement ends at hex center")
	check(game.state.discovered.has(destination), "destination recorded")
	game._attempt(Vector2i(-10, -10), true)
	check(not game.moving and game.state.position == destination, "invalid UI flight rejected")
	var flight: Vector2i = destination
	for landing in SteppeRules.destinations(game.state.world, destination):
		if HexGrid.distance(destination, landing) == 3:
			flight = landing
			break
	check(flight != destination, "range-three flight available")
	game._attempt(flight, true)
	await create_timer(0.7).timeout
	check(game.state.position == flight and game.uki.position.is_equal_approx(HexGrid.center(flight)), "UI flight arrives at selected center")
	check(game.camera.get_screen_center_position().distance_to(game.uki.global_position) < 10, "camera follows Uki")
	var key := InputEventKey.new()
	key.keycode = KEY_SPACE
	key.pressed = true
	game._unhandled_input(key)
	check(game.flight_mode, "flight mode toggle")
	# Export a real rendered viewport when run with a display (headless skips).
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var frame := root.get_texture().get_image()
		check(frame.save_png("/tmp/uki-game-play.png") == OK, "viewport capture")
		var sampled := 0
		var mismatches := 0
		for r in range(-5, 21):
			for q in range(-5, 21):
				var cell := Vector2i(q, r)
				var screen := root.get_stretch_transform() * game.get_global_transform_with_canvas() * HexGrid.center(cell)
				if not Rect2(Vector2(5, 5), Vector2(frame.get_size()) - Vector2(10, 10)).has_point(screen):
					continue
				if screen.x < 400 and screen.y < 150:
					continue
				if HexGrid.center(cell).distance_to(game.uki.position) < 36:
					continue
				var terrain := SteppeRules.terrain(game.state.world, cell) if game.state.discovered.has(cell) else "unexplored"
				if frame.get_pixelv(Vector2i(screen)).to_html(false) != SteppeRules.PALETTE[terrain].to_html(false):
					mismatches += 1
				sampled += 1
		check(sampled > 10 and mismatches == 0, "rendered hex centers have exact approved colors")
	game.queue_free()
	await process_frame
	print("GAME: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
