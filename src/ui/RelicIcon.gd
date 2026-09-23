class_name RelicIcon
extends Control
## A relic's placeholder icon: its glyph on a round badge of its color. Hovering it shows the
## relic's name and what it does.

const SIZE := 30.0

var relic: Relic:
	set(value):
		relic = value
		tooltip_text = describe(relic) if relic else ""
		queue_redraw()


func _init(p_relic: Relic = null, icon_size := SIZE) -> void:
	custom_minimum_size = Vector2(icon_size, icon_size)
	mouse_filter = MOUSE_FILTER_PASS
	relic = p_relic


## Returns a relic's tooltip, e.g. "Reinforced Frame (Common)\n+40 max HP.".
static func describe(p_relic: Relic) -> String:
	if p_relic is TimedStatus:
		var text := p_relic.description
		return "%s (%d fights left)\n%s" % [p_relic.relic_name, p_relic.fights, text.left(1).to_upper() + text.substr(1)]
	return "%s (%s)\n%s" % [p_relic.relic_name, Relic.Rarity.find_key(p_relic.rarity).capitalize(), p_relic.description]


func _draw() -> void:
	if relic == null:
		return
	var radius := minf(size.x, size.y) / 2.0
	var center := size / 2.0
	draw_circle(center, radius, CombatColors.NIGHT)
	draw_arc(center, radius - 1.5, 0, TAU, 32, relic.color, 3.0, true)
	var font_size := roundi(radius * 1.1)
	CombatDraw.text(self, CombatDraw.BODY_FONT, Rect2(Vector2.ZERO, size), relic.glyph, font_size, relic.color, 0,
		HORIZONTAL_ALIGNMENT_CENTER)
