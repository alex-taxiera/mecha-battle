class_name EvasionPassiveTest
extends GdUnitTestSuite

const __source: String = "res://src/data/passives/EvasionPassive.gd"
const Fixtures := preload("res://test/TestFixtures.gd")


func test_every_fourth_shot_misses() -> void:
	var phantom := BattleMech.new(MechGridData.new(Fixtures.phantom_frame()))
	var taken: Array[int] = []
	for i in 8:
		taken.append(_shoot(phantom, 10))
	assert_array(taken).contains_exactly([10, 10, 10, 0, 10, 10, 10, 0])
	# Positive control: a frame without it takes every shot.
	var plain := BattleMech.new(MechGridData.new(Fixtures.cross_chassis()))
	for i in 4:
		assert_int(_shoot(plain, 10)).is_equal(10)


func test_only_shots_can_miss_and_previews_do_not_count() -> void:
	var phantom := BattleMech.new(MechGridData.new(Fixtures.phantom_frame()))
	for i in 3:
		assert_int(phantom.take_damage(5, HitPipeline.Kind.STORM)).is_equal(5)
		var preview := HitPipeline.Hit.new(HitPipeline.Kind.SHOT, phantom, 10)
		preview.preview = true
		HitPipeline.resolve(preview)
	# None of that counted: the 4th real shot is still three away.
	assert_int(_shoot(phantom, 10)).is_equal(10)
	assert_int(_shoot(phantom, 10)).is_equal(10)
	assert_int(_shoot(phantom, 10)).is_equal(10)
	assert_int(_shoot(phantom, 10)).is_equal(0)


func test_a_missed_shot_is_marked_on_the_weapon() -> void:
	var chassis := Fixtures.armed_cross()
	chassis.base_energy = 0
	var grid := MechGridData.new(chassis)
	var gun := Fixtures.part("Gun", MechPart.PartType.WEAPON, Fixtures.ARM_SHAPE, 0, {"damage": 10, "cooldown_max": 0.1})
	assert_bool(grid.place_part(gun, Vector2i(-1, 1))).is_true()
	var shooter := BattleMech.new(grid)
	shooter.active_parts[0].current_cooldown = 0.0
	var phantom := BattleMech.new(MechGridData.new(Fixtures.phantom_frame()))
	var engine := CombatEngine.new(shooter, phantom)
	engine.start()
	var missed: Array[bool] = []
	for i in 4:
		engine.process_tick(0.1)
		missed.append(shooter.active_parts[0].last_missed)
	assert_array(missed).contains_exactly([false, false, false, true])


func test_the_phase_cloak_makes_it_every_third() -> void:
	var cloak := PassiveTuning.new()
	cloak.key = EvasionPassive.EVERY
	cloak.value = 3
	var phantom := BattleMech.new(MechGridData.new(Fixtures.phantom_frame()), [], 1.0, -1, [cloak] as Array[Relic])
	phantom.start_fight()
	var taken: Array[int] = []
	for i in 6:
		taken.append(_shoot(phantom, 10))
	assert_array(taken).contains_exactly([10, 10, 0, 10, 10, 0])


func _shoot(mech: BattleMech, damage: int) -> int:
	return mech.take_hit(HitPipeline.Hit.new(HitPipeline.Kind.SHOT, mech, damage))
