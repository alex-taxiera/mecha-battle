class_name HardpointTest
extends GdUnitTestSuite

const __source: String = "res://src/data/Hardpoint.gd"
const Fixtures := preload("res://test/TestFixtures.gd")


func test_get_cells() -> void:
	# A left arm just off the frame, beside rows 1-3.
	assert_array(Fixtures.left_arm(Vector2i(-1, 1)).get_cells()).contains_exactly(
		[Vector2i(-1, 1), Vector2i(-1, 2), Vector2i(-1, 3)])
	assert_array(Fixtures.back(Vector2i(1, -2)).get_cells()).contains_exactly(
		[Vector2i(1, -2), Vector2i(2, -2), Vector2i(1, -1), Vector2i(2, -1)])
	# A shape drawn away from (0, 0) still starts at the origin.
	var drawn_away: Array[Vector2i] = [Vector2i(2, 3), Vector2i(2, 4)]
	assert_array(Fixtures.hardpoint("stub", "Stub", Vector2i(5, 0), drawn_away).get_cells()).contains_exactly(
		[Vector2i(5, 0), Vector2i(5, 1)])


func test_fits_only_a_weapon_of_its_exact_shape() -> void:
	var arm := Fixtures.left_arm(Vector2i(-1, 1))
	assert_bool(arm.fits(Fixtures.gatling())).is_true()
	# The same 1x3 shape, but not a weapon.
	assert_bool(arm.fits(Fixtures.part("Bar", MechPart.PartType.UTILITY, Fixtures.ARM_SHAPE))).is_false()
	# A weapon, but 2x2, which fits a back instead.
	assert_bool(arm.fits(Fixtures.missile_pod())).is_false()
	assert_bool(Fixtures.back(Vector2i.ZERO).fits(Fixtures.missile_pod())).is_true()
	# A shorter weapon doesn't fit either, though it would sit inside the bay.
	var stub := Fixtures.part("Stub", MechPart.PartType.WEAPON, [Vector2i(0, 0), Vector2i(0, 1)])
	assert_bool(arm.fits(stub)).is_false()
	assert_bool(arm.fits(null)).is_false()
