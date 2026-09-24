class_name MechGridUITest
extends GdUnitTestSuite

const __source: String = "res://src/ui/MechGridUI.gd"
const SCENE := preload("res://src/ui/MechGridUI.tscn")
const Fixtures := preload("res://test/TestFixtures.gd")

var _gatling: MechPart # 1x3 vertical arm weapon, 4 gold
var _laser: MechPart   # 1x1, 2 gold
var _reactor: MechPart # 2x1, 3 gold
var _heatsink: MechPart # L, 4 gold
var _run: RunState
var _grid_ui: MechGridUI
var _previews: Array[MechStats] = []
var _messages: Array = []


func before_test() -> void:
	_gatling = Fixtures.gatling()
	_laser = Fixtures.laser()
	_reactor = Fixtures.reactor()
	_heatsink = Fixtures.heatsink()
	# The armed cross: a left arm at (-1, 1)-(-1, 3), a right arm at (4, 1)-(4, 3), and a 2x2
	# back at (1, -2)-(2, -1).
	_run = RunState.new(Fixtures.armed_cross(), [_gatling, _laser, _reactor, _heatsink], Fixtures.rules(), 10, RunRng.new(7))
	_run.open_shop()
	_grid_ui = auto_free(SCENE.instantiate())
	_grid_ui.run = _run
	add_child(_grid_ui)
	_previews = []
	_messages = []
	_grid_ui.preview_changed.connect(func(stats: MechStats) -> void: _previews.append(stats))
	_grid_ui.message.connect(func(text: String, good: bool) -> void: _messages.append([text, good]))


func test_lays_out_the_frame_and_its_bays() -> void:
	# The bays reach one column left of the frame and two rows above it: 6 cells each way.
	var side := 6 * MechGridUI.CELL_PITCH - MechGridUI.CELL_GAP
	assert_that(_grid_ui.get_combined_minimum_size()).is_equal(Vector2(side, side))
	# The back's top-left bay cell is two in from the left, at the top.
	var half := MechGridUI.CELL_SIZE / 2
	assert_that(_grid_ui.cell_center(Vector2i(1, -2))).is_equal(Vector2(2 * MechGridUI.CELL_PITCH + half, half))
	assert_that(_grid_ui.cell_at(Vector2(half, half))).is_equal(Vector2i(-1, -2))
	assert_that(_grid_ui.cell_at(_grid_ui.cell_center(Vector2i(3, 2)))).is_equal(Vector2i(3, 2))


func test_hovering_a_shop_part_previews_the_buy() -> void:
	var drag := _shop_drag(_heatsink)
	# At (1, 1), (1, 2), (2, 2) it fits, lights its open edges, and reports the stats it would give.
	assert_bool(_grid_ui._can_drop_data(_cell_center(Vector2i(1, 1)), drag)).is_true()
	assert_str(_grid_ui.get_preview_text()).is_equal("Install · -4g")
	assert_array(_grid_ui.get_shown_edges()).has_size(7).contains_exactly_in_any_order(
		Vector2i(1, 0), Vector2i(0, 1), Vector2i(2, 1), Vector2i(0, 2), Vector2i(3, 2), Vector2i(1, 3), Vector2i(2, 3))
	assert_int(_previews.back().hp).is_equal(30)
	# Where it doesn't fit, it says why, lights nothing, and clears the preview stats.
	assert_bool(_grid_ui._can_drop_data(_cell_center(Vector2i(1, 3)), drag)).is_false()
	assert_str(_grid_ui.get_preview_text()).is_equal("Doesn't fit on the chassis")
	assert_array(_grid_ui.get_shown_edges()).is_empty()
	assert_object(_previews.back()).is_null()
	assert_bool(_grid_ui._can_drop_data(_cell_center(Vector2i(0, 2)), drag)).is_false()
	assert_str(_grid_ui.get_preview_text()).is_equal("No frame there")
	# Hovering buys nothing.
	assert_int(_run.gold).is_equal(10)


