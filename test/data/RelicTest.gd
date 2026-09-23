class_name RelicTest
extends GdUnitTestSuite
## Each placeholder relic's hook, through the real stats, fight, and run code. Numbers are set on
## each relic here, not read from its .tres, so tuning the content doesn't break these.

const __source: String = "res://src/data/Relic.gd"
const Fixtures := preload("res://test/TestFixtures.gd")
const LEFT_ARM := Vector2i(-1, 1)

var _grid: MechGridData


func before_test() -> void:
	_grid = MechGridData.new(Fixtures.armed_cross()) # 30 HP, 3 energy a turn


func test_a_plain_relic_changes_nothing() -> void:
	var relic := Relic.new()
	assert_bool(_grid.place_part(Fixtures.heatsink(), Vector2i(1, 1))).is_true()
	var plain := MechStats.calculate(_grid, [])
	var with_relic := MechStats.calculate(_grid, [], [relic])
	assert_int(with_relic.hp).is_equal(plain.hp)
	assert_int(with_relic.heat_vented).is_equal(plain.heat_vented)
	var mech := BattleMech.new(_grid, [], 1.0, -1, [relic])
	assert_bool(relic.on_fight_start(mech)).is_false()
	assert_int(relic.modify_gold(10)).is_equal(10)
	assert_int(relic.modify_damage_taken(mech, 7)).is_equal(7)


func test_reinforced_frame_adds_hp() -> void:
	var relic := ReinforcedFrame.new()
	relic.hp = 40
	assert_int(MechStats.calculate(_grid, [], [relic]).hp).is_equal(70)
	assert_int(BattleMech.new(_grid, [], 1.0, -1, [relic]).max_hp).is_equal(70)


func test_capacitor_bank_banks_energy_at_the_start() -> void:
	var relic := CapacitorBank.new()
	relic.energy = 50
	var mech := BattleMech.new(_grid, [], 1.0, -1, [relic])
	var triggered: Array[Relic] = []
	mech.relic_triggered.connect(func(r: Relic) -> void: triggered.append(r))
	var engine := CombatEngine.new(mech, BattleMech.new(MechGridData.new(Fixtures.cross_chassis())))
	assert_int(mech.current_energy).is_equal(0)
	engine.start()
	assert_int(mech.current_energy).is_equal(50)
	assert_array(triggered).contains_same_exactly([relic])


func test_coolant_reserve_vents_more_from_each_heatsink() -> void:
	var relic := CoolantReserve.new()
	relic.cooling = 5
	var heatsink := Fixtures.heatsink()
	heatsink.cooling = 15
	assert_bool(_grid.place_part(heatsink, Vector2i(1, 1))).is_true()
	assert_bool(_grid.place_part(Fixtures.laser(), Vector2i(3, 1))).is_true()
	var stats := MechStats.calculate(_grid, [], [relic])
	assert_int(stats.heat_vented).is_equal(20)
	# Parts that don't vent are left alone.
	var laser := _grid.get_placement_at(Vector2i(3, 1))
	assert_int(stats.part_stats[laser].cooling).is_equal(0)


func test_salvage_drone_rounds_extra_gold_up() -> void:
	var relic := SalvageDrone.new()
	relic.bonus = 0.25
	assert_int(relic.modify_gold(10)).is_equal(13) # 12.5, rounded up
	assert_int(relic.modify_gold(8)).is_equal(10)


func test_field_repair_kit_repairs_after_a_win() -> void:
	var relic := FieldRepairKit.new()
	relic.repair = 20
	var run := RunState.new(Fixtures.armed_cross(), [], [])
	run.add_relic(relic)
	var mech := run.make_player_mech()
	mech.take_damage(25)
	run.record_fight(RunState.FightResult.WIN, mech)
	assert_int(run.hull_damage).is_equal(5)
	# A loss ends the run with the hull wrecked; nothing is repaired.
	var lost := run.make_player_mech()
	lost.take_damage(999)
	run.record_fight(RunState.FightResult.LOSS, lost)
	assert_int(run.hull_damage).is_equal(30)


