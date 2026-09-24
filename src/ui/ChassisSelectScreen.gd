class_name ChassisSelectScreen
extends Control
## Where a run starts: one card per chassis with its playstyle, slot layout, stats, and passive.
## Choosing one emits [signal chassis_chosen]. With a profile, frames it hasn't unlocked are
## greyed out with how to earn them, and a footer shows its totals and a Reset progress button.
## Each card has a -/+ picker for the run's Threat level, up to the highest the frame has
## unlocked, and the footer has checkboxes for the custom modes. The picker follows
## Slay-The-Robot's NewRunMenu (MIT, DesirePathGames), clamping the new level rather than the old
## one and keeping a level per frame.

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
const THREAT_COLOR := Color(0.96, 0.55, 0.36)

## The frames to choose from. Left empty, every MechChassis in [constant CHASSIS_DIR].
@export var options: Array[MechChassis] = []
## The player's progress and the game's unlocks, for locking frames. Without a profile nothing
## is locked. Set them with [method set_locks] once the screen is up.
var profile: Profile
var unlocks: Array[Unlock] = []
## The Threat ladder, level 1 first. Empty hides the picker.
var threat_levels: Array[RunModifier] = []
## The custom modes offered as checkboxes. Empty hides them.
var custom_modifiers: Array[RunModifier] = []

# Chassis id -> the Threat level picked on its card, clamped again whenever it's read.
var _threats: Dictionary[String, int] = {}
var _customs_on: Array[RunModifier] = []
var _customs_row := HBoxContainer.new()

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


## Sets the Threat ladder and the custom modes, and redraws the cards.
func set_modifiers(p_threat_levels: Array[RunModifier], p_custom: Array[RunModifier]) -> void:
	threat_levels.assign(p_threat_levels)
	threat_levels.sort_custom(func(a: RunModifier, b: RunModifier) -> bool: return a.threat_level < b.threat_level)
	custom_modifiers.assign(p_custom)
	_customs_on.assign(_customs_on.filter(func(modifier: RunModifier) -> bool: return modifier in custom_modifiers))
	if is_node_ready():
		_build_cards()


## Returns the highest Threat [param chassis] can be played at: the highest its record unlocked
## (every level without a profile), as far as the ladder goes.
func get_max_threat(chassis: MechChassis) -> int:
	var unlocked := profile.get_threat_unlocked(chassis.id) if profile else threat_levels.size()
	return clampi(unlocked, 0, threat_levels.size())


## Returns the Threat picked for [param chassis], within what it has unlocked.
func get_threat(chassis: MechChassis) -> int:
	return clampi(_threats.get(chassis.id, 0), 0, get_max_threat(chassis))


## Picks Threat [param value] for [param chassis], clamped to what it has unlocked, and redraws.
func set_threat(chassis: MechChassis, value: int) -> void:
	_threats[chassis.id] = clampi(value, 0, get_max_threat(chassis))
	if is_node_ready():
		_build_cards()


## Turns the custom mode [param modifier] on or off; turning one on turns off those it excludes.
func set_custom(modifier: RunModifier, on: bool) -> void:
	_customs_on = RunModifier.toggle(_customs_on, modifier, on)
	if is_node_ready():
		_build_customs()


## Returns the custom modes turned on.
func get_custom_modifiers() -> Array[RunModifier]:
	return _customs_on.duplicate()


## Returns the modifiers a run on [param chassis] starts with: the Threat levels up to the one
## picked, then the custom modes turned on.
func get_run_modifiers(chassis: MechChassis) -> Array[RunModifier]:
	var modifiers := RunModifier.threat_stack(threat_levels, get_threat(chassis))
	modifiers.append_array(_customs_on)
	return modifiers


## Returns the words under a card's Threat picker: the level and what it adds, e.g.
## "Threat 2 · Shop prices +15%", with the lower levels it stacks on counted.
func threat_text(chassis: MechChassis) -> String:
	var threat := get_threat(chassis)
	if threat == 0:
		return "Threat 0 · the standard run"
	var top := threat_levels[threat - 1]
	return "Threat %d · %s%s" % [threat, top.description, " (+%d below)" % (threat - 1) if threat > 1 else ""]


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
	_build_customs()
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