func test_a_weapon_snaps_into_any_cell_of_a_bay() -> void:
	# Held by its bottom cell, over the left arm's top cell: unsnapped it would hang off the top.
	var drag := PartDragData.from_shop(_slot_of(_gatling), _gatling, 0, Vector2i(0, 2))
	assert_bool(_grid_ui._can_drop_data(_cell_center(Vector2i(-1, 1)), drag)).is_true()
	assert_str(_grid_ui.get_preview_text()).is_equal("Install · -4g")
	# The frame cells touching the bay light up: a part there would link with the gun.
	assert_array(_grid_ui.get_shown_edges()).has_size(2).contains_exactly_in_any_order(Vector2i(0, 1), Vector2i(0, 2))
	assert_int(_previews.back().damage).is_equal(8)
	# The frame, a bay of another shape, and a weapon's bay for anything else say why not.
	assert_bool(_grid_ui._can_drop_data(_cell_center(Vector2i(2, 3)), drag)).is_false() # (2, 1)-(2, 3)
	assert_str(_grid_ui.get_preview_text()).is_equal("Weapons mount on hardpoints")
	# Held there, reaching up into the back bay from (1, 1), it's the wrong shape for it.
	assert_bool(_grid_ui._can_drop_data(_cell_center(Vector2i(1, 1)), drag)).is_false() # (1, -1)-(1, 1)
	assert_str(_grid_ui.get_preview_text()).is_equal("Doesn't fit this hardpoint")
	assert_bool(_grid_ui._can_drop_data(_cell_center(Vector2i(2, -1)), drag)).is_false()
	assert_str(_grid_ui.get_preview_text()).is_equal("Doesn't fit this hardpoint")
	assert_bool(_grid_ui._can_drop_data(_cell_center(Vector2i(-1, 2)), _shop_drag(_laser))).is_false()
	assert_str(_grid_ui.get_preview_text()).is_equal("Only weapons mount here")
	# Dropped on the right arm's bottom cell, it mounts in the right arm.
	_grid_ui._drop_data(_cell_center(Vector2i(4, 3)), drag)
	assert_object(_run.grid.get_placement_at(Vector2i(4, 1)).part).is_not_null()
	assert_that(_run.grid.get_placement_at(Vector2i(4, 1)).origin).is_equal(Vector2i(4, 1))
	assert_int(_run.gold).is_equal(6)
	assert_array(_messages).contains_exactly([["Installed Twin Gatling · -4g", true]])
	await await_idle_frame()


func test_dragging_a_weapon_lights_the_bays_it_fits() -> void:
	var left_arm := _run.grid.chassis.hardpoints[0]
	var right_arm := _run.grid.chassis.hardpoints[1]
	_grid_ui.show_open_bays(_shop_drag(_gatling))
	assert_array(_grid_ui.get_open_bays()).has_size(2).contains_same_exactly_in_any_order([left_arm, right_arm])
	# Not for other parts, and not once the drag ends.
	_grid_ui.show_open_bays(_shop_drag(_laser))
	assert_array(_grid_ui.get_open_bays()).is_empty()
	_grid_ui.show_open_bays(_shop_drag(_gatling))
	_grid_ui.show_open_bays(null)
	assert_array(_grid_ui.get_open_bays()).is_empty()
	# A mounted weapon being moved can go back where it was, or to the other arm.
	assert_bool(_run.buy(_slot_of(_gatling), left_arm.origin)).is_true()
	var drag: PartDragData = _grid_ui._get_drag_data(_cell_center(Vector2i(-1, 2)))
	_grid_ui.show_open_bays(drag)
	assert_array(_grid_ui.get_open_bays()).has_size(2).contains_same_exactly_in_any_order([left_arm, right_arm])
	await await_idle_frame()


func test_occupied_and_unaffordable_spots_say_why() -> void:
	assert_bool(_run.buy(_slot_of(_laser), Vector2i(1, 2))).is_true() # 10 -> 8
	var drag := _shop_drag(_heatsink)
	assert_bool(_grid_ui._can_drop_data(_cell_center(Vector2i(1, 1)), drag)).is_false()
	assert_str(_grid_ui.get_preview_text()).is_equal("Those slots are occupied")
	# Short of gold, a spot that fits still lights its edges but won't take the drop.
	_run.gold = 3
	assert_bool(_grid_ui._can_drop_data(_cell_center(Vector2i(2, 0)), drag)).is_false()
	assert_str(_grid_ui.get_preview_text()).is_equal("Not enough gold (need 4g)")
	assert_array(_grid_ui.get_shown_edges()).is_not_empty()
	await await_idle_frame()


