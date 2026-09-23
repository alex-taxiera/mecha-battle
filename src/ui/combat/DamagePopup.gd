class_name DamagePopup
extends Control
## A number or word that pops up over a mech and floats away, after the mockup's damage
## popups: it swells in, rises, and fades out, then frees itself.

## How far it rises, in pixels.
const RISE := 70.0
## The share of its time spent swelling in.
const SWELL := 0.12

var text := ""
var color := CombatColors.INK
var font_size := 24


func _init(p_text := "", p_color := CombatColors.INK, p_font_size := 24) -> void:
	text = p_text
	color = p_color
	font_size = p_font_size
	mouse_filter = MOUSE_FILTER_IGNORE
	size = Vector2(CombatDraw.text_width(CombatDraw.PIXEL_BOLD_FONT, text, font_size) + 8, font_size + 8)
	pivot_offset = size / 2.0


## Plays the pop over [param seconds], centered on [param at], then frees the popup. Out of the
## tree it just sits there.
func play(at: Vector2, seconds: float) -> void:
	position = (at - size / 2.0).round()
	if not is_inside_tree():
		return
	scale = Vector2(0.7, 0.7)
	modulate.a = 0.0
	var start_y := position.y
	var pop := create_tween()
	pop.tween_property(self, "scale", Vector2(1.2, 1.2), seconds * SWELL)
	pop.parallel().tween_property(self, "modulate:a", 1.0, seconds * SWELL)
	pop.parallel().tween_property(self, "position:y", start_y - 8.0, seconds * SWELL)
	var rest := seconds * (1.0 - SWELL)
	pop.tween_property(self, "scale", Vector2.ONE, rest)
	pop.parallel().tween_property(self, "position:y", start_y - RISE, rest).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	pop.parallel().tween_property(self, "modulate:a", 0.0, rest).set_ease(Tween.EASE_IN)
	pop.tween_callback(queue_free)


func _draw() -> void:
	CombatDraw.text(self, CombatDraw.PIXEL_BOLD_FONT, Rect2(Vector2.ZERO, size), text, font_size, color, 2,
		HORIZONTAL_ALIGNMENT_CENTER)
