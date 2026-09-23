class_name ResultPanel
extends Control
## The end of a fight, after the mockup's result modal: VICTORY, DEFEAT, or DRAW over the dimmed
## stage, where the run stands, the fight's numbers, and a button to carry on.

signal return_pressed

const THEME := preload("res://resources/ui/combat_theme.tres")
const TITLE_SIZE := 112
## Seconds the panel takes to rise in.
const APPEAR_TIME := 0.25

var title_label := Label.new()
var record_label := Label.new()
var return_button := Button.new()

var _center := CenterContainer.new()
var _column := VBoxContainer.new()
var _rows := VBoxContainer.new()


func _init() -> void:
	theme = THEME
	visible = false
	set_anchors_preset(PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.035, 0.055, 0.7)
	dim.set_anchors_preset(PRESET_FULL_RECT)
	add_child(dim)
	_center.set_anchors_preset(PRESET_FULL_RECT)
	add_child(_center)
	_column.add_theme_constant_override("separation", 22)
	_center.add_child(_column)
	title_label.theme_type_variation = &"PixelBoldLabel"
	title_label.add_theme_font_size_override("font_size", TITLE_SIZE)
	title_label.add_theme_constant_override("outline_size", 16)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_column.add_child(title_label)
	record_label.theme_type_variation = &"PixelLabel"
	record_label.add_theme_font_size_override("font_size", 16)
	record_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_column.add_child(record_label)
	var stats := PanelContainer.new()
	stats.custom_minimum_size = Vector2(506, 0)
	stats.size_flags_horizontal = SIZE_SHRINK_CENTER
	stats.add_theme_stylebox_override("panel", _stats_style())
	stats.add_child(_rows)
	_column.add_child(stats)
	return_button.text = "CONTINUE"
	return_button.size_flags_horizontal = SIZE_SHRINK_CENTER
	_style_button(return_button)
	return_button.pressed.connect(return_pressed.emit)
	_column.add_child(return_button)


## Shows the result: [param title] in [param color], the [param record] line, and [param stats]
## as [label, value] rows.
func present(title: String, color: Color, record: String, stats: Array) -> void:
	title_label.text = title
	title_label.add_theme_color_override("font_color", color)
	record_label.text = record
	for row in _rows.get_children():
		_rows.remove_child(row)
		row.queue_free()
	for stat: Array in stats:
		_rows.add_child(_row(stat[0], stat[1]))
	visible = true
	if is_inside_tree():
		return_button.grab_focus()
		_center.modulate.a = 0.0
		_center.position.y = 14.0
		var rise := create_tween().set_parallel().set_ease(Tween.EASE_OUT)
		rise.tween_property(_center, "modulate:a", 1.0, APPEAR_TIME)
		rise.tween_property(_center, "position:y", 0.0, APPEAR_TIME)


## Returns the rows shown, as [label, value] pairs.
func get_rows() -> Array:
	return _rows.get_children().map(func(row: Node) -> Array: return [row.get_child(0).text, row.get_child(1).text])


func _row(label: String, value: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	var key := Label.new()
	key.text = label
	key.size_flags_horizontal = SIZE_EXPAND_FILL
	key.add_theme_font_size_override("font_size", 20)
	key.add_theme_color_override("font_color", CombatColors.DIM)
	key.add_theme_constant_override("outline_size", 0)
	var shown := Label.new()
	shown.text = value
	shown.theme_type_variation = &"MonoLabel"
	shown.add_theme_font_size_override("font_size", 20)
	shown.add_theme_constant_override("outline_size", 0)
	shown.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(key)
	row.add_child(shown)
	return row


func _stats_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = CombatColors.NIGHT
	style.border_color = CombatColors.FRAME
	style.set_border_width_all(3)
	style.set_content_margin_all(20)
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_offset = Vector2(0, 6)
	style.shadow_size = 1
	return style


# The mockup's yellow button: a dark ring and a thick dark base that shrinks when pressed.
func _style_button(button: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = CombatColors.TAG
	normal.border_color = CombatColors.NIGHT
	normal.set_border_width_all(4)
	normal.border_width_bottom = 12
	normal.content_margin_left = 32
	normal.content_margin_right = 32
	normal.content_margin_top = 16
	normal.content_margin_bottom = 12
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = CombatColors.TAG.lightened(0.15)
	var pressed: StyleBoxFlat = normal.duplicate()
	pressed.border_width_bottom = 4
	pressed.border_width_top = 12
	pressed.bg_color = CombatColors.TAG.darkened(0.08)
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.border_color = CombatColors.PLAYER
	focus.set_border_width_all(2)
	focus.set_expand_margin_all(4)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("hover_pressed", pressed)
	button.add_theme_stylebox_override("focus", focus)
	button.add_theme_font_override("font", CombatDraw.PIXEL_FONT)
	button.add_theme_font_size_override("font_size", 16)
	for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		button.add_theme_color_override(color_name, CombatColors.NIGHT)
