class_name StashPanel
extends PanelContainer
## The run's stash: spare parts, wrapping into rows that scroll. Drag one onto the mech to
## install it; drag an installed part here to take it off the mech and store it.

## Emitted with a short status line for the player, e.g. when a part is stored.
signal message(text: String, good: bool)

const TITLE_COLOR := Color(0.93, 0.94, 0.96)
const DIM_COLOR := Color(0.6, 0.63, 0.66)

var run: RunState:
	set(value):
		if run and run.changed.is_connected(refresh):
			run.changed.disconnect(refresh)
		run = value
		if run:
			run.changed.connect(refresh)
		refresh()

var title_label := Label.new()
var hint_label := Label.new()
var items := HFlowContainer.new()


func _init() -> void:
	custom_minimum_size.y = 150
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	margin.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.mouse_filter = MOUSE_FILTER_IGNORE
	margin.add_child(box)
	title_label.add_theme_font_size_override("font_size", 18)
	title_label.add_theme_color_override("font_color", TITLE_COLOR)
	box.add_child(title_label)
	hint_label.add_theme_font_size_override("font_size", 12)
	hint_label.add_theme_color_override("font_color", DIM_COLOR)
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(hint_label)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	box.add_child(scroll)
	items.add_theme_constant_override("h_separation", 10)
	items.add_theme_constant_override("v_separation", 10)
	items.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.add_child(items)


## Shows the stash as it is now.
func refresh() -> void:
	for item in items.get_children():
		items.remove_child(item)
		item.queue_free()
	if run == null:
		return
	title_label.text = "Stash · %d part%s" % [run.stash.size(), "" if run.stash.size() == 1 else "s"]
	if run.stash.is_empty():
		hint_label.text = "Parts from loot land here. Drag installed parts here to store them."
	else:
		hint_label.text = "Drag a part onto the mech to install it. Drag installed parts here to store them."
	for i in run.stash.size():
		var entry := run.stash[i]
		var item := StashItem.new(i, entry.part, entry.rotation)
		item.rotate_requested.connect(run.rotate_stashed.bind(i))
		items.add_child(item)


## Returns the stash's items, left to right.
func get_items() -> Array[StashItem]:
	var found: Array[StashItem] = []
	found.assign(items.get_children())
	return found


## Returns whether [param data] is an installed part that can be stored by dropping it here.
func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return run != null and data is PartDragData and data.is_from_grid()


## Stores the installed part being dropped here.
func _drop_data(_at_position: Vector2, data: Variant) -> void:
	var drag: PartDragData = data
	if run.unequip(drag.from_cell):
		message.emit("Stored %s in the stash" % drag.part.part_name, true)
