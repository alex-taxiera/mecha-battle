class_name ChassisPreview
extends Control
## Draws a chassis's slot layout small: usable slots light, cut-away ones faint. The chassis
## select screen shows one per frame, on a card lighter than the shop's grid, so it uses its
## own brighter colors.

const SLOT_COLOR := Color(0.42, 0.47, 0.55)
const CUT_AWAY_COLOR := Color(0.1, 0.11, 0.13, 0.5)

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
	return Vector2(chassis.size) * (cell_size + gap) - Vector2(gap, gap)


func _draw() -> void:
	if chassis == null:
		return
	for y in chassis.size.y:
		for x in chassis.size.x:
			var cell := Vector2i(x, y)
			var color := SLOT_COLOR if chassis.is_usable(cell) else CUT_AWAY_COLOR
			draw_rect(Rect2(Vector2(cell) * (cell_size + gap), Vector2(cell_size, cell_size)), color)
