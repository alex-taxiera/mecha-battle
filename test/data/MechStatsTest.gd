class_name MechStatsTest
extends GdUnitTestSuite

const __source: String = "res://src/data/MechStats.gd"
const Fixtures := preload("res://test/TestFixtures.gd")

const LEFT_ARM := Vector2i(-1, 0)
const RIGHT_ARM := Vector2i(6, 0)

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
	# Roomy and open, with the Skirmisher's 30 base HP and 3 base energy. Its arms touch the
	# first three rows of its outer columns: (0, 0)-(0, 2) on the left, (5, 0)-(5, 2) on the right.
	var chassis := Fixtures.open_chassis(Vector2i(6, 6))
	chassis.hardpoints = [Fixtures.left_arm(LEFT_ARM), Fixtures.right_arm(RIGHT_ARM)]
	_grid = MechGridData.new(chassis)


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
	_place(Fixtures.gatling(), LEFT_ARM)        # 8 damage, draws 3 energy
	_place(Fixtures.reactor(), Vector2i(3, 0))  # +4 energy, +5 HP
	_place(Fixtures.laser(), Vector2i(5, 5))    # +12 HP
	_place(Fixtures.heatsink(), Vector2i(3, 3)) # nothing on its own
	var stats := _stats()
	assert_array(stats.links).is_empty()
	assert_int(stats.hp).is_equal(30 + 5 + 12)
	assert_int(stats.energy_generated).is_equal(3 + 4)
	assert_int(stats.energy_drawn).is_equal(3)
	assert_int(stats.damage).is_equal(8)


func test_a_parts_mk_scales_its_own_numbers() -> void:
	var reactor := Fixtures.reactor() # 4 energy, 5 HP
	reactor.level = 2
	_place(reactor, Vector2i(2, 0))
	var gun := Fixtures.gatling()     # 8 damage, 3 energy a shot
	gun.level = 3
	gun.heat = 10
	_place(gun, LEFT_ARM)
	var heatsink := Fixtures.heatsink()
	heatsink.cooling = 15
	heatsink.level = 2
	_place(heatsink, Vector2i(4, 1))
	var stats := MechStats.calculate(_grid, [])
	var reactor_numbers := stats.part_stats[_grid.get_placement_at(Vector2i(2, 0))]
	assert_int(reactor_numbers.energy).is_equal(6)  # 4 × 1.5
	assert_int(reactor_numbers.hp).is_equal(8)      # 7.5, rounded
	var gun_numbers := stats.part_stats[_grid.get_placement_at(LEFT_ARM)]
	assert_int(gun_numbers.damage).is_equal(16)    # 8 × 2
	# Energy cost and heat don't scale.
	assert_int(gun_numbers.energy_draw).is_equal(3)
	assert_int(gun_numbers.heat).is_equal(10)
	assert_int(stats.heat_vented).is_equal(23)     # 15 × 1.5, rounded
	# Links add on top of the scaled number: an overcharging reactor touching the gun.
	var linked := MechStats.calculate(_grid, [_overcharge])
	assert_int(linked.part_stats[_grid.get_placement_at(LEFT_ARM)].damage).is_greater_equal(16)


func test_weapons_link_through_their_bay() -> void:
	#    -1 0 1 2
	#  0  G  . H .    G: gatling in the left arm
	#  1  G  . H H    H: heatsink
	#  2  G  . . .
	var gatling := _place(Fixtures.gatling(), LEFT_ARM)
	var heatsink := _place(Fixtures.heatsink(), Vector2i(1, 0))
	# A cell away from the bay, the heatsink doesn't cool the gun.
	assert_array(_stats().links).is_empty()
	assert_int(_stats().damage).is_equal(8)
	# Touching the bay, it does.
	assert_bool(_grid.move_part(heatsink.cells[0], Vector2i(0, 0))).is_true()
	var stats := _stats()
	assert_int(stats.damage).is_equal(12) # 8 x 1.5
	assert_int(stats.part_stats[_grid.get_placement_at(LEFT_ARM)].links).is_equal(1)
	assert_object(stats.links[0].contact.a.part).is_same(gatling.part)


func test_cooled_multiplies_weapon_damage_once() -> void:
	#    -1 0 1
	#  0  G  H .    G: gatling in the left arm
	#  1  G  H H    H, A: heatsinks
	#  2  G  A A
	#  3     . A
	var gatling := _place(Fixtures.gatling(), LEFT_ARM)
	_place(Fixtures.heatsink(), Vector2i(0, 0))
	assert_int(_stats().damage).is_equal(12) # 8 x 1.5
	_place(Fixtures.heatsink(), Vector2i(0, 2), 2)
	var stats := _stats()
	assert_int(stats.damage).is_equal(12) # a second heatsink doesn't cool it any further
	assert_int(stats.get_rule_counts()[_cooled]).is_equal(2)
	assert_int(stats.part_stats[gatling].links).is_equal(2)


