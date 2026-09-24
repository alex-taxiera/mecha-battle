class_name StashPanelTest
extends GdUnitTestSuite

const __source: String = "res://src/ui/StashPanel.gd"
const Fixtures := preload("res://test/TestFixtures.gd")

var _run: RunState
var _panel: StashPanel


func before_test() -> void:
	_run = RunState.new(Fixtures.armed_cross(), [], [])
	_panel = auto_free(StashPanel.new())
	_panel.run = _run
	add_child(_panel)


func test_an_empty_stash_says_where_parts_come_from() -> void:
	assert_str(_panel.title_label.text).is_equal("Stash · 0 parts")
	assert_str(_panel.hint_label.text).is_equal("Parts from loot land here. Drag installed parts here to store them.")
	assert_array(_panel.get_items()).is_empty()


func test_shows_each_stashed_part_and_follows_the_run() -> void:
	_run.stash_part(Fixtures.heatsink(), 1)
	_run.stash_part(Fixtures.gatling())
	assert_str(_panel.title_label.text).is_equal("Stash · 2 parts")
	var items := _panel.get_items()
	assert_array(items).has_size(2)
	assert_str(items[0].name_label.text).is_equal("L-Shaped Heatsink")
	assert_int(items[0].turns).is_equal(1)
	assert_str(items[1].info_label.text).is_equal("Weapon · 1×3")
	# Weapons don't turn; the heatsink does, through its button.
	assert_bool(items[1].rotate_button.visible).is_false()
	assert_bool(items[0].rotate_button.visible).is_true()
	items[0].rotate_button.pressed.emit()
	assert_int(_run.stash[0].rotation).is_equal(2)
	await await_idle_frame() # free the items the refresh replaced


func test_dragging_a_stashed_part_carries_it() -> void:
	_run.stash_part(Fixtures.reactor(), 1)
	var drag: PartDragData = _panel.get_items()[0]._get_drag_data(Vector2.ZERO)
	assert_bool(drag.is_from_stash()).is_true()
	assert_bool(drag.is_from_grid()).is_false()
	assert_int(drag.stash_index).is_equal(0)
	assert_int(drag.rotation).is_equal(1)
	assert_str(drag.part.part_name).is_equal("Micro-Reactor")


func test_dropping_an_installed_part_here_stores_it() -> void:
	assert_bool(_run.grid.place_part(Fixtures.laser(), Vector2i(1, 1))).is_true()
	var messages := []
	_panel.message.connect(func(text: String, _good: bool) -> void: messages.append(text))
	var from_grid := PartDragData.from_grid(Vector2i(1, 1), _run.grid.get_part_at(Vector2i(1, 1)), 0)
	assert_bool(_panel._can_drop_data(Vector2.ZERO, from_grid)).is_true()
	_panel._drop_data(Vector2.ZERO, from_grid)
	assert_object(_run.grid.get_part_at(Vector2i(1, 1))).is_null()
	assert_array(_run.stash).has_size(1)
	assert_array(messages).contains_exactly(["Stored Point-Defense Laser in the stash"])
	# Away from a shop, shop offers don't drop here; stashed parts never do.
	assert_bool(_panel._can_drop_data(Vector2.ZERO, PartDragData.from_shop(0, Fixtures.laser(), 0))).is_false()
	assert_bool(_panel._can_drop_data(Vector2.ZERO, PartDragData.from_stash(0, Fixtures.laser(), 0))).is_false()
	assert_bool(_panel._can_drop_data(Vector2.ZERO, "text")).is_false()
	await await_idle_frame()


func test_dropping_a_copy_on_a_stash_item_merges_them() -> void:
	_run.stash_part(Fixtures.heatsink())
	_run.stash_part(Fixtures.heatsink())
	var items := _panel.get_items()
	var drag := items[1]._get_drag_data(Vector2.ZERO) as PartDragData
	assert_bool(items[0]._can_drop_data(Vector2.ZERO, drag)).is_true()
	items[0]._drop_data(Vector2.ZERO, drag)
	assert_array(_run.stash).has_size(1)
	assert_int(_run.stash[0].part.level).is_equal(2)
	await await_idle_frame()


func test_an_item_passes_other_drops_to_the_stash() -> void:
	_run.stash_part(Fixtures.heatsink())
	assert_bool(_run.grid.place_part(Fixtures.laser(), Vector2i(1, 1))).is_true()
	var item := _panel.get_items()[0]
	var from_grid := PartDragData.from_grid(Vector2i(1, 1), _run.grid.get_part_at(Vector2i(1, 1)), 0)
	# Not a copy of the heatsink, so it's stored, as if dropped on the stash itself.
	assert_bool(item._can_drop_data(Vector2.ZERO, from_grid)).is_true()
	item._drop_data(Vector2.ZERO, from_grid)
	assert_array(_run.stash).has_size(2)
	assert_int(_run.stash[0].part.level).is_equal(1)
	await await_idle_frame()


func test_at_a_shop_dropping_an_offer_here_buys_it_into_the_stash() -> void:
	var laser := Fixtures.laser() # 2 gold
	var run := RunState.new(Fixtures.armed_cross(), [laser], [], 10)
	run.open_shop()
	var panel: StashPanel = auto_free(StashPanel.new())
	panel.run = run
	add_child(panel)
	var drag := PartDragData.from_shop(0, run.shop.slots[0].part, 0)
	assert_bool(panel._can_drop_data(Vector2.ZERO, drag)).is_true()
	panel._drop_data(Vector2.ZERO, drag)
	assert_array(run.stash).has_size(1)
	assert_int(run.gold).is_equal(8)
	# Too little gold: no drop.
	run.gold = 0
	run.shop.restock()
	assert_bool(panel._can_drop_data(Vector2.ZERO, PartDragData.from_shop(0, run.shop.slots[0].part, 0))).is_false()
	await await_idle_frame()
