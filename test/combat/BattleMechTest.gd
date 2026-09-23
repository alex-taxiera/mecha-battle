class_name BattleMechTest
extends GdUnitTestSuite

const __source: String = "res://src/combat/BattleMech.gd"
const Fixtures := preload("res://test/TestFixtures.gd")
# The armed cross's left arm, touching (0, 1) and (0, 2).
const LEFT_ARM := Vector2i(-1, 1)

var _chassis: MechChassis # the Skirmisher: 30 base HP


func before_test() -> void:
	_chassis = Fixtures.armed_cross()


func test_max_hp_is_the_chassis_plus_its_parts() -> void:
	# An empty Skirmisher has just its base HP.
	var empty := BattleMech.new(MechGridData.new(_chassis))
	assert_int(empty.max_hp).is_equal(30)
	assert_int(empty.current_health).is_equal(30)
	# A laser (+12) and a reactor (+5), and a fight starts at full health with no energy.
	var mech := BattleMech.new(_grid_with([[Fixtures.laser(), Vector2i(1, 0)], [Fixtures.reactor(), Vector2i(1, 2)]]))
	assert_int(mech.max_hp).is_equal(47)
	assert_int(mech.current_health).is_equal(47)
	assert_int(mech.current_energy).is_equal(0)
	assert_int(mech.base_energy).is_equal(3) # the Skirmisher's, each turn


func test_take_damage_lowers_health_down_to_zero() -> void:
	var mech := BattleMech.new(MechGridData.new(_chassis)) # 30 HP
	assert_int(mech.take_damage(8)).is_equal(8)
	assert_int(mech.current_health).is_equal(22)
	mech.take_damage(100)
	assert_int(mech.current_health).is_equal(0)
	assert_int(mech.max_hp).is_equal(30)


func test_thick_plating_takes_2_off_every_hit() -> void:
	var bastion := BattleMech.new(MechGridData.new(Fixtures.bastion())) # 450 HP
	assert_int(bastion.take_damage(8)).is_equal(6)
	assert_int(bastion.current_health).is_equal(444)
	# Hits of 2 or less do nothing, and it never heals.
	assert_int(bastion.take_damage(2)).is_equal(0)
	assert_int(bastion.take_damage(1)).is_equal(0)
	assert_int(bastion.take_damage(0)).is_equal(0)
	assert_int(bastion.current_health).is_equal(444)


func test_damage_taken_can_be_asked_without_taking_the_hit() -> void:
	var bastion := BattleMech.new(MechGridData.new(Fixtures.bastion())) # 450 HP, plating 2
	assert_int(bastion.get_damage_taken(8)).is_equal(6)
	assert_int(bastion.get_damage_taken(1)).is_equal(0)
	assert_int(bastion.current_health).is_equal(450)
	# Without plating, a hit lands in full.
	assert_int(BattleMech.new(MechGridData.new(_chassis)).get_damage_taken(8)).is_equal(8)


func test_max_hp_uses_the_rounds_chassis_hp() -> void:
	var grid := _grid_with([[Fixtures.laser(), Vector2i(1, 1)]])
	# Round 3: 30 × 1.15² = 39.675, rounded down, plus the laser's 12.
	var mech := BattleMech.new(grid, [], 3)
	assert_int(mech.max_hp).is_equal(51)
	assert_int(mech.current_health).is_equal(51)
	assert_int(BattleMech.new(grid).max_hp).is_equal(42) # round 1 by default


func test_heat_stays_between_empty_and_full() -> void:
	var mech := BattleMech.new(MechGridData.new(_chassis))
	assert_int(mech.heat).is_equal(0)
	mech.add_heat(60)
	assert_int(mech.heat).is_equal(60)
	mech.add_heat(60)
	assert_int(mech.heat).is_equal(100)
	mech.add_heat(-130)
	assert_int(mech.heat).is_equal(0)


func test_heat_past_the_throttle_line_slows_the_fire_rate() -> void:
	var mech := BattleMech.new(MechGridData.new(_chassis))
	var rates := []
	for heat in [0, 50, 75, 100]:
		mech.heat = heat
		rates.append(mech.get_fire_rate())
	# Full speed up to 50 heat, then evenly down to half at 100.
	assert_array(rates).is_equal([1.0, 1.0, 0.75, 0.5])


