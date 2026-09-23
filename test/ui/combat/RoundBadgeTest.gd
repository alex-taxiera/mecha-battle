class_name RoundBadgeTest
extends GdUnitTestSuite

const __source: String = "res://src/ui/combat/RoundBadge.gd"


func test_shows_the_sector_floor_and_wins() -> void:
	var badge: RoundBadge = auto_free(RoundBadge.new())
	assert_str(badge.get_text()).is_equal("SECTOR 1  0W")
	badge.set_progress(2, 5, 7)
	assert_str(badge.get_text()).is_equal("SECTOR 2 · FLOOR 5  7W")
	# Before a node is picked there's no floor to show.
	badge.set_progress(3, 0, 9)
	assert_str(badge.get_text()).is_equal("SECTOR 3  9W")
