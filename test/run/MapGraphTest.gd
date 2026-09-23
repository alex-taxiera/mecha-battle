class_name MapGraphTest
extends GdUnitTestSuite

const __source: String = "res://src/run/MapGraph.gd"

var _graph: MapGraph
var _left: MapNode
var _right: MapNode
var _top: MapNode


# Two nodes on the bottom floor, both leading to one above, which leads to the boss.
func before_test() -> void:
	_graph = MapGraph.new()
	_left = MapNode.new(0, 0)
	_right = MapNode.new(0, 2)
	_top = MapNode.new(1, 1, MapNode.Type.SHOP)
	_graph.boss = MapNode.new(2, 1, MapNode.Type.BOSS)
	_graph.boss.id = "boss"
	_left.next = [_top]
	_right.next = [_top]
	_top.next = [_graph.boss]
	_graph.floors = [[_left, _right], [_top]]


func test_nodes_are_listed_floor_by_floor_then_the_boss() -> void:
	assert_array(_graph.get_nodes()).contains_same_exactly([_left, _right, _top, _graph.boss])
	assert_object(_graph.find_node("1_1")).is_same(_top)
	assert_object(_graph.find_node("boss")).is_same(_graph.boss)
	assert_object(_graph.find_node("9_9")).is_null()


func test_travel_goes_up_the_links() -> void:
	# At first, any node on the bottom floor.
	assert_array(_graph.get_reachable()).contains_same_exactly([_left, _right])
	assert_bool(_graph.travel(_top)).is_false()
	assert_bool(_graph.travel(_right)).is_true()
	assert_object(_graph.current).is_same(_right)
	assert_bool(_right.visited).is_true()
	assert_bool(_left.visited).is_false()
	# Then only what the current node links to.
	assert_array(_graph.get_reachable()).contains_same_exactly([_top])
	assert_bool(_graph.travel(_left)).is_false()
	assert_bool(_graph.is_at_boss()).is_false()
	assert_bool(_graph.travel(_top)).is_true()
	assert_bool(_graph.travel(_graph.boss)).is_true()
	assert_bool(_graph.is_at_boss()).is_true()
	assert_array(_graph.get_reachable()).is_empty()


func test_node_kinds() -> void:
	assert_bool(_left.is_fight()).is_true()
	assert_bool(_graph.boss.is_fight()).is_true()
	assert_bool(MapNode.new(3, 0, MapNode.Type.ELITE).is_fight()).is_true()
	assert_bool(_top.is_fight()).is_false()
	assert_bool(MapNode.new(3, 0, MapNode.Type.EVENT).is_fight()).is_false()
	assert_int(_left.get_tier()).is_equal(EnemyLoadout.Tier.NORMAL)
	assert_int(MapNode.new(3, 0, MapNode.Type.ELITE).get_tier()).is_equal(EnemyLoadout.Tier.ELITE)
	assert_int(_graph.boss.get_tier()).is_equal(EnemyLoadout.Tier.BOSS)
	assert_str(_right.id).is_equal("0_2")