func test_overcharge_adds_damage_per_reactor() -> void:
	#    -1 0 1
	#  0  G  R R    G: gatling in the left arm
	#  1  G  . .    R: reactors
	#  2  G  R R
	_place(Fixtures.gatling(), LEFT_ARM)
	_place(Fixtures.reactor(), Vector2i(0, 0))
	_place(Fixtures.reactor(), Vector2i(0, 2))
	var stats := _stats()
	assert_int(stats.damage).is_equal(8 + 3 + 3)
	assert_int(stats.energy_generated).is_equal(3 + 4 + 4)
	assert_int(stats.hp).is_equal(30 + 5 + 5)
	assert_int(stats.get_rule_counts()[_overcharge]).is_equal(2)


func test_bonuses_add_before_they_multiply() -> void:
	#    -1 0 1
	#  0  G  R R    G: gatling in the left arm
	#  1  G  A A    R: reactor
	#  2  G  . A    A: heatsink
	var gatling := _place(Fixtures.gatling(), LEFT_ARM)
	_place(Fixtures.reactor(), Vector2i(0, 0))
	_place(Fixtures.heatsink(), Vector2i(0, 1), 2)
	var stats := _stats()
	assert_int(stats.part_stats[gatling].damage).is_equal(17) # (8 + 3) x 1.5 = 16.5, rounded
	assert_int(stats.damage).is_equal(17)
	assert_int(stats.part_stats[gatling].bonuses[_overcharge]).is_equal(1)
	assert_int(stats.part_stats[gatling].bonuses[_cooled]).is_equal(1)
	assert_array(stats.part_stats[gatling].get_bonus_total(RuleBonus.Stat.DAMAGE)).is_equal([3.0, 1.5])


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
	# The heatsink shares two edges with the gatling's bay but makes one link.
	_place(Fixtures.gatling(), LEFT_ARM)
	_place(Fixtures.heatsink(), Vector2i(0, 0))
	var stats := _stats()
	assert_array(stats.links).has_size(1)
	assert_object(stats.links[0].rule).is_same(_cooled)


func test_unmatched_pairs_do_not_link() -> void:
	# A laser touches the gatling's bay, but no rule covers Weapon + Defense.
	_place(Fixtures.gatling(), LEFT_ARM)
	_place(Fixtures.laser(), Vector2i(0, 1))
	assert_array(_stats().links).is_empty()


func test_underpowered_weapons_lose_damage() -> void:
	# Two gatlings draw 6 energy against the chassis's 3: half power, half damage.
	_place(Fixtures.gatling(), LEFT_ARM)
	_place(Fixtures.gatling(), RIGHT_ARM)
	var stats := _stats()
	assert_int(stats.get_net_energy()).is_equal(-3)
	assert_float(stats.power).is_equal(0.5)
	assert_int(stats.damage).is_equal(8) # 16 x 0.5
	# A reactor out of their reach covers the draw.
	_place(Fixtures.reactor(), Vector2i(4, 4))
	stats = _stats()
	assert_float(stats.power).is_equal(1.0)
	assert_int(stats.damage).is_equal(16)


func test_parts_count_as_often_as_they_act_in_a_turn() -> void:
	# A gatling firing every half second counts twice a turn; a reactor pulsing every 2 seconds,
	# half. Their own numbers stay per activation.
	var gatling := Fixtures.gatling() # 8 damage for 3 energy
	gatling.cooldown_max = 0.5
	var reactor := Fixtures.reactor() # +4 energy
	reactor.cooldown_max = 2.0
	var gun := _place(gatling, LEFT_ARM)
	_place(reactor, Vector2i(3, 3))
	var stats := _stats()
	assert_int(stats.energy_drawn).is_equal(6)
	assert_int(stats.energy_generated).is_equal(3 + 2)
	assert_int(stats.damage).is_equal(13) # 16 a turn at 5/6 power: 13.3, rounded
	assert_int(stats.part_stats[gun].damage).is_equal(8)
	assert_int(stats.part_stats[gun].energy_draw).is_equal(3)
	# Positive control: at a 1-second cooldown, a part counts once, like one with none.
	assert_float(MechStats.activations_per_turn(gatling.cooldown_max)).is_equal(2.0)
	gatling.cooldown_max = 1.0
	assert_float(MechStats.activations_per_turn(gatling.cooldown_max)).is_equal(1.0)
	assert_float(MechStats.activations_per_turn(Fixtures.laser().cooldown_max)).is_equal(1.0)


