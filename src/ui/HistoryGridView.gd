class_name HistoryGridView
extends Control
## A past run's mech in miniature: each cell its parts covered, in its part type's color, from a
## history entry's grid snapshot (see [method Profile.summarize]).

const CELL := 9.0
const GAP := 1.0

## [x, y, part type] per cell. Numbers may come back from JSON as floats.
var cells: Array = []:
	set(value):
		cells = value
		update_minimum_size()
		queue_redraw()


func _init(p_cells: Array = []) -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	cells = p_cells


func _get_minimum_size() -> Vector2:
	var bounds := _bounds()
	return Vector2(bounds.size) * (CELL + GAP) if bounds.has_area() else Vector2.ZERO


func _draw() -> void:
	var bounds := _bounds()
	for cell: Array in cells:
		var at := Vector2(int(cell[0]) - bounds.position.x, int(cell[1]) - bounds.position.y) * (CELL + GAP)
		var color: Color = PartShapeView.TYPE_COLORS.get(int(cell[2]), Color.GRAY)
		draw_rect(Rect2(at, Vector2(CELL, CELL)), color)


# The cells' bounding box, in cells.
func _bounds() -> Rect2i:
	if cells.is_empty():
		return Rect2i()
	var low := Vector2i(int(cells[0][0]), int(cells[0][1]))
	var high := low
	for cell: Array in cells:
		var at := Vector2i(int(cell[0]), int(cell[1]))
		low = low.min(at)
		high = high.max(at)
	return Rect2i(low, high - low + Vector2i.ONE)
