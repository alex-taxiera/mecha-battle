class_name MapViewTest
extends GdUnitTestSuite

const __source: String = "res://src/ui/map/MapView.gd"
const Fixtures := preload("res://test/TestFixtures.gd")

var _map: MapGraph
var _view: MapView


func before_test() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	_map = MapGenerator.new().generate(Fixtures.act(), rng)
	_view = auto_free(MapView.new())
	_view.map = _map
	_view.size = _view.get_minimum_size()
	add_child(_view)


func test_is_sized_to_hold_the_whole_map() -> void:
	# 7 columns 96 apart and 12 floors 72 apart, with margins and room for the boss.
	assert_that(_view.get_minimum_size()).is_equal(Vector2(56 * 2 + 96 * 6, 48 * 2 + 100 + 72 * 12))
	for node in _map.get_nodes():
		var at := _view.get_node_position(node)
		assert_bool(Rect2(Vector2.ZERO, _view.size).has_point(at)).append_failure_message(node.id).is_true()


func test_floors_climb_up_the_view_and_the_boss_sits_on_top() -> void:
	var bottom := _view.get_node_position(_map.floors[0][0])
	var top := _view.get_node_position(_map.floors[-1][0])
	var boss := _view.get_node_position(_map.boss)
	assert_float(top.y).is_less(bottom.y)
	assert_float(boss.y).is_less(top.y)
	assert_float(boss.x).is_equal_approx(_view.size.x / 2.0, 0.01)


func test_finds_the_node_under_a_point() -> void:
	for node in _map.get_nodes():
		assert_object(_view.node_at(_view.get_node_position(node))).append_failure_message(node.id).is_same(node)
	# Between nodes there's nothing.
	assert_object(_view.node_at(Vector2(1, 1))).is_null()


func test_only_reachable_nodes_can_be_pressed() -> void:
	var pressed: Array[MapNode] = []
	_view.node_pressed.connect(func(node: MapNode) -> void: pressed.append(node))
	var start: MapNode = _map.floors[0][0]
	# Nothing is reachable until the view is told.
	assert_bool(_view.press(start)).is_false()
	_view.reachable = _map.get_reachable()
	assert_bool(_view.press(_map.boss)).is_false()
	assert_bool(_view.press(null)).is_false()
	assert_bool(_view.press(start)).is_true()
	assert_array(pressed).contains_same_exactly([start])


func test_tooltips_explain_each_node() -> void:
	var start: MapNode = _map.floors[0][0]
	assert_str(_view._get_tooltip(_view.get_node_position(start))).is_equal("Battle\nFight one of the sector's mechs.")
	assert_str(_view._get_tooltip(Vector2(1, 1))).is_empty()
	assert_str(MapView.describe(_map.boss)).is_equal("Sector Boss: Boss\nThe sector's boss. Beat it to move on.")
	var elite := MapNode.new(5, 1, MapNode.Type.ELITE)
	assert_str(MapView.describe(elite)).is_equal("Elite\nA tougher mech with better loot.")
	# Every kind has a glyph, color, name, and blurb.
	assert_array(MapView.KINDS.keys()).contains_exactly_in_any_order(MapNode.Type.values())