func test_dropping_a_shop_part_buys_it() -> void:
	var drag := _shop_drag(_heatsink)
	assert_bool(_grid_ui._can_drop_data(_cell_center(Vector2i(1, 1)), drag)).is_true()
	_grid_ui._drop_data(_cell_center(Vector2i(1, 1)), drag)
	assert_str(_run.grid.get_part_at(Vector2i(2, 2)).part_name).is_equal(_heatsink.part_name)
	assert_int(_run.gold).is_equal(6)
	assert_array(_messages).contains_exactly([["Installed L-Shaped Heatsink · -4g", true]])
	# The new part's open edges stay lit for a moment.
	assert_array(_grid_ui.get_shown_edges()).has_size(7)
	await await_idle_frame()


func test_dropping_a_stashed_part_installs_it() -> void:
	_run.stash_part(_heatsink, 1) # turned once: XX over X.
	var drag := PartDragData.from_stash(0, _run.stash[0].part, 1)
	# At (2, 2) turned, it fits; upright it would have hit the corner.
	assert_bool(_grid_ui._can_drop_data(_cell_center(Vector2i(2, 2)), drag)).is_true()
	assert_str(_grid_ui.get_preview_text()).is_equal("Install")
	assert_bool(_grid_ui._can_drop_data(_cell_center(Vector2i(3, 3)), drag)).is_false()
	_grid_ui._drop_data(_cell_center(Vector2i(2, 2)), drag)
	assert_object(_run.grid.get_part_at(Vector2i(3, 2))).is_not_null()
	assert_array(_run.stash).is_empty()
	assert_int(_run.gold).is_equal(10) # installing is free
	assert_array(_messages).contains_exactly([["Installed L-Shaped Heatsink from the stash", true]])
	await await_idle_frame()


func test_dragging_a_stashed_weapon_lights_the_bays_it_fits() -> void:
	_run.stash_part(_gatling)
	_grid_ui.show_open_bays(PartDragData.from_stash(0, _run.stash[0].part, 0))
	assert_array(_grid_ui.get_open_bays().map(func(bay: Hardpoint) -> String: return bay.id)) \
		.contains_exactly_in_any_order(["left_arm", "right_arm"])


func test_dropping_a_copy_onto_a_part_merges_them() -> void:
	assert_bool(_run.grid.place_part(Fixtures.laser(), Vector2i(1, 1))).is_true()
	_run.stash_part(Fixtures.laser())
	var drag := PartDragData.from_stash(0, _run.stash[0].part, 0)
	assert_bool(_grid_ui._can_drop_data(_cell_center(Vector2i(1, 1)), drag)).is_true()
	assert_str(_grid_ui.get_preview_text()).is_equal("Merge → Mk II")
	_grid_ui._drop_data(_cell_center(Vector2i(1, 1)), drag)
	assert_int(_run.grid.get_part_at(Vector2i(1, 1)).level).is_equal(2)
	assert_array(_run.stash).is_empty()
	assert_array(_messages).contains_exactly([["Merged into Point-Defense Laser Mk II", true]])
	await await_idle_frame()


func test_a_part_that_cannot_merge_is_still_blocked() -> void:
	assert_bool(_run.grid.place_part(Fixtures.laser(), Vector2i(1, 1))).is_true()
	_run.stash_part(Fixtures.reactor())
	var drag := PartDragData.from_stash(0, _run.stash[0].part, 0)
	assert_bool(_grid_ui._can_drop_data(_cell_center(Vector2i(1, 1)), drag)).is_false()
	assert_str(_grid_ui.get_preview_text()).is_equal("Those slots are occupied")


func test_merging_installed_and_shop_parts() -> void:
	assert_bool(_run.grid.place_part(Fixtures.laser(), Vector2i(1, 1))).is_true()
	assert_bool(_run.grid.place_part(Fixtures.laser(), Vector2i(2, 2))).is_true()
	var from_grid := _grid_ui._get_drag_data(_cell_center(Vector2i(2, 2))) as PartDragData
	assert_bool(_grid_ui._can_drop_data(_cell_center(Vector2i(1, 1)), from_grid)).is_true()
	_grid_ui._drop_data(_cell_center(Vector2i(1, 1)), from_grid)
	assert_object(_run.grid.get_part_at(Vector2i(2, 2))).is_null()
	var target := _run.grid.get_part_at(Vector2i(1, 1))
	assert_int(target.level).is_equal(2)
	# A shop laser onto a Mk I laser buys and merges.
	assert_bool(_run.grid.place_part(Fixtures.laser(), Vector2i(2, 2))).is_true()
	var shop_drag := _shop_drag(_laser)
	assert_bool(_grid_ui._can_drop_data(_cell_center(Vector2i(2, 2)), shop_drag)).is_true()
	assert_str(_grid_ui.get_preview_text()).is_equal("Merge → Mk II · -2g")
	_grid_ui._drop_data(_cell_center(Vector2i(2, 2)), shop_drag)
	assert_int(_run.grid.get_part_at(Vector2i(2, 2)).level).is_equal(2)
	assert_int(_run.gold).is_equal(8)
	await await_idle_frame()


