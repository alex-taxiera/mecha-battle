class_name MechGridData
extends RefCounted
## Pure grid math for a mech: tracks which [MechPart] occupies which cell of its
## [MechChassis]. Holds no UI code. Views call into it and redraw on [signal grid_updated].

## Emitted whenever a part is placed, moved, rotated, or removed.
signal grid_updated

## Whether a footprint fits, or the first reason it doesn't, in the order they're checked.
enum Fit { OK, OUT_OF_BOUNDS, DISABLED_CELL, OCCUPIED }

const _NEIGHBOR_OFFSETS: Array[Vector2i] = [
	Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT,
]


## A part placed on the grid. Tracked separately from the [MechPart] because the
## same resource (e.g. a shared .tres blueprint) may be placed more than once.
class Placement:
	var part: MechPart
	## The top-left of the part's turned shape.
	var origin: Vector2i
	## Quarter-turns clockwise, 0-3.
	var rotation: int
	var cells: Array[Vector2i]

	func _init(p_part: MechPart, p_origin: Vector2i, p_rotation: int) -> void:
		part = p_part
		origin = p_origin
		rotation = p_rotation
		cells = MechGridData.get_footprint(p_part, p_origin, p_rotation)


## Two placed parts that touch, with one edge they share.
class Contact:
	var a: Placement
	var b: Placement
	## The cell of [member a] on the shared edge.
	var cell_a: Vector2i
	## The cell of [member b] on the shared edge, next to [member cell_a].
	var cell_b: Vector2i

	func _init(p_a: Placement, p_b: Placement, p_cell_a: Vector2i, p_cell_b: Vector2i) -> void:
		a = p_a
		b = p_b
		cell_a = p_cell_a
		cell_b = p_cell_b


var chassis: MechChassis

## Occupied cell -> the placement covering it.
var _placements: Dictionary[Vector2i, Placement] = {}


func _init(p_chassis: MechChassis) -> void:
	chassis = p_chassis


## Returns whether [param part], turned [param rotation] quarter-turns clockwise, fits with its
## top-left at [param origin_coords], or the first problem: any cell outside the chassis, then
## any disabled cell, then any occupied cell.
func check_placement(part: MechPart, origin_coords: Vector2i, rotation := 0) -> Fit:
	if part == null:
		return Fit.OUT_OF_BOUNDS
	return _check(get_footprint(part, origin_coords, rotation), null)


## Returns whether [param part] fits with its shape anchored at [param origin_coords]:
## every cell must be inside the grid, not a disabled cell, and unoccupied.
func can_place_part(part: MechPart, origin_coords: Vector2i, rotation := 0) -> bool:
	return check_placement(part, origin_coords, rotation) == Fit.OK


## Places [param part] at [param origin_coords], turned [param rotation] quarter-turns
## clockwise, if it fits. Returns whether it was placed.
func place_part(part: MechPart, origin_coords: Vector2i, rotation := 0) -> bool:
	if not can_place_part(part, origin_coords, rotation):
		return false
	_add(Placement.new(part, origin_coords, posmod(rotation, 4)))
	grid_updated.emit()
	return true


## Removes the part covering [param coords] (any of its cells) and returns it,
## or returns [code]null[/code] if the cell is empty.
func remove_part(coords: Vector2i) -> MechPart:
	var placement: Placement = _placements.get(coords)
	if placement == null:
		return null
	_erase(placement)
	grid_updated.emit()
	return placement.part


## Returns whether the part covering [param coords] would fit with its top-left moved to
## [param new_origin], keeping its rotation. Its current cells count as free. An empty
## [param coords] has nothing to move and reports OUT_OF_BOUNDS.
func check_move(coords: Vector2i, new_origin: Vector2i) -> Fit:
	var placement: Placement = _placements.get(coords)
	if placement == null:
		return Fit.OUT_OF_BOUNDS
	return _check(get_footprint(placement.part, new_origin, placement.rotation), placement)


## Moves the part covering [param coords] so its top-left is at [param new_origin], keeping
## its rotation. Returns whether it moved; the grid is unchanged if it doesn't fit there.
func move_part(coords: Vector2i, new_origin: Vector2i) -> bool:
	var placement: Placement = _placements.get(coords)
	return placement != null and _relocate(placement, new_origin, placement.rotation)


