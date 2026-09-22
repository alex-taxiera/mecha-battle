class_name MechChassis
extends Resource
## A mech frame: the grid parts are placed on, and the stats it gives before any parts.

@export var id: String
@export var chassis_name: String
## The frame's shape in a few words, e.g. "Cross frame".
@export var frame_name: String
@export var size := Vector2i(4, 4)
## Cells inside [member size] that can never hold a part.
@export var disabled_cells: Array[Vector2i] = []
@export var base_hp: int
## Energy generated each turn before any generators.
@export var base_energy := 3


## Returns whether [param cell] lies inside the frame's bounds, disabled or not.
func contains(cell: Vector2i) -> bool:
	return Rect2i(Vector2i.ZERO, size).has_point(cell)


## Returns whether a part can occupy [param cell]: inside the frame and not disabled.
func is_usable(cell: Vector2i) -> bool:
	return contains(cell) and cell not in disabled_cells


## Returns how many cells can hold parts.
func get_usable_cell_count() -> int:
	var count := 0
	for y in size.y:
		for x in size.x:
			if is_usable(Vector2i(x, y)):
				count += 1
	return count
