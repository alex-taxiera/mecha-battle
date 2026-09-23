class_name PartDragData
extends RefCounted
## What a part carries while it's dragged: bought from a shop slot, or an installed part being
## moved around the grid or sold back to the shop.

var part: MechPart
## Quarter-turns clockwise the part is dragged at.
var rotation: int
## The cell of the turned shape held under the cursor, so a drop lines up with the preview.
var grab_offset: Vector2i
## The shop slot the part is bought from, or -1 for an installed part.
var slot_index := -1
## A cell of the installed part being dragged, when [member slot_index] is -1.
var from_cell: Vector2i


static func from_shop(p_slot_index: int, p_part: MechPart, p_rotation: int, p_grab_offset := Vector2i.ZERO) -> PartDragData:
	var drag := PartDragData.new()
	drag.slot_index = p_slot_index
	drag.part = p_part
	drag.rotation = p_rotation
	drag.grab_offset = p_grab_offset
	return drag


static func from_grid(p_from_cell: Vector2i, p_part: MechPart, p_rotation: int, p_grab_offset := Vector2i.ZERO) -> PartDragData:
	var drag := PartDragData.new()
	drag.from_cell = p_from_cell
	drag.part = p_part
	drag.rotation = p_rotation
	drag.grab_offset = p_grab_offset
	return drag


func is_from_shop() -> bool:
	return slot_index >= 0
