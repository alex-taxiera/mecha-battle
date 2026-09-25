class_name MapGeneratorTest
extends GdUnitTestSuite

const __source: String = "res://src/run/MapGenerator.gd"
const Fixtures := preload("res://test/TestFixtures.gd")
# Maps checked by the tests that look at every map.
const SEEDS := 60
# The fixture sector's shape, from design: 12 floors of 7 columns, 6 paths, specials from floor 4.
const FLOORS := 12
const COLUMNS := 7


func test_the_map_has_its_floors_and_a_boss_on_top() -> void:
	var map := _map(1)
	assert_int(map.floors.size()).is_equal(FLOORS)
	assert_int(map.boss.type).is_equal(MapNode.Type.BOSS)
	assert_int(map.boss.floor_index).is_equal(FLOORS)
	assert_str(map.boss.id).is_equal("boss")
	assert_object(map.current).is_null()
	for node: MapNode in map.floors[-1]:
		assert_array(node.next).contains_same_exactly([map.boss])
	assert_array(map.boss.next).is_empty()


func test_every_node_lies_on_a_path_from_the_bottom_to_the_boss() -> void:
	for map_seed in SEEDS:
		var map := _map(map_seed)
		var reached := {}
		for node: MapNode in map.floors[0]:
			_reach(node, reached)
		for node in map.get_nodes():
			assert_bool(reached.has(node)).append_failure_message("seed %d: %s unreachable" % [map_seed, node.id]).is_true()
			assert_bool(node == map.boss or not node.next.is_empty()) \
				.append_failure_message("seed %d: %s is a dead end" % [map_seed, node.id]).is_true()


func test_links_climb_one_floor_at_most_one_column_aside() -> void:
	for map_seed in SEEDS:
		var map := _map(map_seed)
		for floor_nodes: Array in map.floors.slice(0, FLOORS - 1):
			for node: MapNode in floor_nodes:
				for child in node.next:
					var context := "seed %d: %s -> %s" % [map_seed, node.id, child.id]
					assert_int(child.floor_index).append_failure_message(context).is_equal(node.floor_index + 1)
					assert_int(absi(child.column - node.column)).append_failure_message(context).is_less_equal(1)


func test_no_two_links_cross() -> void:
	for map_seed in SEEDS:
		var map := _map(map_seed)
		for floor_nodes: Array in map.floors.slice(0, FLOORS - 1):
			for node: MapNode in floor_nodes:
				for child in node.next:
					if child.column == node.column:
						continue
					# The opposite diagonal between the same two columns.
					var neighbor := _at(floor_nodes, child.column)
					var crossed := neighbor != null and neighbor.next.any(func(n: MapNode) -> bool: return n.column == node.column)
					assert_bool(crossed).append_failure_message("seed %d: %s -> %s crosses" % [map_seed, node.id, child.id]).is_false()


func test_the_map_opens_with_a_choice() -> void:
	for map_seed in SEEDS:
		assert_int(_map(map_seed).floors[0].size()).append_failure_message("seed %d" % map_seed).is_greater_equal(2)


func test_the_bottom_floor_is_fights_and_the_top_floor_hangars() -> void:
	for map_seed in SEEDS:
		var map := _map(map_seed)
		for node: MapNode in map.floors[0]:
			assert_int(node.type).is_equal(MapNode.Type.BATTLE)
		for node: MapNode in map.floors[-1]:
			assert_int(node.type).is_equal(MapNode.Type.HANGAR)


func test_no_elite_or_hangar_before_the_special_floor() -> void:
	var seen_elite := false
	for map_seed in SEEDS:
		for node in _map(map_seed).get_nodes():
			if node.floor_index < 4:
				assert_int(node.type).append_failure_message("seed %d: %s" % [map_seed, node.id]) \
					.is_not_equal(MapNode.Type.ELITE).is_not_equal(MapNode.Type.HANGAR)
			seen_elite = seen_elite or node.type == MapNode.Type.ELITE
	# Positive control: elites do show up above it.
	assert_bool(seen_elite).is_true()