func test_dragging_an_installed_part_moves_it() -> void:
	assert_bool(_run.buy(_slot_of(_heatsink), Vector2i(1, 0))).is_true() # (1, 0), (1, 1), (2, 1); 10 -> 6
	# Grabbed by its foot, the drag remembers the cell and the grab.
	var drag: PartDragData = _grid_ui._get_drag_data(_cell_center(Vector2i(2, 1)))
	assert_bool(drag.is_from_shop()).is_false()
	assert_that(drag.from_cell).is_equal(Vector2i(2, 1))
	assert_that(drag.grab_offset).is_equal(Vector2i(1, 1))
	# Dropped with its foot on (2, 3), it fills (1, 2), (1, 3), (2, 3), for free.
	assert_bool(_grid_ui._can_drop_data(_cell_center(Vector2i(2, 3)), drag)).is_true()
	assert_str(_grid_ui.get_preview_text()).is_equal("Move here")
	_grid_ui._drop_data(_cell_center(Vector2i(2, 3)), drag)
	assert_object(_run.grid.get_part_at(Vector2i(1, 3))).is_not_null()
	assert_object(_run.grid.get_part_at(Vector2i(1, 0))).is_null()
	assert_int(_run.gold).is_equal(6)
	assert_object(_grid_ui._get_drag_data(_cell_center(Vector2i(3, 1)))).is_null() # nothing there
	await await_idle_frame()


func test_dragging_a_mounted_weapon_moves_it_between_arms() -> void:
	assert_bool(_run.buy(_slot_of(_gatling), Vector2i(-1, 1))).is_true() # 10 -> 6
	var drag: PartDragData = _grid_ui._get_drag_data(_cell_center(Vector2i(-1, 3)))
	assert_that(drag.from_cell).is_equal(Vector2i(-1, 3))
	# Over any cell of the right arm, it snaps into it.
	assert_bool(_grid_ui._can_drop_data(_cell_center(Vector2i(4, 1)), drag)).is_true()
	assert_str(_grid_ui.get_preview_text()).is_equal("Move here")
	_grid_ui._drop_data(_cell_center(Vector2i(4, 1)), drag)
	assert_object(_run.grid.get_part_at(Vector2i(4, 3))).is_not_null()
	assert_object(_run.grid.get_part_at(Vector2i(-1, 1))).is_null()
	assert_int(_run.gold).is_equal(6)
	await await_idle_frame()


func test_parts_carry_no_text_and_pop_up_their_details_on_hover() -> void:
	assert_bool(_run.buy(_slot_of(_gatling), Vector2i(-1, 1))).is_true() # the left arm, 10 -> 6
	assert_array(_grid_ui.find_children("*", "Label", true, false)).is_empty()
	var tip := _grid_ui._get_tooltip(_cell_center(Vector2i(-1, 2)))
	assert_str(tip).is_equal("Twin Gatling\nWeapon · 1×3\n8 DMG · -3 EN")
	var popup: PartInfo = auto_free(_grid_ui._make_custom_tooltip(tip))
	assert_str("\n".join(popup.get_rows())).is_equal(tip)
	# Once a heatsink touching its bay cools it, the popup shows the linked numbers.
	assert_bool(_run.buy(_slot_of(_heatsink), Vector2i(0, 1))).is_true() # (0, 1), (0, 2), (1, 2)
	assert_str(_grid_ui._get_tooltip(_cell_center(Vector2i(-1, 2)))) \
		.is_equal("Twin Gatling\nWeapon · 1×3\n12 DMG · -3 EN\nCooled ×1.5")
	# Empty cells show nothing, and neither does a part while it's dragged.
	assert_str(_grid_ui._get_tooltip(_cell_center(Vector2i(1, 0)))).is_empty()
	_grid_ui._get_drag_data(_cell_center(Vector2i(-1, 2)))
	assert_str(_grid_ui._get_tooltip(_cell_center(Vector2i(-1, 2)))).is_empty()
	await await_idle_frame() # free the rotate buttons the buys replaced


