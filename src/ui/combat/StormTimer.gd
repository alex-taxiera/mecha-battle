class_name StormTimer
extends Control
## The big countdown at the top of the combat screen: whole seconds until the electrical storm,
## then STORM once it's up.

const FONT_SIZE := 56

## Seconds left until the storm; 0 once it's up.
var seconds_left := 0.0


func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE


func set_countdown(seconds: float) -> void:
	seconds_left = seconds
	queue_redraw()


## Returns what the timer shows: the seconds left, rounded up, or "STORM".
func get_text() -> String:
	# Ticks leave float error behind (ten 0.1s make 0.9999...), which would round a whole second
	# up to the one before it.
	return "STORM" if is_storm() else str(ceili(seconds_left - CombatEngine.TIME_EPSILON))


func is_storm() -> bool:
	return seconds_left <= 0.0


func _get_minimum_size() -> Vector2:
	return Vector2(280, 64)


func _draw() -> void:
	var color := CombatColors.STORM if is_storm() else CombatColors.INK
	CombatDraw.text(self, CombatDraw.PIXEL_BOLD_FONT, Rect2(Vector2.ZERO, size), get_text(), FONT_SIZE, color, 3,
		HORIZONTAL_ALIGNMENT_CENTER)
