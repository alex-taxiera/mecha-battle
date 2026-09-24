class_name RunModifierTest
extends GdUnitTestSuite

const __source: String = "res://src/data/RunModifier.gd"
const Fixtures := preload("res://test/TestFixtures.gd")
const LEFT_ARM := Vector2i(-1, 1)


func test_threat_stacks_the_levels_up_to_the_one_chosen() -> void:
	var levels := Fixtures.threat_levels()
	levels.reverse() # the order given doesn't matter
	var stack := RunModifier.threat_stack(levels, 3)
	assert_array(stack.map(func(level: RunModifier) -> int: return level.threat_level)).contains_exactly([1, 2, 3])
	assert_array(RunModifier.threat_stack(levels, 0)).is_empty()
	assert_array(RunModifier.threat_stack(levels, 1)).has_size(1)
	assert_array(RunModifier.threat_stack(levels, 8)).has_size(8)
	# Custom modes (level 0) are never part of a stack.
	levels.append(Fixtures.glass_cannon())
	assert_array(RunModifier.threat_stack(levels, 8)).has_size(8)


func test_turning_a_mode_on_turns_off_the_ones_it_excludes() -> void:
	var glass := Fixtures.glass_cannon()
	var endless := Fixtures.endless()
	var sturdy := Fixtures.run_modifier("sturdy", {"is_custom": true, "exclusive_with": ["glass_cannon"] as Array[String]})
	# Positive control: modes that don't exclude each other are both on.
	var on := RunModifier.toggle([], glass, true)
	on = RunModifier.toggle(on, endless, true)
	assert_array(on).contains_same_exactly_in_any_order([glass, endless]).has_size(2)
	# Sturdy excludes Glass Cannon: turning it on turns Glass Cannon off...
	on = RunModifier.toggle(on, sturdy, true)
	assert_array(on).contains_same_exactly_in_any_order([endless, sturdy]).has_size(2)
	# ...and the other way round, though only Sturdy names the pair.
	on = RunModifier.toggle(on, glass, true)
	assert_array(on).contains_same_exactly_in_any_order([endless, glass]).has_size(2)
	on = RunModifier.toggle(on, endless, false)
	assert_array(on).contains_same_exactly([glass])
	# Turning one on twice keeps one.
	assert_array(RunModifier.toggle(on, glass, true)).has_size(1)


func test_a_run_without_modifiers_is_threat_zero() -> void:
	var run := _run([])
	assert_int(run.get_threat()).is_equal(0)
	assert_float(run.get_mod_product(&"shop_price_scale")).is_equal(1.0)
	assert_float(run.get_mod_sum(&"repair_share_add")).is_equal(0.0)
	assert_int(_run(RunModifier.threat_stack(Fixtures.threat_levels(), 3)).get_threat()).is_equal(3)


func test_threat_1_gives_enemies_a_tenth_more_hp() -> void:
	var run := _run([_level(1)])
	# The fixture enemies are the bare 30 HP cross.
	assert_int(run.make_enemy_mech(_first(run, MapNode.Type.BATTLE)).max_hp).is_equal(33)
	var control := _run([])
	assert_int(control.make_enemy_mech(_first(control, MapNode.Type.BATTLE)).max_hp).is_equal(30)


func test_threat_2_raises_shop_prices() -> void:
	var part := Fixtures.part("Pricey", MechPart.PartType.DEFENSE, [Vector2i(0, 0)], 20, {"hp": 1})
	var run := _run([_level(2)], [part])
	run.gold = 22
	run.open_shop()
	assert_int(run.price_of(part)).is_equal(23)
	assert_bool(run.can_afford(part)).append_failure_message("23g with 22 gold").is_false()
	assert_bool(run.buy_to_stash(0)).is_false()
	run.gold = 23
	assert_bool(run.buy_to_stash(0)).is_true()
	assert_int(run.gold).is_equal(0)
	# Sold back at the same shop, it refunds what was paid.
	assert_int(run.stash_sell_value(0)).is_equal(23)
	var control := _run([], [part])
	assert_int(control.price_of(part)).is_equal(20)


func test_threat_2_costs_at_least_a_gold_more_on_cheap_parts() -> void:
	var run := _run([_level(2)])
	# 2 * 1.15 = 2.3 and 3 * 1.15 = 3.45: rounded to nearest, they'd cost the same as ever.
	assert_int(run.price_of(Fixtures.laser())).is_equal(3)
	assert_int(run.price_of(Fixtures.reactor())).is_equal(4)
	assert_int(run.price_of(Fixtures.gatling())).is_equal(5)
	var control := _run([])
	assert_int(control.price_of(Fixtures.laser())).is_equal(2)
	assert_int(control.price_of(Fixtures.reactor())).is_equal(3)


