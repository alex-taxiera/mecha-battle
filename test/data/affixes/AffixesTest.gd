class_name AffixesTest
extends GdUnitTestSuite
## The elite affixes, each on a mech the way an enemy carries them: as relics.

const __source: String = "res://src/data/affixes/Shielded.gd"
const Fixtures := preload("res://test/TestFixtures.gd")

const LEFT_ARM := Vector2i(-1, 1)


func test_shielded_starts_with_a_quarter_of_max_hp_as_shield() -> void:
	var mech := _mech([], [Fixtures.shielded()], 100)
	assert_int(mech.shield).is_equal(0)
	mech.start_fight()
	assert_int(mech.shield).is_equal(25)
	assert_int(mech.max_shield).is_equal(25)


func test_rapid_fire_shortens_weapon_cooldowns() -> void:
	var gun := _gun(10, 1.0)
	var mech := _mech([[gun, LEFT_ARM]], [Fixtures.rapid_fire()])
	assert_float(_active_for(mech, gun).cooldown_max).is_equal_approx(0.85, 1e-6)
	# Positive control: without it, the part's own.
	var plain := _gun(10, 1.0)
	assert_float(_active_for(_mech([[plain, LEFT_ARM]], []), plain).cooldown_max).is_equal(1.0)


func test_reflective_answers_heavy_shots() -> void:
	var attacker := _mech([[_gun(30, 0.5), LEFT_ARM]], [], 100)
	var target := _mech([], [Fixtures.reflective()], 200)
	_run(attacker, target, 5)
	assert_int(attacker.current_health).is_equal(100 - 15)
	# A lighter shot doesn't set it off.
	var light := _mech([[_gun(29, 0.5), LEFT_ARM]], [], 100)
	_run(light, _mech([], [Fixtures.reflective()], 200), 5)
	assert_int(light.current_health).is_equal(100)


func test_regenerating_repairs_a_share_a_second() -> void:
	var regen := Fixtures.regenerating()
	regen.heal_share = 0.1
	var mech := _mech([], [regen], 100)
	mech.current_health = 50
	for i in 10:
		mech.tick_relics(0.1)
	assert_int(mech.current_health).is_equal(60)
	# Never past full, and not once it's down.
	for i in 100:
		mech.tick_relics(0.1)
	assert_int(mech.current_health).is_equal(100)
	mech.current_health = 0
	mech.tick_relics(1.0)
	assert_int(mech.current_health).is_equal(0)


func test_unstable_hits_harder_and_hotter() -> void:
	var gun := _gun(10, 1.0)
	gun.heat = 5
	var mech := _mech([[gun, LEFT_ARM]], [Fixtures.unstable()])
	assert_int(_active_for(mech, gun).damage).is_equal(12)
	assert_int(_active_for(mech, gun).heat).is_equal(15)


func test_armored_takes_3_off_every_hit() -> void:
	var mech := _mech([], [Fixtures.armored()], 100)
	assert_int(mech.take_damage(10)).is_equal(7)
	assert_int(mech.take_damage(2)).is_equal(0)


func test_burning_shots_leave_burn() -> void:
	var attacker := _mech([[_gun(1, 0.5), LEFT_ARM]], [Fixtures.burning()], 100)
	var target := _mech([], [], 200)
	_run(attacker, target, 5)
	assert_int(target.get_status_charges("burn")).is_equal(1)
	# Positive control: the same gun without the affix leaves nothing.
	var clean := _mech([], [], 200)
	_run(_mech([[_gun(1, 0.5), LEFT_ARM]], [], 100), clean, 5)
	assert_int(clean.get_status_charges("burn")).is_equal(0)


# A free arm gun hitting for [param damage] every [param seconds].
func _gun(damage: int, seconds: float) -> MechPart:
	return Fixtures.part("Gun", MechPart.PartType.WEAPON, Fixtures.ARM_SHAPE, 0, {"damage": damage, "cooldown_max": seconds})


func _mech(placements: Array, affixes: Array[Relic], hp := 30) -> BattleMech:
	var chassis := Fixtures.armed_cross()
	chassis.base_hp = hp
	chassis.base_energy = 0
	var grid := MechGridData.new(chassis)
	for entry in placements:
		assert_bool(grid.place_part(entry[0], entry[1])).is_true()
	return BattleMech.new(grid, [], 1.0, -1, affixes)


func _run(left: BattleMech, right: BattleMech, ticks: int) -> void:
	var engine := CombatEngine.new(left, right)
	engine.start()
	for i in ticks:
		engine.process_tick(0.1)


func _active_for(mech: BattleMech, part: MechPart) -> ActivePart:
	for active in mech.active_parts:
		if active.part == part:
			return active
	return null


func test_ablative_ignores_the_first_hit_each_fight() -> void:
	var affix := Fixtures.ablative_affix()
	var mech := _mech([], [affix], 100)
	mech.start_fight()
	assert_int(mech.take_damage(20)).is_equal(0)
	assert_int(mech.take_damage(20)).is_equal(20)


func test_hardened_firmware_shrugs_off_the_first_debuff() -> void:
	var mech := _mech([], [Fixtures.hardened_firmware()], 100)
	mech.start_fight()
	# Buffs aren't blocked and don't use it up.
	mech.add_status(Fixtures.haste(), 2)
	assert_int(mech.get_status_charges("haste")).is_equal(2)
	assert_object(mech.add_status(Fixtures.burn(), 3)).is_null()
	assert_int(mech.get_status_charges("burn")).is_equal(0)
	mech.add_status(Fixtures.burn(), 3)
	assert_int(mech.get_status_charges("burn")).is_equal(3)


func test_vampiric_repairs_a_fifth_of_each_landed_shot() -> void:
	var attacker := _mech([[_gun(10, 0.5), LEFT_ARM]], [Fixtures.vampiric()], 100)
	attacker.current_health = 50
	var target := _mech([], [], 200)
	_run(attacker, target, 5)
	assert_int(target.current_health).is_equal(190)
	assert_int(attacker.current_health).is_equal(52)


func test_jamming_shots_leave_jammed() -> void:
	var attacker := _mech([[_gun(1, 0.5), LEFT_ARM]], [Fixtures.jamming()], 100)
	var target := _mech([], [], 200)
	_run(attacker, target, 5)
	assert_int(target.get_status_charges("jammed")).is_equal(1)
