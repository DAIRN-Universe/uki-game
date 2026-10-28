class_name ExplorationState
extends RefCounted
## Authoritative gameplay state; no AI context, rendering, or network dependency.
var world: Dictionary
var position: Vector2i
var discovered: Dictionary = {}
var won := false

func _init(specification: Dictionary) -> void:
	world = specification.duplicate(true)
	position = SteppeRules.start(world)
	_reveal()

func move_to(destination: Vector2i, flight := false) -> bool:
	if not SteppeRules.can_move(world, position, destination, flight):
		return false
	position = destination
	_reveal()
	return true

func _reveal() -> void:
	for cell in SteppeRules.visible_from(position):
		discovered[cell] = true
	# The two unreachable rim corners are excluded from the shared target.
	won = SteppeRules.exploration_complete(discovered)
