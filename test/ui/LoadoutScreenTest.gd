class_name LoadoutScreenTest
extends GdUnitTestSuite

const __source: String = "res://src/ui/LoadoutScreen.gd"
const SCENE := preload("res://src/ui/LoadoutScreen.tscn")
const Fixtures := preload("res://test/TestFixtures.gd")

var _gatling: MechPart  # 1x3 vertical arm weapon, 4 gold
var _laser: MechPart    # 1x1, 2 gold
var _reactor: MechPart  # 2x1, 3 gold
var _heatsink: MechPart # L, 4 gold
var _screen: LoadoutScreen


func before_test() -> void:
	_gatling = Fixtures.gatling()
	_laser = Fixtures.laser()
	_reactor = Fixtures.reactor()
	_heatsink = Fixtures.heatsink()
	_screen = auto_free(SCENE.instantiate())
	_screen.chassis = Fixtures.armed_cross() # arms at (-1, 1) and (4, 1), a back at (1, -2)
	_screen.catalog = [_gatling, _laser, _reactor, _heatsink]
	_screen.rules = Fixtures.rules()
	add_child(_screen)


func test_shows_the_hull_gold_chassis_and_shop() -> void:
	assert_str(_text("RoundLabel")).is_equal("Run") # a run without sectors
	assert_str(_text("ScreenTitle")).is_equal("Scrap Shop") # a run of its own opens a shop
	assert_bool(_screen.get_node("%ShopArea").visible).is_true()
	assert_str(_button("LeaveButton").text).is_equal("Leave shop")
	assert_str(_text("RecordLabel")).is_equal("Hull: 30 / 30 HP · 0 won")
	assert_str(_text("GoldLabel")).is_equal("Gold: 10")
	assert_str(_text("ChassisLabel")).is_equal("Chassis · The Skirmisher")
	assert_str(_text("ChassisInfo")).is_equal("Cross frame · 0 / 12 slots · 0 / 3 hardpoints")
	assert_array(_items().map(func(item: ShopItem) -> MechPart: return item.part)).has_size(4) \
		.contains_same_exactly_in_any_order(_gatling, _laser, _reactor, _heatsink)
	assert_array(_stats_panel().get_rule_rows()).has_size(4)


func test_shows_the_chassis_passive_under_the_grid() -> void:
	# The cross fixture has no passive, so there's nothing to show.
	assert_bool((_screen.get_node("%PassiveLabel") as Label).visible).is_false()
	var screen: LoadoutScreen = auto_free(SCENE.instantiate())
	screen.chassis = Fixtures.bastion()
	screen.catalog = [_gatling, _laser, _reactor, _heatsink]
	screen.rules = Fixtures.rules()
	add_child(screen)
	var label: Label = screen.get_node("%PassiveLabel")
	assert_bool(label.visible).is_true()
	assert_str(label.text).is_equal("Thick Plating: Reduces all incoming flat damage by 2.")
	assert_str((screen.get_node("%ChassisLabel") as Label).text).is_equal("Chassis · The Bastion")
	assert_str((screen.get_node("%ChassisInfo") as Label).text).is_equal("Wide frame · 0 / 12 slots · 0 / 1 hardpoints")


func test_dragging_a_shop_part_onto_the_mech_buys_it() -> void:
	var drag: PartDragData = _item_for(_gatling)._get_drag_data(Vector2.ZERO)
	var target := _cell_center(Vector2i(-1, 2)) # the left arm
	assert_bool(_grid_ui()._can_drop_data(target, drag)).is_true()
	# While it hovers, the stats row shows what the drop would add.
	assert_bool(_stats_panel().damage.delta.visible).is_true()
	assert_str(_stats_panel().damage.delta.text).is_equal("+8")

	_grid_ui()._drop_data(target, drag)
	assert_str(_text("GoldLabel")).is_equal("Gold: 6")
	assert_str(_text("ChassisInfo")).is_equal("Cross frame · 0 / 12 slots · 1 / 3 hardpoints")
	assert_bool(_items()[drag.slot_index].sold).is_true()
	assert_str(_stats_panel().damage.value.text).is_equal("8")
	assert_bool(_stats_panel().damage.delta.visible).is_false()
	# A grid part fills the frame's slots instead.
	assert_bool(_screen.run.buy(_slot_of(_heatsink), Vector2i(0, 1))).is_true()
	assert_str(_text("ChassisInfo")).is_equal("Cross frame · 3 / 12 slots · 1 / 3 hardpoints")
	await await_idle_frame() # free the shop cards the refresh replaced


