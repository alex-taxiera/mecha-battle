class_name MechPartTest
extends GdUnitTestSuite

const __source: String = "res://src/data/MechPart.gd"

const VERTICAL_1X3: Array[Vector2i] = [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2)]
# X.
# XX
const L_SHAPE: Array[Vector2i] = [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1)]


func test_get_shape_turns_clockwise() -> void:
	# A vertical bar lies down after one turn and stands back up after two.
	var vertical := _make_part(VERTICAL_1X3)
	assert_array(vertical.get_shape(1)).contains_exactly([Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)])
	assert_array(vertical.get_shape(2)).contains_exactly(VERTICAL_1X3)
	# X.  ->  XX  ->  XX  ->  .X
	# XX      X.      .X      XX
	var l_part := _make_part(L_SHAPE)
	assert_array(l_part.get_shape(1)).contains_exactly([Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1)])
	assert_array(l_part.get_shape(2)).contains_exactly([Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1)])
	assert_array(l_part.get_shape(3)).contains_exactly([Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)])


func test_full_and_negative_turns() -> void:
	var l_part := _make_part(L_SHAPE)
	assert_array(l_part.get_shape()).contains_exactly(L_SHAPE)
	assert_array(l_part.get_shape(4)).contains_exactly(L_SHAPE)
	assert_array(l_part.get_shape(-1)).contains_exactly(l_part.get_shape(3))


func test_get_shape_starts_at_the_top_left() -> void:
	# A shape drawn away from (0, 0), out of order, comes back anchored and row by row.
	var part := _make_part([Vector2i(3, 2), Vector2i(2, 1)])
	assert_array(part.get_shape()).contains_exactly([Vector2i(0, 0), Vector2i(1, 1)])


func test_can_rotate() -> void:
	assert_bool(_make_part(VERTICAL_1X3).can_rotate()).is_true()
	assert_bool(_make_part(L_SHAPE).can_rotate()).is_true()
	# Turning these changes nothing.
	assert_bool(_make_part([Vector2i(0, 0)]).can_rotate()).is_false()
	assert_bool(_make_part([Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]).can_rotate()).is_false()


func test_weapons_never_rotate() -> void:
	# The same 1x3 turns as a plain part but not as a weapon, which must match its hardpoint.
	var weapon := _make_part(VERTICAL_1X3)
	assert_bool(weapon.can_rotate()).is_true()
	weapon.type = MechPart.PartType.WEAPON
	assert_bool(weapon.can_rotate()).is_false()


func test_normalized() -> void:
	# Anchored at the top-left and sorted row by row, so equal footprints compare equal.
	var cells: Array[Vector2i] = [Vector2i(-1, 3), Vector2i(-1, 1), Vector2i(-1, 2)]
	assert_array(MechPart.normalized(cells)).contains_exactly(VERTICAL_1X3)
	assert_array(cells).contains_exactly([Vector2i(-1, 3), Vector2i(-1, 1), Vector2i(-1, 2)]) # left as it was


# A plain grid part. Not a weapon (a new MechPart's default type), since weapons only mount on
# hardpoints and never turn.
func _make_part(shape: Array[Vector2i]) -> MechPart:
	var part := MechPart.new()
	part.type = MechPart.PartType.UTILITY
	part.grid_shape = shape
	return part
