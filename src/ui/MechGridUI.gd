class_name MechGridUI
extends Control
## Draws a run's mech grid and takes parts dragged onto it: bought from the shop or moved
## around the grid. It never decides what fits or what anything is worth: it asks the
## [RunState] and draws the answer.

## Emitted when a drag's hover changes: the stats the drop would give, or null when nothing
## droppable is hovered.
signal preview_changed(stats: MechStats)
## Emitted with a short status line for the player, e.g. when a rotation has no room.
signal message(text: String, good: bool)

const CELL_SIZE := 80.0
const CELL_GAP := 4.0
const CELL_PITCH := CELL_SIZE + CELL_GAP
## How long a newly placed part's open edges stay lit.
const FLASH_SECONDS := 1.6

const CELL_COLOR := Color(0.2, 0.22, 0.26)
const DISABLED_CELL_COLOR := Color(0.07, 0.07, 0.09)
const FITS_COLOR := Color(0.4, 1.0, 0.5, 0.45)
const BLOCKED_COLOR := Color(1.0, 0.35, 0.35, 0.45)
const EDGE_COLOR := Color(0.96, 0.83, 0.43)
const LABEL_COLOR := Color(0.0, 0.0, 0.0, 0.85)
const LABEL_FONT_SIZE := 11
const MOVING_ALPHA := 0.3

const _FIT_REASONS := {
	MechGridData.Fit.OUT_OF_BOUNDS: "Doesn't fit on the chassis",
	MechGridData.Fit.DISABLED_CELL: "No frame there",
	MechGridData.Fit.OCCUPIED: "Those slots are occupied",
}

var run: RunState:
	set(value):
		if run:
			run.changed.disconnect(_on_run_changed)
		run = value
		if run:
			run.changed.connect(_on_run_changed)
		_on_run_changed()

# The run's current stats, refreshed on every change.
var _stats: MechStats
# While a drag hovers the grid: the drag, the origin it would drop at, and what that would do.
var _drag: PartDragData
var _drag_origin: Vector2i
var _preview: RunState.Preview
# The installed part being dragged away, drawn faded.
var _moving: MechGridData.Placement
# The installed part under the mouse, whose open edges are shown.
var _hovered: MechGridData.Placement
# Open edges lit briefly after a part is placed or moved.
var _flash_edges: Array[Vector2i] = []
var _flash_timer: Timer
# Each placement -> its overlay of name, stat line, bonuses, and rotate button.
var _overlays: Dictionary[MechGridData.Placement, Control] = {}


func _ready() -> void:
	_flash_timer = Timer.new()
	_flash_timer.one_shot = true
	_flash_timer.timeout.connect(_end_flash)
	add_child(_flash_timer)


func _get_minimum_size() -> Vector2:
	if run == null:
		return Vector2.ZERO
	return Vector2(run.grid.chassis.size) * CELL_PITCH - Vector2(CELL_GAP, CELL_GAP)


func _get_drag_data(at_position: Vector2) -> Variant:
	if run == null:
		return null
	var cell := _cell_at(at_position)
	var placement := run.grid.get_placement_at(cell)
	if placement == null:
		return null
	var drag := PartDragData.from_grid(cell, placement.part, placement.rotation, cell - placement.origin)
	# Tests call this outside a real drag, where Godot won't accept a preview.
	if get_viewport().gui_is_dragging():
		set_drag_preview(PartShapeView.make_drag_preview(placement.part, placement.rotation, drag.grab_offset))
	_set_moving(placement)
	return drag


func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if run == null or not data is PartDragData:
		return false
	var drag: PartDragData = data
	var origin := _cell_at(at_position) - drag.grab_offset
	if drag != _drag or origin != _drag_origin:
		_drag = drag
		_drag_origin = origin
		if drag.is_from_shop():
			_preview = run.preview_buy(drag.slot_index, origin)
		else:
			_preview = run.preview_move(drag.from_cell, origin)
		preview_changed.emit(_preview.stats if _accepts(_preview) else null)
		queue_redraw()
	return _accepts(_preview)


func _drop_data(at_position: Vector2, data: Variant) -> void:
	var drag: PartDragData = data
	var origin := _cell_at(at_position) - drag.grab_offset
	_clear_preview()
	var first_cell := origin + drag.part.get_shape(drag.rotation)[0]
	if drag.is_from_shop():
		if run.buy(drag.slot_index, origin):
			message.emit("Installed %s · -%dg" % [drag.part.part_name, drag.part.cost], true)
			_flash(first_cell)
	elif run.move(drag.from_cell, origin):
		_flash(first_cell)


func _gui_input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion and run:
		var hovered := run.grid.get_placement_at(_cell_at(motion.position))
		if hovered != _hovered:
			_hovered = hovered
			queue_redraw()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_DRAG_END:
			_set_moving(null)
			_clear_preview()
		NOTIFICATION_MOUSE_EXIT:
			_hovered = null
			_clear_preview()
			queue_redraw()


