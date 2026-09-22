class_name PartDragData
extends RefCounted
## What a part carries while it is dragged onto a MechGridUI.

var part: MechPart
## The cell of [member MechPart.grid_shape] held under the cursor, so a drop lines up
## with the drag preview.
var grab_offset: Vector2i


func _init(p_part: MechPart, p_grab_offset := Vector2i.ZERO) -> void:
	part = p_part
	grab_offset = p_grab_offset
