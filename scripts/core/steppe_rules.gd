class_name SteppeRules
extends RefCounted
const SIZE := 16
const FLIGHT_RANGE := 3
const REVEAL_RADIUS := 1
const TERRAINS := ["steppe", "mountain", "river", "sea"]
const PALETTE := {
	"steppe": Color("C9BE91"), "mountain": Color("938D7E"),
	"river": Color("83BED0"), "sea": Color("477F94"),
	"unexplored": Color("303638"), "border": Color("8D8567")}

static func inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < SIZE and cell.y < SIZE

static func boundary(cell: Vector2i) -> bool:
	return inside(cell) and (cell.x == 0 or cell.y == 0 or cell.x == SIZE - 1 or cell.y == SIZE - 1)

static func required_for_victory(cell: Vector2i) -> bool:
	# With an impassable rim and radius one, these two axial corners have
	# no interior neighbor. Only these human-approved exceptions are optional.
	return inside(cell) and cell != Vector2i.ZERO and cell != Vector2i(SIZE - 1, SIZE - 1)

static func exploration_complete(discovered: Dictionary) -> bool:
	for r in range(SIZE):
		for q in range(SIZE):
			var cell := Vector2i(q, r)
			if required_for_victory(cell) and not discovered.has(cell):
				return false
	return true

static func terrain(world: Dictionary, cell: Vector2i) -> String:
	if not inside(cell):
		return "outside"
	return world.cells[cell.y * SIZE + cell.x]

static func start(world: Dictionary) -> Vector2i:
	return Vector2i(int(world.start[0]), int(world.start[1]))

static func can_move(world: Dictionary, a: Vector2i, b: Vector2i, flight: bool) -> bool:
	var distance := HexGrid.distance(a, b)
	if terrain(world, a) != "steppe" or terrain(world, b) != "steppe":
		return false
	if distance < 1 or distance > (FLIGHT_RANGE if flight else 1):
		return false
	if flight:
		for cell in HexGrid.trajectory(a, b):
			if terrain(world, cell) not in ["steppe", "river"]:
				return false
	return true

static func destinations(world: Dictionary, a: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for r in range(-FLIGHT_RANGE, FLIGHT_RANGE + 1):
		for q in range(-FLIGHT_RANGE, FLIGHT_RANGE + 1):
			var b := a + Vector2i(q, r)
			if can_move(world, a, b, true):
				result.append(b)
	return result

static func visible_from(cell: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = [cell]
	for direction in HexGrid.DIRECTIONS:
		if inside(cell + direction):
			result.append(cell + direction)
	return result
