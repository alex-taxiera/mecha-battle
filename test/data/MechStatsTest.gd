class_name MechStatsTest
extends GdUnitTestSuite

const __source: String = "res://src/data/MechStats.gd"
const Fixtures := preload("res://test/TestFixtures.gd")

var _cooled: SynergyRule
var _overcharge: SynergyRule
var _stable: SynergyRule
var _plated: SynergyRule
var _rules: Array[SynergyRule] = []
var _grid: MechGridData


func before_test() -> void:
	_cooled = Fixtures.cooled()
	_overcharge = Fixtures.overcharge()
	_stable = Fixtures.stable()
	_plated = Fixtures.plated()
	_rules = [_cooled, _overcharge, _stable, _plated]
	# Roomy and open, with the Skirmisher's 30 base HP and 3 base energy.
	_grid = MechGridData.new(Fixtures.open_chassis(Vector2i(6, 6)))


func test_an_empty_mech_has_the_chassis_stats() -> void:
	var stats := _stats()
	assert_int(stats.hp).is_equal(30)
	assert_int(stats.energy_generated).is_equal(3)
	assert_int(stats.energy_drawn).is_equal(0)
	assert_int(stats.get_net_energy()).is_equal(3)
	assert_int(stats.damage).is_equal(0)
	assert_float(stats.power).is_equal(1.0)
	assert_array(stats.links).is_empty()


func test_parts_add_their_base_stats() -> void:
	_place(Fixtures.gatling(), Vector2i(0, 0))  # 8 damage, draws 3 energy
	_place(Fixtures.reactor(), Vector2i(3, 0))  # +4 energy, +5 HP
	_place(Fixtures.laser(), Vector2i(5, 5))    # +12 HP
	_place(Fixtures.heatsink(), Vector2i(3, 3)) # nothing on its own
	var stats := _stats()
	assert_array(stats.links).is_empty()
	assert_int(stats.hp).is_equal(30 + 5 + 12)
	assert_int(stats.energy_generated).is_equal(3 + 4)
	assert_int(stats.energy_drawn).is_equal(3)
	assert_int(stats.damage).is_equal(8)


func test_cooled_multiplies_weapon_damage_once() -> void:
	#     0 1 2 3 4
	#  0  . . G H .    G: gatling
	#  1  A A G H H    H, A: heatsinks
	#  2  . A G . .
	var gatling := _place(Fixtures.gatling(), Vector2i(2, 0))
	_place(Fixtures.heatsink(), Vector2i(3, 0))
	assert_int(_stats().damage).is_equal(12) # 8 x 1.5
	_place(Fixtures.heatsink(), Vector2i(0, 1), 2)
	var stats := _stats()
	assert_int(stats.damage).is_equal(12) # a second heatsink doesn't cool it any further
	assert_int(stats.get_rule_counts()[_cooled]).is_equal(2)
	assert_int(stats.part_stats[gatling].links).is_equal(2)


func test_overcharge_adds_damage_per_reactor() -> void:
	#     0 1 2 3 4
	#  0  . . G . .
	#  1  . . G R R    R: reactors
	#  2  R R G . .
	_place(Fixtures.gatling(), Vector2i(2, 0))
	_place(Fixtures.reactor(), Vector2i(3, 1))
	_place(Fixtures.reactor(), Vector2i(0, 2))
	var stats := _stats()
	assert_int(stats.damage).is_equal(8 + 3 + 3)
	assert_int(stats.energy_generated).is_equal(3 + 4 + 4)
	assert_int(stats.hp).is_equal(30 + 5 + 5)
	assert_int(stats.get_rule_counts()[_overcharge]).is_equal(2)


func test_bonuses_add_before_they_multiply() -> void:
	#     0 1 2 3 4
	#  0  . . G R R
	#  1  A A G . .
	#  2  . A G . .
	var gatling := _place(Fixtures.gatling(), Vector2i(2, 0))
	_place(Fixtures.reactor(), Vector2i(3, 0))
	_place(Fixtures.heatsink(), Vector2i(0, 1), 2)
	var stats := _stats()
	assert_int(stats.part_stats[gatling].damage).is_equal(17) # (8 + 3) x 1.5 = 16.5, rounded
	assert_int(stats.damage).is_equal(17)
	assert_float(stats.part_stats[gatling].bonuses[_overcharge]).is_equal(3.0)
	assert_float(stats.part_stats[gatling].bonuses[_cooled]).is_equal(1.5)


