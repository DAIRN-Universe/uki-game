extends Node2D
var state: ExplorationState
var uki: Node2D
var camera: Camera2D
var hud: Label
var flight_mode := false
var moving := false
var world_seed := 2026
var message := "Explore the steppe."
const KEYS := [KEY_E, KEY_W, KEY_Q, KEY_A, KEY_S, KEY_D]

func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--seed="):
			world_seed = clampi(int(argument.trim_prefix("--seed=")), -2147483648, 2147483647)
	state = ExplorationState.new(SteppeGenerator.generate(world_seed))
	uki = Node2D.new()
	uki.set_script(load("res://scripts/game/uki.gd"))
	add_child(uki)
	uki.position = HexGrid.center(state.position)
	camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.0
	uki.add_child(camera)
	camera.reset_smoothing()
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var panel := PanelContainer.new()
	panel.position = Vector2(16, 16)
	canvas.add_child(panel)
	hud = Label.new()
	hud.add_theme_constant_override("outline_size", 2)
	panel.add_child(hud)
	_update_hud()
	# Offline generation has already been validated. Meta proposals can only
	# replace it before play, and must pass the identical validator.
	var proxy_url := OS.get_environment("UKI_META_PROXY_URL")
	if not proxy_url.is_empty():
		set_process_unhandled_input(false)
		set_process(false)
		message = "Considering a Meta Muse Spark proposal…"
		_update_hud()
		var adapter := MetaSteppeAdapter.new()
		add_child(adapter)
		var proposal: Dictionary = await adapter.propose(world_seed, proxy_url)
		state = ExplorationState.new(proposal)
		uki.position = HexGrid.center(state.position)
		camera.reset_smoothing()
		message = "Explore the steppe."
		set_process_unhandled_input(true)
		set_process(true)
		adapter.queue_free()
		_update_hud()
	queue_redraw()

func _process(_delta: float) -> void:
	queue_redraw()
	if moving:
		return
	for i in range(KEYS.size()):
		if Input.is_physical_key_pressed(KEYS[i]):
			_attempt(state.position + HexGrid.DIRECTIONS[i], false)
			break

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			flight_mode = not flight_mode
			_update_hud()
	if event is InputEventMouseButton and event.pressed:
		if event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			_attempt(HexGrid.from_pixel(get_global_mouse_position()),
				flight_mode or event.button_index == MOUSE_BUTTON_RIGHT)

func _attempt(destination: Vector2i, flight: bool) -> void:
	if moving:
		return
	if not state.move_to(destination, flight):
		message = "Cannot fly there." if flight else "Choose a neighboring steppe hex."
		_update_hud()
		return
	moving = true
	message = "Explore the steppe."
	var tween := create_tween()
	tween.tween_property(uki, "position", HexGrid.center(destination),
		0.16 * HexGrid.distance(HexGrid.from_pixel(uki.position), destination))
	await tween.finished
	moving = false
	_update_hud()

func _update_hud() -> void:
	hud.text = "UKI · GREAT STEPPE\nQ W E / A S D: walk · Left click: adjacent hex\nRight click: fly · Space: toggle flight · Flight range: 3\n%s\n%s" % [
		"Flight selected" if flight_mode else "Walking selected",
		"Steppe explored — victory! You may keep roaming." if state.won else message]

func _draw() -> void:
	if state == null or camera == null:
		return
	# Fill the entire viewport with the same unknown lattice. Never outline the
	# finite map, expose coordinates, or draw terrain beyond discovered cells.
	var half := get_viewport_rect().size * 0.5 + Vector2(100, 100)
	var focus := camera.get_screen_center_position()
	var lo := HexGrid.from_pixel(focus - half)
	var hi := HexGrid.from_pixel(focus + half)
	for r in range(lo.y - 3, hi.y + 4):
		var left := HexGrid.from_pixel(Vector2(focus.x - half.x, r * HexGrid.ROW_SPACING))
		var right := HexGrid.from_pixel(Vector2(focus.x + half.x, r * HexGrid.ROW_SPACING))
		for q in range(left.x - 2, right.x + 3):
			var cell := Vector2i(q, r)
			var terrain := SteppeRules.terrain(state.world, cell) if state.discovered.has(cell) else "unexplored"
			var points := HexGrid.corners(cell)
			draw_colored_polygon(points, SteppeRules.PALETTE[terrain])
			points.append(points[0])
			draw_polyline(points, SteppeRules.PALETTE.border, 1.0, true)
	var selected := HexGrid.from_pixel(get_global_mouse_position())
	if SteppeRules.can_move(state.world, state.position, selected, flight_mode or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)):
		# Only show legal landing hints on already discovered terrain.
		if state.discovered.has(selected):
			var outline := HexGrid.corners(selected)
			outline.append(outline[0])
			draw_polyline(outline, SteppeRules.PALETTE.border, 2.0, true)
