class_name ChassisPassiveTest
extends GdUnitTestSuite

const __source: String = "res://src/data/ChassisPassive.gd"
const Fixtures := preload("res://test/TestFixtures.gd")


# A passive using every hook: it counts its fight starts and ticks in the mech's passive state,
# fires every shot a second time, speeds weapons up by half, and turns away every storm strike.
class Everything:
	extends ChassisPassive

	func make_interceptors(_mech: BattleMech) -> Array[HitInterceptor]:
		return [StormShield.new()]

	func on_fight_start(mech: BattleMech) -> void:
		mech.passive_state["starts"] = mech.passive_state.get("starts", 0) + 1

	func on_tick(mech: BattleMech, delta: float) -> void:
		mech.passive_state["seconds"] = mech.passive_state.get("seconds", 0.0) + delta

	func extra_shots(_mech: BattleMech, _weapon: ActivePart) -> int:
		return 1

	func modify_weapon_speed(_mech: BattleMech, speed: float) -> float:
		return speed * 1.5


class StormShield:
	extends HitInterceptor

	func _init() -> void:
		side = Side.TARGET

	func intercept(hit: HitPipeline.Hit) -> Result:
		return Result.REJECTED if hit.kind == HitPipeline.Kind.STORM else Result.CONTINUE


func test_a_frame_without_a_passive_does_nothing_extra() -> void:
	var mech := _armed(null)
	assert_float(mech.get_weapon_speed()).is_equal(1.0)
	assert_int(mech.get_damage_taken(10)).is_equal(10)
	var engine := _fight(mech)
	engine.process_tick(0.1)
	assert_int(mech.active_parts[0].shots).is_equal(1)


func test_a_passive_hooks_into_the_fight() -> void:
	var mech := _armed(Everything.new())
	assert_float(mech.get_weapon_speed()).is_equal(1.5)
	var engine := _fight(mech)
	assert_int(mech.passive_state["starts"]).is_equal(1)
	engine.process_tick(0.1)
	engine.process_tick(0.1)
	assert_float(mech.passive_state["seconds"]).is_equal_approx(0.2, 1e-6)
	# Every paid shot is followed by a free one.
	assert_int(mech.active_parts[0].shots).is_equal(2)
	# Its interceptor turns away the storm, and only the storm.
	var storm := HitPipeline.Hit.new(HitPipeline.Kind.STORM, mech, 10)
	assert_int(mech.take_hit(storm)).is_equal(0)
	assert_int(mech.get_damage_taken(10)).is_equal(10)


func test_two_mechs_on_one_frame_keep_their_own_state() -> void:
	var chassis := Fixtures.armed_cross()
	chassis.passive = OverclockPassive.new()
	var first := BattleMech.new(MechGridData.new(chassis))
	var second := BattleMech.new(MechGridData.new(chassis))
	assert_int(chassis.passive.extra_shots(first, null)).is_equal(1)
	assert_int(chassis.passive.extra_shots(first, null)).is_equal(0)
	# The second mech's Overclock is still unspent.
	assert_int(chassis.passive.extra_shots(second, null)).is_equal(1)


# The armed cross with a free gun in its left arm that fires on the first tick, on [param passive].
func _armed(passive: ChassisPassive) -> BattleMech:
	var chassis := Fixtures.armed_cross()
	chassis.passive = passive
	var grid := MechGridData.new(chassis)
	var gun := Fixtures.part("Gun", MechPart.PartType.WEAPON, Fixtures.ARM_SHAPE, 0, {"damage": 1, "cooldown_max": 10.0})
	assert_bool(grid.place_part(gun, Vector2i(-1, 1))).is_true()
	var mech := BattleMech.new(grid)
	mech.active_parts[0].current_cooldown = 0.0
	return mech


func _fight(mech: BattleMech) -> CombatEngine:
	var dummy := Fixtures.cross_chassis()
	dummy.base_hp = 1000
	var engine := CombatEngine.new(mech, BattleMech.new(MechGridData.new(dummy)))
	engine.start()
	return engine
