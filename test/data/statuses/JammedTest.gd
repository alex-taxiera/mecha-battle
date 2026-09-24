class_name JammedTest
extends GdUnitTestSuite

const __source: String = "res://src/data/statuses/Jammed.gd"
const Fixtures := preload("res://test/TestFixtures.gd")


func test_jammed_weapons_count_down_slower() -> void:
	var mech := BattleMech.new(MechGridData.new(Fixtures.cross_chassis()))
	mech.add_status(Fixtures.jammed(), 3)
	assert_float(mech.get_weapon_speed()).is_equal_approx(0.76, 1e-6)
	# It isn't heat: the heat gauge's fire rate stays full, and throttling stacks on top.
	assert_float(mech.get_fire_rate()).is_equal(1.0)
	mech.heat = 100
	assert_float(mech.get_weapon_speed()).is_equal_approx(0.38, 1e-6)
	# At its 6 charges it's capped.
	var stuck := BattleMech.new(MechGridData.new(Fixtures.cross_chassis()))
	stuck.add_status(Fixtures.jammed(), 20)
	assert_float(stuck.get_weapon_speed()).is_equal_approx(0.52, 1e-6)


func test_a_jammed_weapon_fires_later() -> void:
	# Free guns every half second: jammed ×3 at 76% speed fires at 0.7 s, not 0.5 s.
	var jammed := _mech()
	var plain := _mech()
	jammed.add_status(Fixtures.jammed(), 3)
	var engine := CombatEngine.new(jammed, plain)
	engine.start()
	for i in 6:
		engine.process_tick(0.1)
	assert_int(jammed.active_parts[0].shots).is_equal(0)
	assert_int(plain.active_parts[0].shots).is_equal(1)
	engine.process_tick(0.1)
	assert_int(jammed.active_parts[0].shots).is_equal(1)


func _mech() -> BattleMech:
	var chassis := Fixtures.armed_cross()
	chassis.base_energy = 0
	var gun := Fixtures.part("Gun", MechPart.PartType.WEAPON, Fixtures.ARM_SHAPE, 0, {"damage": 1, "cooldown_max": 0.5})
	var grid := MechGridData.new(chassis)
	assert_bool(grid.place_part(gun, Vector2i(-1, 1))).is_true()
	return BattleMech.new(grid)
