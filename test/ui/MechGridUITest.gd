class_name MechGridUITest
extends GdUnitTestSuite

const __source: String = "res://src/ui/MechGridUI.gd"
const SCENE := preload("res://src/ui/MechGridUI.tscn")
const VERTICAL_1X3: Array[Vector2i] = [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2)]

var _grid: MechGridData
var _grid_ui: MechGridUI


func before_test() -> void:
	_grid = MechGridData.new()
	_grid_ui = auto_free(SCENE.instantiate())
	_grid_ui.grid_data = _grid
	add_child(_grid_ui)


func test_accepts_a_drop_only_where_the_grid_data_allows_it() -> void:
	var drag := PartDragData.new(_make_part(VERTICAL_1X3))
	assert_bool(_grid_ui._can_drop_data(_cell_center(Vector2i(1, 1)), drag)).is_true()  # (1, 1)-(1, 3)
	assert_bool(_grid_ui._can_drop_data(_cell_center(Vector2i(1, 2)), drag)).is_false() # hangs off the bottom
	assert_bool(_grid_ui._can_drop_data(_cell_center(Vector2i(0, 1)), drag)).is_false() # tail on the (0, 3) corner
	assert_bool(_grid.place_part(_make_part(VERTICAL_1X3), Vector2i(2, 0))).is_true()
	assert_bool(_grid_ui._can_drop_data(_cell_center(Vector2i(2, 1)), drag)).is_false() # overlaps that part


func test_rejects_drags_that_are_not_parts() -> void:
	var center := _cell_center(Vector2i(1, 1))
	assert_bool(_grid_ui._can_drop_data(center, "text")).is_false()
	assert_bool(_grid_ui._can_drop_data(center, _make_part(VERTICAL_1X3))).is_false()
	assert_bool(_grid_ui._can_drop_data(center, PartDragData.new(_make_part(VERTICAL_1X3)))).is_true()


func test_drop_places_the_part_and_reports_it() -> void:
	var part := _make_part(VERTICAL_1X3)
	var dropped := []
	_grid_ui.part_dropped.connect(func(p: MechPart, origin: Vector2i) -> void: dropped.append([p, origin]))

	_grid_ui._drop_data(_cell_center(Vector2i(2, 0)), PartDragData.new(part))

	for cell: Vector2i in [Vector2i(2, 0), Vector2i(2, 1), Vector2i(2, 2)]:
		assert_object(_grid.get_part_at(cell)).is_same(part)
	assert_array(dropped).has_size(1)
	assert_object(dropped[0][0]).is_same(part)
	assert_that(dropped[0][1]).is_equal(Vector2i(2, 0))


func test_the_grabbed_cell_lands_under_the_cursor() -> void:
	# Held by its bottom cell and dropped on (1, 3), a 1x3 fills (1, 1)-(1, 3)...
	var part := _make_part(VERTICAL_1X3)
	var drag := PartDragData.new(part, Vector2i(0, 2))
	assert_bool(_grid_ui._can_drop_data(_cell_center(Vector2i(1, 3)), drag)).is_true()
	_grid_ui._drop_data(_cell_center(Vector2i(1, 3)), drag)
	for cell: Vector2i in [Vector2i(1, 1), Vector2i(1, 2), Vector2i(1, 3)]:
		assert_object(_grid.get_part_at(cell)).is_same(part)
	# ...while held that way over (2, 1), its top would stick out above the grid.
	assert_bool(_grid_ui._can_drop_data(_cell_center(Vector2i(2, 1)), drag)).is_false()


func _cell_center(cell: Vector2i) -> Vector2:
	return Vector2(cell) * MechGridUI.CELL_PITCH + Vector2.ONE * MechGridUI.CELL_SIZE / 2


func _make_part(shape: Array[Vector2i]) -> MechPart:
	var part := MechPart.new()
	part.grid_shape = shape
	return part
