class_name HexGrid
extends RefCounted
## Pointy-top regular hexes inside nominal 72 × 72 bounds.
const RADIUS := 36.0
const WIDTH := sqrt(3.0) * RADIUS
const ROW_SPACING := 1.5 * RADIUS
const DIRECTIONS := [Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1),
	Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1)]

static func center(cell: Vector2i) -> Vector2:
	return Vector2(WIDTH * (cell.x + cell.y * 0.5), ROW_SPACING * cell.y)

static func from_pixel(point: Vector2) -> Vector2i:
	return round_axial(Vector2(point.x / WIDTH - point.y / (3.0 * RADIUS), point.y / ROW_SPACING))

static func round_axial(point: Vector2) -> Vector2i:
	var cube := Vector3(point.x, -point.x - point.y, point.y)
	var rounded := cube.round()
	var diff := (rounded - cube).abs()
	if diff.x > diff.y and diff.x > diff.z:
		rounded.x = -rounded.y - rounded.z
	elif diff.y > diff.z:
		rounded.y = -rounded.x - rounded.z
	else:
		rounded.z = -rounded.x - rounded.y
	return Vector2i(int(rounded.x), int(rounded.z))

static func distance(a: Vector2i, b: Vector2i) -> int:
	var delta := a - b
	return maxi(maxi(absi(delta.x), absi(delta.y)), absi(delta.x + delta.y))

static func corners(cell: Vector2i) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(6):
		var angle := deg_to_rad(60.0 * i - 30.0)
		points.append(center(cell) + Vector2(cos(angle), sin(angle)) * RADIUS)
	return points

static var _trajectory_cache: Dictionary = {}

static func trajectory(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	# Conservative supercover: include every hex touched by the center-to-center
	# segment, including both sides of an exact edge/corner tie.
	var delta := b - a
	if not _trajectory_cache.has(delta):
		_trajectory_cache[delta] = _uncached_trajectory(Vector2i.ZERO, delta)
	var translated: Array[Vector2i] = []
	for offset in _trajectory_cache[delta]:
		translated.append(a + offset)
	return translated

static func _uncached_trajectory(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for r in range(mini(a.y, b.y) - 1, maxi(a.y, b.y) + 2):
		for q in range(mini(a.x, b.x) - 1, maxi(a.x, b.x) + 2):
			var cell := Vector2i(q, r)
			if _segment_touches_hex(center(a), center(b), cell):
				result.append(cell)
	return result

static func _segment_touches_hex(a: Vector2, b: Vector2, cell: Vector2i) -> bool:
	# Clip a segment against six convex half planes. Outward normals point
	# toward neighboring centers. Epsilon makes ties conservative.
	var low := 0.0
	var high := 1.0
	for direction in DIRECTIONS:
		var normal := center(direction).normalized()
		var offset := normal.dot(a - center(cell)) - WIDTH * 0.5 - 0.001
		var slope := normal.dot(b - a)
		if absf(slope) < 0.00001:
			if offset > 0.0:
				return false
		elif slope > 0.0:
			high = minf(high, -offset / slope)
		else:
			low = maxf(low, -offset / slope)
		if low > high:
			return false
	return true
