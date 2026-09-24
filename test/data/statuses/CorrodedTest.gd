class_name CorrodedTest
extends GdUnitTestSuite

const __source: String = "res://src/data/statuses/Corroded.gd"
const Fixtures := preload("res://test/TestFixtures.gd")


func test_corrosion_makes_every_hit_bigger_before_plating() -> void:
	var plain := BattleMech.new(MechGridData.new(Fixtures.cross_chassis()))
	plain.add_status(Fixtures.corroded(), 2)
	assert_int(plain.get_damage_taken(10)).is_equal(16)
	# On a Bastion, the corrosion comes before its plating: 10 + 6 - 2.
	var bastion := BattleMech.new(MechGridData.new(Fixtures.bastion()))
	bastion.add_status(Fixtures.corroded(), 2)
	assert_int(bastion.get_damage_taken(10)).is_equal(14)
	# Positive control: without it, just the plating.
	assert_int(BattleMech.new(MechGridData.new(Fixtures.bastion())).get_damage_taken(10)).is_equal(8)


func test_five_charges_eat_the_shield_away() -> void:
	var grid := MechGridData.new(Fixtures.cross_chassis())
	assert_bool(grid.place_part(Fixtures.shield_emitter(), Vector2i(1, 0))).is_true()
	var mech := BattleMech.new(grid)
	var overflows := []
	mech.status_overflowed.connect(func(_status: ActiveStatus, times: int) -> void: overflows.append(times))
	mech.add_status(Fixtures.corroded(), 4)
	assert_int(mech.shield).is_equal(200)
	mech.add_status(Fixtures.corroded(), 1)
	assert_int(mech.shield).is_equal(0)
	assert_array(overflows).contains_exactly([1])
	# It starts over from nothing.
	assert_object(mech.get_status("corroded")).is_null()
