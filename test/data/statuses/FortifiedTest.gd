class_name FortifiedTest
extends GdUnitTestSuite

const __source: String = "res://src/data/statuses/Fortified.gd"
const Fixtures := preload("res://test/TestFixtures.gd")


func test_fortified_hits_are_smaller() -> void:
	var mech := BattleMech.new(MechGridData.new(Fixtures.cross_chassis()))
	# Positive control: without it, the full hit.
	assert_int(mech.get_damage_taken(10)).is_equal(10)
	mech.add_status(Fixtures.fortified(), 2)
	assert_int(mech.get_damage_taken(10)).is_equal(6)
	assert_int(mech.get_damage_taken(3)).is_equal(0)


func test_it_stacks_after_plating() -> void:
	# On a Bastion: 10 - 2 plating - 4.
	var bastion := BattleMech.new(MechGridData.new(Fixtures.bastion()))
	bastion.add_status(Fixtures.fortified(), 2)
	assert_int(bastion.get_damage_taken(10)).is_equal(4)
