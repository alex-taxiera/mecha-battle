class_name ActivePartTest
extends GdUnitTestSuite

const __source: String = "res://src/combat/ActivePart.gd"
const Fixtures := preload("res://test/TestFixtures.gd")


func test_wraps_a_part_ready_for_a_fight() -> void:
	var gatling := Fixtures.gatling()
	gatling.cooldown_max = 1.5
	var active := ActivePart.new(gatling)
	assert_object(active.part).is_same(gatling)
	assert_float(active.current_cooldown).is_equal(1.5)
	assert_bool(active.is_active).is_true()
	# The cooldown ticks on the ActivePart, not on the shared part.
	active.current_cooldown -= 1.0
	active.is_active = false
	assert_float(active.current_cooldown).is_equal(0.5)
	assert_float(gatling.cooldown_max).is_equal(1.5)


func test_fights_with_its_own_numbers_or_its_linked_ones() -> void:
	var gatling := Fixtures.gatling() # 8 damage for 3 energy
	var own := ActivePart.new(gatling)
	assert_int(own.damage).is_equal(8)
	assert_int(own.energy_cost).is_equal(3)
	assert_int(own.energy_gen).is_equal(0)
	# Its numbers on a grid, e.g. cooled and overcharged: (8 + 3) × 1.5.
	var numbers := MechStats.PartStats.new()
	numbers.damage = 17
	numbers.energy_draw = 3
	var linked := ActivePart.new(gatling, numbers)
	assert_int(linked.damage).is_equal(17)
	assert_int(linked.energy_cost).is_equal(3)
	assert_int(gatling.damage).is_equal(8) # the part itself is unchanged
	# A generator's energy comes through the same way.
	var reactor_numbers := MechStats.PartStats.new()
	reactor_numbers.energy = 6
	assert_int(ActivePart.new(Fixtures.reactor(), reactor_numbers).energy_gen).is_equal(6)
