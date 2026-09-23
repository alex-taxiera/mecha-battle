class_name ShopItem
extends PanelContainer
## One shop slot. Dragging its part onto the mech grid buys it; a bought slot shows as sold.

## Emitted when the player asks to turn the offer a quarter-turn.
signal rotate_requested

const COST_COLOR := Color(0.94, 0.71, 0.24)
const TOO_EXPENSIVE_COLOR := Color(0.94, 0.42, 0.42)

var slot_index := -1
var part: MechPart
## Quarter-turns clockwise the offer is shown and bought at.
var turns := 0
var sold := false
## Unaffordable parts can still be dragged; the grid explains why they can't drop.
var affordable := true

@onready var _offer: Control = %Offer
@onready var _sold_label: Label = %SoldLabel
@onready var _name_label: Label = %NameLabel
@onready var _cost_label: Label = %CostLabel
@onready var _shape_view: PartShapeView = %ShapeView
@onready var _info_label: Label = %InfoLabel
@onready var _rotate_button: Button = %RotateButton
@onready var _description_label: Label = %DescriptionLabel


func _ready() -> void:
	_offer.visible = not sold
	_sold_label.visible = sold
	if sold:
		return
	_name_label.text = part.part_name
	_cost_label.text = "%dg" % part.cost
	_cost_label.add_theme_color_override("font_color", COST_COLOR if affordable else TOO_EXPENSIVE_COLOR)
	_shape_view.part = part
	_shape_view.turns = turns
	_info_label.text = PartInfo.summary(part, turns)
	_description_label.text = part.description
	_rotate_button.visible = part.can_rotate()
	_rotate_button.pressed.connect(rotate_requested.emit)
	mouse_default_cursor_shape = CURSOR_DRAG
	if not affordable:
		tooltip_text = "Not enough gold"


func _get_drag_data(at_position: Vector2) -> Variant:
	if sold:
		return null
	var drag := PartDragData.from_shop(slot_index, part, turns, _grab_offset_at(at_position))
	# Tests call this outside a real drag, where Godot won't accept a preview.
	if get_viewport().gui_is_dragging():
		set_drag_preview(PartShapeView.make_drag_preview(part, turns, drag.grab_offset))
	return drag


# The shape cell under the press, so the part stays held where it was grabbed.
func _grab_offset_at(at_position: Vector2) -> Vector2i:
	var local := at_position + global_position - _shape_view.global_position
	var cell := Vector2i((local / (_shape_view.cell_size + _shape_view.gap)).floor())
	return cell if cell in part.get_shape(turns) else Vector2i.ZERO
