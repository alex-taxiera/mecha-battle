class_name RunHud
extends HBoxContainer
## The run at a glance, along the top of the screens between fights: the sector and floor, the
## relics found, the hull's HP, and gold. Follows its [RunState] as it changes.

const TEXT_COLOR := Color(0.93, 0.94, 0.96)
const DIM_COLOR := Color(0.72, 0.74, 0.78)
const GOLD_COLOR := Color(0.96, 0.83, 0.43)
const HP_COLOR := Color("#5fd38a")
const LOW_HP_COLOR := Color("#ff4d4d")
## Below this share of max HP, the bar turns red.
const LOW_HP := 0.3

var run: RunState:
	set(value):
		if run and run.changed.is_connected(refresh):
			run.changed.disconnect(refresh)
		run = value
		if run:
			run.changed.connect(refresh)
		refresh()

var sector_label := Label.new()
var floor_label := Label.new()
var hp_bar := ProgressBar.new()
var hp_label := Label.new()
var gold_label := Label.new()
## The run's relics, then its statuses, one icon each.
var relic_bar := HBoxContainer.new()


func _init() -> void:
	add_theme_constant_override("separation", 24)
	var place := VBoxContainer.new()
	place.add_theme_constant_override("separation", 0)
	place.size_flags_horizontal = SIZE_EXPAND_FILL
	_style(sector_label, 22, TEXT_COLOR)
	_style(floor_label, 12, DIM_COLOR)
	place.add_child(floor_label)
	place.add_child(sector_label)
	add_child(place)
	relic_bar.add_theme_constant_override("separation", 6)
	relic_bar.size_flags_vertical = SIZE_SHRINK_CENTER
	add_child(relic_bar)

	var hull := VBoxContainer.new()
	hull.add_theme_constant_override("separation", 2)
	hull.size_flags_vertical = SIZE_SHRINK_CENTER
	_style(hp_label, 13, TEXT_COLOR)
	hull.add_child(hp_label)
	hp_bar.custom_minimum_size = Vector2(220, 14)
	hp_bar.show_percentage = false
	hull.add_child(hp_bar)
	add_child(hull)

	_style(gold_label, 18, GOLD_COLOR)
	gold_label.size_flags_vertical = SIZE_SHRINK_CENTER
	gold_label.custom_minimum_size.x = 110
	gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(gold_label)


## Shows the run as it is now.
func refresh() -> void:
	if run == null:
		return
	var act := run.get_act()
	var sector := "Sector %d of %d" % [run.act_index + 1, run.acts.size()] if act else "Run"
	floor_label.text = sector if run.get_floor_number() == 0 else "%s · Floor %d" % [sector, run.get_floor_number()]
	sector_label.text = act.sector_name if act else run.grid.chassis.chassis_name
	var max_hp := run.get_max_hp()
	var hp := run.get_current_hp()
	hp_label.text = "Hull %d / %d HP" % [hp, max_hp]
	hp_bar.max_value = maxi(max_hp, 1)
	hp_bar.value = hp
	var fill := StyleBoxFlat.new()
	fill.bg_color = LOW_HP_COLOR if hp < max_hp * LOW_HP else HP_COLOR
	hp_bar.add_theme_stylebox_override("fill", fill)
	gold_label.text = "%d gold" % run.gold
	for icon in relic_bar.get_children():
		relic_bar.remove_child(icon)
		icon.queue_free()
	for relic in run.relics:
		relic_bar.add_child(RelicIcon.new(relic))
	for status in run.statuses:
		relic_bar.add_child(RelicIcon.new(status))


func _style(label: Label, font_size: int, color: Color) -> void:
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
