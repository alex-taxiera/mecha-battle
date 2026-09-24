class_name ChassisSelectScreen
extends Control
## Where a run starts: one card per chassis with its playstyle, slot layout, stats, and passive.
## Choosing one emits [signal chassis_chosen]. With a profile, frames it hasn't unlocked are
## greyed out with how to earn them, and a footer shows its totals and a Reset progress button.

## Emitted when the player picks the frame to start the run with.
signal chassis_chosen(chassis: MechChassis)
## Emitted when the player confirms resetting their progress.
signal reset_requested

const CHASSIS_DIR := "res://resources/chassis"
## Frames in the order the design lists them, by id. Any others follow, by id.
const ORDER := ["bastion", "striker", "reactor"]
const TEXT_COLOR := Color(0.93, 0.94, 0.96)
const DIM_COLOR := Color(0.72, 0.74, 0.78)
const PASSIVE_COLOR := Color(0.96, 0.83, 0.43)
const LOCKED_COLOR := Color(0.94, 0.42, 0.42)

## The frames to choose from. Left empty, every MechChassis in [constant CHASSIS_DIR].
@export var options: Array[MechChassis] = []
## The player's progress and the game's unlocks, for locking frames. Without a profile nothing
## is locked. Set them with [method set_locks] once the screen is up.
var profile: Profile
var unlocks: Array[Unlock] = []

var _stats_label := Label.new()
var _reset_button := Button.new()
var _reset_dialog := ConfirmationDialog.new()

@onready var _cards: Container = %Cards


func _ready() -> void:
	if options.is_empty():
		var loaded := LoadoutScreen.load_dir(CHASSIS_DIR).filter(func(resource: Resource) -> bool: return resource is MechChassis)
		loaded.sort_custom(_listed_before)
		options.assign(loaded)
	_add_footer()
	_build_cards()


## Sets the progress that decides which frames are locked, and redraws the cards.
func set_locks(p_profile: Profile, p_unlocks: Array[Unlock]) -> void:
	profile = p_profile
	unlocks.assign(p_unlocks)
	if is_node_ready():
		_build_cards()


## Returns the unlock [param chassis] is waiting on, or null if it can be chosen.
func get_lock(chassis: MechChassis) -> Unlock:
	return profile.get_lock(Unlock.Kind.CHASSIS, chassis.id, unlocks) if profile else null


## Asks to wipe the profile's progress (the game does it); the button confirms first.
func reset_progress() -> void:
	reset_requested.emit()


func _build_cards() -> void:
	for card in _cards.get_children():
		_cards.remove_child(card)
		card.queue_free()
	_stats_label.visible = profile != null
	_reset_button.visible = profile != null
	if profile:
		_stats_label.text = "Runs %d · Wins %d · Fights won %d · Bosses beaten %d" % [profile.runs, profile.wins,
			profile.fights_won, profile.bosses_beaten]
	# Every preview gets the tallest layout's height, so the text under them lines up.
	var previews: Array[ChassisPreview] = []
	var preview_height := 0.0
	for chassis in options:
		var preview := ChassisPreview.new()
		preview.chassis = chassis
		previews.append(preview)
		preview_height = maxf(preview_height, preview.get_minimum_size().y)
	for i in options.size():
		_cards.add_child(_make_card(options[i], previews[i], preview_height))


## Starts the run with [param chassis], unless it's locked.
func choose(chassis: MechChassis) -> void:
	if get_lock(chassis) == null:
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


## A frame's numbers in a line, e.g. "45 HP · 2 EN a turn · 12 slots · 1 hardpoint".
static func stats_line(chassis: MechChassis) -> String:
	var hardpoints := chassis.hardpoints.size()
	return "%d HP · %d EN a turn · %d slots · %d hardpoint%s" % [chassis.base_hp, chassis.base_energy,
		chassis.get_usable_cell_count(), hardpoints, "" if hardpoints == 1 else "s"]


func _make_card(chassis: MechChassis, preview: ChassisPreview, preview_height: float) -> Control:
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
	frame.custom_minimum_size.y = preview_height
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
	var lock := get_lock(chassis)
	if lock:
		box.add_child(_label("Locked · %s" % lock.hint, 14, LOCKED_COLOR))
		button.text = "Locked"
		button.disabled = true
		preview.modulate = Color(1, 1, 1, 0.35)
	box.add_child(button)
	return card


# Totals and the Reset progress button, under the cards.
func _add_footer() -> void:
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 16)
	_stats_label.add_theme_font_size_override("font_size", 13)
	_stats_label.add_theme_color_override("font_color", DIM_COLOR)
	_stats_label.size_flags_horizontal = SIZE_EXPAND_FILL
	footer.add_child(_stats_label)
	_reset_button.text = "Reset progress"
	_reset_button.pressed.connect(_reset_dialog.popup_centered)
	footer.add_child(_reset_button)
	_reset_dialog.title = "Reset progress?"
	_reset_dialog.dialog_text = "This forgets every unlock and total. It can't be undone."
	_reset_dialog.confirmed.connect(reset_progress)
	footer.add_child(_reset_dialog)
	_cards.get_parent().add_child(footer)


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