func test_threat_2_raises_relic_prices_too() -> void:
	var run := _run([_level(2)], [], Fixtures.relics())
	var control := _run([], [], Fixtures.relics())
	run.open_shop()
	control.open_shop()
	assert_array(run.shop.relic_offers).is_not_empty()
	for i in control.shop.relic_offers.size():
		assert_int(run.shop.relic_offers[i].price).is_equal(ceili(control.shop.relic_offers[i].price * 1.15 - 0.001))


func test_threat_3_cuts_normal_battles_gold() -> void:
	var run := _run([_level(3)])
	var control := _run([])
	var battle := run.roll_reward(_first(run, MapNode.Type.BATTLE)).gold
	var control_battle := control.roll_reward(_first(control, MapNode.Type.BATTLE)).gold
	assert_int(control_battle).is_greater(0)
	assert_int(battle).is_equal(roundi(control_battle * 0.75))
	# Elites pay the same.
	assert_int(run.roll_reward(_first(run, MapNode.Type.ELITE)).gold) \
		.is_equal(control.roll_reward(_first(control, MapNode.Type.ELITE)).gold)


func test_threat_4_gives_elites_another_affix() -> void:
	var run := _run([_level(4)], [], [], _affixes())
	var control := _run([], [], [], _affixes())
	assert_array(_first(run, MapNode.Type.ELITE).affixes).has_size(2)
	assert_array(_first(control, MapNode.Type.ELITE).affixes).has_size(1)


func test_threat_5_repairs_less() -> void:
	var run := _run([_level(5)])
	assert_float(run.get_repair_share(0.3)).is_equal_approx(0.2, 0.0001)
	assert_float(_run([]).get_repair_share(0.3)).is_equal_approx(0.3, 0.0001)
	# However far it's cut, a repair still mends a little.
	var harsh := _run([Fixtures.run_modifier("harsh", {"repair_share_add": -0.5})])
	assert_float(harsh.get_repair_share(0.3)).is_equal_approx(0.05, 0.0001)


func test_threat_5_changes_what_the_hangar_repair_says_and_does() -> void:
	var run := _run([_level(5)])
	run.hull_damage = 20
	var repair := RepairShareEffect.new()
	repair.share = 0.3
	# 20% of the cross's 30 HP.
	assert_str(repair.describe(run)).is_equal("Repair 6 hull (20% of max).")
	repair.apply(run, EventResult.new())
	assert_int(run.hull_damage).is_equal(14)


func test_threat_6_makes_boss_phases_come_sooner() -> void:
	var run := _run([_level(6)])
	assert_float(run.make_enemy_mech(run.map.boss).phase_threshold_bonus).is_equal_approx(0.16, 0.0001)
	var control := _run([])
	assert_float(control.make_enemy_mech(control.map.boss).phase_threshold_bonus).is_equal(0.0)


func test_threat_7_gives_normal_battles_a_chance_of_an_affix() -> void:
	var sure := _run([Fixtures.run_modifier("sure", {"normal_affix_chance": 1.0}, 7)], [], [], _affixes())
	for node in _all(sure, MapNode.Type.BATTLE):
		assert_array(node.affixes).append_failure_message(node.id).has_size(1)
	var control := _run([], [], [], _affixes())
	for node in _all(control, MapNode.Type.BATTLE):
		assert_array(node.affixes).append_failure_message(node.id).is_empty()
	# At the ladder's 25%, some battles roll one and some don't.
	var some := _run([_level(7)], [], [], _affixes())
	var rolled := _all(some, MapNode.Type.BATTLE).filter(func(node: MapNode) -> bool: return not node.affixes.is_empty())
	assert_int(rolled.size()).is_greater(0).is_less(_all(some, MapNode.Type.BATTLE).size())


func test_threat_8_starts_damaged_with_a_glitch() -> void:
	var level := _level(8)
	var run := _run([level])
	assert_int(run.hull_damage).is_equal(3) # a tenth of 30
	assert_array(run.stash).has_size(1)
	assert_str(run.stash[0].part.part_name).is_equal("Glitch")
	assert_object(run.stash[0].part).is_not_same(level.start_parts[0])
	var control := _run([])
	assert_int(control.hull_damage).is_equal(0)
	assert_array(control.stash).is_empty()


