class_name DrainedTest
extends GdUnitTestSuite

const __source: String = "res://src/data/statuses/Drained.gd"
const Fixtures := preload("res://test/TestFixtures.gd")


func test_each_charge_drains_energy_every_second() -> void:
	var mech := BattleMech.new(MechGridData.new(Fixtures.cross_chassis()))
	mech.current_energy = 100
	mech.add_status(Fixtures.drained(), 2)
	for i in 10:
		mech.tick_statuses(0.1)
	assert_int(mech.current_energy).is_equal(88) # 6 a charge, 2 charges, 1 second


func test_energy_never_drains_below_zero() -> void:
	var mech := BattleMech.new(MechGridData.new(Fixtures.cross_chassis()))
	mech.current_energy = 5
	mech.add_status(Fixtures.drained(), 10)
	for i in 10:
		mech.tick_statuses(0.1)
	assert_int(mech.current_energy).is_equal(0)
