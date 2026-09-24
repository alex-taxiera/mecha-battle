class_name KitIcon
extends Control
## A field kit's placeholder icon: its glyph on a square badge of its color (relics are round).
## Hovering it shows the kit's name, when it acts, and what it does.

const SIZE := 30.0

var kit: FieldKit:
	set(value):
		kit = value
		tooltip_text = describe(kit) if kit else ""
		queue_redraw()


func _init(p_kit: FieldKit = null, icon_size := SIZE) -> void:
	custom_minimum_size = Vector2(icon_size, icon_size)
	mouse_filter = MOUSE_FILTER_PASS
	kit = p_kit


## Returns a kit's tooltip, e.g. "Emergency Patch (field kit)\nAuto: at 25% HP\nRepairs 25%...".
static func describe(p_kit: FieldKit) -> String:
	return "%s (field kit)\n%s\n%s" % [p_kit.kit_name, p_kit.describe_trigger(), p_kit.description]


func _draw() -> void:
	if kit == null:
		return
	# A square, centered, however the icon is stretched.
	var side := minf(size.x, size.y) - 3.0
	var rect := Rect2((size - Vector2(side, side)) / 2.0, Vector2(side, side))
	draw_rect(rect, CombatColors.NIGHT)
	draw_rect(rect, kit.color, false, 3.0)
	var font_size := roundi(minf(size.x, size.y) * 0.55)
	CombatDraw.text(self, CombatDraw.BODY_FONT, Rect2(Vector2.ZERO, size), kit.glyph, font_size, kit.color, 0,
		HORIZONTAL_ALIGNMENT_CENTER)
