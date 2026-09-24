class_name RoundTwoRelicsTest
extends GdUnitTestSuite
## The second round of relics, each through the real stats, fight, and run code. Numbers are set
## here, not read from the .tres files.

const __source: String = "res://src/data/Relic.gd"
const Fixtures := preload("res://test/TestFixtures.gd")
const LEFT_ARM := Vector2i(-1, 1)


func test_last_stand_hits_harder_when_low() -> void:
	var relic := LastStand.new()
	var mech := _gunner([relic], 20)
	var gun := mech.active_parts[0]
	assert_int(mech.get_shot_damage(gun)).is_equal(20)
	mech.current_health = roundi(mech.max_hp * 0.3)
	assert_int(mech.get_shot_damage(gun)).is_equal(26)


func test_ablative_core_ignores_the_first_hit_each_fight() -> void:
	var relic := AblativeCore.new()
	var mech := _gunner([relic], 1)
	relic.on_fight_start(mech)
	assert_int(mech.take_damage(15)).is_equal(0)
	assert_int(mech.take_damage(15)).is_equal(15)
	# A new fight, a fresh one.
	relic.on_fight_start(mech)
	assert_int(mech.take_damage(15)).is_equal(0)


func test_kinetic_battery_carries_leftover_energy_into_the_next_fight() -> void:
	var relic := KineticBattery.new()
	var first := _gunner([relic], 1)
	first.current_energy = 160
	first.end_fight(true)
	var second := _gunner([relic], 1)
	var triggered := []
	second.relic_triggered.connect(func(shown: Relic) -> void: triggered.append(shown))
	second.start_fight()
	assert_array(triggered).contains_same_exactly([relic])
	assert_int(second.current_energy).is_equal(100)
	# Only once: the fight after starts empty unless it banks more.
	var third := _gunner([relic], 1)
	third.start_fight()
	assert_int(third.current_energy).is_equal(0)


func test_recycler_adds_to_every_sale() -> void:
	var run := _run()
	run.stash_part(Fixtures.heatsink()) # 4 gold, bought earlier: half back
	assert_int(run.stash_sell_value(0)).is_equal(2)
	run.add_relic(_named(SellBonus.new(), "Recycler"))
	assert_int(run.stash_sell_value(0)).is_equal(5)


func test_pyromaniac_feeds_a_burn() -> void:
	var relic := StatusFeeder.new()
	relic.status = Fixtures.burn()
	var target := _dummy()
	var hit := HitPipeline.Hit.new(HitPipeline.Kind.SHOT, target, 1)
	# Positive control: nothing to feed on a target that isn't burning.
	relic.on_hit_dealt(null, hit)
	assert_int(target.get_status_charges("burn")).is_equal(0)
	target.add_status(Fixtures.burn(), 2)
	relic.on_hit_dealt(null, hit)
	assert_int(target.get_status_charges("burn")).is_equal(3)


func test_insulated_wiring_blocks_drained_only() -> void:
	var relic := StatusImmunity.new()
	relic.status_id = "drained"
	var mech := _gunner([relic], 1)
	assert_object(mech.add_status(Fixtures.drained(), 3)).is_null()
	assert_int(mech.get_status_charges("drained")).is_equal(0)
	mech.add_status(Fixtures.burn(), 3)
	assert_int(mech.get_status_charges("burn")).is_equal(3)


func test_black_box_contract_trades_gold_for_energy() -> void:
	var relic := BlackBoxContract.new()
	var grid := MechGridData.new(Fixtures.armed_cross())
	var stats := MechStats.calculate(grid, [], [relic])
	assert_int(stats.base_energy).is_equal(43)
	assert_int(relic.modify_gold(25)).is_equal(0)


func test_weapon_tuning_changes_weapons_and_shops() -> void:
	var payload := WeaponTuning.new()
	payload.damage_scale = 1.25
	payload.cooldown_scale = 1.2
	var grid := MechGridData.new(Fixtures.armed_cross())
	var gun := Fixtures.part("Gun", MechPart.PartType.WEAPON, Fixtures.ARM_SHAPE, 0, {"damage": 20, "cooldown_max": 2.0})
	assert_bool(grid.place_part(gun, LEFT_ARM)).is_true()
	assert_bool(grid.place_part(Fixtures.laser(), Vector2i(1, 1))).is_true()
	var numbers := MechStats.calculate(grid, [], [payload]).part_stats[grid.get_placement_at(LEFT_ARM)]
	assert_int(numbers.damage).is_equal(25)
	assert_float(numbers.cooldown).is_equal_approx(2.4, 1e-6)
	# An auto-loader: one part fewer at each shop.
	var loader := WeaponTuning.new()
	loader.shop_slots = -1
	var run := _run()
	run.add_relic(loader)
	run.open_shop()
	assert_array(run.shop.slots).has_size(ShopStock.SIZE - 1)
	run.reroll()
	assert_array(run.shop.slots).has_size(ShopStock.SIZE - 1)


func test_frame_extender_opens_cells_or_adds_hp() -> void:
	var relic := FrameExtender.new()
	relic.cells = 3
	relic.fallback_hp = 40
	var chassis := Fixtures.armed_cross()
	chassis.size = Vector2i(4, 5)
	chassis.expansion_cells.assign([Vector2i(1, 4), Vector2i(2, 4)])
	var run := RunState.new(chassis, [], [], 10, RunRng.new(1))
	var hp := run.get_max_hp()
	run.add_relic(relic)
	# Room for two; the third becomes 40 max HP.
	assert_int(run.cells_to_open).is_equal(2)
	assert_int(run.get_max_hp()).is_equal(hp + 40)