## Turns the part covering [param coords] a quarter-turn clockwise, keeping its top-left.
## Returns whether it turned; the grid is unchanged if the new footprint doesn't fit.
func rotate_part(coords: Vector2i) -> bool:
	var placement: Placement = _placements.get(coords)
	return placement != null and _relocate(placement, placement.origin, posmod(placement.rotation + 1, 4))


## Returns an independent grid with the same chassis and placements, for trying changes
## without touching this one.
func copy() -> MechGridData:
	var clone := MechGridData.new(chassis)
	for placement in get_placements():
		clone._add(Placement.new(placement.part, placement.origin, placement.rotation))
	return clone


## Returns the part covering [param coords], or [code]null[/code] if the cell is empty.
func get_part_at(coords: Vector2i) -> MechPart:
	var placement: Placement = _placements.get(coords)
	return placement.part if placement else null


## Returns the placement covering [param coords], or [code]null[/code] if the cell is empty.
## Treat it as read-only.
func get_placement_at(coords: Vector2i) -> Placement:
	return _placements.get(coords)


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


## Returns the empty, usable cells orthogonally next to [param cells], not counting
## [param cells] themselves: the open edges where another part could touch them.
func get_open_edges(cells: Array[Vector2i]) -> Array[Vector2i]:
	var edges: Array[Vector2i] = []
	for cell in cells:
		for offset in _NEIGHBOR_OFFSETS:
			var neighbor := cell + offset
			if neighbor in cells or neighbor in edges or _placements.has(neighbor):
				continue
			if chassis.is_usable(neighbor):
				edges.append(neighbor)
	return edges


## Returns each pair of placed parts that touch, once, with the first edge they share when
## scanning cells row by row.
func get_contacts() -> Array[Contact]:
	var cells: Array[Vector2i] = []
	cells.assign(_placements.keys())
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	var contacts: Array[Contact] = []
	for cell in cells:
		var placement: Placement = _placements[cell]
		for offset: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN]:
			var other: Placement = _placements.get(cell + offset)
			if other and other != placement and not _touching(contacts, placement, other):
				contacts.append(Contact.new(placement, other, cell, cell + offset))
	return contacts


## Returns how many cells are occupied.
func get_used_cell_count() -> int:
	return _placements.size()


## Returns the cells [param part] would cover, turned [param rotation] quarter-turns clockwise
## with its top-left at [param origin_coords].
static func get_footprint(part: MechPart, origin_coords: Vector2i, rotation := 0) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for offset in part.get_shape(rotation):
		cells.append(origin_coords + offset)
	return cells


# The first problem with [param cells], checking every cell for each problem in priority order.
# The cells of [param ignoring] (a part being moved) count as free. No cells never fits.
func _check(cells: Array[Vector2i], ignoring: Placement) -> Fit:
	if cells.is_empty():
		return Fit.OUT_OF_BOUNDS
	for cell in cells:
		if not chassis.contains(cell):
			return Fit.OUT_OF_BOUNDS
	for cell in cells:
		if not chassis.is_usable(cell):
			return Fit.DISABLED_CELL
	for cell in cells:
		var occupant: Placement = _placements.get(cell)
		if occupant and occupant != ignoring:
			return Fit.OCCUPIED
	return Fit.OK


# Re-places [param placement] at a new origin and rotation if it fits there with its own cells
# counted as free. Emits grid_updated once; changes nothing on failure.
func _relocate(placement: Placement, new_origin: Vector2i, new_rotation: int) -> bool:
	var moved := Placement.new(placement.part, new_origin, new_rotation)
	if _check(moved.cells, placement) != Fit.OK:
		return false
	_erase(placement)
	_add(moved)
	grid_updated.emit()
	return true


func _add(placement: Placement) -> void:
	for cell in placement.cells:
		_placements[cell] = placement


func _erase(placement: Placement) -> void:
	for cell in placement.cells:
		_placements.erase(cell)


static func _touching(contacts: Array[Contact], x: Placement, y: Placement) -> bool:
	for contact in contacts:
		if (contact.a == x and contact.b == y) or (contact.a == y and contact.b == x):
			return true
	return false