func test_stable_adds_generator_energy() -> void:
	#     0 1
	#  0  R R    R: reactor
	#  1  H .    H: heatsink
	#  2  H H
	var reactor := _place(Fixtures.reactor(), Vector2i(0, 0))
	assert_int(_stats().energy_generated).is_equal(3 + 4)
	var heatsink := _place(Fixtures.heatsink(), Vector2i(0, 1))
	var stats := _stats()
	assert_int(stats.energy_generated).is_equal(3 + 4 + 2)
	assert_int(stats.part_stats[reactor].energy).is_equal(6)
	assert_int(stats.part_stats[heatsink].links).is_equal(1) # "Cooling 1 part"


func test_plated_gives_every_touching_laser_hp() -> void:
	# Three lasers in a row: the middle one touches both others.
	var left := _place(Fixtures.laser(), Vector2i(0, 0))
	var middle := _place(Fixtures.laser(), Vector2i(1, 0))
	var right := _place(Fixtures.laser(), Vector2i(2, 0))
	var stats := _stats()
	assert_int(stats.part_stats[left].hp).is_equal(12 + 4)
	assert_int(stats.part_stats[middle].hp).is_equal(12 + 4 + 4)
	assert_int(stats.part_stats[right].hp).is_equal(12 + 4)
	assert_int(stats.hp).is_equal(30 + 16 + 20 + 16)
	assert_int(stats.get_rule_counts()[_plated]).is_equal(2)


func test_a_touching_pair_links_once() -> void:
	# The heatsink shares two edges with the gatling but makes one link.
	_place(Fixtures.gatling(), Vector2i(2, 0))
	_place(Fixtures.heatsink(), Vector2i(3, 0))
	var stats := _stats()
	assert_array(stats.links).has_size(1)
	assert_object(stats.links[0].rule).is_same(_cooled)


func test_unmatched_pairs_do_not_link() -> void:
	# No rule covers Weapon + Weapon.
	_place(Fixtures.gatling(), Vector2i(0, 0))
	_place(Fixtures.gatling(), Vector2i(1, 0))
	assert_array(_stats().links).is_empty()


func test_underpowered_weapons_lose_damage() -> void:
	# Two gatlings draw 6 energy against the chassis's 3: half power, half damage.
	_place(Fixtures.gatling(), Vector2i(0, 0))
	_place(Fixtures.gatling(), Vector2i(1, 0))
	var stats := _stats()
	assert_int(stats.get_net_energy()).is_equal(-3)
	assert_float(stats.power).is_equal(0.5)
	assert_int(stats.damage).is_equal(8) # 16 x 0.5
	# A reactor out of their reach covers the draw.
	_place(Fixtures.reactor(), Vector2i(4, 4))
	stats = _stats()
	assert_float(stats.power).is_equal(1.0)
	assert_int(stats.damage).is_equal(16)


func test_rules_match_their_types_in_either_order() -> void:
	assert_bool(_cooled.matches(MechPart.PartType.WEAPON, MechPart.PartType.UTILITY)).is_true()
	assert_bool(_cooled.matches(MechPart.PartType.UTILITY, MechPart.PartType.WEAPON)).is_true()
	assert_bool(_cooled.matches(MechPart.PartType.WEAPON, MechPart.PartType.WEAPON)).is_false()


func _stats() -> MechStats:
	return MechStats.calculate(_grid, _rules)


func _place(part: MechPart, origin: Vector2i, rotation := 0) -> MechGridData.Placement:
	var context := "%s at %s" % [part.part_name, origin]
	assert_bool(_grid.place_part(part, origin, rotation)).append_failure_message(context).is_true()
	return _grid.get_placement_at(MechGridData.get_footprint(part, origin, rotation)[0])
