class_name ShopScreenTest
extends GdUnitTestSuite

const __source: String = "res://src/ui/ShopScreen.gd"
const SCENE := preload("res://src/ui/ShopScreen.tscn")

var _cannon: MechPart # 1x3 vertical, costs 4
var _laser: MechPart  # 1x1, costs 2
var _armor: MechPart  # 2x1, costs 9: more than the 6 starting gold
var _screen: ShopScreen


func before_test() -> void:
	_cannon = _make_part("Cannon", 4, [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2)])
	_laser = _make_part("Laser", 2, [Vector2i(0, 0)])
	_armor = _make_part("Armor", 9, [Vector2i(0, 0), Vector2i(1, 0)])
	_screen = auto_free(SCENE.instantiate())
	_screen.starting_gold = 6
	_screen.catalog = [_cannon, _laser, _armor]
	add_child(_screen)


func test_shows_the_catalog_and_gold() -> void:
	assert_array(_items()).has_size(3)
	assert_str(_gold_label().text).is_equal("Gold: 6")
	# Only affordable parts can be picked up.
	assert_object(_item_for(_cannon)._get_drag_data(Vector2.ZERO)).is_instanceof(PartDragData)
	assert_object(_item_for(_armor)._get_drag_data(Vector2.ZERO)).is_null()


func test_dropping_a_shop_part_on_the_grid_buys_it() -> void:
	var drag: PartDragData = _item_for(_cannon)._get_drag_data(Vector2.ZERO)
	var grid_ui: MechGridUI = _screen.get_node("%MechGridUI")
	# Aim so the part's origin lands on the target cell, whichever cell it was grabbed by.
	var corner_spot := _cell_center(Vector2i(0, 0) + drag.grab_offset)
	var open_spot := _cell_center(Vector2i(1, 0) + drag.grab_offset)

	# Hovering where it doesn't fit buys nothing.
	assert_bool(grid_ui._can_drop_data(corner_spot, drag)).is_false()
	assert_int(_screen.shop.gold).is_equal(6)

	assert_bool(grid_ui._can_drop_data(open_spot, drag)).is_true()
	grid_ui._drop_data(open_spot, drag)

	for cell: Vector2i in [Vector2i(1, 0), Vector2i(1, 1), Vector2i(1, 2)]:
		assert_object(_screen.grid.get_part_at(cell)).is_same(_cannon)
	assert_int(_screen.shop.gold).is_equal(2)
	assert_str(_gold_label().text).is_equal("Gold: 2")
	assert_array(_screen.shop.offers).contains_same_exactly(_laser, _armor)
	assert_array(_items()).has_size(2)
	assert_object(_item_for(_cannon)).is_null()
	await await_idle_frame() # free the replaced shop items before GdUnit counts orphans


func test_a_part_is_held_by_the_cell_it_was_grabbed_by() -> void:
	await await_idle_frame() # let the containers lay out the shop items
	var item := _item_for(_cannon)
	var view: PartShapeView = item.get_node("%ShapeView")
	assert_float(view.global_position.y).is_greater(item.global_position.y) # laid out below the name
	var pitch := view.cell_size + view.gap
	var bottom_cell_center := Vector2(0, 2) * pitch + Vector2.ONE * view.cell_size / 2
	var press := view.global_position - item.global_position + bottom_cell_center

	var drag: PartDragData = item._get_drag_data(press)
	assert_that(drag.grab_offset).is_equal(Vector2i(0, 2))
	# Pressing outside the shape, e.g. on the name, holds it by its origin.
	drag = item._get_drag_data(Vector2(item.size.x / 2, 4))
	assert_that(drag.grab_offset).is_equal(Vector2i.ZERO)


func test_sells_every_part_in_the_parts_folder_by_default() -> void:
	var screen: ShopScreen = auto_free(SCENE.instantiate())
	add_child(screen)
	var part_files := Array(ResourceLoader.list_directory(ShopScreen.PARTS_DIR)).filter(
		func(file: String) -> bool: return file.ends_with(".tres"))
	assert_bool(part_files.is_empty()).is_false()
	assert_array(screen.shop.offers).has_size(part_files.size())


func _items() -> Array[Node]:
	return _screen.get_node("%Items").get_children()


func _item_for(part: MechPart) -> ShopItem:
	for item: ShopItem in _items():
		if item.part == part:
			return item
	return null


func _gold_label() -> Label:
	return _screen.get_node("%GoldLabel")


func _cell_center(cell: Vector2i) -> Vector2:
	return Vector2(cell) * MechGridUI.CELL_PITCH + Vector2.ONE * MechGridUI.CELL_SIZE / 2


func _make_part(part_name: String, cost: int, shape: Array[Vector2i]) -> MechPart:
	var part := MechPart.new()
	part.part_name = part_name
	part.cost = cost
	part.grid_shape = shape
	return part
