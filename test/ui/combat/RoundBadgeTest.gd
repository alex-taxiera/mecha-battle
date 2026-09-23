class_name RoundBadgeTest
extends GdUnitTestSuite

const __source: String = "res://src/ui/combat/RoundBadge.gd"


func test_shows_the_round_and_record() -> void:
	var badge: RoundBadge = auto_free(RoundBadge.new())
	assert_str(badge.get_text()).is_equal("ROUND 1  0W 0L")
	badge.set_record(3, 2, 1, 0)
	assert_str(badge.get_text()).is_equal("ROUND 3  2W 1L")
	# Draws show once there are any.
	badge.set_record(4, 2, 1, 1)
	assert_str(badge.get_text()).is_equal("ROUND 4  2W 1L 1D")
