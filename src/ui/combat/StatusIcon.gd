class_name StatusIcon
extends Control
## A status on a mech in a fight: its glyph on a badge of its color, with its charges in the
## corner. Hovering it shows what it is and does.

const SIZE := 26.0
const COUNT_SIZE := 14

var status: ActiveStatus


func _init(p_status: ActiveStatus) -> void:
	status = p_status
	custom_minimum_size = Vector2(SIZE, SIZE)
	mouse_filter = MOUSE_FILTER_PASS
	refresh()


## Returns a status's tooltip, e.g. "Burn ×3 (Debuff)\n+2 heat a second per charge.".
static func describe(p_status: ActiveStatus) -> String:
	var data := p_status.data
	return "%s ×%d (%s)\n%s" % [data.status_name, p_status.charges, MechStatus.Type.find_key(data.type).capitalize(), data.description]


## Redraws the charges and the tooltip.
func refresh() -> void:
	tooltip_text = describe(status)
	queue_redraw()


## Returns the number drawn in the corner.
func get_count_text() -> String:
	return str(status.charges)


func _draw() -> void:
	var radius := minf(size.x, size.y) / 2.0
	var center := size / 2.0
	var color := status.data.color
	draw_circle(center, radius, CombatColors.NIGHT)
	draw_arc(center, radius - 1.5, 0, TAU, 32, color, 2.5, true)
	CombatDraw.text(self, CombatDraw.BODY_FONT, Rect2(Vector2.ZERO, size), status.data.glyph, roundi(radius), color, 0,
		HORIZONTAL_ALIGNMENT_CENTER)
	var corner := Rect2(Vector2(size.x * 0.45, size.y * 0.55), size * 0.55)
	CombatDraw.text(self, CombatDraw.PIXEL_BOLD_FONT, corner, get_count_text(), COUNT_SIZE, CombatColors.INK, 2,
		HORIZONTAL_ALIGNMENT_RIGHT)
