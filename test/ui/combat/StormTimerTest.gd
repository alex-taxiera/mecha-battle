class_name StormTimerTest
extends GdUnitTestSuite

const __source: String = "res://src/ui/combat/StormTimer.gd"


func test_counts_whole_seconds_down_to_the_storm() -> void:
	var timer: StormTimer = auto_free(StormTimer.new())
	timer.set_countdown(20.0)
	assert_str(timer.get_text()).is_equal("20")
	timer.set_countdown(19.9)
	assert_str(timer.get_text()).is_equal("20")
	timer.set_countdown(0.05)
	assert_str(timer.get_text()).is_equal("1")
	assert_bool(timer.is_storm()).is_false()
	timer.set_countdown(0.0)
	assert_str(timer.get_text()).is_equal("STORM")
	assert_bool(timer.is_storm()).is_true()


func test_float_error_doesnt_hold_a_second_back() -> void:
	var timer: StormTimer = auto_free(StormTimer.new())
	# A countdown a hair over a whole second, as summed ticks leave it, reads as that second.
	timer.set_countdown(19.0 + 1e-9)
	assert_str(timer.get_text()).is_equal("19")
	# Positive control: a real fraction of a second still rounds up.
	timer.set_countdown(19.01)
	assert_str(timer.get_text()).is_equal("20")
