class_name MechGaugesTest
extends GdUnitTestSuite

const __source: String = "res://src/ui/combat/MechGauges.gd"
const Fixtures := preload("res://test/TestFixtures.gd")


func test_energy_fills_toward_100_and_shows_the_real_bank() -> void:
	var gauges: MechGauges = auto_free(MechGauges.new())
	var mech := _mech()
	mech.current_energy = 36
	gauges.refresh(mech)
	assert_str(gauges.energy.get_text()).is_equal("36")
	assert_float(gauges.energy.get_fraction()).is_equal_approx(0.36, 1e-6)
	mech.current_energy = 250
	gauges.refresh(mech)
	assert_str(gauges.energy.get_text()).is_equal("250")
	assert_float(gauges.energy.get_fraction()).is_equal(1.0)


func test_heat_reddens_as_it_slows_the_weapons() -> void:
	var gauges: MechGauges = auto_free(MechGauges.new())
	var mech := _mech()
	# The tick marks where throttling starts.
	assert_float(gauges.heat.mark).is_equal(0.5)
	mech.heat = 50
	gauges.refresh(mech)
	assert_that(gauges.heat.fill_color).is_equal(CombatColors.HEAT)
	assert_str(gauges.heat.get_text()).is_equal("50")
	# At 80 the weapons run at 70%: the fill is 60% of the way to red.
	mech.heat = 80
	gauges.refresh(mech)
	assert_that(gauges.heat.fill_color).is_equal(CombatColors.HEAT.lerp(CombatColors.DANGER, 0.6))
	assert_bool(gauges.heat.hot).is_false()
	mech.heat = 100
	gauges.refresh(mech)
	assert_that(gauges.heat.fill_color).is_equal(CombatColors.DANGER)


func test_heat_runs_hot_above_80_or_while_shut_down() -> void:
	var gauges: MechGauges = auto_free(MechGauges.new())
	var mech := _mech()
	mech.heat = 80
	gauges.refresh(mech)
	assert_bool(gauges.heat.hot).is_false()
	assert_that(gauges.heat.tag_color).is_equal(CombatColors.HEAT)
	mech.heat = 81
	gauges.refresh(mech)
	assert_bool(gauges.heat.hot).is_true()
	assert_that(gauges.heat.tag_color).is_equal(CombatColors.DANGER)
	# Shut down, it's cold but hot-tagged, and says so.
	mech.heat = 0
	mech.shutdown_left = 2.0
	gauges.refresh(mech)
	assert_bool(gauges.heat.hot).is_true()
	assert_that(gauges.heat.fill_color).is_equal(CombatColors.HEAT)
	assert_str(gauges.heat.get_text()).is_equal("OFFLINE")


func test_a_hot_gauge_pulses_in_the_tree() -> void:
	var gauges: MechGauges = auto_free(MechGauges.new())
	var mech := _mech()
	mech.heat = 95
	gauges.refresh(mech)
	# Made hot before entering the tree, it starts pulsing on entering.
	add_child(gauges)
	await await_millis(150)
	assert_float(gauges.heat.glow).is_greater(0.0)
	mech.heat = 10
	gauges.refresh(mech)
	assert_bool(gauges.heat.hot).is_false()
	assert_float(gauges.heat.glow).is_equal(0.0)


func test_gauges_glide_to_each_new_value() -> void:
	var gauges: MechGauges = auto_free(MechGauges.new())
	add_child(gauges)
	gauges.smoothing = 0.2
	var mech := _mech()
	mech.current_energy = 40
	gauges.refresh(mech)
	# Heading for 40 at once; the fill and the number drawn count up to it.
	assert_str(gauges.energy.get_text()).is_equal("40")
	assert_float(gauges.energy.shown).is_less(40.0)
	await await_millis(300)
	assert_float(gauges.energy.shown).is_equal_approx(40.0, 1e-3)
	assert_float(gauges.heat.smoothing).is_equal(0.2)


func _mech() -> BattleMech:
	return BattleMech.new(MechGridData.new(Fixtures.cross_chassis()))

