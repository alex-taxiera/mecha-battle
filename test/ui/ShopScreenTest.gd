class_name ShopScreenTest
extends GdUnitTestSuite

const __source: String = "res://src/ui/ShopScreen.gd"
const SCENE := preload("res://src/ui/ShopScreen.tscn")
const Fixtures := preload("res://test/TestFixtures.gd")

var _gatling: MechPart  # 1x3 vertical, 4 gold
var _laser: MechPart    # 1x1, 2 gold
var _reactor: MechPart  # 2x1, 3 gold
var _heatsink: MechPart # L, 4 gold
var _screen: ShopScreen


func before_test() -> void:
	_gatling = Fixtures.gatling()
	_laser = Fixtures.laser()
	_reactor = Fixtures.reactor()
	_heatsink = Fixtures.heatsink()
	_screen = auto_free(SCENE.instantiate())
	_screen.chassis = Fixtures.cross_chassis()
	_screen.catalog = [_gatling, _laser, _reactor, _heatsink]
	_screen.rules = Fixtures.rules()
	add_child(_screen)


func test_shows_the_round_gold_chassis_and_shop() -> void:
	assert_str(_text("RoundLabel")).is_equal("Hangar · Round 1")
	assert_str(_text("GoldLabel")).is_equal("Gold: 10")
	assert_str(_text("ChassisLabel")).is_equal("Chassis · The Skirmisher")
	assert_str(_text("ChassisInfo")).is_equal("Cross frame · 0 / 12 slots used")
	assert_array(_items().map(func(item: ShopItem) -> MechPart: return item.part)).has_size(4) \
		.contains_same_exactly_in_any_order(_gatling, _laser, _reactor, _heatsink)
	assert_array(_stats_panel().get_rule_rows()).has_size(4)


func test_dragging_a_shop_part_onto_the_grid_buys_it() -> void:
	var drag: PartDragData = _item_for(_gatling)._get_drag_data(Vector2.ZERO)
	var target := _cell_center(Vector2i(1, 0) + drag.grab_offset) # origin (1, 0)
	assert_bool(_grid_ui()._can_drop_data(target, drag)).is_true()
	# While it hovers, the stats row shows what the drop would add.
	assert_bool(_stats_panel().damage.delta.visible).is_true()
	assert_str(_stats_panel().damage.delta.text).is_equal("+8")

	_grid_ui()._drop_data(target, drag)
	assert_str(_text("GoldLabel")).is_equal("Gold: 6")
	assert_str(_text("ChassisInfo")).is_equal("Cross frame · 3 / 12 slots used")
	assert_bool(_items()[drag.slot_index].sold).is_true()
	assert_str(_stats_panel().damage.value.text).is_equal("8")
	assert_bool(_stats_panel().damage.delta.visible).is_false()
	await await_idle_frame() # free the shop cards the refresh replaced


func test_reroll_and_next_round_buttons() -> void:
	_button("RerollButton").pressed.emit()
	assert_str(_text("GoldLabel")).is_equal("Gold: 9")
	_screen.run.gold = 0
	_button("RerollButton").pressed.emit()
	assert_bool(_toast().visible).is_true()
	assert_str(_toast().text).is_equal("Not enough gold to reroll")

	_button("NextRoundButton").pressed.emit()
	assert_str(_text("RoundLabel")).is_equal("Hangar · Round 2")
	assert_str(_text("GoldLabel")).is_equal("Gold: 10") # the 0 left over plus 10 income
	assert_str(_toast().text).is_equal("Round 2 · +10g income, shop restocked")
	await await_idle_frame()


func test_dropping_an_installed_part_on_the_shop_sells_it() -> void:
	assert_bool(_screen.run.buy(_slot_of(_gatling), Vector2i(1, 0))).is_true() # 10 -> 6
	var drag: PartDragData = _grid_ui()._get_drag_data(_cell_center(Vector2i(1, 1)))
	_screen.show_sell_zone(drag)
	assert_bool(_sell_zone().visible).is_true()
	assert_str(_text("SellLabel")).is_equal("Sell for +4g")
	assert_str(_text("SellNote")).is_equal("Full refund: bought this round")
	# Installed parts can be sold there; shop offers can't.
	assert_bool(_screen.can_sell(Vector2.ZERO, drag)).is_true()
	assert_bool(_screen.can_sell(Vector2.ZERO, _item_for(_laser)._get_drag_data(Vector2.ZERO))).is_false()

	_screen.sell(Vector2.ZERO, drag)
	assert_str(_text("GoldLabel")).is_equal("Gold: 10")
	assert_object(_screen.run.grid.get_part_at(Vector2i(1, 1))).is_null()
	assert_str(_toast().text).is_equal("Sold Twin Gatling · +4g")
	assert_bool(_sell_zone().visible).is_false()
	await await_idle_frame()


func test_parts_from_earlier_rounds_sell_for_half() -> void:
	assert_bool(_screen.run.buy(_slot_of(_gatling), Vector2i(1, 0))).is_true()
	_button("NextRoundButton").pressed.emit()
	_screen.show_sell_zone(_grid_ui()._get_drag_data(_cell_center(Vector2i(1, 1))))
	assert_str(_text("SellLabel")).is_equal("Sell for +2g")
	assert_str(_text("SellNote")).is_equal("Half value: bought in an earlier round")
	await await_idle_frame()


func test_rotating_a_shop_offer() -> void:
	var slot := _slot_of(_gatling)
	assert_bool(_items()[slot].get_node("%RotateButton").visible).is_true()
	assert_bool(_item_for(_laser).get_node("%RotateButton").visible).is_false() # a 1x1 can't turn
	_items()[slot].rotate_requested.emit()
	assert_int(_screen.run.slots[slot].rotation).is_equal(1)
	assert_int(_items()[slot].turns).is_equal(1)
	assert_str(_items()[slot].get_node("%InfoLabel").text).is_equal("Weapon · 3×1")
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
	var screen: ShopScreen = auto_free(SCENE.instantiate())
	add_child(screen)
	var part_files := _tres_in(ShopScreen.PARTS_DIR)
	var rule_files := _tres_in(ShopScreen.RULES_DIR)
	assert_bool(part_files.is_empty() or rule_files.is_empty()).is_false()
	assert_array(screen.catalog).has_size(part_files.size())
	assert_array(screen.rules).has_size(rule_files.size())


func _items() -> Array[Node]:
	return _screen.get_node("%Slots").get_children()


func _item_for(part: MechPart) -> ShopItem:
	return _items()[_slot_of(part)]


func _slot_of(part: MechPart) -> int:
	for i in _screen.run.slots.size():
		if _screen.run.slots[i].part == part:
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
	return Vector2(cell) * MechGridUI.CELL_PITCH + Vector2.ONE * MechGridUI.CELL_SIZE / 2


static func _tres_in(dir: String) -> Array:
	return Array(ResourceLoader.list_directory(dir)).filter(func(file: String) -> bool: return file.ends_with(".tres"))