func _draw() -> void:
	if run == null:
		return
	var chassis := run.grid.chassis
	for y in chassis.size.y:
		for x in chassis.size.x:
			var cell := Vector2i(x, y)
			draw_rect(_cell_rect(cell), CELL_COLOR if chassis.is_usable(cell) else DISABLED_CELL_COLOR)
	for cell in _shown_edges():
		_draw_edge(cell)
	for placement in run.grid.get_placements():
		var color := PartShapeView.color_for(placement.part.type)
		if placement == _moving:
			color.a = MOVING_ALPHA
		PartShapeView.draw_cells(self, placement.cells, CELL_SIZE, CELL_GAP, color)
	if _preview:
		var fill := FITS_COLOR if _accepts(_preview) else BLOCKED_COLOR
		for cell in _preview.cells:
			if chassis.contains(cell):
				draw_rect(_cell_rect(cell), fill)
	for link in _shown_links():
		_draw_link(link)
	if _preview:
		_draw_preview_label()


## Returns the words a hovered drop shows: what it does, or why it can't.
func get_preview_text() -> String:
	if _preview == null:
		return ""
	if _preview.fit != MechGridData.Fit.OK:
		return _FIT_REASONS[_preview.fit]
	if not _preview.affordable:
		return "Not enough gold (need %dg)" % _drag.part.cost
	return "Install · -%dg" % _drag.part.cost if _drag.is_from_shop() else "Move here"


## Returns the open edges currently lit: around a droppable hover, else the part under the
## mouse, else a part just placed.
func get_shown_edges() -> Array[Vector2i]:
	return _shown_edges()


func _on_run_changed() -> void:
	_stats = run.stats() if run else null
	# Moves and rotations replace placements, so drop references to old ones.
	_hovered = null
	_moving = null
	_rebuild_overlays()
	update_minimum_size()
	queue_redraw()


func _accepts(preview: RunState.Preview) -> bool:
	return preview != null and preview.fit == MechGridData.Fit.OK and preview.affordable


func _clear_preview() -> void:
	if _drag == null:
		return
	_drag = null
	_preview = null
	preview_changed.emit(null)
	queue_redraw()


func _set_moving(placement: MechGridData.Placement) -> void:
	if _moving and _overlays.has(_moving):
		_overlays[_moving].modulate.a = 1.0
	_moving = placement
	if _moving and _overlays.has(_moving):
		_overlays[_moving].modulate.a = MOVING_ALPHA
	queue_redraw()


func _flash(cell: Vector2i) -> void:
	var placement := run.grid.get_placement_at(cell)
	if placement == null:
		return
	_flash_edges = run.grid.get_open_edges(placement.cells)
	_flash_timer.start(FLASH_SECONDS)
	queue_redraw()


func _end_flash() -> void:
	_flash_edges.clear()
	queue_redraw()


func _shown_edges() -> Array[Vector2i]:
	if _preview:
		return _preview.open_edges
	if _hovered:
		return run.grid.get_open_edges(_hovered.cells)
	return _flash_edges


# Links of the hovered drop if it's droppable, otherwise the mech's current links.
func _shown_links() -> Array[MechStats.Link]:
	if _accepts(_preview):
		return _preview.stats.links
	if _stats:
		return _stats.links
	return []


func _rotate(cell: Vector2i) -> void:
	if not run.rotate_placed(cell):
		message.emit("No room to rotate here", false)


func _rebuild_overlays() -> void:
	for overlay in _overlays.values():
		remove_child(overlay)
		overlay.queue_free()
	_overlays.clear()
	if run == null:
		return
	for placement in run.grid.get_placements():
		var overlay := _make_overlay(placement)
		add_child(overlay)
		_overlays[placement] = overlay


# The type tag, name, stat line, and bonuses shown over a placed part, plus its rotate button.
# The name gets its own line so the button never squeezes it on a one-cell-wide label.
func _make_overlay(placement: MechGridData.Placement) -> Control:
	var rect := _label_rect(placement)
	var box := VBoxContainer.new()
	box.mouse_filter = MOUSE_FILTER_IGNORE
	box.position = rect.position + Vector2(5, 3)
	box.size = rect.size - Vector2(10, 6)
	box.add_theme_constant_override("separation", 0)
	var header := HBoxContainer.new()
	header.mouse_filter = MOUSE_FILTER_IGNORE
	var tag := _overlay_label(PartShapeView.tag_for(placement.part.type))
	tag.size_flags_horizontal = SIZE_EXPAND_FILL
	tag.size_flags_vertical = SIZE_SHRINK_BEGIN
	header.add_child(tag)
	if placement.part.can_rotate():
		var rotate := RotateButton.new()
		# PASS lets drags that start or drop on the button reach the grid.
		rotate.mouse_filter = MOUSE_FILTER_PASS
		rotate.custom_minimum_size = Vector2(22, 22)
		rotate.size_flags_vertical = SIZE_SHRINK_BEGIN
		rotate.pressed.connect(_rotate.bind(placement.cells[0]))
		header.add_child(rotate)
	box.add_child(header)
	box.add_child(_overlay_label(placement.part.part_name))
	var numbers: MechStats.PartStats = _stats.part_stats[placement]
	box.add_child(_overlay_label(stat_line(numbers)))
	var bonuses := bonus_line(numbers)
	if not bonuses.is_empty():
		box.add_child(_overlay_label(bonuses))
	return box


