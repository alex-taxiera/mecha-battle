class_name StashItem
extends PanelContainer
## One part in the stash: its shape, name, and size, and a rotate button when it can turn.
## Dragging it onto the mech installs it; dropping a copy of it here, from the stash or the mech,
## merges the two a Mk up.

## Emitted when the player asks to turn the part a quarter-turn.
signal rotate_requested
## Emitted when a copy of this part is dropped on it, to merge.
signal merge_requested(drag: PartDragData)

const NAME_COLOR := Color(0.93, 0.94, 0.96)
const DIM_COLOR := Color(0.6, 0.63, 0.66)

var stash_index := -1
var part: MechPart
## The stash the item sits in. Drops that aren't merges go to it, so storing and buying still work
## over an item.
var panel: StashPanel
## Quarter-turns clockwise the part is stashed at.
var turns := 0

var shape_view := PartShapeView.new()
var name_label := Label.new()
var info_label := Label.new()
var rotate_button := RotateButton.new()


func _init(p_stash_index := -1, p_part: MechPart = null, p_turns := 0) -> void:
	stash_index = p_stash_index
	part = p_part
	turns = p_turns
	custom_minimum_size = Vector2(170, 0)
	mouse_default_cursor_shape = CURSOR_DRAG
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	margin.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.mouse_filter = MOUSE_FILTER_IGNORE
	margin.add_child(box)
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", NAME_COLOR)
	box.add_child(name_label)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	body.mouse_filter = MOUSE_FILTER_IGNORE
	box.add_child(body)
	shape_view.cell_size = 14.0
	body.add_child(shape_view)
	info_label.add_theme_font_size_override("font_size", 11)
	info_label.add_theme_color_override("font_color", DIM_COLOR)
	info_label.size_flags_horizontal = SIZE_EXPAND_FILL
	body.add_child(info_label)
	rotate_button.size_flags_vertical = SIZE_SHRINK_BEGIN
	rotate_button.pressed.connect(rotate_requested.emit)
	body.add_child(rotate_button)
	if part:
		name_label.text = part.get_display_name()
		shape_view.part = part
		shape_view.turns = turns
		info_label.text = PartInfo.summary(part, turns)
		rotate_button.visible = part.can_rotate()
		tooltip_text = part.description


## Returns whether [param data] can drop here: a copy of this part, from the stash or the mech,
## to merge, or whatever the stash itself takes.
func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if _merges(data):
		return true
	return panel != null and panel._can_drop_data(at_position, data)


func _drop_data(at_position: Vector2, data: Variant) -> void:
	if _merges(data):
		merge_requested.emit(data)
	elif panel:
		panel._drop_data(at_position, data)


func _merges(data: Variant) -> bool:
	return data is PartDragData and not data.is_from_shop() and part != null and data.part.can_merge_with(part)


func _get_drag_data(at_position: Vector2) -> Variant:
	if part == null:
		return null
	var drag := PartDragData.from_stash(stash_index, part, turns, _grab_offset_at(at_position))
	# Tests call this outside a real drag, where Godot won't accept a preview.
	if get_viewport().gui_is_dragging():
		set_drag_preview(PartShapeView.make_drag_preview(part, turns, drag.grab_offset))
	return drag


# The shape cell under the press, so the part stays held where it was grabbed.
func _grab_offset_at(at_position: Vector2) -> Vector2i:
	var local := at_position + global_position - shape_view.global_position
	var cell := Vector2i((local / (shape_view.cell_size + shape_view.gap)).floor())
	return cell if cell in part.get_shape(turns) else Vector2i.ZERO
