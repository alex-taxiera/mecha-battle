class_name StormTimer
extends Control
## The big countdown at the top of the combat screen: whole seconds until the electrical storm,
## pulsing red in the last [constant URGENT_SECONDS], then STORM once it's up.

const FONT_SIZE := 56
## STORM is longer than any count, so it's set smaller to fit between the health bars.
const STORM_FONT_SIZE := 32
## The countdown pulses red at or below this many seconds.
const URGENT_SECONDS := 5.0
## Each half of the pulse, red then white, lasts this long.
const PULSE_STEP := 0.25

## Seconds left until the storm; 0 once it's up.
var seconds_left := 0.0
## False once the fight is over: the countdown holds still and stops pulsing.
var running := true:
	set(p_running):
		running = p_running
		set_process(is_urgent())
		queue_redraw()

var _pulse_time := 0.0


func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	set_process(false)


func set_countdown(seconds: float) -> void:
	seconds_left = seconds
	set_process(is_urgent())
	queue_redraw()


## Returns whether the storm is close: at most [constant URGENT_SECONDS] away, but not up yet.
func is_urgent() -> bool:
	return running and not is_storm() and seconds_left <= URGENT_SECONDS


## Returns what the timer shows: the seconds left, rounded up, or "STORM".
func get_text() -> String:
	# Ticks leave float error behind (ten 0.1s make 0.9999...), which would round a whole second
	# up to the one before it.
	return "STORM" if is_storm() else str(ceili(seconds_left - CombatEngine.TIME_EPSILON))


func is_storm() -> bool:
	return seconds_left <= 0.0


func _get_minimum_size() -> Vector2:
	return Vector2(280, 64)


func _process(delta: float) -> void:
	_pulse_time += delta
	queue_redraw()


func _draw() -> void:
	var color := CombatColors.STORM if is_storm() else CombatColors.INK
	if is_urgent() and int(_pulse_time / PULSE_STEP) % 2 == 1:
		color = CombatColors.DANGER
	CombatDraw.text(self, CombatDraw.PIXEL_BOLD_FONT, Rect2(Vector2.ZERO, size), get_text(),
		STORM_FONT_SIZE if is_storm() else FONT_SIZE, color, 3, HORIZONTAL_ALIGNMENT_CENTER)
