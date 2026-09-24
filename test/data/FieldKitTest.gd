class_name FieldKitTest
extends GdUnitTestSuite
## Field kits: what each does, when they fire, using them in a fight, and carrying them in a run.

const __source: String = "res://src/data/FieldKit.gd"
const Fixtures := preload("res://test/TestFixtures.gd")
const LEFT_ARM := Vector2i(-1, 1)


func test_each_kit_does_its_job() -> void:
	var mech := _mech(100)
	var enemy := _mech(200)
	mech.current_health = 40
	Fixtures.emergency_patch().apply(mech, enemy)
	assert_int(mech.current_health).is_equal(65)
	mech.heat = 95
	Fixtures.coolant_flush().apply(mech, enemy)
	assert_int(mech.heat).is_equal(25)
	Fixtures.shield_cell().apply(mech, enemy)
	assert_int(mech.shield).is_equal(100)
	assert_int(mech.max_shield).is_equal(100)
	Fixtures.micro_missile().apply(mech, enemy)
	assert_int(enemy.current_health).is_equal(140)
	assert_int(mech.damage_dealt).is_equal(60)
	Fixtures.foam_armor().apply(mech, enemy)
	assert_int(mech.get_status_charges("fortified")).is_equal(6)
	mech.current_health = 0
	Fixtures.reboot_protocol().apply(mech, enemy)
	assert_int(mech.current_health).is_equal(20)


func test_a_strike_goes_through_the_enemys_plating() -> void:
	var bastion := BattleMech.new(MechGridData.new(Fixtures.bastion()))
	Fixtures.micro_missile().apply(_mech(100), bastion)
	assert_int(bastion.current_health).is_equal(bastion.max_hp - 58)


func test_auto_kits_know_when_they_are_due() -> void:
	var mech := _mech(100)
	var patch := Fixtures.emergency_patch()
	var flush := Fixtures.coolant_flush()
	var reboot := Fixtures.reboot_protocol()
	assert_bool(patch.is_due(mech)).is_false()
	assert_bool(flush.is_due(mech)).is_false()
	assert_bool(reboot.is_due(mech)).is_false()
	mech.current_health = 25
	mech.heat = 90
	assert_bool(patch.is_due(mech)).is_true()
	assert_bool(flush.is_due(mech)).is_true()
	# Down: only the revive is due.
	mech.current_health = 0
	assert_bool(patch.is_due(mech)).is_false()
	assert_bool(reboot.is_due(mech)).is_true()
	assert_str(patch.describe_trigger()).is_equal("Auto: at 25% HP")
	assert_str(flush.describe_trigger()).is_equal("Auto: at 90 heat")
	assert_str(reboot.describe_trigger()).is_equal("Auto: when the mech would go down")
	assert_str(Fixtures.micro_missile().describe_trigger()).is_equal("Use in a fight · 20 EN")
	assert_str(Fixtures.foam_armor().describe_trigger()).is_equal("At the start of the next fight")


func test_a_manual_kit_is_used_once_and_paid_for() -> void:
	var mech := _mech(100, [Fixtures.micro_missile()])
	var enemy := _mech(200)
	var engine := _fight(mech, enemy)
	var used := []
	engine.kit_used.connect(func(_mech: BattleMech, kit: FieldKit) -> void: used.append(kit.id))
	# Not enough energy yet.
	mech.current_energy = 19
	assert_bool(engine.use_kit(mech, 0)).is_false()
	assert_int(enemy.current_health).is_equal(200)
	mech.current_energy = 25
	assert_bool(engine.use_kit(mech, 0)).is_true()
	assert_int(mech.current_energy).is_equal(5)
	assert_int(enemy.current_health).is_equal(140)
	assert_array(used).contains_exactly(["micro_missile"])
	# Once.
	mech.current_energy = 100
	assert_bool(engine.use_kit(mech, 0)).is_false()
	assert_bool(engine.use_kit(mech, 5)).is_false()


