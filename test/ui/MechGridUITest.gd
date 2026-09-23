class_name MechGridUITest
extends GdUnitTestSuite

const __source: String = "res://src/ui/MechGridUI.gd"
const SCENE := preload("res://src/ui/MechGridUI.tscn")
const Fixtures := preload("res://test/TestFixtures.gd")

var _gatling: MechPart # 1x3 vertical, 4 gold
var _laser: MechPart   # 1x1, 2 gold
var _heatsink: MechPart # L, 4 gold
var _run: RunState
var _grid_ui: MechGridUI
var _previews: Array[MechStats] = []
var _messages: Array = []


func before_test() -> void:
	_gatling = Fixtures.gatling()
	_laser = Fixtures.laser()
	_heatsink = Fixtures.heatsink()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	_run = RunState.new(Fixtures.cross_chassis(), [_gatling, _laser, Fixtures.reactor(), _heatsink], Fixtures.rules(), 10, rng)
	_grid_ui = auto_free(SCENE.instantiate())
	_grid_ui.run = _run
	add_child(_grid_ui)
	_previews = []
	_messages = []
	_grid_ui.preview_changed.connect(func(stats: MechStats) -> void: _previews.append(stats))
	_grid_ui.message.connect(func(text: String, good: bool) -> void: _messages.append([text, good]))


func test_hovering_a_shop_part_previews_the_buy() -> void:
	var drag := _shop_drag(_gatling)
	# Upright at (1, 1)-(1, 3) it fits, lights its open edges, and reports the stats it would give.
	assert_bool(_grid_ui._can_drop_data(_cell_center(Vector2i(1, 1)), drag)).is_true()
	assert_str(_grid_ui.get_preview_text()).is_equal("Install · -4g")
	assert_array(_grid_ui.get_shown_edges()).has_size(6).contains_exactly_in_any_order(
		Vector2i(1, 0), Vector2i(0, 1), Vector2i(2, 1), Vector2i(0, 2), Vector2i(2, 2), Vector2i(2, 3))
	assert_int(_previews.back().damage).is_equal(8)
	# Where it doesn't fit, it says why, lights nothing, and clears the preview stats.
	assert_bool(_grid_ui._can_drop_data(_cell_center(Vector2i(1, 2)), drag)).is_false()
	assert_str(_grid_ui.get_preview_text()).is_equal("Doesn't fit on the chassis")
	assert_array(_grid_ui.get_shown_edges()).is_empty()
	assert_object(_previews.back()).is_null()
	assert_bool(_grid_ui._can_drop_data(_cell_center(Vector2i(0, 1)), drag)).is_false()
	assert_str(_grid_ui.get_preview_text()).is_equal("No frame there")
	# Hovering buys nothing.
	assert_int(_run.gold).is_equal(10)


func test_occupied_and_unaffordable_spots_say_why() -> void:
	assert_bool(_run.buy(_slot_of(_laser), Vector2i(1, 2))).is_true() # 10 -> 8
	var drag := _shop_drag(_gatling)
	assert_bool(_grid_ui._can_drop_data(_cell_center(Vector2i(1, 1)), drag)).is_false()
	assert_str(_grid_ui.get_preview_text()).is_equal("Those slots are occupied")
	# Short of gold, a spot that fits still lights its edges but won't take the drop.
	_run.gold = 3
	assert_bool(_grid_ui._can_drop_data(_cell_center(Vector2i(2, 0)), drag)).is_false()
	assert_str(_grid_ui.get_preview_text()).is_equal("Not enough gold (need 4g)")
	assert_array(_grid_ui.get_shown_edges()).is_not_empty()
	await await_idle_frame()


func test_dropping_a_shop_part_buys_it() -> void:
	var drag := _shop_drag(_gatling)
	assert_bool(_grid_ui._can_drop_data(_cell_center(Vector2i(1, 1)), drag)).is_true()
	_grid_ui._drop_data(_cell_center(Vector2i(1, 1)), drag)
	assert_str(_run.grid.get_part_at(Vector2i(1, 3)).part_name).is_equal(_gatling.part_name)
	assert_int(_run.gold).is_equal(6)
	assert_array(_messages).contains_exactly([["Installed Twin Gatling · -4g", true]])
	# The new part's open edges stay lit for a moment.
	assert_array(_grid_ui.get_shown_edges()).has_size(6)
	await await_idle_frame()


