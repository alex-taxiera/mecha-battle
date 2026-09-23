class_name MessageScreen
extends Control
## A plain full-screen message with one button: the run's HUD (when there's a run), a title,
## some lines of text, a column of options (for screens built on this one), and a button that
## emits [signal confirmed]. Shows sector clears and how a run ended.

## Emitted when the player presses the button.
signal confirmed

const THEME := preload("res://resources/ui/theme.tres")
const TEXT_COLOR := Color(0.93, 0.94, 0.96)
const DIM_COLOR := Color(0.72, 0.74, 0.78)

var hud := RunHud.new()
var title_label := Label.new()
var body_label := Label.new()
## Buttons for choices, added by screens built on this one. Hidden while empty.
var options := VBoxContainer.new()
var button := Button.new()


## Shows [param title] in [param color] over [param lines], with [param button_text] on the
## button. Pass the [param run] to show its HUD on top.
func _init(title := "", color := TEXT_COLOR, lines: PackedStringArray = [], button_text := "Continue", run: RunState = null) -> void:
	theme = THEME
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	margin.add_child(column)
	hud.run = run
	hud.visible = run != null
	column.add_child(hud)

	var center := CenterContainer.new()
	center.size_flags_vertical = SIZE_EXPAND_FILL
	column.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	box.custom_minimum_size.x = 520
	center.add_child(box)
	title_label.text = title
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 40)
	title_label.add_theme_color_override("font_color", color)
	box.add_child(title_label)
	body_label.text = "\n".join(lines)
	body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.add_theme_font_size_override("font_size", 16)
	body_label.add_theme_color_override("font_color", DIM_COLOR)
	box.add_child(body_label)
	options.add_theme_constant_override("separation", 10)
	options.visible = false
	box.add_child(options)
	button.text = button_text
	button.custom_minimum_size = Vector2(200, 44)
	button.size_flags_horizontal = SIZE_SHRINK_CENTER
	button.pressed.connect(confirmed.emit)
	box.add_child(button)


## Adds an option button reading [param label] over [param hint], calling [param action] when
## pressed (deferred, since options usually change the screen). Returns the button.
func add_option(label: String, hint: String, action: Callable) -> Button:
	var option := Button.new()
	option.text = "%s\n%s" % [label, hint] if not hint.is_empty() else label
	option.custom_minimum_size = Vector2(520, 56)
	option.pressed.connect(action, CONNECT_DEFERRED)
	options.add_child(option)
	options.visible = true
	return option
