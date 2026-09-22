class_name MechChassisTest
extends GdUnitTestSuite

const __source: String = "res://src/data/MechChassis.gd"
const Fixtures := preload("res://test/TestFixtures.gd")


func test_cross_frame() -> void:
	var chassis := Fixtures.cross_chassis()
	assert_int(chassis.get_usable_cell_count()).is_equal(12)
	# A corner is inside the frame but disabled; the cell beside it is usable.
	assert_bool(chassis.contains(Vector2i(0, 0))).is_true()
	assert_bool(chassis.is_usable(Vector2i(0, 0))).is_false()
	assert_bool(chassis.is_usable(Vector2i(1, 0))).is_true()
	# Off the edge is neither.
	assert_bool(chassis.contains(Vector2i(4, 1))).is_false()
	assert_bool(chassis.is_usable(Vector2i(-1, 1))).is_false()


func test_open_frame() -> void:
	var chassis := Fixtures.open_chassis(Vector2i(5, 5))
	assert_int(chassis.get_usable_cell_count()).is_equal(25)
	assert_bool(chassis.is_usable(Vector2i(0, 0))).is_true()
	assert_bool(chassis.is_usable(Vector2i(4, 4))).is_true()
	assert_bool(chassis.contains(Vector2i(5, 4))).is_false()
