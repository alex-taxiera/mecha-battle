class_name BurnTest
extends GdUnitTestSuite

const __source: String = "res://src/data/statuses/Burn.gd"
const Fixtures := preload("res://test/TestFixtures.gd")


func test_each_charge_heats_the_mech_every_second() -> void:
	var mech := BattleMech.new(MechGridData.new(Fixtures.cross_chassis()))
	mech.add_status(Fixtures.burn(), 3)
	for i in 10:
		mech.tick_statuses(0.1)
	assert_int(mech.heat).is_equal(6) # 2 a charge, 3 charges, 1 second
	assert_int(mech.get_status_charges("burn")).is_equal(2)
	# Positive control: no Burn, no heat.
	var cool := BattleMech.new(MechGridData.new(Fixtures.cross_chassis()))
	for i in 10:
		cool.tick_statuses(0.1)
	assert_int(cool.heat).is_equal(0)


func test_burn_stops_at_ten_charges() -> void:
	var mech := BattleMech.new(MechGridData.new(Fixtures.cross_chassis()))
	mech.add_status(Fixtures.burn(), 25)
	assert_int(mech.get_status_charges("burn")).is_equal(10)
