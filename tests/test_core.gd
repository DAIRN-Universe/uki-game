extends SceneTree
var checks := 0
var failures := 0

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

func _init() -> void:
	for r in range(-20, 21):
		for q in range(-20, 21):
			var cell := Vector2i(q, r)
			check(HexGrid.from_pixel(HexGrid.center(cell)) == cell, "coordinate round trip")
	for direction in HexGrid.DIRECTIONS:
		check(HexGrid.distance(Vector2i.ZERO, direction) == 1, "six adjacent cells")
		check(is_equal_approx(HexGrid.center(direction).length(), HexGrid.WIDTH), "center spacing")
	check(HexGrid.corners(Vector2i.ZERO).size() == 6, "six hex vertices")
	var colors := {"steppe": "c9be91", "mountain": "938d7e", "river": "83bed0", "sea": "477f94", "unexplored": "303638", "border": "8d8567"}
	for terrain in colors:
		check(SteppeRules.PALETTE[terrain].to_html(false) == colors[terrain], "exact approved color: " + terrain)
	for direction in HexGrid.DIRECTIONS:
		var shared := 0
		for a in HexGrid.corners(Vector2i.ZERO):
			for b in HexGrid.corners(direction):
				if a.distance_to(b) < 0.001:
					shared += 1
		check(shared == 2, "adjacent hexes share exactly one edge")
	var world := SteppeGenerator.generate(2026)
	check(SteppeValidator.validate(world, 2026).is_empty(), "valid example world")
	check(world == SteppeGenerator.generate(2026), "reproducible seed")
	check(world != SteppeGenerator.generate(42), "different seeds differ")
	for seed_value in range(64):
		var generated := SteppeGenerator.generate(seed_value)
		check(SteppeValidator.validate(generated, seed_value).is_empty(), "valid seed %d" % seed_value)
		for r in range(16):
			for q in range(16):
				var cell := Vector2i(q, r)
				if SteppeRules.boundary(cell):
					check(SteppeRules.terrain(generated, cell) in ["mountain", "sea"], "sealed boundary for generated seed")
	for seed_value in [-2147483648, -1, 2147483647]:
		var generated := SteppeGenerator.generate(seed_value)
		check(SteppeValidator.validate(generated, seed_value).is_empty(), "valid boundary seed")
		check(generated == SteppeGenerator.generate(seed_value), "reproducible boundary seed")
	check(SteppeValidator.validate(SteppeGenerator._candidate(0, 0), 0).is_empty(), "emergency fallback family member is valid")
	_test_boundary(world)
	_test_movement()
	_test_validation(world)
	_test_victory(world)
	print("CORE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _test_boundary(world: Dictionary) -> void:
	check(SteppeRules.REVEAL_RADIUS == 1, "reveal radius stays one")
	check(not SteppeRules.required_for_victory(Vector2i.ZERO), "origin corner exempt")
	check(not SteppeRules.required_for_victory(Vector2i(15, 15)), "opposite corner exempt")
	check(SteppeRules.required_for_victory(Vector2i(0, 15)), "other corner still required")
	check(SteppeRules.required_for_victory(Vector2i(15, 0)), "other corner still required")
	check(not SteppeRules.required_for_victory(Vector2i(-1, 0)), "outside map is not a target")
	var positions := SteppeValidator.reachable(world)
	for r in range(16):
		for q in range(16):
			var cell := Vector2i(q, r)
			if not SteppeRules.boundary(cell):
				continue
			for terrain in ["steppe", "river"]:
				var bad := world.duplicate(true)
				bad.cells[r * 16 + q] = terrain
				check("Boundary cells must be mountain or sea." in SteppeValidator.validate(bad, 2026), "reject every walkable or river boundary cell")
			for origin in positions:
				if HexGrid.distance(origin, cell) <= 3:
					check(not SteppeRules.can_move(world, origin, cell, true), "cannot fly onto rim")
					check(not SteppeRules.can_move(world, origin, cell, false), "cannot walk onto rim")

func fixture() -> Dictionary:
	var cells: Array = []
	cells.resize(256)
	cells.fill("steppe")
	return {"version": 1, "seed": 0, "width": 16, "height": 16,
		"cells": cells, "start": [5, 5], "rivers": []}

func _test_movement() -> void:
	var world := fixture()
	var a := Vector2i(5, 5)
	for direction in HexGrid.DIRECTIONS:
		check(SteppeRules.can_move(world, a, a + direction, false), "walk neighbor")
	check(not SteppeRules.can_move(world, a, a, true), "reject stationary flight")
	check(not SteppeRules.can_move(world, a, a + Vector2i(2, 0), false), "walk range")
	check(SteppeRules.can_move(world, a, a + Vector2i(3, 0), true), "flight range three")
	check(not SteppeRules.can_move(world, a, a + Vector2i(4, 0), true), "reject flight range four")
	check(not SteppeRules.can_move(world, Vector2i.ZERO, Vector2i(-1, 0), true), "bounds")
	for terrain in ["mountain", "sea", "river"]:
		world.cells[5 * 16 + 6] = terrain
		check(not SteppeRules.can_move(world, a, a + Vector2i(1, 0), false), "cannot walk onto " + terrain)
		check(not SteppeRules.can_move(world, a, a + Vector2i(1, 0), true), "cannot land on " + terrain)
		check(SteppeRules.can_move(world, a, a + Vector2i(2, 0), true) == (terrain == "river"), "flight crossing " + terrain)
	world.cells[5 * 16 + 6] = "steppe"
	# (0,0) → (1,1) follows the shared edge of (1,0)/(0,1).
	for blocked in [Vector2i(6, 5), Vector2i(5, 6)]:
		world.cells[blocked.y * 16 + blocked.x] = "mountain"
		check(not SteppeRules.can_move(world, a, a + Vector2i(1, 1), true), "edge tie blocks either side")
		world.cells[blocked.y * 16 + blocked.x] = "steppe"
	for r in range(-3, 4):
		for q in range(-3, 4):
			var b := a + Vector2i(q, r)
			if HexGrid.distance(a, b) <= 3:
				var forward := HexGrid.trajectory(a, b)
				var backward := HexGrid.trajectory(b, a)
				check(forward.size() == backward.size(), "symmetric trajectory size")
				for cell in forward:
					check(cell in backward, "symmetric trajectory cells")

func _test_validation(world: Dictionary) -> void:
	for malformed in [null, [], {}, {"version": 1}]:
		check(not SteppeValidator.validate(malformed, 2026).is_empty(), "reject malformed schema")
	for field in ["version", "seed", "width", "height", "cells", "start", "rivers"]:
		var bad := world.duplicate(true)
		bad[field] = "bad"
		check(not SteppeValidator.validate(bad, 2026).is_empty(), "reject invalid " + field)
	var bad := world.duplicate(true)
	bad.cells[0] = "gold"
	check(not SteppeValidator.validate(bad, 2026).is_empty(), "reject out-of-scope terrain")
	bad = world.duplicate(true)
	bad.start = [16, 0]
	check(not SteppeValidator.validate(bad, 2026).is_empty(), "reject out-of-bounds start")
	bad = world.duplicate(true)
	bad.rivers[0].remove_at(1)
	check(not SteppeValidator.validate(bad, 2026).is_empty(), "reject river discontinuity or undeclared river")
	bad = world.duplicate(true)
	bad.rivers[0].reverse()
	check(not SteppeValidator.validate(bad, 2026).is_empty(), "reject reversed river endpoints")
	bad = world.duplicate(true)
	bad.cells[SteppeRules.start(bad).y * 16 + SteppeRules.start(bad).x] = "mountain"
	check(not SteppeValidator.validate(bad, 2026).is_empty(), "reject impassable start")
	bad = world.duplicate(true)
	var start := SteppeRules.start(bad)
	for r in range(16):
		for q in range(16):
			var cell := Vector2i(q, r)
			if HexGrid.distance(start, cell) == 1:
				bad.cells[r * 16 + q] = "mountain"
	check("Unsolvable geography: some cells cannot be revealed." in SteppeValidator.validate(bad, 2026), "reject trapped start")

	bad = world.duplicate(true)
	var source := SteppeValidator.point(bad.rivers[0][0])
	for direction in HexGrid.DIRECTIONS:
		var cell: Vector2i = source + direction
		if SteppeRules.terrain(bad, cell) == "mountain":
			bad.cells[cell.y * 16 + cell.x] = "sea"
	check("River source must touch a mountain." in SteppeValidator.validate(bad, 2026), "reject disconnected mountain source")
	bad = world.duplicate(true)
	var mouth := SteppeValidator.point(bad.rivers[0][-1])
	for direction in HexGrid.DIRECTIONS:
		var cell: Vector2i = mouth + direction
		if SteppeRules.terrain(bad, cell) == "sea":
			bad.cells[cell.y * 16 + cell.x] = "mountain"
	check("River mouth must touch the sea." in SteppeValidator.validate(bad, 2026), "reject disconnected sea mouth")
	bad = world.duplicate(true)
	bad.rivers[0].insert(1, bad.rivers[0][0])
	check(not SteppeValidator.validate(bad, 2026).is_empty(), "reject repeated river coordinate")
	bad = world.duplicate(true)
	bad.start = [0.5, 2]
	check(not SteppeValidator.validate(bad, 2026).is_empty(), "reject fractional coordinate")
	bad = world.duplicate(true)
	bad.extra = true
	check(not SteppeValidator.validate(bad, 2026).is_empty(), "reject additional schema field")

func _test_victory(world: Dictionary) -> void:
	var state := ExplorationState.new(world)
	check(not state.won and state.discovered.size() <= 7, "initial fog")
	var before := state.discovered.duplicate()
	check(not state.move_to(Vector2i(-1, -1), true), "invalid movement rejected")
	check(state.discovered == before, "invalid movement preserves state")
	# Physically traverse a spanning tree using the public gameplay API, then
	# backtrack. This proves victory without teleporting or changing discovery.
	var seen := {state.position: true}
	var stack: Array[Vector2i] = [state.position]
	while not stack.is_empty():
		var next: Array[Vector2i] = []
		for destination in SteppeRules.destinations(world, state.position):
			if not seen.has(destination):
				next.append(destination)
				break
		if not next.is_empty():
			check(state.move_to(next[0], true), "traverse reachable position")
			seen[next[0]] = true
			stack.append(next[0])
		else:
			stack.pop_back()
			if not stack.is_empty():
				check(state.move_to(stack[-1], true), "revisit/backtrack")
	check(state.won and state.discovered.size() == 254, "all required cells revealed triggers victory")
	check(not state.discovered.has(Vector2i.ZERO) and not state.discovered.has(Vector2i(15, 15)), "unreachable corners remain fogged without blocking victory")
	for cell in state.discovered.keys():
		var missing := state.discovered.duplicate()
		missing.erase(cell)
		check(not SteppeRules.exploration_complete(missing), "every non-exempt cell is required, including rim terrain")