func test_only_manual_kits_are_pressed_and_not_while_shut_down() -> void:
	var mech := _mech(100, [Fixtures.emergency_patch(), Fixtures.shield_cell()])
	var engine := _fight(mech, _mech(200))
	mech.current_energy = 100
	assert_bool(engine.use_kit(mech, 0)).is_false()
	mech.shutdown_left = 2.0
	assert_bool(engine.use_kit(mech, 1)).is_false()
	mech.shutdown_left = 0.0
	assert_bool(engine.use_kit(mech, 1)).is_true()


func test_a_kit_that_finishes_the_enemy_ends_the_fight_at_once() -> void:
	var mech := _mech(100, [Fixtures.micro_missile()])
	var enemy := _mech(50)
	var engine := _fight(mech, enemy)
	var winner := []
	engine.battle_ended.connect(func(who: BattleMech) -> void: winner.append(who))
	mech.current_energy = 20
	assert_bool(engine.use_kit(mech, 0)).is_true()
	assert_int(engine.state).is_equal(CombatEngine.State.FINISHED)
	assert_array(winner).contains_same_exactly([mech])
	assert_bool(engine.use_kit(mech, 0)).is_false()


func test_an_auto_kit_fires_once_when_due() -> void:
	var mech := _mech(100, [Fixtures.emergency_patch()])
	var engine := _fight(mech, _mech(200))
	mech.current_health = 30
	engine.process_tick(0.1)
	assert_int(mech.current_health).is_equal(30)
	mech.current_health = 20
	engine.process_tick(0.1)
	assert_int(mech.current_health).is_equal(45)
	mech.current_health = 10
	engine.process_tick(0.1)
	assert_int(mech.current_health).is_equal(10)


func test_a_reboot_catches_the_mech_once() -> void:
	var mech := _mech(100, [Fixtures.reboot_protocol()])
	var engine := _fight(mech, _mech(200))
	mech.current_health = 0
	engine.process_tick(0.1)
	assert_int(engine.state).is_equal(CombatEngine.State.RUNNING)
	assert_int(mech.current_health).is_equal(20)
	mech.current_health = 0
	engine.process_tick(0.1)
	assert_int(engine.state).is_equal(CombatEngine.State.FINISHED)
	# Positive control: without it, the first fall ends the fight.
	var plain := _mech(100)
	var ended := _fight(plain, _mech(200))
	plain.current_health = 0
	ended.process_tick(0.1)
	assert_int(ended.state).is_equal(CombatEngine.State.FINISHED)


func test_a_fight_start_kit_acts_as_the_fight_begins() -> void:
	var mech := _mech(100, [Fixtures.foam_armor()])
	_fight(mech, _mech(200))
	assert_int(mech.get_status_charges("fortified")).is_equal(6)
	assert_array(mech.kits_used).contains_exactly([0])


func test_a_run_carries_up_to_three_kits_and_spends_used_ones() -> void:
	var run := _run()
	assert_bool(run.add_kit(Fixtures.micro_missile())).is_true()
	assert_bool(run.add_kit(Fixtures.shield_cell())).is_true()
	assert_bool(run.add_kit(Fixtures.foam_armor())).is_true()
	assert_bool(run.has_kit_room()).is_false()
	assert_bool(run.add_kit(Fixtures.emergency_patch())).is_false()
	assert_array(run.kits).has_size(3)
	# The fight gets them; the ones it used are gone after.
	var mech := run.make_player_mech()
	assert_array(mech.kits).has_size(3)
	mech.kits_used.assign([0, 2])
	run.record_fight(RunState.FightResult.WIN, mech)
	assert_array(run.kits.map(func(kit: FieldKit) -> String: return kit.id)).contains_exactly(["shield_cell"])
	assert_bool(run.discard_kit(0)).is_true()
	assert_array(run.kits).is_empty()
	assert_bool(run.discard_kit(0)).is_false()


