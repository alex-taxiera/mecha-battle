class_name LoadoutPart
extends Resource
## One part of a ready-made build: which part, where its top-left goes on the grid, and how it's
## turned. A chassis's starter kit and each enemy's build are lists of these.

@export var part: MechPart
## The part's top-left in the grid's cell coordinates. A weapon's is its bay's origin.
@export var origin: Vector2i
## Quarter-turns clockwise.
@export var rotation := 0


## Places a copy of each part in [param lineup] on [param grid], so the build never shares part
## instances with anything else. Returns false, reporting the first part that doesn't fit, if
## any part couldn't be placed; the parts before it stay placed.
static func place_all(grid: MechGridData, lineup: Array[LoadoutPart]) -> bool:
	for entry in lineup:
		if entry.part == null or not grid.place_part(entry.part.duplicate(), entry.origin, entry.rotation):
			push_error("LoadoutPart: can't place %s at %s on %s" % [entry.part.id if entry.part else "nothing",
				entry.origin, grid.chassis.chassis_name])
			return false
	return true


static func make(p_part: MechPart, p_origin: Vector2i, p_rotation := 0) -> LoadoutPart:
	var entry := LoadoutPart.new()
	entry.part = p_part
	entry.origin = p_origin
	entry.rotation = p_rotation
	return entry