func test_hp_link_bonuses_count_when_given_the_rules() -> void:
	# Two touching lasers: 30 + 12 + 12, plus Plated's +4 each.
	var grid := _grid_with([[Fixtures.laser(), Vector2i(1, 1)], [Fixtures.laser(), Vector2i(2, 1)]])
	assert_int(BattleMech.new(grid, Fixtures.rules()).max_hp).is_equal(62)
	assert_int(BattleMech.new(grid).max_hp).is_equal(54)


func test_makes_one_active_part_per_placed_part() -> void:
	var gatling := _with_cooldown(Fixtures.gatling(), 1.5)
	var reactor := Fixtures.reactor()
	var laser := Fixtures.laser()
	# Gatling in the left arm, reactor (2, 1)-(3, 1), laser (2, 2).
	var mech := BattleMech.new(_grid_with([[gatling, LEFT_ARM], [reactor, Vector2i(2, 1)], [laser, Vector2i(2, 2)]]))
	assert_array(mech.active_parts).has_size(3)
	assert_array(mech.active_parts.map(func(active: ActivePart) -> MechPart: return active.part)) \
		.contains_same_exactly_in_any_order(gatling, reactor, laser)
	# Each starts working, with its cooldown full.
	for active in mech.active_parts:
		assert_bool(active.is_active).is_true()
	assert_float(_active_for(mech, gatling).current_cooldown).is_equal(1.5)
	assert_float(_active_for(mech, laser).current_cooldown).is_equal(0.0)


func test_mounted_weapons_know_their_bay() -> void:
	var gatling := Fixtures.gatling()
	var pod := Fixtures.missile_pod()
	var laser := Fixtures.laser()
	# Gatling in the left arm, pod in the back bay over (1, 0) and (2, 0), laser on the grid.
	var mech := BattleMech.new(_grid_with([[gatling, LEFT_ARM], [pod, Vector2i(1, -2)], [laser, Vector2i(1, 1)]]))
	assert_str(_active_for(mech, gatling).hardpoint.hardpoint_name).is_equal("Left Arm")
	assert_str(_active_for(mech, pod).hardpoint.hardpoint_name).is_equal("Back")
	assert_object(_active_for(mech, laser).hardpoint).is_null()


func test_a_weapon_is_starved_when_ready_but_unaffordable() -> void:
	var gatling := _with_cooldown(Fixtures.gatling(), 1.0) # costs 3
	var laser := Fixtures.laser()
	var mech := BattleMech.new(_grid_with([[gatling, LEFT_ARM], [laser, Vector2i(1, 1)]]))
	var gun := _active_for(mech, gatling)
	gun.current_cooldown = 0.0
	mech.current_energy = 2
	assert_bool(mech.is_starved(gun)).is_true()
	# Positive controls: with enough energy, or still cooling down, it isn't.
	mech.current_energy = 3
	assert_bool(mech.is_starved(gun)).is_false()
	mech.current_energy = 0
	gun.current_cooldown = 0.5
	assert_bool(mech.is_starved(gun)).is_false()
	# A shut-down mech's weapons are off, not starved, and only weapons starve.
	gun.current_cooldown = 0.0
	assert_bool(mech.is_starved(gun)).is_true()
	mech.shutdown_left = 1.0
	assert_bool(mech.is_starved(gun)).is_false()
	mech.shutdown_left = 0.0
	var plate := _active_for(mech, laser)
	plate.energy_cost = 5
	assert_bool(mech.is_starved(plate)).is_false()


func test_the_top_weapon_did_the_most_damage() -> void:
	var gatling := Fixtures.gatling()
	var pod := Fixtures.missile_pod()
	var mech := BattleMech.new(_grid_with([[gatling, LEFT_ARM], [pod, Vector2i(1, -2)], [Fixtures.laser(), Vector2i(1, 1)]]))
	# Nothing has hit yet.
	assert_object(mech.get_top_weapon()).is_null()
	_active_for(mech, gatling).damage_dealt = 10
	_active_for(mech, pod).damage_dealt = 14
	assert_object(mech.get_top_weapon()).is_same(_active_for(mech, pod))
	# A tie goes to the weapon placed first.
	_active_for(mech, gatling).damage_dealt = 14
	assert_object(mech.get_top_weapon()).is_same(_active_for(mech, gatling))


