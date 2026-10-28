class_name SteppeGenerator
extends RefCounted
const MAX_ATTEMPTS := 8

static func generate(world_seed: int) -> Dictionary:
	for attempt in range(MAX_ATTEMPTS):
		var candidate := _candidate(world_seed, attempt)
		var errors := SteppeValidator.validate(candidate, world_seed)
		if errors.is_empty():
			return candidate
		push_warning("Steppe candidate %d rejected: %s" % [attempt, str(errors)])
	# A known valid member of the same family; retain the requested seed.
	var fallback := _candidate(0, 0)
	fallback.seed = world_seed
	assert(SteppeValidator.validate(fallback, world_seed).is_empty())
	return fallback

static func _candidate(world_seed: int, attempt: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed + attempt * 7919
	var cells: Array = []
	cells.resize(256)
	cells.fill("steppe")
	for r in range(16):
		cells[r * 16] = "mountain"
		cells[r * 16 + 15] = "sea"
	# Seal all four axial edges; no walkable or river cell reaches the rim.
	for q in range(1, 15):
		cells[q] = "mountain" if q < 8 else "sea"
		cells[15 * 16 + q] = "mountain" if q < 8 else "sea"
	# Narrow irregular projections and inlets reach well into the interior.
	for row in [2, 11]:
		for q in range(1, rng.randi_range(4, 7)):
			cells[row * 16 + q] = "mountain"
	for row in [4, 13]:
		for q in range(rng.randi_range(8, 11), 15):
			cells[row * 16 + q] = "sea"
	var path: Array = []
	var river_row := 7
	for q in range(1, 15):
		path.append([q, river_row])
		cells[river_row * 16 + q] = "river"
		if q < 14:
			var next_row := clampi(river_row + rng.randi_range(-1, 1), 6, 8)
			if next_row > river_row:
				river_row = next_row
				path.append([q, river_row])
				cells[river_row * 16 + q] = "river"
			else:
				river_row = next_row
	var transform := rng.randi_range(0, 3)
	var transformed: Array = []
	transformed.resize(256)
	for r in range(16):
		for q in range(16):
			var target := _transform(Vector2i(q, r), transform)
			transformed[target.y * 16 + target.x] = cells[r * 16 + q]
	var river: Array = []
	for point in path:
		var target := _transform(Vector2i(point[0], point[1]), transform)
		river.append([target.x, target.y])
	var start := _transform(Vector2i(7, 10), transform)
	return {"version": 1, "seed": world_seed, "width": 16, "height": 16,
		"cells": transformed, "start": [start.x, start.y], "rivers": [river]}

static func _transform(cell: Vector2i, variant: int) -> Vector2i:
	var result := Vector2i(cell.y, cell.x) if variant % 2 == 1 else cell
	return Vector2i(15, 15) - result if variant >= 2 else result