func test_heat_is_made_at_each_weapons_cadence_and_vented_by_heatsinks() -> void:
	# A gatling firing every half second at 10 heat a shot draws 6 energy a turn against the
	# chassis's 3: at half power it fires half as often, making 10 heat a turn, not 20.
	var gatling := Fixtures.gatling()
	gatling.cooldown_max = 0.5
	gatling.heat = 10
	_place(gatling, LEFT_ARM)
	var heatsink := Fixtures.heatsink()
	heatsink.cooling = 15
	_place(heatsink, Vector2i(2, 3))
	var stats := _stats()
	assert_int(stats.heat_made).is_equal(10)
	assert_int(stats.heat_vented).is_equal(15)
	assert_int(stats.get_net_heat()).is_equal(-5)
	# Fully powered by a reactor out of reach, it makes all 20 and outruns the heatsink.
	_place(Fixtures.reactor(), Vector2i(4, 1))
	stats = _stats()
	assert_int(stats.heat_made).is_equal(20)
	assert_int(stats.get_net_heat()).is_equal(5)


func test_hp_is_the_chassis_plus_the_parts() -> void:
	_place(Fixtures.laser(), Vector2i(2, 2)) # +12 HP
	var stats := MechStats.calculate(_grid, _rules)
	assert_int(stats.base_hp).is_equal(30)
	assert_int(stats.hp).is_equal(42)


func test_rules_match_their_types_in_either_order() -> void:
	var gatling := Fixtures.gatling()
	var heatsink := Fixtures.heatsink()
	assert_bool(_overcharge.matches(gatling, Fixtures.reactor())).is_true()
	assert_bool(_overcharge.matches(Fixtures.reactor(), gatling)).is_true()
	assert_bool(_cooled.matches(gatling, heatsink)).is_true()
	assert_bool(_cooled.matches(heatsink, gatling)).is_true()
	assert_bool(_cooled.matches(gatling, Fixtures.gatling())).is_false()


func test_rules_can_require_a_tag() -> void:
	#    -1 0 1 2 3 4 5 6
	#  0  G  T R R . . . G    G: gatlings in both arms
	#  1  G  . . S S A . G    T: flush tank (untagged)   R, S: reactors
	#  2  G  . . . . A A G    A: heatsink (tagged)
	var tanked := _place(Fixtures.gatling(), LEFT_ARM)
	_place(Fixtures.flush_tank(), Vector2i(0, 0))
	var by_tank := _place(Fixtures.reactor(), Vector2i(1, 0))
	var sunk := _place(Fixtures.gatling(), RIGHT_ARM)
	_place(Fixtures.heatsink(), Vector2i(4, 1))
	var by_sink := _place(Fixtures.reactor(), Vector2i(2, 1))
	var stats := _stats()
	# The tank is utility, but Cooled and Stable need a heatsink.
	assert_bool(stats.part_stats[tanked].bonuses.has(_cooled)).is_false()
	assert_bool(stats.part_stats[by_tank].bonuses.has(_stable)).is_false()
	assert_bool(stats.part_stats[sunk].bonuses.has(_cooled)).is_true()
	assert_bool(stats.part_stats[by_sink].bonuses.has(_stable)).is_true()
	assert_bool(_cooled.matches(Fixtures.gatling(), Fixtures.flush_tank())).is_false()


func test_overclocked_speeds_a_weapon_up_and_makes_it_cost_more() -> void:
	#    -1 0
	#  0  L  C    L: plasma lance in the left arm (every 4 s, 160 EN)
	#  1  L  C    C: logic chips
	#  2  L  .
	var overclocked := Fixtures.overclocked()
	_rules.append(overclocked)
	var lance := _place(Fixtures.plasma_lance(), LEFT_ARM)
	_place(Fixtures.logic_chip(), Vector2i(0, 0))
	var stats := _stats()
	assert_float(stats.part_stats[lance].cooldown).is_equal_approx(3.6, 1e-6)
	assert_int(stats.part_stats[lance].energy_draw).is_equal(192)
	# Drawn a turn at the faster cadence: 192 / 3.6 = 53.3.
	assert_int(stats.energy_drawn).is_equal(53)
	# A second chip stacks: 4 × 0.81 = 3.24 s, 160 × 1.44 = 230.4.
	_place(Fixtures.logic_chip(), Vector2i(0, 1))
	stats = _stats()
	assert_float(stats.part_stats[lance].cooldown).is_equal_approx(3.24, 1e-6)
	assert_int(stats.part_stats[lance].energy_draw).is_equal(230)
	assert_int(stats.part_stats[lance].bonuses[overclocked]).is_equal(2)


