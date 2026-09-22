class_name MechGridUI
extends Control
## Draws a MechGridData and accepts parts dropped onto it. It never decides whether a
## part fits: it asks the data layer, and redraws when the data says it changed.

## Emitted after a dropped part has been placed.
signal part_dropped(part: MechPart, origin: Vector2i)

const CELL_SIZE := 64.0
const CELL_GAP := 4.0
const CELL_PITCH := CELL_SIZE + CELL_GAP

const CELL_COLOR := Color(0.2, 0.22, 0.26)
const DISABLED_CELL_COLOR := Color(0.07, 0.07, 0.09)
const FITS_COLOR := Color(0.4, 1.0, 0.5, 0.45)
const BLOCKED_COLOR := Color(1.0, 0.35, 0.35, 0.45)
const LABEL_COLOR := Color(0.0, 0.0, 0.0, 0.8)
const LABEL_FONT_SIZE := 12

var grid_data: MechGridData:
	set(value):
		if grid_data:
			grid_data.grid_updated.disconnect(queue_redraw)
		grid_data = value
		if grid_data:
			grid_data.grid_updated.connect(queue_redraw)
		update_minimum_size()
		queue_redraw()

# Cells the dragged part would cover at the hovered spot, and whether it fits there.
var _hover_cells: Array[Vector2i] = []
var _hover_fits := false


func _get_minimum_size() -> Vector2:
	if grid_data == null:
		return Vector2.ZERO
	return Vector2(grid_data.chassis.size) * CELL_PITCH - Vector2(CELL_GAP, CELL_GAP)


func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if grid_data == null or not data is PartDragData:
		return false
	var drag: PartDragData = data
	var origin := _origin_at(at_position, drag)
	var fits := grid_data.can_place_part(drag.part, origin)
	_set_hover(MechGridData.get_footprint(drag.part, origin), fits)
	return fits


func _drop_data(at_position: Vector2, data: Variant) -> void:
	var drag: PartDragData = data
	var origin := _origin_at(at_position, drag)
	_set_hover([], false)
	if grid_data.place_part(drag.part, origin):
		part_dropped.emit(drag.part, origin)


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT or what == NOTIFICATION_DRAG_END:
		_set_hover([], false)


func _draw() -> void:
	if grid_data == null:
		return
	var chassis := grid_data.chassis
	for y in chassis.size.y:
		for x in chassis.size.x:
			var cell := Vector2i(x, y)
			var color := CELL_COLOR if chassis.is_usable(cell) else DISABLED_CELL_COLOR
			draw_rect(_cell_rect(cell), color)
	var font := get_theme_default_font()
	for placement in grid_data.get_placements():
		var part: MechPart = placement.part
		PartShapeView.draw_cells(self, placement.cells, CELL_SIZE, CELL_GAP, PartShapeView.color_for(part.type))
		var label_pos := _cell_rect(placement.cells[0]).position + Vector2(4, 4 + LABEL_FONT_SIZE)
		draw_string(font, label_pos, part.part_name, HORIZONTAL_ALIGNMENT_LEFT, CELL_SIZE - 8, LABEL_FONT_SIZE, LABEL_COLOR)
	var hover_color := FITS_COLOR if _hover_fits else BLOCKED_COLOR
	for cell in _hover_cells:
		if chassis.contains(cell):
			draw_rect(_cell_rect(cell), hover_color)


# The origin that puts the grabbed cell of the dragged part on the cell under at_position.
func _origin_at(at_position: Vector2, drag: PartDragData) -> Vector2i:
	return Vector2i((at_position / CELL_PITCH).floor()) - drag.grab_offset


func _cell_rect(cell: Vector2i) -> Rect2:
	return Rect2(Vector2(cell) * CELL_PITCH, Vector2(CELL_SIZE, CELL_SIZE))


func _set_hover(cells: Array[Vector2i], fits: bool) -> void:
	if cells == _hover_cells and fits == _hover_fits:
		return
	_hover_cells = cells
	_hover_fits = fits
	queue_redraw()
