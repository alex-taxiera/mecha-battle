class_name MechGridDataTest
extends GdUnitTestSuite

const __source: String = "res://src/data/MechGridData.gd"

# Footprints from the design doc, relative to a (0, 0) origin (x right, y down).
const SINGLE: Array[Vector2i] = [Vector2i(0, 0)]
const VERTICAL_1X3: Array[Vector2i] = [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2)]
const HORIZONTAL_2X1: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0)]
# X.
# XX
const L_SHAPE: Array[Vector2i] = [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1)]
# Spelled out rather than read from MechGridData so the tests pin the design doc.
const CORNERS: Array[Vector2i] = [Vector2i(0, 0), Vector2i(3, 0), Vector2i(0, 3), Vector2i(3, 3)]

var _grid_updates := 0


func before_test() -> void:
	_grid_updates = 0


# --- The four tests required by design_doc.md section 5 ---

func test_part_placement_bounds() -> void:
	var grid := MechGridData.new()
	var vertical := _make_part(VERTICAL_1X3)
	var horizontal := _make_part(HORIZONTAL_2X1)

	# Flush against each edge fits...
	assert_bool(grid.can_place_part(vertical, Vector2i(1, 1))).is_true()   # bottom
	assert_bool(grid.can_place_part(horizontal, Vector2i(2, 2))).is_true() # right
	assert_bool(grid.can_place_part(vertical, Vector2i(2, 0))).is_true()   # top
	assert_bool(grid.can_place_part(horizontal, Vector2i(0, 1))).is_true() # left
	# ...but one cell further hangs off it.
	_assert_rejected(grid, vertical, Vector2i(1, 2))
	_assert_rejected(grid, horizontal, Vector2i(3, 2))
	_assert_rejected(grid, vertical, Vector2i(2, -1))
	_assert_rejected(grid, horizontal, Vector2i(-1, 1))


func test_disabled_corners() -> void:
	var grid := MechGridData.new()
	var single := _make_part(SINGLE)

	# Sweep all 16 cells: a 1x1 fits everywhere except the four corners.
	for y in 4:
		for x in 4:
			var cell := Vector2i(x, y)
			assert_bool(grid.can_place_part(single, cell)) \
				.append_failure_message("1x1 at %s" % cell) \
				.is_equal(cell not in CORNERS)

	# Larger parts are rejected when any cell, not just the origin, lands on a corner.
	_assert_rejected(grid, _make_part(HORIZONTAL_2X1), Vector2i(2, 0)) # tail on (3, 0)
	_assert_rejected(grid, _make_part(VERTICAL_1X3), Vector2i(0, 1))   # tail on (0, 3)
	_assert_rejected(grid, _make_part(L_SHAPE), Vector2i(2, 2))        # foot on (3, 3)


func test_part_overlap() -> void:
	var grid := MechGridData.new()
	var vertical := _make_part(VERTICAL_1X3)
	assert_bool(grid.place_part(vertical, Vector2i(1, 0))).is_true() # (1, 0) (1, 1) (1, 2)

	# Touching is fine (adjacency synergies depend on it)...
	assert_bool(grid.can_place_part(_make_part(HORIZONTAL_2X1), Vector2i(2, 1))).is_true()
	# ...but sharing a cell is not, whether it's the new part's origin or another cell.
	_assert_rejected(grid, _make_part(HORIZONTAL_2X1), Vector2i(1, 2)) # origin on (1, 2)
	_assert_rejected(grid, _make_part(HORIZONTAL_2X1), Vector2i(0, 1)) # tail on (1, 1)
	_assert_rejected(grid, _make_part(VERTICAL_1X3), Vector2i(1, 0))   # exactly on top
	# The part already there is undisturbed.
	for cell: Vector2i in [Vector2i(1, 0), Vector2i(1, 1), Vector2i(1, 2)]:
		assert_object(grid.get_part_at(cell)).is_same(vertical)


func test_l_shape_placement() -> void:
	var grid := MechGridData.new()
	var l_part := _make_part(L_SHAPE)

	# Dead center of the cross, well away from every corner.
	assert_bool(grid.can_place_part(l_part, Vector2i(1, 1))).is_true()
	assert_bool(grid.place_part(l_part, Vector2i(1, 1))).is_true()
	for cell: Vector2i in [Vector2i(1, 1), Vector2i(1, 2), Vector2i(2, 2)]:
		assert_object(grid.get_part_at(cell)).is_same(l_part)
	assert_object(grid.get_part_at(Vector2i(2, 1))).is_null() # the L's notch stays free

	# Only real cells count against corners, not the bounding box: this L's
	# bounding box covers the (3, 0) corner, but its notch is what sits there.
	assert_bool(grid.place_part(_make_part(L_SHAPE), Vector2i(2, 0))).is_true()