func test_glass_cannon_trades_hp_for_damage() -> void:
	var run := _run([Fixtures.glass_cannon()])
	var control := _run([])
	assert_int(control.stats().damage).is_equal(8)
	assert_int(run.stats().damage).is_equal(12)
	assert_int(run.get_max_hp()).is_equal(roundi(control.get_max_hp() * 0.5))


func test_endless_starts_the_sectors_over_tougher() -> void:
	var run := _run([Fixtures.endless()], [], [], [], 2)
	run.next_act()
	assert_int(run.act_index).is_equal(1)
	run.next_act()
	assert_int(run.outcome).is_equal(RunState.Outcome.ONGOING)
	assert_int(run.act_index).is_equal(0)
	assert_int(run.loops).is_equal(1)
	# Half again as much HP on the first loop.
	assert_int(run.make_enemy_mech(_first(run, MapNode.Type.BATTLE)).max_hp).is_equal(45)
	# Positive control: without it, the last boss ends the run.
	var control := _run([], [], [], [], 2)
	control.next_act()
	control.next_act()
	assert_int(control.outcome).is_equal(RunState.Outcome.VICTORY)


func test_enemy_overrides_apply_only_at_their_threat_and_above() -> void:
	var enemy := Fixtures.enemy("Grunt", EnemyLoadout.Tier.NORMAL)
	enemy.threat_overrides = {2: {"hp_scale": 1.5}, 5: {"hp_scale": 2.0, "enemy_name": "Grunt Mk II"}}
	assert_object(enemy.with_threat(0)).is_same(enemy)
	assert_object(enemy.with_threat(1)).is_same(enemy)
	assert_float(enemy.with_threat(2).hp_scale).is_equal(1.5)
	assert_float(enemy.with_threat(4).hp_scale).is_equal(1.5)
	var tough := enemy.with_threat(5)
	assert_float(tough.hp_scale).is_equal(2.0)
	assert_str(tough.enemy_name).is_equal("Grunt Mk II")
	# The shared enemy never changes.
	assert_float(enemy.hp_scale).is_equal(1.0)
	assert_str(enemy.enemy_name).is_equal("Grunt")


func test_a_run_fights_enemies_at_its_threat() -> void:
	var run := _run(RunModifier.threat_stack(Fixtures.threat_levels(), 2))
	var node := _first(run, MapNode.Type.BATTLE)
	run.get_enemy(node).threat_overrides = {2: {"hp_scale": 2.0}}
	# 30 HP, doubled by the override and a tenth more from Threat 1.
	assert_int(run.make_enemy_mech(node).max_hp).is_equal(66)
	var control := _run([])
	var control_node := _first(control, MapNode.Type.BATTLE)
	control.get_enemy(control_node).threat_overrides = {2: {"hp_scale": 2.0}}
	assert_int(control.make_enemy_mech(control_node).max_hp).is_equal(30)


# The Threat level [param threat] from the fixtures' ladder, on its own.
func _level(threat: int) -> RunModifier:
	return Fixtures.threat_levels()[threat - 1]


# A run on the armed cross with a gatling in its left arm, through [param act_count] plain
# fixture sectors (enemies at their base HP), with [param modifiers].
func _run(modifiers: Array, catalog: Array[MechPart] = [], relics: Array[Relic] = [], affixes: Array[Relic] = [],
		act_count := 1) -> RunState:
	var chassis := Fixtures.armed_cross()
	chassis.starter_lineup = [LoadoutPart.make(Fixtures.gatling(), LEFT_ARM)]
	var acts: Array[ActData] = []
	for i in act_count:
		acts.append(Fixtures.act())
	var typed: Array[RunModifier] = []
	typed.assign(modifiers)
	return RunState.new(chassis, catalog, [], 10, RunRng.new(5), acts, relics, [], affixes, typed)


func _affixes() -> Array[Relic]:
	return [Fixtures.armored(), Fixtures.shielded(), Fixtures.rapid_fire()]


func _all(run: RunState, type: MapNode.Type) -> Array[MapNode]:
	var nodes: Array[MapNode] = []
	nodes.assign(run.map.get_nodes().filter(func(node: MapNode) -> bool: return node.type == type))
	return nodes


func _first(run: RunState, type: MapNode.Type) -> MapNode:
	var nodes := _all(run, type)
	assert_array(nodes).append_failure_message("the map has no node of type %d" % type).is_not_empty()
	return nodes[0]
