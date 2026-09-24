class_name BossPhaseTest
extends GdUnitTestSuite

const __source: String = "res://src/data/BossPhase.gd"
const Fixtures := preload("res://test/TestFixtures.gd")

const LEFT_ARM := Vector2i(-1, 1)


func test_a_phase_comes_once_at_its_threshold() -> void:
	var boss := _boss([Fixtures.boss_phase("Scrap Armor", 0.5, {"shield_share": 0.3})])
	# Above half: nothing yet.
	boss.current_health = 51
	assert_array(boss.check_phases()).is_empty()
	assert_int(boss.shield).is_equal(0)
	boss.current_health = 50
	var entered := boss.check_phases()
	assert_array(entered).has_size(1)
	assert_int(boss.shield).is_equal(30)
	# Only once.
	boss.current_health = 20
	assert_array(boss.check_phases()).is_empty()
	assert_int(boss.shield).is_equal(30)


func test_a_phase_changes_heat_and_weapons() -> void:
	var gun := _gun(10, 1.0)
	var boss := _boss([Fixtures.boss_phase("Overload", 0.5, {"heat": 90, "cooldown_scale": 0.7, "damage_scale": 1.5,
		"relics": [Fixtures.armored()] as Array[Relic]})], [[gun, LEFT_ARM]])
	boss.current_health = 40
	boss.check_phases()
	assert_int(boss.heat).is_equal(90)
	var active := boss.active_parts[0]
	assert_float(active.cooldown_max).is_equal_approx(0.7, 1e-6)
	assert_float(active.current_cooldown).is_equal_approx(0.7, 1e-6)
	assert_int(active.damage).is_equal(15)
	# The phase's relic acts on hits from now on.
	assert_int(boss.take_damage(10)).is_equal(7)


func test_a_revive_brings_the_boss_back_once() -> void:
	var boss := _boss([Fixtures.boss_phase("Last Protocol", 0.0, {"revive": true, "heal_share": 0.3})])
	var killer := _attacker(200)
	var engine := CombatEngine.new(killer, boss)
	var phases := []
	engine.phase_changed.connect(func(mech: BattleMech, phase: BossPhase) -> void: phases.append([mech, phase.title]))
	var endings := []
	engine.battle_ended.connect(func(winner: BattleMech) -> void: endings.append(winner))
	engine.start()
	# The first 200-damage shot at 0.5 s would finish the boss: it's back at 30 HP instead.
	for i in 5:
		engine.process_tick(0.1)
	assert_int(boss.current_health).is_equal(30)
	assert_array(phases).contains_exactly([[boss, "Last Protocol"]])
	assert_int(engine.state).is_equal(CombatEngine.State.RUNNING)
	# The second one finishes it.
	for i in 5:
		engine.process_tick(0.1)
	assert_int(boss.current_health).is_equal(0)
	assert_array(endings).contains_exactly([killer])


func test_a_threshold_phase_does_not_save_a_boss_that_goes_down() -> void:
	var boss := _boss([Fixtures.boss_phase("Scrap Armor", 0.5, {"shield_share": 0.3})])
	boss.current_health = 0
	assert_array(boss.check_phases()).is_empty()


func test_a_threshold_bonus_brings_phases_sooner() -> void:
	var boss := _boss([Fixtures.boss_phase("Scrap Armor", 0.5, {"shield_share": 0.3})])
	boss.phase_threshold_bonus = 0.16
	boss.current_health = 66
	assert_array(boss.check_phases()).has_size(1)


# A free arm gun hitting for [param damage] every [param seconds].
func _gun(damage: int, seconds: float) -> MechPart:
	return Fixtures.part("Gun", MechPart.PartType.WEAPON, Fixtures.ARM_SHAPE, 0, {"damage": damage, "cooldown_max": seconds})


# A 100 HP boss with [param phases] and each [part, origin] placed.
func _boss(phases: Array[BossPhase], placements := []) -> BattleMech:
	var chassis := Fixtures.armed_cross()
	chassis.base_hp = 100
	chassis.base_energy = 0
	var grid := MechGridData.new(chassis)
	for entry in placements:
		assert_bool(grid.place_part(entry[0], entry[1])).is_true()
	var mech := BattleMech.new(grid)
	mech.phases.assign(phases)
	return mech


# A mech with a free gun hitting for [param damage] every half second.
func _attacker(damage: int) -> BattleMech:
	var chassis := Fixtures.armed_cross()
	chassis.base_hp = 1000
	chassis.base_energy = 0
	var grid := MechGridData.new(chassis)
	assert_bool(grid.place_part(_gun(damage, 0.5), LEFT_ARM)).is_true()
	return BattleMech.new(grid)