func test_reroll_button() -> void:
	_button("RerollButton").pressed.emit()
	assert_str(_text("GoldLabel")).is_equal("Gold: 9")
	_screen.run.gold = 0
	_button("RerollButton").pressed.emit()
	assert_bool(_toast().visible).is_true()
	assert_str(_toast().text).is_equal("Not enough gold to reroll")
	await await_idle_frame()


func test_leave_asks_to_leave() -> void:
	var requests := [0]
	_screen.leave_requested.connect(func() -> void: requests[0] += 1)
	_button("LeaveButton").pressed.emit()
	assert_int(requests[0]).is_equal(1)
	assert_str(_text("GoldLabel")).is_equal("Gold: 10")


func test_shops_in_a_given_run() -> void:
	var acts: Array[ActData] = [Fixtures.act()]
	var run := RunState.new(Fixtures.armed_cross(), [_laser], Fixtures.rules(), 25, RunRng.new(3), acts)
	assert_bool(run.travel(run.get_reachable()[0])).is_true()
	run.open_shop()
	var screen: LoadoutScreen = auto_free(SCENE.instantiate())
	screen.run = run
	add_child(screen)
	assert_object(screen.run).is_same(run)
	assert_str((screen.get_node("%GoldLabel") as Label).text).is_equal("Gold: 25")
	assert_str((screen.get_node("%RoundLabel") as Label).text).is_equal("Sector 1 · Floor 1")
	assert_array(screen.find_children("*", "", true, false).filter(func(node: Node) -> bool: return node is ShopItem)) \
		.has_size(ShopStock.SIZE)


func test_away_from_a_shop_it_shows_the_mech_and_stash_only() -> void:
	var run := RunState.new(Fixtures.armed_cross(), [_laser], Fixtures.rules(), 25)
	run.stash_part(_heatsink)
	var screen: LoadoutScreen = auto_free(SCENE.instantiate())
	screen.run = run
	add_child(screen)
	assert_object(run.shop).is_null() # it opens none of its own
	assert_str((screen.get_node("%ScreenTitle") as Label).text).is_equal("Loadout")
	assert_str((screen.get_node("%LeaveButton") as Button).text).is_equal("Back to map")
	assert_bool((screen.get_node("%ShopArea") as Control).visible).is_false()
	var stash: StashPanel = screen.get_node("%StashPanel")
	assert_object(stash.run).is_same(run)
	assert_array(stash.get_items()).has_size(1)
	# Nothing sells away from a shop, from the mech or the stash.
	var from_stash := stash.get_items()[0]._get_drag_data(Vector2.ZERO) as PartDragData
	assert_bool(screen.can_sell(Vector2.ZERO, from_stash)).is_false()
	# Installing from the stash goes through the grid.
	var grid: MechGridUI = screen.get_node("%MechGridUI")
	assert_bool(grid._can_drop_data(grid.cell_center(Vector2i(1, 1)), from_stash)).is_true()
	grid._drop_data(grid.cell_center(Vector2i(1, 1)), from_stash)
	assert_array(run.stash).is_empty()
	assert_str((screen.get_node("%ChassisInfo") as Label).text).is_equal("Cross frame · 3 / 12 slots · 0 / 3 hardpoints")
	await await_idle_frame()


func test_stashed_parts_sell_at_the_shop() -> void:
	_screen.run.stash_part(_heatsink) # 4 gold, half back
	var stash: StashPanel = _screen.get_node("%StashPanel")
	var drag := stash.get_items()[0]._get_drag_data(Vector2.ZERO) as PartDragData
	assert_bool(_screen.can_sell(Vector2.ZERO, drag)).is_true()
	_screen.show_sell_zone(drag)
	assert_str(_text("SellLabel")).is_equal("Sell for +2g")
	assert_str(_text("SellNote")).is_equal("Half value: bought earlier")
	_screen.sell(Vector2.ZERO, drag)
	assert_array(_screen.run.stash).is_empty()
	assert_str(_text("GoldLabel")).is_equal("Gold: 12")
	assert_str(_toast().text).is_equal("Sold L-Shaped Heatsink · +2g")
	await await_idle_frame()


