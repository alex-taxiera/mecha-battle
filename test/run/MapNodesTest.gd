class_name MapNodesTest
extends GdUnitTestSuite
## The second round of map nodes: Unknown nodes, Salvage Caches, and hazards.

const __source: String = "res://src/data/RunState.gd"
const Fixtures := preload("res://test/TestFixtures.gd")


func test_an_unknown_node_turns_into_something_real() -> void:
	var run := _run()
	var seen := {}
	for i in 200:
		var node := MapNode.new(3, 0, MapNode.Type.UNKNOWN)
		var type := run.resolve_unknown(node)
		assert_int(node.type).is_equal(type)
		seen[type] = seen.get(type, 0) + 1
	assert_array(seen.keys()).contains_exactly_in_any_order([MapNode.Type.EVENT, MapNode.Type.BATTLE,
		MapNode.Type.CACHE, MapNode.Type.SHOP])
	# Events come up most, shops least.
	assert_int(seen[MapNode.Type.EVENT]).is_greater(seen[MapNode.Type.SHOP])
	# Any other node stays as it is.
	var hangar := MapNode.new(3, 0, MapNode.Type.HANGAR)
	assert_int(run.resolve_unknown(hangar)).is_equal(MapNode.Type.HANGAR)


func test_a_cache_hands_out_gold_a_relic_and_a_kit() -> void:
	var run := _run()
	run.kit_pool.assign([Fixtures.shield_cell()])
	var reward := run.roll_cache()
	assert_str(reward.title).is_equal("SALVAGE CACHE")
	assert_int(reward.gold).is_between(8, 12)
	assert_int(run.gold).is_equal(10 + reward.gold)
	assert_array(reward.relics).has_size(1)
	assert_object(reward.kit).is_not_null()
	assert_array(reward.parts).is_empty()
	var screen: RewardScreen = auto_free(RewardScreen.new(run, reward))
	add_child(screen)
	assert_str(screen.title_label.text).is_equal("SALVAGE CACHE")
	assert_str(screen.relic_label.text).is_equal("Recovered a relic and a field kit:")
	await await_idle_frame()


func test_hazards_roll_onto_fights_at_the_sectors_chance() -> void:
	var ion := _ion_storm()
	var always := Fixtures.act()
	always.hazard_chance = 1.0
	always.hazards.assign([ion])
	var run := _run([always])
	for node in run.map.get_nodes():
		if node.type in [MapNode.Type.BATTLE, MapNode.Type.ELITE]:
			assert_object(node.hazard).append_failure_message(node.id).is_same(ion)
		else:
			assert_object(node.hazard).append_failure_message(node.id).is_null()
	# Positive control: at no chance, none.
	for node in _run().map.get_nodes():
		assert_object(node.hazard).is_null()


func test_both_mechs_fight_under_the_hazard() -> void:
	var run := _run()
	var node: MapNode = run.get_reachable()[0]
	node.hazard = _scorched(30)
	var player := run.make_player_mech(node)
	var enemy := run.make_enemy_mech(node)
	player.start_fight()
	enemy.start_fight()
	assert_int(player.heat).is_equal(30)
	assert_int(enemy.heat).is_equal(30)
	# The run's own relics don't keep it.
	assert_array(run.relics).is_empty()
	assert_int(run.make_player_mech().relics.size()).is_equal(0)


func test_an_ion_storm_drains_shields() -> void:
	var grid := MechGridData.new(Fixtures.cross_chassis())
	assert_bool(grid.place_part(Fixtures.shield_emitter(), Vector2i(1, 0))).is_true()
	var mech := BattleMech.new(grid, [], 1.0, -1, [_ion_storm()] as Array[Relic])
	assert_int(mech.shield).is_equal(200)
	mech.start_fight()
	assert_int(mech.shield).is_equal(0)


func test_the_map_tells_of_a_hazard() -> void:
	var node := MapNode.new(2, 1, MapNode.Type.BATTLE)
	node.hazard = _ion_storm()
	assert_str(MapView.describe(node)).is_equal("Battle\nFight one of the sector's mechs.\nHazard: Ion Storm (both mechs): Shields drained.")


func _ion_storm() -> IonStorm:
	var hazard := IonStorm.new()
	hazard.id = "ion_storm"
	hazard.relic_name = "Ion Storm"
	hazard.description = "Shields drained."
	hazard.rarity = Relic.Rarity.AFFIX
	return hazard


func _scorched(heat: int) -> ScorchedGround:
	var hazard := ScorchedGround.new()
	hazard.id = "scorched_ground"
	hazard.relic_name = "Scorched Ground"
	hazard.heat = heat
	hazard.rarity = Relic.Rarity.AFFIX
	return hazard


func _run(acts: Array[ActData] = []) -> RunState:
	if acts.is_empty():
		acts = [Fixtures.act()]
	return RunState.new(Fixtures.armed_cross(), [], [], 10, RunRng.new(4), acts, Fixtures.relics())