func test_a_lone_chip_leaves_a_weapon_alone() -> void:
	var lance := _place(Fixtures.plasma_lance(), LEFT_ARM)
	_place(Fixtures.logic_chip(), Vector2i(3, 3))
	_rules.append(Fixtures.overclocked())
	var stats := _stats()
	assert_float(stats.part_stats[lance].cooldown).is_equal(4.0)
	assert_int(stats.part_stats[lance].energy_draw).is_equal(160)


func test_volatile_generators_make_more_energy_and_heat() -> void:
	#     0 1 2 3
	#  0  C C D D    C, D: combustion cores, 80 EN and 10 heat a second each
	#  1  C C D D
	_rules.append(Fixtures.volatile())
	var left := _place(Fixtures.combustion_core(), Vector2i(0, 0))
	var right := _place(Fixtures.combustion_core(), Vector2i(2, 0))
	var stats := _stats()
	for core in [left, right]:
		assert_int(stats.part_stats[core].energy).is_equal(100)
		assert_int(stats.part_stats[core].heat).is_equal(20)
	assert_int(stats.energy_generated).is_equal(3 + 200)
	assert_int(stats.heat_made).is_equal(40)


func test_only_weapon_heat_is_scaled_by_power() -> void:
	# Two volatile reactors (4 + 20 EN and 10 heat each) and a lance drawing far more than
	# that: 800 EN every 4 s is 200 a turn, against 3 + 48 generated, so power is 0.255.
	_rules.append(Fixtures.volatile())
	var lance := Fixtures.plasma_lance()
	lance.energy_cost = 800
	_place(lance, LEFT_ARM)
	_place(Fixtures.reactor(), Vector2i(2, 2))
	_place(Fixtures.reactor(), Vector2i(2, 3))
	var stats := _stats()
	assert_float(stats.power).is_equal_approx(0.255, 1e-6)
	# The lance's 90 heat every 4 s (22.5 a turn) × 0.255, plus the reactors' full 20.
	assert_int(stats.heat_made).is_equal(26)


func test_insulated_defense_gains_hp_per_utility_part() -> void:
	#     0 1 2
	#  0  . T .    T: flush tank
	#  1  A P .    P: laser (12 HP)
	#  2  A A .    A: heatsink
	_rules.append(Fixtures.insulated())
	var laser := _place(Fixtures.laser(), Vector2i(1, 1))
	_place(Fixtures.flush_tank(), Vector2i(1, 0))
	var stats := _stats()
	assert_int(stats.part_stats[laser].hp).is_equal(13) # 12 × 1.1 = 13.2
	_place(Fixtures.heatsink(), Vector2i(0, 1))
	stats = _stats()
	assert_int(stats.part_stats[laser].hp).is_equal(15) # 12 × 1.21 = 14.52


func test_solar_plating_is_armor_that_makes_energy() -> void:
	var solar := _place(Fixtures.solar_plating(), Vector2i(0, 0))
	var laser := _place(Fixtures.laser(), Vector2i(0, 1))
	var stats := _stats()
	assert_int(stats.part_stats[solar].hp).is_equal(104) # Plated with the laser
	assert_int(stats.part_stats[laser].hp).is_equal(16)
	assert_int(stats.energy_generated).is_equal(3 + 15)
	assert_int(stats.hp).is_equal(30 + 104 + 16)


func test_shield_and_upkeep_add_up() -> void:
	var emitter := Fixtures.part("Emitter", MechPart.PartType.DEFENSE, [Vector2i(0, 0), Vector2i(1, 0)], 4, {"shield": 200, "upkeep": 10})
	_place(emitter, Vector2i(0, 0))
	emitter = emitter.duplicate()
	emitter.level = 2
	_place(emitter, Vector2i(0, 2))
	var stats := _stats()
	assert_int(stats.shield).is_equal(200 + 300) # a Mk II shields 1.5 times as much
	assert_int(stats.energy_drawn).is_equal(20) # upkeep doesn't scale
	assert_int(stats.hp).is_equal(30)


func _stats() -> MechStats:
	return MechStats.calculate(_grid, _rules)


func _place(part: MechPart, origin: Vector2i, rotation := 0) -> MechGridData.Placement:
	var context := "%s at %s" % [part.part_name, origin]
	assert_bool(_grid.place_part(part, origin, rotation)).append_failure_message(context).is_true()
	return _grid.get_placement_at(MechGridData.get_footprint(part, origin, rotation)[0])