# --- Coverage for the rest of the MechGridData API ---

func test_place_and_remove_part() -> void:
	var grid := MechGridData.new()
	grid.grid_updated.connect(func() -> void: _grid_updates += 1)
	var l_part := _make_part(L_SHAPE)

	assert_bool(grid.place_part(l_part, Vector2i(1, 1))).is_true()
	assert_int(_grid_updates).is_equal(1)

	# Removing via any cell of the footprint removes the whole part.
	assert_object(grid.remove_part(Vector2i(2, 2))).is_same(l_part)
	assert_int(_grid_updates).is_equal(2)
	for cell: Vector2i in [Vector2i(1, 1), Vector2i(1, 2), Vector2i(2, 2)]:
		assert_object(grid.get_part_at(cell)).is_null()
	assert_bool(grid.can_place_part(l_part, Vector2i(1, 1))).is_true()

	# Nothing changed, so nothing is emitted.
	assert_object(grid.remove_part(Vector2i(1, 1))).is_null()
	assert_bool(grid.place_part(l_part, Vector2i(3, 3))).is_false()
	assert_int(_grid_updates).is_equal(2)


func test_get_adjacent_parts() -> void:
	#     0 1 2 3
	#  0  # V . #
	#  1  . V L .
	#  2  S V L L
	#  3  # . D #
	var grid := MechGridData.new()
	var vertical := _make_part(VERTICAL_1X3)
	var l_part := _make_part(L_SHAPE)
	var side := _make_part(SINGLE)
	var diagonal := _make_part(SINGLE)
	assert_bool(grid.place_part(vertical, Vector2i(1, 0))).is_true()
	assert_bool(grid.place_part(l_part, Vector2i(2, 1))).is_true()
	assert_bool(grid.place_part(side, Vector2i(0, 2))).is_true()
	assert_bool(grid.place_part(diagonal, Vector2i(2, 3))).is_true()

	# Asked from any of V's cells: L touches V along two edges but is listed once,
	# D only touches V diagonally, and V itself is excluded.
	for cell: Vector2i in [Vector2i(1, 0), Vector2i(1, 2)]:
		assert_array(grid.get_adjacent_parts(cell)).has_size(2) \
			.contains_same_exactly_in_any_order(l_part, side)
	assert_array(grid.get_adjacent_parts(Vector2i(3, 2))).has_size(2) \
		.contains_same_exactly_in_any_order(vertical, diagonal)
	# An empty cell reports what surrounds that single cell.
	assert_array(grid.get_adjacent_parts(Vector2i(0, 1))).has_size(2) \
		.contains_same_exactly_in_any_order(side, vertical)


func test_same_resource_placed_twice() -> void:
	# load() hands out one shared instance per .tres, so two copies of the same
	# blueprint can be the same MechPart object. Each placement is still its own.
	var grid := MechGridData.new()
	var blueprint := _make_part(HORIZONTAL_2X1)
	assert_bool(grid.place_part(blueprint, Vector2i(1, 1))).is_true() # (1, 1) (2, 1)
	assert_bool(grid.place_part(blueprint, Vector2i(1, 2))).is_true() # (1, 2) (2, 2)

	# Each copy sees the other as a neighbor rather than as itself.
	assert_array(grid.get_adjacent_parts(Vector2i(1, 1))).has_size(1) \
		.contains_same_exactly_in_any_order(blueprint)

	# Removing one copy leaves the other in place.
	assert_object(grid.remove_part(Vector2i(2, 2))).is_same(blueprint)
	assert_object(grid.get_part_at(Vector2i(1, 2))).is_null()
	assert_object(grid.get_part_at(Vector2i(1, 1))).is_same(blueprint)
	assert_object(grid.get_part_at(Vector2i(2, 1))).is_same(blueprint)


func _make_part(shape: Array[Vector2i]) -> MechPart:
	var part := MechPart.new()
	part.grid_shape = shape
	return part


# Asserts that both the query and the mutation reject part at origin, and that
# the failed place_part didn't claim any cell of the footprint for it.
func _assert_rejected(grid: MechGridData, part: MechPart, origin: Vector2i) -> void:
	var context := "shape %s at %s" % [part.grid_shape, origin]
	assert_bool(grid.can_place_part(part, origin)).append_failure_message(context).is_false()
	assert_bool(grid.place_part(part, origin)).append_failure_message(context).is_false()
	for offset in part.grid_shape:
		assert_object(grid.get_part_at(origin + offset)).append_failure_message(context).is_not_same(part)