func test_special_nodes_never_come_twice_in_a_row() -> void:
	var special := [MapNode.Type.ELITE, MapNode.Type.HANGAR, MapNode.Type.SHOP, MapNode.Type.CACHE]
	var seen := {}
	# Unknown nodes and caches only come up where a sector weights them.
	var act := Fixtures.act()
	act.unknown_weight = 8
	act.cache_weight = 6
	for map_seed in SEEDS:
		for node in MapGenerator.new().generate(act, _seeded(map_seed)).get_nodes():
			seen[node.type] = true
			for child in node.next:
				if node.type in special:
					assert_int(child.type).append_failure_message("seed %d: %s -> %s" % [map_seed, node.id, child.id]) \
						.is_not_equal(node.type)
	# Positive control: every kind of node turns up somewhere.
	assert_array(seen.keys()).contains_exactly_in_any_order(MapNode.Type.values())


func test_node_kinds_follow_the_weights() -> void:
	# Only events weighted: every floor without a fixed kind is all events.
	var act := Fixtures.act()
	act.battle_weight = 0
	act.elite_weight = 0
	act.hangar_weight = 0
	act.shop_weight = 0
	act.event_weight = 1
	var map := MapGenerator.new().generate(act, _seeded(3))
	for floor_nodes: Array in map.floors.slice(1, FLOORS - 1):
		for node: MapNode in floor_nodes:
			assert_int(node.type).is_equal(MapNode.Type.EVENT)


func test_the_boss_is_one_of_the_sectors_bosses() -> void:
	var act := Fixtures.act()
	var second_boss := Fixtures.enemy("Other Boss", EnemyLoadout.Tier.BOSS)
	act.enemies.append(second_boss)
	var bosses := {}
	for map_seed in 30:
		var boss := MapGenerator.new().generate(act, _seeded(map_seed)).boss.enemy
		assert_int(boss.tier).is_equal(EnemyLoadout.Tier.BOSS)
		bosses[boss] = true
	# Either can come up.
	assert_int(bosses.size()).is_equal(2)
	# Only the boss's enemy is picked with the map.
	for node in _map(1).get_nodes():
		if node.type != MapNode.Type.BOSS:
			assert_object(node.enemy).is_null()


func test_nodes_are_jittered_a_little() -> void:
	var map := _map(2)
	var moved := false
	for node in map.get_nodes():
		assert_float(absf(node.jitter.x)).is_less_equal(MapGenerator.JITTER.x)
		assert_float(absf(node.jitter.y)).is_less_equal(MapGenerator.JITTER.y)
		moved = moved or node.jitter != Vector2.ZERO
	assert_bool(moved).is_true()
	assert_that(map.boss.jitter).is_equal(Vector2.ZERO)


func test_the_same_seed_gives_the_same_map() -> void:
	assert_array(_summary(_map(5))).is_equal(_summary(_map(5)))
	assert_array(_summary(_map(6))).is_not_equal(_summary(_map(5)))


func _map(map_seed: int) -> MapGraph:
	return MapGenerator.new().generate(Fixtures.act(), _seeded(map_seed))


func _seeded(rng_seed: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	return rng


func _reach(node: MapNode, reached: Dictionary) -> void:
	if reached.has(node):
		return
	reached[node] = true
	for child in node.next:
		_reach(child, reached)


func _at(floor_nodes: Array, column: int) -> MapNode:
	for node: MapNode in floor_nodes:
		if node.column == column:
			return node
	return null


func _summary(map: MapGraph) -> Array[String]:
	var summary: Array[String] = []
	for node in map.get_nodes():
		summary.append("%s:%d:%s:%s" % [node.id, node.type, node.jitter, ",".join(node.next.map(func(n: MapNode) -> String: return n.id))])
	return summary
