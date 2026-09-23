class_name StatsPanel
extends HBoxContainer
## The stats row under the grid: HP, energy, damage, and heat, each with the change a hovered
## drop would make, then the active links and the adjacency rules.

const UP_COLOR := Color(0.49, 0.88, 0.63)
const DOWN_COLOR := Color(0.94, 0.42, 0.42)
const NOTE_COLOR := Color(0.6, 0.63, 0.66)
const TEXT_COLOR := Color(0.91, 0.9, 0.88)
const NO_LINKS_TEXT := "No links yet. Parts link when they share an edge, and weapons with the parts touching their hardpoint. Open edges glow yellow while you drag or hover a part."


## The labels of one stat box.
class StatBox:
	var value: Label
	var delta: Label
	var note: Label


var hp: StatBox
var energy: StatBox
var damage: StatBox
var heat: StatBox

var _links: VBoxContainer
var _rules: VBoxContainer
# The stats the links list was last built from, to skip rebuilding it on every hover.
var _links_from: MechStats


func _init() -> void:
	add_theme_constant_override("separation", 12)
	hp = _add_stat_box("Hull HP", Color(0.5, 0.65, 0.86))
	energy = _add_stat_box("Energy / turn", Color(0.65, 0.55, 0.94))
	damage = _add_stat_box("Damage / turn", Color(0.93, 0.43, 0.32))
	heat = _add_stat_box("Heat / turn", Color(1.0, 0.54, 0.24))
	_links = _add_list_box("Active links", true)
	_rules = _add_list_box("Adjacency rules", false)


## Lists every adjacency rule with its color and effect.
func show_rules(rules: Array[SynergyRule]) -> void:
	_clear(_rules)
	for rule in rules:
		_rules.add_child(_rule_row(rule.color, rule.label, rule.effect_text))


## Shows [param current] stats, with the differences [param preview] would make when it's set.
func show_stats(current: MechStats, preview: MechStats) -> void:
	_set_stat(hp, str(current.hp), current.hp, preview.hp if preview else current.hp, "%d from chassis" % current.base_hp)
	_set_stat(energy, _signed(current.get_net_energy()), current.get_net_energy(),
		preview.get_net_energy() if preview else current.get_net_energy(),
		"%d generated · %d drawn" % [current.energy_generated, current.energy_drawn])
	energy.value.add_theme_color_override("font_color", DOWN_COLOR if current.get_net_energy() < 0 else TEXT_COLOR)
	_set_stat(damage, str(current.damage), current.damage, preview.damage if preview else current.damage, _power_text(current))
	damage.note.add_theme_color_override("font_color", DOWN_COLOR if current.energy_drawn and current.power < 1.0 else NOTE_COLOR)
	# More heat is worse: a rise shows red.
	_set_stat(heat, _signed(current.get_net_heat()), current.get_net_heat(),
		preview.get_net_heat() if preview else current.get_net_heat(),
		"%d made · %d vented" % [current.heat_made, current.heat_vented], false)
	heat.value.add_theme_color_override("font_color", DOWN_COLOR if current.get_net_heat() > 0 else TEXT_COLOR)
	if current != _links_from:
		_links_from = current
		_show_links(current)


## Returns the active links list as text, one entry per row: "label → effect ×count".
func get_link_rows() -> PackedStringArray:
	return _row_texts(_links)


## Returns the adjacency rules list as text, one entry per row: "label effect".
func get_rule_rows() -> PackedStringArray:
	return _row_texts(_rules)


static func _row_texts(list: Container) -> PackedStringArray:
	var rows: PackedStringArray = []
	for row in list.get_children():
		if row is Label:
			rows.append(row.text)
			continue
		var texts: PackedStringArray = []
		for child in row.get_children():
			if child is Label:
				texts.append(child.text)
		rows.append(" ".join(texts))
	return rows


func _show_links(current: MechStats) -> void:
	_clear(_links)
	var counts := current.get_rule_counts()
	if counts.is_empty():
		var hint := _label(NO_LINKS_TEXT, 13, NOTE_COLOR)
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_links.add_child(hint)
		return
	for rule: SynergyRule in counts:
		var row := _rule_row(rule.color, "%s → %s" % [rule.label, rule.effect_text], "×%d" % counts[rule], true)
		_links.add_child(row)


# Shows a stat and the change a preview would make: green for better, red for worse, where
# better is higher unless [param higher_is_better] is false.
func _set_stat(box: StatBox, text: String, now: int, then: int, note: String, higher_is_better := true) -> void:
	box.value.text = text
	var change := then - now
	box.delta.visible = change != 0
	box.delta.text = _signed(change)
	box.delta.add_theme_color_override("font_color", UP_COLOR if (change > 0) == higher_is_better else DOWN_COLOR)
	box.note.text = note


func _power_text(stats: MechStats) -> String:
	if stats.energy_drawn == 0:
		return "No weapons mounted"
	if stats.power < 1.0:
		return "Underpowered · %d%% fire rate" % roundi(stats.power * 100)
	return "Fully powered"


func _add_stat_box(title: String, title_color: Color) -> StatBox:
	var column := _add_panel(false)
	column.custom_minimum_size.x = 150
	column.add_child(_label(title.to_upper(), 12, title_color))
	var box := StatBox.new()
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	box.value = _label("", 30, TEXT_COLOR)
	box.delta = _label("", 16, UP_COLOR)
	row.add_child(box.value)
	row.add_child(box.delta)
	column.add_child(row)
	box.note = _label("", 12, NOTE_COLOR)
	column.add_child(box.note)
	return box


func _add_list_box(title: String, expand: bool) -> VBoxContainer:
	var column := _add_panel(expand)
	column.add_child(_label(title.to_upper(), 12, NOTE_COLOR))
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 4)
	column.add_child(list)
	return list


# A panel with padding; returns the column inside it.
func _add_panel(expand: bool) -> VBoxContainer:
	var panel := PanelContainer.new()
	if expand:
		panel.size_flags_horizontal = SIZE_EXPAND_FILL
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	margin.add_child(column)
	panel.add_child(margin)
	add_child(panel)
	return column


# A colored dot, [param text], and [param detail] at the end. With [param wraps], the text wraps
# to fit instead of widening the row.
func _rule_row(color: Color, text: String, detail: String, wraps := false) -> HBoxContainer:
	var row := HBoxContainer.new()
	var dot := ColorRect.new()
	dot.color = color
	dot.custom_minimum_size = Vector2(10, 10)
	dot.size_flags_vertical = SIZE_SHRINK_CENTER
	row.add_child(dot)
	var label := _label(text, 13, TEXT_COLOR)
	label.size_flags_horizontal = SIZE_EXPAND_FILL
	if wraps:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(label)
	row.add_child(_label(detail, 13, NOTE_COLOR))
	return row


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _clear(container: Container) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


static func _signed(value: int) -> String:
	return "+%d" % value if value > 0 else str(value)
