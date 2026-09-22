class_name ShopItem
extends PanelContainer
## One part for sale. Dragging it onto the mech grid buys it.

var part: MechPart
## Unaffordable items are greyed out and can't be dragged.
var affordable := true

@onready var _name_label: Label = %NameLabel
@onready var _shape_view: PartShapeView = %ShapeView
@onready var _info_label: Label = %InfoLabel


func _ready() -> void:
	_name_label.text = part.part_name
	_info_label.text = "%s · %d gold" % [MechPart.PartType.find_key(part.type).capitalize(), part.cost]
	_shape_view.part = part
	mouse_default_cursor_shape = CURSOR_DRAG if affordable else CURSOR_FORBIDDEN
	if not affordable:
		modulate.a = 0.4
		tooltip_text = "Not enough gold"


func _get_drag_data(at_position: Vector2) -> Variant:
	if not affordable:
		return null
	var drag := PartDragData.new(part, _grab_offset_at(at_position))
	# Tests call this outside a real drag, where Godot won't accept a preview.
	if get_viewport().gui_is_dragging():
		set_drag_preview(_make_preview(drag.grab_offset))
	return drag


# The shape cell under the press, so the part stays held where it was grabbed.
func _grab_offset_at(at_position: Vector2) -> Vector2i:
	var local := at_position + global_position - _shape_view.global_position
	var cell := Vector2i((local / (_shape_view.cell_size + _shape_view.gap)).floor())
	return cell if cell in part.grid_shape else Vector2i.ZERO


func _make_preview(grab_offset: Vector2i) -> Control:
	var shape := PartShapeView.new()
	shape.cell_size = MechGridUI.CELL_SIZE
	shape.gap = MechGridUI.CELL_GAP
	shape.part = part
	shape.modulate.a = 0.75
	# Godot pins the preview's top-left to the cursor, so offset the shape inside it to
	# put the grabbed cell's center under the cursor instead.
	shape.position = -(Vector2(grab_offset) * MechGridUI.CELL_PITCH + Vector2.ONE * MechGridUI.CELL_SIZE / 2)
	var preview := Control.new()
	preview.mouse_filter = MOUSE_FILTER_IGNORE
	preview.add_child(shape)
	return preview
