class_name PlaybackControls
extends HBoxContainer
## The fight's playback buttons at the top of the combat screen, after the mockup: pause or
## play, fast-forward, and skip to the end. They only report presses; the combat screen keeps
## the playback state and shows it here with [method show_state].

signal pause_pressed
signal speed_pressed
signal skip_pressed

## The fast-forward icon's tint while the fight runs faster than normal.
const FAST_COLOR := Color("#ff6f86")
const IDLE_COLOR := Color("#d7dce5")

var pause_button := PixelIconButton.new()
var speed_button := PixelIconButton.new()
var skip_button := PixelIconButton.new()


func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 4)
	alignment = ALIGNMENT_CENTER
	pause_button.icon_name = "pause"
	pause_button.tooltip_text = "Pause (Space)"
	speed_button.icon_name = "fast_forward"
	speed_button.tooltip_text = "Speed"
	skip_button.icon_name = "skip"
	skip_button.tooltip_text = "Skip to the end"
	for button: PixelIconButton in [pause_button, speed_button, skip_button]:
		add_child(button)
	pause_button.pressed.connect(pause_pressed.emit)
	speed_button.pressed.connect(speed_pressed.emit)
	skip_button.pressed.connect(skip_pressed.emit)


## Shows the playback state: the pause button offers play while [param paused], fast-forward
## turns pink above 1x [param speed], and every button is off once the fight is [param over].
func show_state(paused: bool, speed: int, over: bool) -> void:
	pause_button.icon_name = "play" if paused else "pause"
	pause_button.tooltip_text = "Play (Space)" if paused else "Pause (Space)"
	speed_button.color = FAST_COLOR if speed > 1 else IDLE_COLOR
	speed_button.tooltip_text = "Speed %dx" % speed
	for button: PixelIconButton in [pause_button, speed_button, skip_button]:
		button.disabled = over