func test_dropping_an_installed_part_on_the_shop_sells_it() -> void:
	assert_bool(_screen.run.buy(_slot_of(_gatling), Vector2i(-1, 1))).is_true() # the left arm, 10 -> 6
	var drag: PartDragData = _grid_ui()._get_drag_data(_cell_center(Vector2i(-1, 2)))
	_screen.show_sell_zone(drag)
	assert_bool(_sell_zone().visible).is_true()
	assert_str(_text("SellLabel")).is_equal("Sell for +4g")
	assert_str(_text("SellNote")).is_equal("Full refund: bought at this shop")
	# Installed parts can be sold there; shop offers can't.
	assert_bool(_screen.can_sell(Vector2.ZERO, drag)).is_true()
	assert_bool(_screen.can_sell(Vector2.ZERO, _item_for(_laser)._get_drag_data(Vector2.ZERO))).is_false()

	_screen.sell(Vector2.ZERO, drag)
	assert_str(_text("GoldLabel")).is_equal("Gold: 10")
	assert_object(_screen.run.grid.get_part_at(Vector2i(-1, 2))).is_null()
	assert_str(_toast().text).is_equal("Sold Twin Gatling · +4g")
	assert_bool(_sell_zone().visible).is_false()
	await await_idle_frame()


func test_parts_from_earlier_shops_sell_for_half() -> void:
	assert_bool(_screen.run.buy(_slot_of(_gatling), Vector2i(-1, 1))).is_true()
	_screen.run.close_shop()
	_screen.run.open_shop()
	_screen.show_sell_zone(_grid_ui()._get_drag_data(_cell_center(Vector2i(-1, 2))))
	assert_str(_text("SellLabel")).is_equal("Sell for +2g")
	assert_str(_text("SellNote")).is_equal("Half value: bought earlier")
	await await_idle_frame()


func test_rotating_a_shop_offer() -> void:
	var slot := _slot_of(_reactor)
	assert_bool(_items()[slot].get_node("%RotateButton").visible).is_true()
	assert_bool(_item_for(_laser).get_node("%RotateButton").visible).is_false()   # a 1x1 can't turn
	assert_bool(_item_for(_gatling).get_node("%RotateButton").visible).is_false() # nor can a weapon
	_items()[slot].rotate_requested.emit()
	assert_int(_screen.run.shop.slots[slot].rotation).is_equal(1)
	assert_int(_items()[slot].turns).is_equal(1)
	assert_str(_items()[slot].get_node("%InfoLabel").text).is_equal("Generator · 1×2")
	await await_idle_frame()


func test_a_part_is_held_by_the_cell_it_was_grabbed_by() -> void:
	await await_idle_frame() # let the containers lay out the shop cards
	var item := _item_for(_gatling)
	var view: PartShapeView = item.get_node("%ShapeView")
	assert_float(view.global_position.y).is_greater(item.global_position.y) # laid out below the name
	var pitch := view.cell_size + view.gap
	var bottom_cell_center := Vector2(0, 2) * pitch + Vector2.ONE * view.cell_size / 2
	var drag: PartDragData = item._get_drag_data(view.global_position - item.global_position + bottom_cell_center)
	assert_that(drag.grab_offset).is_equal(Vector2i(0, 2))
	# Pressing outside the shape, e.g. on the name, holds it by its origin.
	drag = item._get_drag_data(Vector2(item.size.x / 2, 4))
	assert_that(drag.grab_offset).is_equal(Vector2i.ZERO)


func test_loads_parts_and_rules_from_their_folders_by_default() -> void:
	var screen: LoadoutScreen = auto_free(SCENE.instantiate())
	add_child(screen)
	var part_files := _tres_in(LoadoutScreen.PARTS_DIR)
	var rule_files := _tres_in(LoadoutScreen.RULES_DIR)
	assert_bool(part_files.is_empty() or rule_files.is_empty()).is_false()
	assert_array(screen.catalog).has_size(part_files.size())
	assert_array(screen.rules).has_size(rule_files.size())


func _items() -> Array[Node]:
	return _screen.get_node("%Slots").get_children()


func _item_for(part: MechPart) -> ShopItem:
	return _items()[_slot_of(part)]


func _slot_of(part: MechPart) -> int:
	for i in _screen.run.shop.slots.size():
		if _screen.run.shop.slots[i].part == part:
			return i
	return -1


func _text(node_name: String) -> String:
	return (_screen.get_node("%" + node_name) as Label).text


func _button(node_name: String) -> Button:
	return _screen.get_node("%" + node_name)


func _grid_ui() -> MechGridUI:
	return _screen.get_node("%MechGridUI")


func _stats_panel() -> StatsPanel:
	return _screen.get_node("%StatsPanel")


func _sell_zone() -> Control:
	return _screen.get_node("%SellZone")


func _toast() -> Label:
	return _screen.get_node("%Toast")


func _cell_center(cell: Vector2i) -> Vector2:
	return _grid_ui().cell_center(cell)


static func _tres_in(dir: String) -> Array:
	return Array(ResourceLoader.list_directory(dir)).filter(func(file: String) -> bool: return file.ends_with(".tres"))