func _overlay_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", LABEL_FONT_SIZE)
	label.add_theme_color_override("font_color", LABEL_COLOR)
	return label


## A part's numbers in a line, e.g. "17 DMG · -3 EN" or "+6 EN · +5 HP".
static func stat_line(numbers: MechStats.PartStats) -> String:
	var bits: PackedStringArray = []
	if numbers.damage:
		bits.append("%d DMG" % numbers.damage)
	if numbers.energy_draw:
		bits.append("-%d EN" % numbers.energy_draw)
	if numbers.energy:
		bits.append("+%d EN" % numbers.energy)
	if numbers.hp:
		bits.append("+%d HP" % numbers.hp)
	if not bits.is_empty():
		return " · ".join(bits)
	return "Links: %d" % numbers.links if numbers.links else "Not linked"


## The bonuses a part gets from its links, e.g. "Overcharge +3 · Cooled ×1.5".
static func bonus_line(numbers: MechStats.PartStats) -> String:
	var bits: PackedStringArray = []
	for rule: SynergyRule in numbers.bonuses:
		var amount := numbers.bonuses[rule]
		var shown := str(roundi(amount)) if is_equal_approx(amount, roundf(amount)) else str(amount)
		var op := "×" if rule.op == SynergyRule.Op.MULTIPLY else "+"
		bits.append("%s %s%s" % [rule.id.capitalize(), op, shown])
	return " · ".join(bits)


# Rectangular parts label their whole block; others label their first cell.
func _label_rect(placement: MechGridData.Placement) -> Rect2:
	var shape := placement.part.get_shape(placement.rotation)
	var extent := PartShapeView.shape_extent(shape)
	if extent.x * extent.y != shape.size():
		return _cell_rect(placement.cells[0])
	return Rect2(Vector2(placement.origin) * CELL_PITCH, Vector2(extent) * CELL_PITCH - Vector2(CELL_GAP, CELL_GAP))


func _draw_edge(cell: Vector2i) -> void:
	var rect := _cell_rect(cell).grow(-2)
	draw_rect(rect, Color(EDGE_COLOR, 0.13))
	var corners := [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
	for i in 4:
		draw_dashed_line(corners[i], corners[(i + 1) % 4], Color(EDGE_COLOR, 0.75), 2.0, 6.0)


# A dot in the rule's color on the edge the linked pair shares.
func _draw_link(link: MechStats.Link) -> void:
	var center := (_cell_center(link.contact.cell_a) + _cell_center(link.contact.cell_b)) / 2
	draw_circle(center, 9.0, DISABLED_CELL_COLOR)
	draw_circle(center, 7.0, link.rule.color)
	draw_line(center - Vector2(3.5, 0), center + Vector2(3.5, 0), DISABLED_CELL_COLOR, 2.0)
	draw_line(center - Vector2(0, 3.5), center + Vector2(0, 3.5), DISABLED_CELL_COLOR, 2.0)


func _draw_preview_label() -> void:
	var text := get_preview_text()
	var font := get_theme_default_font()
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE)
	var anchor := _cell_rect(_preview_label_cell()).position + Vector2(4, 4)
	draw_rect(Rect2(anchor, text_size + Vector2(8, 4)), Color(0.07, 0.08, 0.09, 0.9))
	var color := Color(0.49, 0.88, 0.63) if _accepts(_preview) else Color(0.94, 0.42, 0.42)
	draw_string(font, anchor + Vector2(4, 2 + font.get_ascent(LABEL_FONT_SIZE)), text, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE, color)


# The first hovered cell inside the chassis, else the cell under the cursor.
func _preview_label_cell() -> Vector2i:
	for cell in _preview.cells:
		if run.grid.chassis.contains(cell):
			return cell
	return _drag_origin + _drag.grab_offset


func _cell_at(at_position: Vector2) -> Vector2i:
	return Vector2i((at_position / CELL_PITCH).floor())


func _cell_rect(cell: Vector2i) -> Rect2:
	return Rect2(Vector2(cell) * CELL_PITCH, Vector2(CELL_SIZE, CELL_SIZE))


func _cell_center(cell: Vector2i) -> Vector2:
	return Vector2(cell) * CELL_PITCH + Vector2.ONE * CELL_SIZE / 2