func test_active_parts_fight_with_their_link_bonuses() -> void:
	# The left arm's gatling cooled by a heatsink touching its bay at (0, 1), (0, 2), (1, 2):
	# 8 × 1.5.
	var gatling := Fixtures.gatling()
	var cooled := _grid_with([[gatling, LEFT_ARM], [Fixtures.heatsink(), Vector2i(0, 1)]])
	var active := _active_for(BattleMech.new(cooled, Fixtures.rules()), gatling)
	assert_int(active.damage).is_equal(12)
	assert_int(active.energy_cost).is_equal(3)
	# A reactor (1, 0)-(2, 0) touching a heatsink at (1, 1): Stable, 4 + 2 energy.
	var reactor := Fixtures.reactor()
	var stable := _grid_with([[reactor, Vector2i(1, 0)], [Fixtures.heatsink(), Vector2i(1, 1)]])
	assert_int(_active_for(BattleMech.new(stable, Fixtures.rules()), reactor).energy_gen).is_equal(6)
	# Without the rules, both fight with their own numbers.
	assert_int(_active_for(BattleMech.new(cooled), gatling).damage).is_equal(8)
	assert_int(_active_for(BattleMech.new(stable), reactor).energy_gen).is_equal(4)


func test_copies_of_one_part_keep_separate_state() -> void:
	# The same MechPart resource placed twice becomes two ActiveParts.
	var laser := _with_cooldown(Fixtures.laser(), 2.0)
	var mech := BattleMech.new(_grid_with([[laser, Vector2i(1, 1)], [laser, Vector2i(2, 1)]]))
	assert_array(mech.active_parts).has_size(2)
	var first := mech.active_parts[0]
	var second := mech.active_parts[1]
	assert_object(first).is_not_same(second)
	assert_object(first.part).is_same(second.part)
	first.current_cooldown = 0.5
	first.is_active = false
	assert_float(second.current_cooldown).is_equal(2.0)
	assert_bool(second.is_active).is_true()


func test_a_fight_leaves_the_grid_and_its_resources_untouched() -> void:
	var gatling := _with_cooldown(Fixtures.gatling(), 1.5)
	var laser := Fixtures.laser()
	var grid := _grid_with([[gatling, LEFT_ARM], [laser, Vector2i(2, 1)]])
	var before := [_saved(gatling), _saved(laser), _saved(_chassis)]
	var mech := BattleMech.new(grid, Fixtures.rules())
	# Play out some combat on the live state.
	mech.current_health -= 20
	mech.current_energy += 5
	for active in mech.active_parts:
		active.current_cooldown = 0.25
		active.is_active = false
	assert_array([_saved(gatling), _saved(laser), _saved(_chassis)]).is_equal(before)
	assert_array(grid.get_placements()).has_size(2)
	assert_object(grid.get_part_at(Vector2i(-1, 3))).is_same(gatling)
	assert_object(grid.get_part_at(Vector2i(2, 1))).is_same(laser)
	# Positive control: the snapshot does catch a change to a part.
	gatling.cooldown_max = 0.5
	assert_that(_saved(gatling)).is_not_equal(before[0])


# An armed-cross grid with each [part, origin] placed.
func _grid_with(placements: Array) -> MechGridData:
	var grid := MechGridData.new(_chassis)
	for entry in placements:
		assert_bool(grid.place_part(entry[0], entry[1])).append_failure_message("placing %s at %s" % [entry[0].part_name, entry[1]]).is_true()
	return grid


func _with_cooldown(part: MechPart, seconds: float) -> MechPart:
	part.cooldown_max = seconds
	return part


func _active_for(mech: BattleMech, part: MechPart) -> ActivePart:
	for active in mech.active_parts:
		if active.part == part:
			return active
	return null


# Every saved property of a resource, with arrays copied so later edits can't change the snapshot.
func _saved(resource: Resource) -> Dictionary:
	var values := {}
	for property in resource.get_property_list():
		if property.usage & PROPERTY_USAGE_STORAGE:
			var value: Variant = resource.get(property.name)
			values[property.name] = value.duplicate(true) if value is Array or value is Dictionary else value
	return values
