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


func test_the_bastion_is_wide_and_the_striker_tall() -> void:
	var bastion := Fixtures.bastion()
	assert_int(bastion.get_usable_cell_count()).is_equal(12)
	assert_bool(bastion.is_usable(Vector2i(3, 2))).is_true()
	assert_bool(bastion.contains(Vector2i(0, 3))).is_false() # only 3 rows
	var striker := Fixtures.striker()
	assert_int(striker.get_usable_cell_count()).is_equal(10)
	assert_bool(striker.is_usable(Vector2i(1, 4))).is_true()
	assert_bool(striker.contains(Vector2i(2, 0))).is_false() # only 2 columns


func test_hardpoints() -> void:
	var chassis := Fixtures.armed_cross()
	var left_arm := chassis.hardpoints[0]
	var back := chassis.hardpoints[2]
	assert_object(chassis.get_hardpoint_at(Vector2i(-1, 3))).is_same(left_arm)
	assert_object(chassis.get_hardpoint_at(Vector2i(2, -1))).is_same(back)
	assert_object(chassis.get_hardpoint_at(Vector2i(-1, 0))).is_null() # just above the arm
	assert_object(chassis.get_hardpoint_at(Vector2i(0, 1))).is_null()  # the frame beside it
	# A bay is off the frame, so no grid part can use its cells.
	assert_bool(chassis.is_usable(Vector2i(-1, 2))).is_false()
	assert_bool(chassis.can_mount(Fixtures.gatling())).is_true()
	assert_bool(chassis.can_mount(Fixtures.missile_pod())).is_true()
	assert_bool(chassis.can_mount(Fixtures.laser())).is_false()
	# The Bastion only has a back bay.
	assert_bool(Fixtures.bastion().can_mount(Fixtures.gatling())).is_false()
	assert_bool(Fixtures.bastion().can_mount(Fixtures.missile_pod())).is_true()


func test_layout_rect_covers_the_frame_and_its_bays() -> void:
	# Arms at x = -1 and 4, the back two rows above the 4x4 frame.
	assert_that(Fixtures.armed_cross().get_layout_rect()).is_equal(Rect2i(-1, -2, 6, 6))
	assert_that(Fixtures.cross_chassis().get_layout_rect()).is_equal(Rect2i(0, 0, 4, 4))
	# The Striker: both arms and a back around its 2x5 frame, 4 wide and 7 tall.
	assert_that(Fixtures.striker().get_layout_rect()).is_equal(Rect2i(-1, -2, 4, 7))
	assert_that(Fixtures.bastion().get_layout_rect()).is_equal(Rect2i(0, -2, 4, 5))
	assert_that(Fixtures.reactor_frame().get_layout_rect()).is_equal(Rect2i(-1, 0, 7, 5))


func test_the_reactor_is_a_diamond_around_a_connected_center() -> void:
	var reactor := Fixtures.reactor_frame()
	assert_int(reactor.get_usable_cell_count()).is_equal(13)
	# The center and its four neighbors are usable, as are the four tips.
	for cell: Vector2i in [Vector2i(2, 2), Vector2i(1, 2), Vector2i(3, 2), Vector2i(2, 1), Vector2i(2, 3),
			Vector2i(2, 0), Vector2i(0, 2), Vector2i(4, 2), Vector2i(2, 4)]:
		assert_bool(reactor.is_usable(cell)).append_failure_message("%s should be usable" % cell).is_true()
	# Beside the tips, the frame is cut away.
	for cell: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(4, 4), Vector2i(3, 4)]:
		assert_bool(reactor.is_usable(cell)).append_failure_message("%s should be disabled" % cell).is_false()