func test_targeting_uplink_doubles_each_fights_first_shot() -> void:
	var relic := TargetingUplink.new()
	relic.multiplier = 2.0
	var mech := _gunner([relic])
	var gun := mech.active_parts[0] # 8 damage
	mech.start_fight()
	assert_int(mech.get_shot_damage(gun)).is_equal(16)
	assert_int(mech.get_shot_damage(gun)).is_equal(8)
	# The next fight gets another.
	mech.start_fight()
	assert_int(mech.get_shot_damage(gun)).is_equal(16)


func test_heat_converter_hits_harder_while_hot() -> void:
	var relic := HeatConverter.new()
	relic.threshold = 50
	relic.bonus = 0.2
	var mech := _gunner([relic])
	var gun := mech.active_parts[0] # 8 damage
	mech.heat = 50
	assert_int(mech.get_shot_damage(gun)).is_equal(8)
	mech.heat = 51
	assert_int(mech.get_shot_damage(gun)).is_equal(10) # 9.6, rounded


func test_overdrive_core_adds_energy_and_heat() -> void:
	var relic := OverdriveCore.new()
	relic.energy = 20
	relic.heat_per_shot = 5
	assert_bool(_grid.place_part(_gun(), LEFT_ARM)).is_true() # 10 heat a shot in this test
	var stats := MechStats.calculate(_grid, [], [relic])
	assert_int(stats.base_energy).is_equal(23)
	assert_int(stats.energy_generated).is_equal(23)
	assert_int(stats.part_stats[_grid.get_placement_at(LEFT_ARM)].heat).is_equal(15)
	var mech := BattleMech.new(_grid, [], 1.0, -1, [relic])
	assert_int(mech.base_energy).is_equal(23)
	assert_int(mech.active_parts[0].heat).is_equal(15)


func test_titan_plating_adds_hp_and_shrinks_hits() -> void:
	var relic := TitanPlating.new()
	relic.hp = 100
	relic.plating = 3
	var mech := BattleMech.new(_grid, [], 1.0, -1, [relic])
	assert_int(mech.max_hp).is_equal(130)
	assert_int(mech.take_damage(10)).is_equal(7)
	assert_int(mech.take_damage(2)).is_equal(0)
	assert_int(mech.current_health).is_equal(123)
	# On a Bastion it stacks after Thick Plating's 2.
	var bastion := BattleMech.new(MechGridData.new(Fixtures.bastion()), [], 1.0, -1, [relic])
	assert_int(bastion.get_damage_taken(10)).is_equal(5)


func test_war_chest_pays_out_on_pickup() -> void:
	var relic := WarChest.new()
	relic.gold = 100
	relic.bonus = 0.1
	var run := RunState.new(Fixtures.armed_cross(), [], [], 10)
	run.add_relic(relic)
	assert_int(run.gold).is_equal(110)
	assert_int(relic.modify_gold(20)).is_equal(22)


func test_relic_shots_land_in_a_real_fight() -> void:
	var relic := TargetingUplink.new()
	relic.multiplier = 2.0
	var target := BattleMech.new(MechGridData.new(Fixtures.cross_chassis()))
	var engine := CombatEngine.new(_gunner([relic]), target)
	var hits: Array[int] = []
	engine.weapon_fired.connect(func(_a: BattleMech, weapon: ActivePart, _t: BattleMech, damage: int) -> void:
		hits.append(damage)
		assert_int(weapon.last_shot).is_equal(damage)) # no plating on the cross
	engine.start()
	while hits.size() < 2 and engine.elapsed < 10.0:
		engine.process_tick(0.1)
	assert_array(hits).is_equal([16, 8])


# A mech with a gun in its left arm: 8 damage for 3 energy, once a second.
func _gunner(relics: Array[Relic]) -> BattleMech:
	assert_bool(_grid.place_part(_gun(), LEFT_ARM)).is_true()
	return BattleMech.new(_grid, [], 1.0, -1, relics)


func _gun() -> MechPart:
	var gun := Fixtures.gatling()
	gun.cooldown_max = 1.0
	gun.heat = 10
	return gun
