class_name MomentumPassiveTest
extends GdUnitTestSuite

const __source: String = "res://src/data/passives/MomentumPassive.gd"
const Fixtures := preload("res://test/TestFixtures.gd")


func test_weapons_speed_up_as_the_fight_goes_on() -> void:
	var mech := BattleMech.new(MechGridData.new(Fixtures.juggernaut_frame()))
	mech.start_fight()
	assert_float(mech.get_weapon_speed()).is_equal(1.0)
	for i in 100:
		mech.tick_relics(0.1)
	# 10 seconds: 20% faster.
	assert_float(mech.get_weapon_speed()).is_equal_approx(1.2, 1e-6)
	# Throttling still applies on top: at full heat, half of that.
	mech.heat = 100
	assert_float(mech.get_weapon_speed()).is_equal_approx(0.6, 1e-6)
	mech.heat = 0
	# Capped at 30%, reached at 15 s.
	for i in 300:
		mech.tick_relics(0.1)
	assert_float(mech.get_weapon_speed()).is_equal_approx(1.3, 1e-6)


func test_each_fight_starts_from_standstill() -> void:
	var chassis := Fixtures.juggernaut_frame()
	var first := BattleMech.new(MechGridData.new(chassis))
	for i in 50:
		first.tick_relics(0.1)
	var second := BattleMech.new(MechGridData.new(chassis))
	assert_float(second.get_weapon_speed()).is_equal(1.0)


func test_the_inertial_core_doubles_the_build_up() -> void:
	var core := PassiveTuning.new()
	core.key = MomentumPassive.RATE
	core.value = 2.0
	var mech := BattleMech.new(MechGridData.new(Fixtures.juggernaut_frame()), [], 1.0, -1, [core] as Array[Relic])
	mech.start_fight()
	# 5 seconds at twice the rate: 20%.
	for i in 50:
		mech.tick_relics(0.1)
	assert_float(mech.get_weapon_speed()).is_equal_approx(1.2, 1e-6)
