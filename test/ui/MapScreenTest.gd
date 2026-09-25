class_name MapScreenTest
extends GdUnitTestSuite

const __source: String = "res://src/ui/MapScreen.gd"
const SCENE := preload("res://src/ui/MapScreen.tscn")
const Fixtures := preload("res://test/TestFixtures.gd")

var _run: RunState
var _screen: MapScreen


func before_test() -> void:
	var acts: Array[ActData] = [Fixtures.act(), Fixtures.act()]
	_run = RunState.new(Fixtures.armed_cross(), [], [], 20, RunRng.new(2), acts)
	_screen = auto_free(SCENE.instantiate())
	_screen.run = _run
	add_child(_screen)


func test_shows_the_run_and_its_map() -> void:
	var hud: RunHud = _screen.get_node("%RunHud")
	assert_object(hud.run).is_same(_run)
	assert_str(hud.sector_label.text).is_equal("Test Sector")
	assert_str(hud.floor_label.text).is_equal("Sector 1 of 2")
	assert_object(_screen.get_view().map).is_same(_run.map)
	assert_array(_screen.get_view().reachable).contains_same_exactly(_run.map.floors[0])
	assert_str((_screen.get_node("%Hint") as Label).text).is_equal("Pick where to start. Each step climbs one floor toward the boss.")
	# A legend entry per kind of node.
	var legend := (_screen.get_node("%Legend") as Container).get_children()
	assert_array(legend.map(func(label: Label) -> String: return label.text)) \
		.contains_exactly(["X  Battle", "!  Elite", "$  Scrap Shop", "+  Hangar", "?  Event", "B  Sector Boss", "~  Unknown",
			"C  Salvage Cache"])


func test_choosing_a_reachable_node_travels_there() -> void:
	var chosen: Array[MapNode] = []
	_screen.node_chosen.connect(func(node: MapNode) -> void: chosen.append(node))
	var node: MapNode = _run.map.floors[0][0]
	# Clicking goes through the view.
	_screen.get_view().press(node)
	assert_array(chosen).contains_same_exactly([node])
	assert_object(_run.map.current).is_same(node)
	# Once chosen, the map takes no more clicks.
	assert_array(_screen.get_view().reachable).is_empty()
	assert_str((_screen.get_node("%RunHud") as RunHud).floor_label.text).is_equal("Sector 1 of 2 · Floor 1")


func test_the_loadout_button_asks_for_the_loadout() -> void:
	var button: Button = _screen.get_node("%LoadoutButton")
	assert_str(button.text).is_equal("Loadout")
	var requests := [0]
	_screen.loadout_requested.connect(func() -> void: requests[0] += 1)
	button.pressed.emit()
	assert_int(requests[0]).is_equal(1)
	# It counts what's waiting in the stash.
	_run.stash_part(Fixtures.laser())
	_run.stash_part(Fixtures.laser())
	assert_str(MapScreen.loadout_text(_run)).is_equal("Loadout · 2 in stash")
	_run.cells_to_open = 1
	assert_str(MapScreen.loadout_text(_run)).is_equal("Loadout · 2 in stash · 1 cell to open")


func test_an_unreachable_node_is_refused() -> void:
	var chosen: Array[MapNode] = []
	_screen.node_chosen.connect(func(node: MapNode) -> void: chosen.append(node))
	assert_bool(_screen.choose(_run.map.boss)).is_false()
	assert_array(chosen).is_empty()
	assert_object(_run.map.current).is_null()
	# Positive control: a bottom-floor node works.
	assert_bool(_screen.choose(_run.map.floors[0][0])).is_true()
	assert_array(chosen).has_size(1)


func test_later_in_the_sector_it_offers_the_next_floor() -> void:
	var node: MapNode = _run.map.floors[0][0]
	assert_bool(_run.travel(node)).is_true()
	var screen: MapScreen = auto_free(SCENE.instantiate())
	screen.run = _run
	add_child(screen)
	assert_array(screen.get_view().reachable).contains_same_exactly(node.next)
	assert_str((screen.get_node("%Hint") as Label).text).is_equal("Pick your next stop.")
