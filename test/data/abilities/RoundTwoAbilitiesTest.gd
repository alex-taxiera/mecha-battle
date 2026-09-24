class_name RoundTwoAbilitiesTest
extends GdUnitTestSuite
## The second round of part abilities: leech, execute, trophies, heat to energy, repair,
## ablative plating, the damage limiter, the status scrubber, and the targeting rule.

const Fixtures := preload("res://test/TestFixtures.gd")
const LEFT_ARM := Vector2i(-1, 1)
const BACK := Vector2i(1, -2)


func test_a_leech_drill_repairs_a_quarter_of_each_hit() -> void:
	var drill := _armed([[Fixtures.leech_drill(), LEFT_ARM]], 1000)
	drill.current_health = 500
	var target := _dummy(1000)
	_hit_once(drill, target)
	# 10 damage, 2.5 rounded to 3.
	assert_int(target.current_health).is_equal(990)
	assert_int(drill.current_health).is_equal(503)
	# Positive control: a plain gun of the same damage repairs nothing.
	var gun := _armed([[_gun(10), LEFT_ARM]], 1000)
	gun.current_health = 500
	_hit_once(gun, _dummy(1000))
	assert_int(gun.current_health).is_equal(500)


func test_a_guillotine_doubles_its_hits_on_a_weakened_target() -> void:
	var cannon := _armed([[Fixtures.guillotine_cannon(), BACK]], 1000)
	var healthy := _dummy(1000)
	_hit_once(cannon, healthy)
	assert_int(healthy.current_health).is_equal(950)
	var weak := _dummy(1000)
	weak.current_health = 300
	_hit_once(_armed([[Fixtures.guillotine_cannon(), BACK]], 1000), weak)
	assert_int(weak.current_health).is_equal(200)


func test_a_trophy_rack_grows_with_each_win_up_to_its_cap() -> void:
	var rack := Fixtures.trophy_rack()
	var grid := MechGridData.new(Fixtures.armed_cross())
	assert_bool(grid.place_part(rack, BACK)).is_true()
	var winner := BattleMech.new(grid)
	var loser_rack := Fixtures.trophy_rack()
	var loser_grid := MechGridData.new(Fixtures.armed_cross())
	assert_bool(loser_grid.place_part(loser_rack, BACK)).is_true()
	var loser := BattleMech.new(loser_grid)
	winner.end_fight(true)
	loser.end_fight(false)
	assert_int(rack.bonus_damage).is_equal(2)
	assert_int(loser_rack.bonus_damage).is_equal(0)
	# The bonus feeds its damage from the next fight on, before the Mk scales it.
	rack.level = 2
	var stats := MechStats.calculate(grid, [])
	assert_int(stats.part_stats[grid.get_placement_at(BACK)].damage).is_equal(48)
	for i in 30:
		winner.end_fight(true)
	assert_int(rack.bonus_damage).is_equal(40)


func test_a_thermoelectric_generator_turns_heat_into_energy() -> void:
	var mech := _armed([[Fixtures.thermoelectric(), Vector2i(1, 1)]], 1000, 0)
	var engine := _fight(mech, _dummy(1000))
	mech.heat = 50
	for i in 10:
		engine.process_tick(0.1)
	# 50 heat × 0.8 = 40 a second.
	assert_int(mech.current_energy).is_equal(40)
	# Positive control: cold, nothing.
	var cold := _armed([[Fixtures.thermoelectric(), Vector2i(1, 1)]], 1000, 0)
	var still := _fight(cold, _dummy(1000))
	for i in 10:
		still.process_tick(0.1)
	assert_int(cold.current_energy).is_equal(0)


func test_a_nanite_bay_repairs_while_the_mech_stands() -> void:
	var mech := _armed([[Fixtures.nanite_bay(), Vector2i(1, 1)]], 1000)
	# 1000 base + 20 = 1020 max; 1% a second is 10.2.
	mech.current_health = 500
	var engine := _fight(mech, _dummy(1000))
	for i in 10:
		engine.process_tick(0.1)
	assert_int(mech.current_health).is_equal(510)
	# Never past full.
	mech.current_health = mech.max_hp
	for i in 10:
		engine.process_tick(0.1)
	assert_int(mech.current_health).is_equal(mech.max_hp)


func test_ablative_plating_shrugs_off_the_first_two_shots() -> void:
	var mech := _armed([[Fixtures.ablative_plating(), Vector2i(1, 1)]], 100)
	# A preview doesn't use it up.
	assert_int(_shot_taken(mech, 10, true)).is_equal(0)
	assert_int(_shot_taken(mech, 10)).is_equal(0)
	assert_int(_shot_taken(mech, 10)).is_equal(0)
	assert_int(_shot_taken(mech, 10)).is_equal(10)
	# Only shots: the storm still hurts.
	var fresh := _armed([[Fixtures.ablative_plating(), Vector2i(1, 1)]], 100)
	assert_int(fresh.take_damage(10, HitPipeline.Kind.STORM)).is_equal(10)
	# Two plates, four shots.
	var doubled := _armed([[Fixtures.ablative_plating(), Vector2i(1, 1)], [Fixtures.ablative_plating(), Vector2i(2, 1)]], 100)
	for i in 4:
		assert_int(_shot_taken(doubled, 10)).append_failure_message("shot %d" % i).is_equal(0)
	assert_int(_shot_taken(doubled, 10)).is_equal(10)


