class_name MechGridData
extends RefCounted
## Pure grid math for a mech chassis: tracks which [MechPart] occupies which cell.
## Holds no UI code. Views call into it and redraw on [signal grid_updated].

## Emitted whenever a part is placed or removed.
signal grid_updated

const GRID_SIZE := Vector2i(4, 4)
## Permanently disabled corners, leaving a plus-shaped chassis.
const DISABLED_CELLS: Array[Vector2i] = [
	Vector2i(0, 0), Vector2i(3, 0), Vector2i(0, 3), Vector2i(3, 3),
]
const _NEIGHBOR_OFFSETS: Array[Vector2i] = [
	Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT,
]


## A part placed on the grid. Tracked separately from the [MechPart] because the
## same resource (e.g. a shared .tres blueprint) may be placed more than once.
class Placement:
	var part: MechPart
	var cells: Array[Vector2i]

	func _init(p_part: MechPart, p_cells: Array[Vector2i]) -> void:
		part = p_part
		cells = p_cells


## Occupied cell -> the placement covering it.
var _placements: Dictionary[Vector2i, Placement] = {}


## Returns whether [param part] fits with its shape anchored at [param origin_coords]:
## every cell must be inside the grid, not a disabled corner, and unoccupied.
func can_place_part(part: MechPart, origin_coords: Vector2i) -> bool:
	if part == null or part.grid_shape.is_empty():
		return false
	for cell in get_footprint(part, origin_coords):
		if not _is_usable(cell) or _placements.has(cell):
			return false
	return true


## Places [param part] at [param origin_coords] if it fits. Returns whether it was placed.
func place_part(part: MechPart, origin_coords: Vector2i) -> bool:
	if not can_place_part(part, origin_coords):
		return false
	var placement := Placement.new(part, get_footprint(part, origin_coords))
	for cell in placement.cells:
		_placements[cell] = placement
	grid_updated.emit()
	return true


## Removes the part covering [param coords] (any of its cells) and returns it,
## or returns [code]null[/code] if the cell is empty.
func remove_part(coords: Vector2i) -> MechPart:
	var placement: Placement = _placements.get(coords)
	if placement == null:
		return null
	for cell in placement.cells:
		_placements.erase(cell)
	grid_updated.emit()
	return placement.part


## Returns the part covering [param coords], or [code]null[/code] if the cell is empty.
func get_part_at(coords: Vector2i) -> MechPart:
	var placement: Placement = _placements.get(coords)
	return placement.part if placement else null


## Returns each placed part once, with the cells it covers. Treat the result as read-only.
func get_placements() -> Array[Placement]:
	var placements: Array[Placement] = []
	for placement in _placements.values():
		if placement not in placements:
			placements.append(placement)
	return placements


## Returns the parts orthogonally touching [param coords], each placement once.
## If a part covers [param coords], its whole footprint is checked and the part
## itself is excluded, so this answers "what is next to this part?".
func get_adjacent_parts(coords: Vector2i) -> Array[MechPart]:
	var own: Placement = _placements.get(coords)
	var footprint: Array[Vector2i] = [coords]
	if own:
		footprint = own.cells
	var seen: Array[Placement] = []
	var adjacent: Array[MechPart] = []
	for cell in footprint:
		for offset in _NEIGHBOR_OFFSETS:
			var neighbor: Placement = _placements.get(cell + offset)
			if neighbor == null or neighbor == own or neighbor in seen:
				continue
			seen.append(neighbor)
			adjacent.append(neighbor.part)
	return adjacent


## Returns the cells [param part] would cover with its shape anchored at [param origin_coords].
static func get_footprint(part: MechPart, origin_coords: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for offset in part.grid_shape:
		cells.append(origin_coords + offset)
	return cells


func _is_usable(cell: Vector2i) -> bool:
	return Rect2i(Vector2i.ZERO, GRID_SIZE).has_point(cell) and cell not in DISABLED_CELLS
