class_name HasteTest
extends GdUnitTestSuite

const __source: String = "res://src/data/statuses/Haste.gd"
const Fixtures := preload("res://test/TestFixtures.gd")


func test_haste_speeds_weapons_up_to_a_cap() -> void:
	var mech := BattleMech.new(MechGridData.new(Fixtures.cross_chassis()))
	assert_float(mech.get_weapon_speed()).is_equal(1.0)
	mech.add_status(Fixtures.haste(), 3)
	assert_float(mech.get_weapon_speed()).is_equal_approx(1.3, 1e-6)
	# Throttling still slows it: half speed at full heat.
	mech.heat = 100
	assert_float(mech.get_weapon_speed()).is_equal_approx(0.65, 1e-6)
	var rushed := BattleMech.new(MechGridData.new(Fixtures.cross_chassis()))
	rushed.add_status(Fixtures.haste(), 5)
	assert_float(rushed.get_weapon_speed()).is_equal_approx(1.5, 1e-6)


func test_haste_and_jammed_cancel_out_partly() -> void:
	var mech := BattleMech.new(MechGridData.new(Fixtures.cross_chassis()))
	mech.add_status(Fixtures.haste(), 2)
	mech.add_status(Fixtures.jammed(), 2)
	# 1.2 × 0.84.
	assert_float(mech.get_weapon_speed()).is_equal_approx(1.008, 1e-6)
