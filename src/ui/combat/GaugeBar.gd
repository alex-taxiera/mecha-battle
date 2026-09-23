class_name GaugeBar
extends Control
## A small framed bar under a mech, after the mockup's EN and HT gauges: a colored tag, a fill,
## and its number, or a [member note] like "OFFLINE", at the right. The fill and number glide to
## each new value. A [member hot] gauge pulses a red glow.

## Seconds for one pulse of a hot gauge's glow.
const PULSE_TIME := 0.5
const TAG_WIDTH := 34
const PADDING := 2
const FONT_SIZE := 8

@export var label := "EN":
	set(p_label):
		label = p_label
		queue_redraw()
@export var tag_color := CombatColors.ENERGY:
	set(p_tag_color):
		tag_color = p_tag_color
		queue_redraw()
@export var fill_color := CombatColors.ENERGY:
	set(p_fill_color):
		fill_color = p_fill_color
		queue_redraw()
## The bar is full at [member max_value]; the number shows [member value] even past it.
var value := 0.0
var max_value := 100.0
## Seconds the fill and number take to glide to a new value.
var smoothing := 0.1
## The value as drawn, gliding toward [member value].
var shown := 0.0:
	set(p_shown):
		shown = p_shown
		queue_redraw()
## Shown instead of the number when set.
var note := ""
var hot := false:
	set(p_hot):
		if p_hot == hot:
			return
		hot = p_hot
		_set_pulsing(hot)
		queue_redraw()
## The glow's strength while hot, 0 to 1.
var glow := 0.0:
	set(p_glow):
		glow = p_glow
		queue_redraw()

var _pulse: Tween
var _glide: Tween


func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE


func _enter_tree() -> void:
	if hot and _pulse == null:
		_set_pulsing(true)


func set_value(p_value: float, p_note := "") -> void:
	value = p_value
	note = p_note
	if _glide:
		_glide.kill()
	if is_inside_tree() and smoothing > 0.0:
		_glide = create_tween()
		_glide.tween_property(self, "shown", value, smoothing)
	else:
		shown = value
	queue_redraw()


## Returns the text the bar is heading for at its right end: the note, or the number.
func get_text() -> String:
	return note if note != "" else str(roundi(value))


## Returns the share of the bar that's filled once it has glided there, from 0 to 1.
func get_fraction() -> float:
	return _fraction_of(value)


func _get_minimum_size() -> Vector2:
	return Vector2(240, 24)


func _draw() -> void:
	var bar := Rect2(Vector2(4, 4), size - Vector2(8, 8))
	if hot:
		var halo := bar.grow(4.0 + 8.0 * glow)
		draw_rect(halo, Color(CombatColors.DANGER, 0.25 * glow))
		draw_rect(bar.grow(6.0), Color(CombatColors.DANGER, 0.35 * glow))
	CombatDraw.frame(self, bar)
	if hot:
		draw_rect(bar.grow(2.0), CombatColors.DANGER, false, 2.0)
	var inner := bar.grow(-PADDING)
	var tag := Rect2(inner.position, Vector2(TAG_WIDTH, inner.size.y))
	var track := Rect2(inner.position.x + TAG_WIDTH + PADDING, inner.position.y, inner.size.x - TAG_WIDTH - PADDING, inner.size.y)
	draw_rect(tag, tag_color)
	CombatDraw.text(self, CombatDraw.PIXEL_BOLD_FONT, tag, label, FONT_SIZE, CombatColors.NIGHT, 0, HORIZONTAL_ALIGNMENT_CENTER)
	draw_rect(track, CombatColors.TRACK)
	CombatDraw.glossy(self, CombatDraw.fill_rect(track, _fraction_of(shown)), fill_color, 2.0)
	var text_rect := Rect2(track.position, track.size - Vector2(5, 0))
	var text := note if note != "" else str(roundi(shown))
	CombatDraw.text(self, CombatDraw.PIXEL_FONT, text_rect, text, FONT_SIZE, CombatColors.INK, 1, HORIZONTAL_ALIGNMENT_RIGHT)


func _fraction_of(amount: float) -> float:
	return clampf(amount / max_value, 0.0, 1.0) if max_value > 0.0 else 0.0


func _set_pulsing(on: bool) -> void:
	if _pulse:
		_pulse.kill()
		_pulse = null
	glow = 0.0
	if on and is_inside_tree():
		_pulse = create_tween().set_loops()
		_pulse.tween_property(self, "glow", 1.0, PULSE_TIME / 2.0).set_trans(Tween.TRANS_SINE)
		_pulse.tween_property(self, "glow", 0.0, PULSE_TIME / 2.0).set_trans(Tween.TRANS_SINE)