func test_a_shop_sells_kits_while_there_is_room() -> void:
	var run := _run()
	run.kit_pool.assign([Fixtures.micro_missile(), Fixtures.shield_cell(), Fixtures.foam_armor()])
	run.gold = 100
	run.open_shop()
	assert_array(run.shop.kit_offers).has_size(RunState.SHOP_KITS)
	var offer: ShopStock.KitOffer = run.shop.kit_offers[0]
	assert_int(offer.price).is_equal(offer.kit.price)
	assert_bool(run.buy_kit(0)).is_true()
	assert_int(run.gold).is_equal(100 - offer.price)
	assert_array(run.kits).contains_same_exactly([offer.kit])
	assert_bool(run.buy_kit(0)).is_false()
	# No room, no sale.
	run.add_kit(Fixtures.emergency_patch())
	run.add_kit(Fixtures.emergency_patch())
	assert_bool(run.buy_kit(1)).is_false()


func test_fights_sometimes_drop_a_kit_and_bosses_never() -> void:
	var run := _run()
	run.kit_pool.assign([Fixtures.micro_missile()])
	var drops := {EnemyLoadout.Tier.NORMAL: 0, EnemyLoadout.Tier.ELITE: 0, EnemyLoadout.Tier.BOSS: 0}
	for type: MapNode.Type in [MapNode.Type.BATTLE, MapNode.Type.ELITE, MapNode.Type.BOSS]:
		var node := MapNode.new(1, 0, type)
		for i in 60:
			var reward := run.roll_reward(node)
			if reward.kit:
				drops[reward.tier] += 1
	assert_int(drops[EnemyLoadout.Tier.NORMAL]).is_greater(0).is_less(30)
	assert_int(drops[EnemyLoadout.Tier.ELITE]).is_greater(drops[EnemyLoadout.Tier.NORMAL])
	assert_int(drops[EnemyLoadout.Tier.BOSS]).is_equal(0)
	# Without a pool, nothing drops.
	var bare := _run()
	for i in 30:
		assert_object(bare.roll_reward(MapNode.new(1, 0, MapNode.Type.ELITE)).kit).is_null()


func test_a_reward_kit_takes_a_free_slot() -> void:
	var run := _run()
	var reward := FightReward.new()
	reward.kit = Fixtures.shield_cell()
	assert_bool(run.take_reward_kit(reward)).is_true()
	assert_bool(run.take_reward_kit(reward)).is_false()
	assert_array(run.kits).has_size(1)


func test_an_event_can_give_a_kit() -> void:
	var run := _run()
	run.kit_pool.assign([Fixtures.foam_armor()])
	var effect := KitEffect.new()
	assert_str(effect.describe(run)).is_equal("Get a random field kit.")
	var result := EventResult.new()
	effect.apply(run, result)
	assert_array(result.lines).contains_exactly(["Got a Foam Armor"])
	effect.kit = Fixtures.shield_cell()
	effect.apply(run, result)
	effect.apply(run, result)
	var full := EventResult.new()
	effect.apply(run, full)
	assert_array(full.lines).contains_exactly(["No room for the Shield Cell: every kit slot is full"])


func _mech(hp: int, kits: Array = []) -> BattleMech:
	var chassis := Fixtures.cross_chassis()
	chassis.base_hp = hp
	chassis.base_energy = 0
	var mech := BattleMech.new(MechGridData.new(chassis))
	mech.kits.assign(kits)
	return mech


func _fight(left: BattleMech, right: BattleMech) -> CombatEngine:
	var engine := CombatEngine.new(left, right)
	engine.start()
	return engine


func _run() -> RunState:
	var acts: Array[ActData] = [Fixtures.act()]
	return RunState.new(Fixtures.armed_cross(), [Fixtures.laser()], [], 10, RunRng.new(2), acts, Fixtures.relics())