## A frame's numbers in a line, e.g. "45 HP · 2 EN a turn · 12 slots (+4) · 1 hardpoint", the
## "+4" being the locked cells it can grow into.
static func stats_line(chassis: MechChassis) -> String:
	var hardpoints := chassis.hardpoints.size()
	var locked := chassis.get_locked_cells().size()
	var slots := "%d slots" % chassis.get_usable_cell_count() + (" (+%d)" % locked if locked > 0 else "")
	return "%d HP · %d EN a turn · %s · %d hardpoint%s" % [chassis.base_hp, chassis.base_energy, slots,
		hardpoints, "" if hardpoints == 1 else "s"]


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
	var lock := get_lock(chassis)
	if not threat_levels.is_empty() and lock == null:
		box.add_child(_make_threat_picker(chassis))
	var button := Button.new()
	button.text = "Choose %s" % chassis.chassis_name
	button.custom_minimum_size.y = 40
	button.pressed.connect(choose.bind(chassis))
	if lock:
		box.add_child(_label("Locked · %s" % lock.hint, 14, LOCKED_COLOR))
		button.text = "Locked"
		button.disabled = true
		preview.modulate = Color(1, 1, 1, 0.35)
	box.add_child(button)
	return card


# The -/+ Threat picker and what the picked level adds; its tooltip lists every level stacked.
func _make_threat_picker(chassis: MechChassis) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	var threat := get_threat(chassis)
	var highest := get_max_threat(chassis)
	var down := Button.new()
	down.text = "−"
	down.custom_minimum_size = Vector2(32, 28)
	down.disabled = threat <= 0
	down.pressed.connect(func() -> void: set_threat(chassis, threat - 1), CONNECT_DEFERRED)
	row.add_child(down)
	var level := _label("Threat %d" % threat, 16, THREAT_COLOR if threat > 0 else DIM_COLOR)
	level.custom_minimum_size.x = 80
	level.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(level)
	var up := Button.new()
	up.text = "+"
	up.custom_minimum_size = Vector2(32, 28)
	up.disabled = threat >= highest
	up.pressed.connect(func() -> void: set_threat(chassis, threat + 1), CONNECT_DEFERRED)
	row.add_child(up)
	if highest < threat_levels.size():
		up.tooltip_text = "Win a run at Threat %d to unlock Threat %d" % [highest, highest + 1]
		row.add_child(_label("Win at %d to unlock %d" % [highest, highest + 1], 12, DIM_COLOR))
	var summary := _label(threat_text(chassis), 12, DIM_COLOR)
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var lines := PackedStringArray()
	for modifier in RunModifier.threat_stack(threat_levels, threat):
		lines.append("%d · %s" % [modifier.threat_level, modifier.description])
	summary.tooltip_text = "\n".join(lines)
	summary.mouse_filter = MOUSE_FILTER_PASS
	box.add_child(summary)
	return box


# A checkbox per custom mode, in the footer.
func _build_customs() -> void:
	for box in _customs_row.get_children():
		_customs_row.remove_child(box)
		box.queue_free()
	_customs_row.visible = not custom_modifiers.is_empty()
	for modifier in custom_modifiers:
		var box := CheckBox.new()
		box.text = modifier.modifier_name
		box.tooltip_text = modifier.description
		box.button_pressed = modifier in _customs_on
		box.toggled.connect(func(on: bool) -> void: set_custom(modifier, on), CONNECT_DEFERRED)
		_customs_row.add_child(box)


# Totals and the Reset progress button, under the cards.
func _add_footer() -> void:
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 16)
	_stats_label.add_theme_font_size_override("font_size", 13)
	_stats_label.add_theme_color_override("font_color", DIM_COLOR)
	_stats_label.size_flags_horizontal = SIZE_EXPAND_FILL
	footer.add_child(_stats_label)
	_customs_row.add_theme_constant_override("separation", 12)
	footer.add_child(_customs_row)
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
