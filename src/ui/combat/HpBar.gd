class_name HpBar
extends Control
## A mech's health across the top of the combat screen, after the mockup: its name and owner
## over a framed bar with an HP tag, a fill that glides to each new value and turns red below
## [constant LOW_FRACTION], and a white trail that catches up a moment after a hit. [member mirrored] flips it for the right
## side: the tag sits on the right and the bar drains toward it.

## Below this share of full health the fill turns red.
const LOW_FRACTION := 0.3
## Seconds the trail waits after a hit, then takes to catch up.
const TRAIL_DELAY := 0.25
const TRAIL_TIME := 0.6
const NAME_ROW := 32
const BAR_HEIGHT := 40
const PADDING := 4
const TAG_WIDTH := 56
const NAME_SIZE := 24
const OWNER_SIZE := 16
const VALUE_SIZE := 16

@export var mirrored := false:
	set(p_mirrored):
		mirrored = p_mirrored
		queue_redraw()
@export var accent := CombatColors.PLAYER:
	set(p_accent):
		accent = p_accent
		queue_redraw()
## Shown above the bar, e.g. "THE STRIKER" and "PLAYER".
var mech_name := "":
	set(p_mech_name):
		mech_name = p_mech_name
		queue_redraw()
var owner_text := "":
	set(p_owner_text):
		owner_text = p_owner_text
		queue_redraw()
var value := 0
var max_value := 1
## Seconds the fill takes to glide to a new value. The combat screen makes it a tick's length,
## so the bar moves steadily instead of jumping each tick.
var smoothing := 0.1
## The fill's share of full health as drawn, gliding toward [method get_fraction].
var shown := 1.0:
	set(p_shown):
		shown = p_shown
		queue_redraw()
## The trail's share of full health. It sits at or above the fill, and drains after it.
var trail := 1.0:
	set(p_trail):
		trail = p_trail
		queue_redraw()

var _fill_tween: Tween
var _trail_tween: Tween


func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE


## Shows [param p_value] of [param p_max] health. A drop leaves the trail behind for a moment.
func set_health(p_value: int, p_max: int) -> void:
	var dropped := p_value < value and p_max == max_value
	value = p_value
	max_value = maxi(p_max, 1)
	if _fill_tween:
		_fill_tween.kill()
	if _trail_tween:
		_trail_tween.kill()
	if is_inside_tree() and smoothing > 0.0:
		_fill_tween = create_tween()
		_fill_tween.tween_property(self, "shown", get_fraction(), smoothing)
	else:
		shown = get_fraction()
	if dropped and is_inside_tree():
		_trail_tween = create_tween()
		_trail_tween.tween_interval(TRAIL_DELAY)
		_trail_tween.tween_property(self, "trail", get_fraction(), TRAIL_TIME).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	else:
		trail = get_fraction()
	queue_redraw()


## Returns the share of full health left, from 0 to 1.
func get_fraction() -> float:
	return clampf(float(value) / max_value, 0.0, 1.0)


## Returns the number on the bar, e.g. "190/220".
func get_text() -> String:
	return "%d/%d" % [value, max_value]


func get_fill_color() -> Color:
	return CombatColors.DANGER if get_fraction() < LOW_FRACTION else CombatColors.HP


func _get_minimum_size() -> Vector2:
	return Vector2(496, NAME_ROW + BAR_HEIGHT + 13)


func _draw() -> void:
	_draw_names()
	var bar := Rect2(PADDING, NAME_ROW + PADDING, size.x - PADDING * 2, BAR_HEIGHT)
	CombatDraw.frame(self, bar)
	var inner := bar.grow(-PADDING)
	var tag := Rect2(inner.end.x - TAG_WIDTH if mirrored else inner.position.x, inner.position.y, TAG_WIDTH, inner.size.y)
	var track_x: float = inner.position.x if mirrored else inner.position.x + TAG_WIDTH + PADDING
	var track := Rect2(track_x, inner.position.y, inner.size.x - TAG_WIDTH - PADDING, inner.size.y)
	draw_rect(tag, CombatColors.TAG)
	CombatDraw.text(self, CombatDraw.PIXEL_BOLD_FONT, tag, "HP", VALUE_SIZE, CombatColors.NIGHT, 0, HORIZONTAL_ALIGNMENT_CENTER)
	draw_rect(track, CombatColors.TRACK)
	draw_rect(CombatDraw.fill_rect(track, maxf(trail, shown), mirrored), Color(1, 1, 1, 0.8))
	CombatDraw.glossy(self, CombatDraw.fill_rect(track, shown, mirrored), get_fill_color())
	CombatDraw.text(self, CombatDraw.PIXEL_FONT, track, get_text(), VALUE_SIZE, CombatColors.INK, 2, HORIZONTAL_ALIGNMENT_CENTER)


# The name in the side's accent, then the owner, sharing a baseline. Mirrored, they read from
# the right edge: the owner, then the name.
func _draw_names() -> void:
	var baseline := NAME_ROW - 8.0
	var name_width := CombatDraw.text_width(CombatDraw.PIXEL_FONT, mech_name, NAME_SIZE)
	var owner_width := CombatDraw.text_width(CombatDraw.PIXEL_FONT, owner_text, OWNER_SIZE)
	var gap := 12.0
	var name_x: float = size.x - PADDING - name_width if mirrored else float(PADDING)
	var owner_x: float = name_x - gap - owner_width if mirrored else name_x + name_width + gap
	CombatDraw.text_at(self, CombatDraw.PIXEL_FONT, Vector2(name_x, baseline), mech_name, NAME_SIZE, accent, 2)
	CombatDraw.text_at(self, CombatDraw.PIXEL_FONT, Vector2(owner_x, baseline), owner_text, OWNER_SIZE, CombatColors.INK, 2)
