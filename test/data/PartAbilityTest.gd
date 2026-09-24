class_name PartAbilityTest
extends GdUnitTestSuite

const __source: String = "res://src/data/PartAbility.gd"
const Fixtures := preload("res://test/TestFixtures.gd")


# Counts its ticks on the part, and on the fight's end records whether its mech won.
class Recorder:
	extends PartAbility

	func on_tick(_mech: BattleMech, active: ActivePart, delta: float) -> void:
		active.counters["seconds"] = active.counters.get("seconds", 0.0) + delta

	func on_fight_end(_mech: BattleMech, active: ActivePart, won: bool) -> void:
		active.part.set_meta("won", won)


func test_a_part_ticks_while_its_mech_runs() -> void:
	var mech := _mech_with(Recorder.new())
	var engine := _fight(mech, _dummy(1000))
	for i in 3:
		engine.process_tick(0.1)
	assert_float(mech.active_parts[0].counters["seconds"]).is_equal_approx(0.3, 1e-6)
	# A shut-down mech's parts don't tick.
	mech.shutdown_left = 1.0
	engine.process_tick(0.1)
	assert_float(mech.active_parts[0].counters["seconds"]).is_equal_approx(0.3, 1e-6)


func test_the_fights_end_tells_each_side_whether_it_won() -> void:
	var winner := _mech_with(Recorder.new(), 50)
	var loser := _mech_with(Recorder.new())
	var engine := _fight(winner, loser)
	while engine.state == CombatEngine.State.RUNNING:
		engine.process_tick(0.1)
	assert_bool(winner.active_parts[0].part.get_meta("won")).is_true()
	assert_bool(loser.active_parts[0].part.get_meta("won")).is_false()


# A 1x1 part carrying [param ability] on the armed cross, with a gun of [param damage] too.
func _mech_with(ability: PartAbility, damage := 0) -> BattleMech:
	var chassis := Fixtures.armed_cross()
	chassis.base_hp = 100
	var grid := MechGridData.new(chassis)
	var part := Fixtures.part("Recorder", MechPart.PartType.UTILITY, [Vector2i(0, 0)], 0,
		{"abilities": [ability] as Array[PartAbility]})
	assert_bool(grid.place_part(part, Vector2i(1, 1))).is_true()
	if damage > 0:
		var gun := Fixtures.part("Gun", MechPart.PartType.WEAPON, Fixtures.ARM_SHAPE, 0, {"damage": damage, "cooldown_max": 0.5})
		assert_bool(grid.place_part(gun, Vector2i(-1, 1))).is_true()
	return BattleMech.new(grid)


func _dummy(hp: int) -> BattleMech:
	var chassis := Fixtures.cross_chassis()
	chassis.base_hp = hp
	return BattleMech.new(MechGridData.new(chassis))


func _fight(left: BattleMech, right: BattleMech) -> CombatEngine:
	var engine := CombatEngine.new(left, right)
	engine.start()
	return engine