func test_empty_bays_say_what_they_mount() -> void:
	assert_str(_grid_ui._get_tooltip(_cell_center(Vector2i(4, 2)))).is_equal("Right Arm hardpoint\nMounts a 1×3 weapon")
	assert_str(_grid_ui._get_tooltip(_cell_center(Vector2i(2, -1)))).is_equal("Back hardpoint\nMounts a 2×2 weapon")
	# Godot shows these in its plain tooltip; parts get the PartInfo popup.
	assert_object(_grid_ui._make_custom_tooltip("Back hardpoint")).is_null()
	# Beside the bays, outside the frame, there's nothing to say.
	assert_str(_grid_ui._get_tooltip(_cell_center(Vector2i(-1, -2)))).is_empty()


func test_rotate_buttons_turn_parts_in_place() -> void:
	assert_bool(_run.buy(_slot_of(_reactor), Vector2i(1, 1))).is_true() # (1, 1) (2, 1)
	# Its button sits on its top-right cell and stands it upright, about its top-left.
	assert_that(_cell_under(_rotate_buttons()[0])).is_equal(Vector2i(2, 1))
	_rotate_buttons()[0].pressed.emit()
	for cell: Vector2i in [Vector2i(1, 1), Vector2i(1, 2)]:
		assert_object(_run.grid.get_part_at(cell)).is_not_null()
	assert_that(_cell_under(_rotate_buttons()[0])).is_equal(Vector2i(1, 1))
	# With a laser at (2, 1), there's no room to lay it back down.
	assert_bool(_run.buy(_slot_of(_laser), Vector2i(2, 1))).is_true()
	# Weapons never turn, so a mounted gun gets no button either.
	assert_bool(_run.buy(_slot_of(_gatling), Vector2i(-1, 1))).is_true()
	assert_array(_rotate_buttons()).has_size(1) # the 1x1 laser and the gun have none
	_rotate_buttons()[0].pressed.emit()
	assert_array(_messages.back()).contains_exactly(["No room to rotate here", false])
	assert_object(_run.grid.get_part_at(Vector2i(1, 2))).is_not_null()
	await await_idle_frame()


func test_leaving_the_grid_clears_the_preview() -> void:
	assert_bool(_grid_ui._can_drop_data(_cell_center(Vector2i(1, 1)), _shop_drag(_heatsink))).is_true()
	_grid_ui.notification(Control.NOTIFICATION_MOUSE_EXIT)
	assert_str(_grid_ui.get_preview_text()).is_empty()
	assert_object(_previews.back()).is_null()
	# Only part drags are accepted at all.
	assert_bool(_grid_ui._can_drop_data(_cell_center(Vector2i(1, 1)), "text")).is_false()


func _shop_drag(part: MechPart) -> PartDragData:
	return PartDragData.from_shop(_slot_of(part), part, 0)


func _slot_of(part: MechPart) -> int:
	for i in _run.shop.slots.size():
		if _run.shop.slots[i].part == part:
			return i
	return -1


func _rotate_buttons() -> Array[Node]:
	return _grid_ui.find_children("*", "Button", true, false)


func _cell_under(control: Control) -> Vector2i:
	return _grid_ui.cell_at(control.position + control.size / 2)


func _cell_center(cell: Vector2i) -> Vector2:
	return _grid_ui.cell_center(cell)


func test_a_glowing_cell_opens_on_a_click() -> void:
	var chassis := Fixtures.armed_cross()
	chassis.size = Vector2i(4, 5)
	for x in 4:
		chassis.expansion_cells.append(Vector2i(x, 4))
	_run = RunState.new(chassis, [], Fixtures.rules(), 10)
	_grid_ui.run = _run
	# Locked, with nothing to open: the tooltip says how cells open, and clicks do nothing.
	var locked := Vector2i(1, 4)
	assert_str(_grid_ui.locked_text(locked)).contains("Hangars")
	assert_bool(_grid_ui.open_at(locked)).is_false()
	_run.grant_cells(1)
	assert_str(_grid_ui.locked_text(locked)).is_equal("Locked cell\nClick to open it (1 to open)")
	assert_bool(_grid_ui.open_at(locked)).is_true()
	assert_bool(_run.grid.chassis.is_usable(locked)).is_true()
	assert_array(_messages).contains([["Opened a cell on the frame", true]])
	await await_idle_frame()