func test_a_damage_limiter_caps_every_hit() -> void:
	var mech := _armed([[Fixtures.damage_limiter(), Vector2i(1, 1)]], 1000)
	assert_int(mech.take_damage(150)).is_equal(60)
	assert_int(mech.take_damage(40)).is_equal(40)
	# After plating: on a Bastion, 150 - 2 is still capped at 60, and 61 - 2 isn't.
	var grid := MechGridData.new(Fixtures.bastion())
	assert_bool(grid.place_part(Fixtures.damage_limiter(), Vector2i(1, 1))).is_true()
	var bastion := BattleMech.new(grid)
	assert_int(bastion.take_damage(150)).is_equal(60)
	assert_int(bastion.take_damage(61)).is_equal(59)


func test_a_status_scrubber_clears_the_worst_debuff_every_five_seconds() -> void:
	var mech := _armed([[Fixtures.status_scrubber(), Vector2i(1, 1)]], 1000)
	var engine := _fight(mech, _dummy(1000))
	for i in 49:
		engine.process_tick(0.1)
	mech.add_status(Fixtures.burn(), 3)
	mech.add_status(Fixtures.jammed(), 5)
	mech.add_status(Fixtures.haste(), 5)
	engine.process_tick(0.1)
	# At 5 s it clears the Jammed (the most charges); the Burn stays, and so does the buff.
	assert_object(mech.get_status("jammed")).is_null()
	assert_object(mech.get_status("burn")).is_not_null()
	assert_object(mech.get_status("haste")).is_not_null()
	# Charged again five seconds later.
	for i in 30:
		engine.process_tick(0.1)
	mech.add_status(Fixtures.burn(), 5)
	engine.process_tick(0.1)
	assert_object(mech.get_status("burn")).is_not_null()
	for i in 20:
		engine.process_tick(0.1)
	assert_object(mech.get_status("burn")).is_null()


func test_a_targeting_computer_sharpens_the_weapons_it_touches() -> void:
	var grid := MechGridData.new(Fixtures.armed_cross())
	var gun := _gun(20)
	assert_bool(grid.place_part(gun, LEFT_ARM)).is_true()
	assert_bool(grid.place_part(Fixtures.targeting_computer(), Vector2i(0, 1))).is_true()
	var rules: Array[SynergyRule] = [Fixtures.targeted()]
	var stats := MechStats.calculate(grid, rules)
	assert_int(stats.part_stats[grid.get_placement_at(LEFT_ARM)].damage).is_equal(22)
	# Two stack: 20 × 1.21.
	assert_bool(grid.place_part(Fixtures.targeting_computer(), Vector2i(0, 2))).is_true()
	stats = MechStats.calculate(grid, rules)
	assert_int(stats.part_stats[grid.get_placement_at(LEFT_ARM)].damage).is_equal(24)
	# Positive control: a plain utility part doesn't.
	var plain := MechGridData.new(Fixtures.armed_cross())
	assert_bool(plain.place_part(_gun(20), LEFT_ARM)).is_true()
	assert_bool(plain.place_part(Fixtures.part("Box", MechPart.PartType.UTILITY, [Vector2i(0, 0)]), Vector2i(0, 1))).is_true()
	assert_int(MechStats.calculate(plain, rules).part_stats[plain.get_placement_at(LEFT_ARM)].damage).is_equal(20)


func test_a_capacitor_battery_releases_energy_every_fourth_shot() -> void:
	var mech := _armed([[_gun(1), LEFT_ARM], [Fixtures.capacitor_battery(), Vector2i(0, 1)]], 1000, 0)
	mech.active_parts[0].cooldown_max = 0.1
	mech.active_parts[0].current_cooldown = 0.0
	var engine := _fight(mech, _dummy(1000))
	for i in 3:
		engine.process_tick(0.1)
	assert_int(mech.current_energy).is_equal(0)
	engine.process_tick(0.1)
	assert_int(mech.current_energy).is_equal(40)


# The armed cross at [param hp] base HP and [param energy] a turn, with [param placements]
# ([part, origin] pairs).
func _armed(placements: Array, hp: int, energy := 1000) -> BattleMech:
	var chassis := Fixtures.armed_cross()
	chassis.base_hp = hp
	chassis.base_energy = energy
	var grid := MechGridData.new(chassis)
	for placement: Array in placements:
		assert_bool(grid.place_part(placement[0], placement[1])).append_failure_message(str(placement)).is_true()
	return BattleMech.new(grid)


func _dummy(hp: int) -> BattleMech:
	var chassis := Fixtures.cross_chassis()
	chassis.base_hp = hp
	chassis.base_energy = 0
	return BattleMech.new(MechGridData.new(chassis))


func _gun(damage: int) -> MechPart:
	return Fixtures.part("Gun", MechPart.PartType.WEAPON, Fixtures.ARM_SHAPE, 0, {"damage": damage, "cooldown_max": 10.0})


func _fight(left: BattleMech, right: BattleMech) -> CombatEngine:
	var engine := CombatEngine.new(left, right)
	engine.start()
	return engine


# Fires [param attacker]'s first weapon once at [param target], right away.
func _hit_once(attacker: BattleMech, target: BattleMech) -> void:
	var engine := _fight(attacker, target)
	for active in attacker.active_parts:
		active.current_cooldown = 0.0 if active.part.type == MechPart.PartType.WEAPON else active.current_cooldown
	engine.process_tick(0.1)


# A shot of [param damage] at [param mech]: what it takes, or would take for a [param preview].
func _shot_taken(mech: BattleMech, damage: int, preview := false) -> int:
	var hit := HitPipeline.Hit.new(HitPipeline.Kind.SHOT, mech, damage)
	hit.preview = preview
	var taken := HitPipeline.resolve(hit)
	return hit.damage if preview else taken
