class_name TriggerAbilitiesTest
extends GdUnitTestSuite
## The trigger parts: each acts on its event, and the neighbor triggers only for what they touch.

const __source: String = "res://src/data/abilities/EnergyOnNeighborFire.gd"
const Fixtures := preload("res://test/TestFixtures.gd")

# The armed cross's left arm touches (0, 1) and (0, 2).
const LEFT_ARM := Vector2i(-1, 1)


func test_a_coupler_charges_off_the_weapon_it_touches() -> void:
	var mech := _armed([[_gun(0.5), LEFT_ARM], [Fixtures.capacitor_coupler(), Vector2i(0, 1)]])
	var engine := _fight(mech)
	for i in 5:
		engine.process_tick(0.1)
	assert_int(mech.current_energy).is_equal(5)
	for i in 5:
		engine.process_tick(0.1)
	assert_int(mech.current_energy).is_equal(10)


func test_a_coupler_away_from_the_weapon_does_nothing() -> void:
	var mech := _armed([[_gun(0.5), LEFT_ARM], [Fixtures.capacitor_coupler(), Vector2i(2, 2)]])
	var engine := _fight(mech)
	for i in 10:
		engine.process_tick(0.1)
	assert_int(mech.current_energy).is_equal(0)


func test_a_feeder_speeds_the_other_weapon_every_third_shot() -> void:
	# A narrow frame with arms either side of row 0: the feeder across it touches both.
	var chassis := Fixtures.open_chassis(Vector2i(2, 3))
	chassis.base_energy = 0
	chassis.hardpoints = [Fixtures.left_arm(Vector2i(-1, 0)), Fixtures.right_arm(Vector2i(2, 0))]
	var grid := MechGridData.new(chassis)
	var fast := _gun(0.5)
	var slow := _gun(10.0)
	for entry in [[fast, Vector2i(-1, 0)], [slow, Vector2i(2, 0)], [Fixtures.ammo_feeder(), Vector2i(0, 0)]]:
		assert_bool(grid.place_part(entry[0], entry[1])).is_true()
	var mech := BattleMech.new(grid)
	var engine := _fight(mech)
	for i in 10:
		engine.process_tick(0.1)
	# Two shots from the fast gun: not yet.
	assert_float(_active_for(mech, slow).current_cooldown).is_equal_approx(9.0, 1e-6)
	for i in 5:
		engine.process_tick(0.1)
	# The third takes 0.5 s off.
	assert_float(_active_for(mech, slow).current_cooldown).is_equal_approx(8.0, 1e-6)


func test_a_vent_dumps_heat_when_the_shield_breaks() -> void:
	var mech := _armed([[Fixtures.shield_emitter(), Vector2i(1, 0)], [Fixtures.emergency_vent(), Vector2i(2, 0)]])
	mech.heat = 60
	mech.take_damage(50) # the shield holds
	assert_int(mech.heat).is_equal(60)
	mech.take_damage(250) # this one breaks it
	assert_int(mech.shield).is_equal(0)
	assert_int(mech.heat).is_equal(20)
	# Once broken, more hits don't vent again.
	mech.take_damage(5)
	assert_int(mech.heat).is_equal(20)


func test_a_vent_answers_a_collapse_too() -> void:
	var mech := _armed([[Fixtures.shield_emitter(), Vector2i(1, 0)], [Fixtures.emergency_vent(), Vector2i(2, 0)]])
	mech.heat = 60
	mech.collapse_shield()
	assert_int(mech.heat).is_equal(20)


func test_a_meltdown_capacitor_charges_the_weapons_it_touches() -> void:
	# The Reactor's arms touch only its tips: the capacitor on the left tip touches the left gun.
	var chassis := Fixtures.reactor_frame()
	chassis.base_energy = 0
	var grid := MechGridData.new(chassis)
	var near := _gun(10.0)
	var far := _gun(10.0)
	for entry in [[near, Vector2i(-1, 1)], [far, Vector2i(5, 1)], [Fixtures.meltdown_capacitor(), Vector2i(0, 2)]]:
		assert_bool(grid.place_part(entry[0], entry[1])).is_true()
	var mech := BattleMech.new(grid)
	mech.heat = 100
	var engine := _fight(mech)
	engine.process_tick(0.1)
	assert_bool(mech.is_shut_down()).is_true()
	assert_float(_active_for(mech, near).current_cooldown).is_equal(0.0)
	# The far gun only ticked down, at half speed from full heat.
	assert_float(_active_for(mech, far).current_cooldown).is_equal_approx(9.95, 1e-6)


func test_a_dynamo_charges_off_every_hit_taken() -> void:
	var mech := _armed([[Fixtures.kinetic_dynamo(), Vector2i(1, 0)]])
	mech.take_damage(10)
	mech.take_damage(10)
	assert_int(mech.current_energy).is_equal(6)
	# A hit that does nothing doesn't count.
	mech.take_damage(0)
	assert_int(mech.current_energy).is_equal(6)


func test_neighbors_are_the_parts_touching_each_other() -> void:
	var gun := _gun(1.0)
	var near := Fixtures.capacitor_coupler()
	var far := Fixtures.capacitor_coupler()
	var mech := _armed([[gun, LEFT_ARM], [near, Vector2i(0, 1)], [far, Vector2i(2, 2)]])
	assert_array(_active_for(mech, gun).neighbors).contains_exactly([_active_for(mech, near)])
	assert_array(_active_for(mech, near).neighbors).contains_exactly([_active_for(mech, gun)])
	assert_array(_active_for(mech, far).neighbors).is_empty()


func test_a_counter_triggers_every_nth_time() -> void:
	var active := ActivePart.new(Fixtures.laser())
	var ability := PartAbility.new()
	var seen := []
	for i in 7:
		seen.append(active.count(ability, 3))
	assert_array(seen).is_equal([false, false, true, false, false, true, false])


# A free gun firing every [param seconds].
func _gun(seconds: float) -> MechPart:
	return Fixtures.part("Gun", MechPart.PartType.WEAPON, Fixtures.ARM_SHAPE, 0, {"damage": 1, "cooldown_max": seconds})


# An armed cross with no base energy and each [part, origin] placed.
func _armed(placements: Array) -> BattleMech:
	var chassis := Fixtures.armed_cross()
	chassis.base_energy = 0
	var grid := MechGridData.new(chassis)
	for entry in placements:
		assert_bool(grid.place_part(entry[0], entry[1])).append_failure_message("%s at %s" % [entry[0].part_name, entry[1]]).is_true()
	return BattleMech.new(grid)


func _fight(mech: BattleMech) -> CombatEngine:
	var dummy := Fixtures.cross_chassis()
	dummy.base_hp = 1000
	dummy.base_energy = 0
	var engine := CombatEngine.new(mech, BattleMech.new(MechGridData.new(dummy)))
	engine.start()
	return engine


func _active_for(mech: BattleMech, part: MechPart) -> ActivePart:
	for active in mech.active_parts:
		if active.part == part:
			return active
	return null
