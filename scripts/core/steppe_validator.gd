class_name SteppeValidator
extends RefCounted
## Untrusted proposals never reach gameplay before this validation boundary.
const FIELDS := ["version", "seed", "width", "height", "cells", "start", "rivers"]

static func whole(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value))

static func coordinate(value: Variant) -> bool:
	return value is Array and value.size() == 2 and whole(value[0]) and whole(value[1]) and value[0] >= 0 and value[0] < 16 and value[1] >= 0 and value[1] < 16

static func point(value: Array) -> Vector2i:
	return Vector2i(int(value[0]), int(value[1]))

static func validate(value: Variant, expected_seed: int) -> Array[String]:
	var errors: Array[String] = []
	if not value is Dictionary:
		return ["Proposal must be an object."]
	var world: Dictionary = value
	if world.size() != FIELDS.size():
		return ["Unexpected or missing schema fields."]
	for field in FIELDS:
		if not world.has(field):
			return ["Missing field: " + field]
	for field in ["version", "seed", "width", "height"]:
		if not whole(world[field]):
			return ["Expected integer: " + field]
	if world.version != 1 or world.width != 16 or world.height != 16:
		return ["Unsupported version or dimensions."]
	if world.seed < -2147483648 or world.seed > 2147483647 or world.seed != expected_seed:
		return ["Proposal seed does not match request."]
	if not world.cells is Array or world.cells.size() != 256:
		return ["Expected 256 row-major terrain cells."]
	for terrain in world.cells:
		if not terrain is String or terrain not in SteppeRules.TERRAINS:
			return ["Invalid terrain."]
	for terrain in SteppeRules.TERRAINS:
		if terrain not in world.cells:
			return ["Missing terrain: " + terrain]
	for r in range(SteppeRules.SIZE):
		for q in range(SteppeRules.SIZE):
			var cell := Vector2i(q, r)
			if SteppeRules.boundary(cell) and SteppeRules.terrain(world, cell) not in ["mountain", "sea"]:
				return ["Boundary cells must be mountain or sea."]
	if not coordinate(world.start) or SteppeRules.terrain(world, point(world.start)) != "steppe":
		return ["Start must be an in-bounds steppe hex."]
	if not world.rivers is Array or world.rivers.is_empty() or world.rivers.size() > 256:
		return ["Expected declared river paths."]
	var river_cells: Dictionary = {}
	for path in world.rivers:
		if not path is Array or path.is_empty() or path.size() > 256:
			return ["River path is empty or too long."]
		for i in range(path.size()):
			if not coordinate(path[i]):
				return ["Invalid river coordinate."]
			var cell := point(path[i])
			if SteppeRules.terrain(world, cell) != "river" or river_cells.has(cell):
				return ["River path repeats or references non-river terrain."]
			river_cells[cell] = true
			if i > 0 and HexGrid.distance(point(path[i - 1]), cell) != 1:
				return ["River is not continuous."]
		if not _next_to(world, point(path[0]), "mountain"):
			return ["River source must touch a mountain."]
		if not _next_to(world, point(path[-1]), "sea"):
			return ["River mouth must touch the sea."]
	for r in range(16):
		for q in range(16):
			var cell := Vector2i(q, r)
			if SteppeRules.terrain(world, cell) == "river" and not river_cells.has(cell):
				return ["Undeclared river terrain."]
	var positions := reachable(world)
	var revealed: Dictionary = {}
	for cell in positions:
		for visible in SteppeRules.visible_from(cell):
			revealed[visible] = true
	if not SteppeRules.exploration_complete(revealed):
		errors.append("Unsolvable geography: some cells cannot be revealed.")
	return errors

static func _next_to(world: Dictionary, cell: Vector2i, terrain: String) -> bool:
	for direction in HexGrid.DIRECTIONS:
		if SteppeRules.terrain(world, cell + direction) == terrain:
			return true
	return false

static func reachable(world: Dictionary) -> Array[Vector2i]:
	var queue: Array[Vector2i] = [SteppeRules.start(world)]
	var seen := {queue[0]: true}
	var index := 0
	while index < queue.size():
		for destination in SteppeRules.destinations(world, queue[index]):
			if not seen.has(destination):
				seen[destination] = true
				queue.append(destination)
		index += 1
	return queue
