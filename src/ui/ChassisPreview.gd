class_name ChassisPreview
extends Control
## Draws a chassis's slot layout small: usable slots light, cut-away ones faint, and its
## hardpoint bays around them in a weapon tint. The chassis select screen shows one per frame,
## on a card lighter than the shop's grid, so it uses its own brighter colors.

const SLOT_COLOR := Color(0.42, 0.47, 0.55)
const CUT_AWAY_COLOR := Color(0.1, 0.11, 0.13, 0.5)
const BAY_COLOR := Color(0.72, 0.3, 0.29)

@export var cell_size := 22.0
@export var gap := 3.0

var chassis: MechChassis:
	set(value):
		chassis = value
		update_minimum_size()
		queue_redraw()


func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE


func _get_minimum_size() -> Vector2:
	if chassis == null:
		return Vector2.ZERO
	return Vector2(chassis.get_layout_rect().size) * (cell_size + gap) - Vector2(gap, gap)


func _draw() -> void:
	if chassis == null:
		return
	for y in chassis.size.y:
		for x in chassis.size.x:
			var cell := Vector2i(x, y)
			_draw_cell(cell, SLOT_COLOR if chassis.is_usable(cell) else CUT_AWAY_COLOR)
	for hardpoint in chassis.hardpoints:
		for cell in hardpoint.get_cells():
			_draw_cell(cell, BAY_COLOR)


# Bays can sit left of or above the frame, so cells are drawn from the layout's top-left.
func _draw_cell(cell: Vector2i, color: Color) -> void:
	var top_left := Vector2(cell - chassis.get_layout_rect().position) * (cell_size + gap)
	draw_rect(Rect2(top_left, Vector2(cell_size, cell_size)), color)
