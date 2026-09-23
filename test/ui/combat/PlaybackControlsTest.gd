class_name PlaybackControlsTest
extends GdUnitTestSuite

const __source: String = "res://src/ui/combat/PlaybackControls.gd"


func test_each_button_reports_its_press() -> void:
	var controls: PlaybackControls = auto_free(PlaybackControls.new())
	var presses := []
	controls.pause_pressed.connect(func() -> void: presses.append("pause"))
	controls.speed_pressed.connect(func() -> void: presses.append("speed"))
	controls.skip_pressed.connect(func() -> void: presses.append("skip"))
	controls.pause_button.pressed.emit()
	controls.speed_button.pressed.emit()
	controls.skip_button.pressed.emit()
	assert_array(presses).is_equal(["pause", "speed", "skip"])


func test_shows_the_playback_state() -> void:
	var controls: PlaybackControls = auto_free(PlaybackControls.new())
	controls.show_state(false, 1, false)
	assert_str(controls.pause_button.icon_name).is_equal("pause")
	assert_that(controls.speed_button.color).is_equal(PlaybackControls.IDLE_COLOR)
	assert_bool(controls.skip_button.disabled).is_false()
	controls.show_state(true, 2, false)
	assert_str(controls.pause_button.icon_name).is_equal("play")
	assert_that(controls.speed_button.color).is_equal(PlaybackControls.FAST_COLOR)
	assert_str(controls.speed_button.tooltip_text).is_equal("Speed 2x")
	controls.show_state(false, 1, true)
	for button in [controls.pause_button, controls.speed_button, controls.skip_button]:
		assert_bool(button.disabled).is_true()


func test_buttons_never_take_focus() -> void:
	# Space pauses the fight, so a focused button mustn't swallow it.
	var controls: PlaybackControls = auto_free(PlaybackControls.new())
	for button in [controls.pause_button, controls.speed_button, controls.skip_button]:
		assert_int(button.focus_mode).is_equal(Control.FOCUS_NONE)
	# Every icon the controls use exists.
	for name in ["pause", "play", "fast_forward", "skip"]:
		assert_bool(PixelIconButton.ICONS.has(name)).append_failure_message(name).is_true()
