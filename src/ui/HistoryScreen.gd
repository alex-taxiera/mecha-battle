class_name HistoryScreen
extends Control
## The profile's past runs, newest first: each run's mech in miniature, its frame, Threat, and how
## it ended, its MVP part, relics, date, and seed. Built in code. Back emits [signal closed].

signal closed

const THEME := preload("res://resources/ui/theme.tres")
const TITLE_COLOR := Color("#5aa9ff")
const TEXT_COLOR := Color(0.93, 0.94, 0.96)
const DIM_COLOR := Color(0.72, 0.74, 0.78)
const WIN_COLOR := Color("#5fd38a")
const LOSS_COLOR := Color("#ff4d4d")

var profile: Profile
var entries := VBoxContainer.new()
var back_button := Button.new()


func _init(p_profile: Profile = null) -> void:
	profile = p_profile
	theme = THEME
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	margin.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var title := _label("RUN HISTORY", 30, TITLE_COLOR)
	title.size_flags_horizontal = SIZE_EXPAND_FILL
	header.add_child(title)
	back_button.text = "Back"
	back_button.custom_minimum_size = Vector2(140, 40)
	back_button.pressed.connect(closed.emit)
	header.add_child(back_button)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	entries.size_flags_horizontal = SIZE_EXPAND_FILL
	entries.add_theme_constant_override("separation", 10)
	scroll.add_child(entries)
	if profile == null or profile.history.is_empty():
		entries.add_child(_label("No runs yet. Finish one and it shows up here.", 15, DIM_COLOR))
		return
	for entry in profile.history:
		entries.add_child(_make_entry(entry))


## Returns each entry's text, top to bottom, one entry per item.
func get_entry_texts() -> Array[PackedStringArray]:
	var texts: Array[PackedStringArray] = []
	for entry in entries.get_children():
		var lines := PackedStringArray()
		for node in entry.find_children("*", "Label", true, false):
			lines.append((node as Label).text)
		texts.append(lines)
	return texts


## Returns the lines an entry shows, e.g. "The Bastion · Threat 2 · Run complete".
static func entry_lines(entry: Dictionary) -> PackedStringArray:
	var won := bool(entry.get("won", false))
	var title: String = entry.get("chassis_name", "?")
	if int(entry.get("threat", 0)) > 0:
		title += " · Threat %d" % int(entry["threat"])
	title += " · %s" % ("Run complete" if won else "Mech destroyed")
	var place: String = entry.get("cause", "")
	if not won:
		var loop := int(entry.get("loop", 0))
		place += " · %sSector %d · Floor %d" % ["Loop %d · " % (loop + 1) if loop > 0 else "", int(entry.get("sector", 1)),
			int(entry.get("floor", 0))]
	var record := "Fights won %d" % int(entry.get("fights_won", 0))
	if not str(entry.get("mvp", "")).is_empty():
		record += " · MVP: %s (%d damage)" % [entry["mvp"], int(entry.get("mvp_damage", 0))]
	var relics: Array = entry.get("relics", [])
	var when := "%s · Seed %d" % [entry.get("date", ""), int(entry.get("seed", 0))]
	if not str(entry.get("daily", "")).is_empty():
		when += " · Daily run"
	return PackedStringArray([title, place, record, "Relics: %s" % (", ".join(relics) if not relics.is_empty() else "none"), when])


func _make_entry(entry: Dictionary) -> Control:
	var card := PanelContainer.new()
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	card.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	margin.add_child(row)
	var frame := CenterContainer.new()
	frame.custom_minimum_size = Vector2(90, 90)
	frame.add_child(HistoryGridView.new(entry.get("grid", [])))
	row.add_child(frame)
	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 2)
	text.size_flags_horizontal = SIZE_EXPAND_FILL
	row.add_child(text)
	var lines := entry_lines(entry)
	var won := bool(entry.get("won", false))
	text.add_child(_label(lines[0], 17, WIN_COLOR if won else LOSS_COLOR))
	for i in range(1, lines.size()):
		var line := _label(lines[i], 13, TEXT_COLOR if i < 3 else DIM_COLOR)
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.add_child(line)
	return card


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label
