class_name ChassisSelectScreen
extends Control
## Where a run starts: one card per chassis with its playstyle, slot layout, stats, and passive.
## Choosing one emits [signal chassis_chosen].

## Emitted when the player picks the frame to start the run with.
signal chassis_chosen(chassis: MechChassis)

const CHASSIS_DIR := "res://resources/chassis"
## Frames in the order the design lists them, by id. Any others follow, by id.
const ORDER := ["bastion", "striker", "reactor"]
const TEXT_COLOR := Color(0.93, 0.94, 0.96)
const DIM_COLOR := Color(0.72, 0.74, 0.78)
const PASSIVE_COLOR := Color(0.96, 0.83, 0.43)
# Tall enough for the tallest layout, so every card's text lines up.
const PREVIEW_HEIGHT := 5 * 25.0

## The frames to choose from. Left empty, every MechChassis in [constant CHASSIS_DIR].
@export var options: Array[MechChassis] = []

@onready var _cards: Container = %Cards


func _ready() -> void:
	if options.is_empty():
		var loaded := ShopScreen.load_dir(CHASSIS_DIR).filter(func(resource: Resource) -> bool: return resource is MechChassis)
		loaded.sort_custom(_listed_before)
		options.assign(loaded)
	for chassis in options:
		_cards.add_child(_make_card(chassis))


## Starts the run with [param chassis].
func choose(chassis: MechChassis) -> void:
	chassis_chosen.emit(chassis)


## Returns each card's text, top to bottom, one card per entry.
func get_card_texts() -> Array[PackedStringArray]:
	var texts: Array[PackedStringArray] = []
	for card in _cards.get_children():
		var lines := PackedStringArray()
		for node in card.find_children("*", "", true, false):
			if node is Label or node is Button:
				lines.append(node.text)
		texts.append(lines)
	return texts


## A frame's numbers in a line, e.g. "45 HP · 2 EN a turn · 12 slots".
static func stats_line(chassis: MechChassis) -> String:
	return "%d HP · %d EN a turn · %d slots" % [chassis.base_hp, chassis.base_energy, chassis.get_usable_cell_count()]


func _make_card(chassis: MechChassis) -> Control:
	var card := PanelContainer.new()
	card.size_flags_horizontal = SIZE_EXPAND_FILL
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	card.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)
	box.add_child(_label(chassis.chassis_name, 22, TEXT_COLOR))
	box.add_child(_label(chassis.playstyle, 13, DIM_COLOR))
	var frame := CenterContainer.new()
	frame.custom_minimum_size.y = PREVIEW_HEIGHT
	var preview := ChassisPreview.new()
	preview.chassis = chassis
	frame.add_child(preview)
	box.add_child(frame)
	box.add_child(_label(stats_line(chassis), 14, TEXT_COLOR))
	box.add_child(_label(chassis.passive_name, 16, PASSIVE_COLOR))
	var passive := _label(chassis.passive_text, 13, DIM_COLOR)
	passive.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	passive.size_flags_vertical = SIZE_EXPAND_FILL
	box.add_child(passive)
	var button := Button.new()
	button.text = "Choose %s" % chassis.chassis_name
	button.custom_minimum_size.y = 40
	button.pressed.connect(choose.bind(chassis))
	box.add_child(button)
	return card


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


# Listed frames first in ORDER; the rest after, by id.
static func _listed_before(a: MechChassis, b: MechChassis) -> bool:
	var rank_a := ORDER.find(a.id)
	var rank_b := ORDER.find(b.id)
	if rank_a == -1:
		rank_a = ORDER.size()
	if rank_b == -1:
		rank_b = ORDER.size()
	if rank_a != rank_b:
		return rank_a < rank_b
	return a.id < b.id