func test_dragging_an_installed_part_moves_it() -> void:
	assert_bool(_run.buy(_slot_of(_gatling), Vector2i(1, 0))).is_true() # (1, 0)-(1, 2), 10 -> 6
	# Grabbed by its bottom cell, the drag remembers the cell and the grab.
	var drag: PartDragData = _grid_ui._get_drag_data(_cell_center(Vector2i(1, 2)))
	assert_bool(drag.is_from_shop()).is_false()
	assert_that(drag.from_cell).is_equal(Vector2i(1, 2))
	assert_that(drag.grab_offset).is_equal(Vector2i(0, 2))
	# Dropped with that cell on (2, 3), it fills (2, 1)-(2, 3), for free.
	assert_bool(_grid_ui._can_drop_data(_cell_center(Vector2i(2, 3)), drag)).is_true()
	assert_str(_grid_ui.get_preview_text()).is_equal("Move here")
	_grid_ui._drop_data(_cell_center(Vector2i(2, 3)), drag)
	assert_object(_run.grid.get_part_at(Vector2i(2, 1))).is_not_null()
	assert_object(_run.grid.get_part_at(Vector2i(1, 0))).is_null()
	assert_int(_run.gold).is_equal(6)
	assert_object(_grid_ui._get_drag_data(_cell_center(Vector2i(3, 1)))).is_null() # nothing there
	await await_idle_frame()


func test_parts_carry_no_text_and_pop_up_their_details_on_hover() -> void:
	assert_bool(_run.buy(_slot_of(_gatling), Vector2i(1, 1))).is_true() # (1, 1)-(1, 3), 10 -> 6
	assert_array(_grid_ui.find_children("*", "Label", true, false)).is_empty()
	var tip := _grid_ui._get_tooltip(_cell_center(Vector2i(1, 2)))
	assert_str(tip).is_equal("Twin Gatling\nWeapon · 1×3\n8 DMG · -3 EN")
	var popup: PartInfo = auto_free(_grid_ui._make_custom_tooltip(tip))
	assert_str("\n".join(popup.get_rows())).is_equal(tip)
	# Once a heatsink cools it, the popup shows the linked numbers.
	assert_bool(_run.buy(_slot_of(_heatsink), Vector2i(2, 1))).is_true() # (2, 1), (2, 2), (3, 2)
	assert_str(_grid_ui._get_tooltip(_cell_center(Vector2i(1, 2)))) \
		.is_equal("Twin Gatling\nWeapon · 1×3\n12 DMG · -3 EN\nCooled ×1.5")
	# Empty cells show nothing, and neither does a part while it's dragged.
	assert_str(_grid_ui._get_tooltip(_cell_center(Vector2i(1, 0)))).is_empty()
	_grid_ui._get_drag_data(_cell_center(Vector2i(1, 2)))
	assert_str(_grid_ui._get_tooltip(_cell_center(Vector2i(1, 2)))).is_empty()
	await await_idle_frame() # free the rotate buttons the buys replaced


func test_rotate_buttons_turn_parts_in_place() -> void:
	assert_bool(_run.buy(_slot_of(_gatling), Vector2i(1, 1))).is_true() # (1, 1)-(1, 3)
	# Its button sits on its top-right cell and turns it on its side, about its top-left.
	assert_that(_cell_under(_rotate_buttons()[0])).is_equal(Vector2i(1, 1))
	_rotate_buttons()[0].pressed.emit()
	for cell: Vector2i in [Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1)]:
		assert_object(_run.grid.get_part_at(cell)).is_not_null()
	assert_that(_cell_under(_rotate_buttons()[0])).is_equal(Vector2i(3, 1))
	# With a laser at (1, 2), there's no room to stand it back up.
	assert_bool(_run.buy(_slot_of(_laser), Vector2i(1, 2))).is_true()
	assert_array(_rotate_buttons()).has_size(1) # the 1x1 laser has none
	_rotate_buttons()[0].pressed.emit()
	assert_array(_messages.back()).contains_exactly(["No room to rotate here", false])
	assert_object(_run.grid.get_part_at(Vector2i(3, 1))).is_not_null()
	await await_idle_frame()


func test_leaving_the_grid_clears_the_preview() -> void:
	assert_bool(_grid_ui._can_drop_data(_cell_center(Vector2i(1, 1)), _shop_drag(_gatling))).is_true()
	_grid_ui.notification(Control.NOTIFICATION_MOUSE_EXIT)
	assert_str(_grid_ui.get_preview_text()).is_empty()
	assert_object(_previews.back()).is_null()
	# Only part drags are accepted at all.
	assert_bool(_grid_ui._can_drop_data(_cell_center(Vector2i(1, 1)), "text")).is_false()


func _shop_drag(part: MechPart) -> PartDragData:
	return PartDragData.from_shop(_slot_of(part), part, 0)


func _slot_of(part: MechPart) -> int:
	for i in _run.slots.size():
		if _run.slots[i].part == part:
			return i
	return -1


func _rotate_buttons() -> Array[Node]:
	return _grid_ui.find_children("*", "Button", true, false)


func _cell_under(control: Control) -> Vector2i:
	return Vector2i(((control.position + control.size / 2) / MechGridUI.CELL_PITCH).floor())


func _cell_center(cell: Vector2i) -> Vector2:
	return Vector2(cell) * MechGridUI.CELL_PITCH + Vector2.ONE * MechGridUI.CELL_SIZE / 2