func test_adaptive_armor_fortifies_with_each_hit() -> void:
	var relic := StatusOnHitTaken.new()
	relic.status = Fixtures.fortified()
	var mech := _gunner([relic], 1)
	mech.take_damage(10)
	assert_int(mech.get_status_charges("fortified")).is_equal(1)
	# The next hit is 2 smaller.
	assert_int(mech.take_damage(10)).is_equal(8)
	# A hit that does nothing gives nothing.
	mech.take_damage(0)
	assert_int(mech.get_status_charges("fortified")).is_equal(2)


func test_membership_chip_makes_the_first_reroll_free() -> void:
	var run := _run()
	run.add_relic(FreeReroll.new())
	run.gold = 5
	run.open_shop()
	assert_int(run.get_reroll_cost()).is_equal(0)
	assert_bool(run.reroll()).is_true()
	assert_int(run.gold).is_equal(5)
	assert_int(run.get_reroll_cost()).is_equal(1)
	assert_bool(run.reroll()).is_true()
	assert_int(run.gold).is_equal(4)
	# A new shop, a new free one.
	run.close_shop()
	run.open_shop()
	assert_int(run.get_reroll_cost()).is_equal(0)


func test_reinforced_bulkheads_toughen_defense_parts() -> void:
	var relic := PartTypeBonus.new()
	relic.part_type = MechPart.PartType.DEFENSE
	relic.hp = 15
	var grid := MechGridData.new(Fixtures.armed_cross())
	assert_bool(grid.place_part(Fixtures.laser(), Vector2i(1, 1))).is_true()
	assert_bool(grid.place_part(Fixtures.heatsink(), Vector2i(1, 2))).is_true()
	var stats := MechStats.calculate(grid, [], [relic])
	assert_int(stats.part_stats[grid.get_placement_at(Vector2i(1, 1))].hp).is_equal(12 + 15)
	assert_int(stats.part_stats[grid.get_placement_at(Vector2i(1, 2))].hp).is_equal(0)


func test_afterburner_readies_overclock_again_at_half_hp() -> void:
	var relic := Afterburner.new()
	var chassis := Fixtures.armed_cross()
	chassis.passive = OverclockPassive.new()
	chassis.base_hp = 100
	var mech := BattleMech.new(MechGridData.new(chassis), [], 1.0, -1, [relic] as Array[Relic])
	mech.start_fight()
	assert_int(chassis.passive.extra_shots(mech, null)).is_equal(1)
	mech.take_damage(40)
	assert_int(chassis.passive.extra_shots(mech, null)).is_equal(0)
	mech.take_damage(15)
	assert_int(chassis.passive.extra_shots(mech, null)).is_equal(1)
	# Once a fight.
	mech.take_damage(10)
	assert_int(chassis.passive.extra_shots(mech, null)).is_equal(0)


func test_containment_field_cuts_each_shutdown_short() -> void:
	var relic := ContainmentField.new()
	relic.shutdown_cut = 1.5
	var mech := _gunner([relic], 1)
	mech.start_fight()
	mech.shutdown_left = 3.0
	mech.tick_relics(0.1)
	assert_float(mech.shutdown_left).is_equal_approx(1.5, 1e-6)
	# Not again while that shutdown runs down.
	mech.shutdown_left = 1.4
	mech.tick_relics(0.1)
	assert_float(mech.shutdown_left).is_equal_approx(1.4, 1e-6)


func test_chassis_relics_only_turn_up_for_their_chassis() -> void:
	var bastion_only := Fixtures.relic("Bulkheads", Relic.Rarity.UNCOMMON)
	bastion_only.chassis_id = "bastion"
	var anyone := Fixtures.relic("Anyone", Relic.Rarity.UNCOMMON)
	var relics: Array[Relic] = [bastion_only, anyone]
	var bastion := Fixtures.bastion()
	bastion.id = "bastion"
	var striker := Fixtures.striker()
	striker.id = "striker"
	assert_bool(RunState.new(bastion, [], [], 10, RunRng.new(1), [], relics).relic_pool.has(bastion_only)).is_true()
	var other := RunState.new(striker, [], [], 10, RunRng.new(1), [], relics)
	assert_bool(other.relic_pool.has(bastion_only)).is_false()
	assert_bool(other.relic_pool.has(anyone)).is_true()


func _gunner(relics: Array, damage: int) -> BattleMech:
	var chassis := Fixtures.armed_cross()
	chassis.base_hp = 100
	chassis.base_energy = 0
	var grid := MechGridData.new(chassis)
	var gun := Fixtures.part("Gun", MechPart.PartType.WEAPON, Fixtures.ARM_SHAPE, 0, {"damage": damage, "cooldown_max": 1.0})
	assert_bool(grid.place_part(gun, LEFT_ARM)).is_true()
	var typed: Array[Relic] = []
	typed.assign(relics)
	return BattleMech.new(grid, [], 1.0, -1, typed)


func _dummy() -> BattleMech:
	return BattleMech.new(MechGridData.new(Fixtures.cross_chassis()))


func _run() -> RunState:
	var run := RunState.new(Fixtures.armed_cross(), [Fixtures.laser(), Fixtures.heatsink(), Fixtures.reactor(),
		Fixtures.gatling(), Fixtures.missile_pod()], [], 10, RunRng.new(1))
	return run


func _named(relic: Relic, relic_name: String) -> Relic:
	relic.id = relic_name.to_snake_case()
	relic.relic_name = relic_name
	return relic
