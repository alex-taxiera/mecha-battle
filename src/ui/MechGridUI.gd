class_name MechGridUI
extends Control
## Draws a run's mech grid, with its hardpoint bays around it, and takes parts dragged onto it:
## bought from the shop, installed from the stash, or moved around. Dropped onto a copy of itself,
## a part merges into it, a Mk up. It never decides what fits or what anything is worth: it asks
## the [RunState] and draws the answer. Parts carry no text but their Mk; hovering one pops up its
## [PartInfo]. A weapon dragged over any cell of a bay snaps into that bay.

## Emitted when a drag's hover changes: the stats the drop would give, or null when nothing
## droppable is hovered.
signal preview_changed(stats: MechStats)
## Emitted with a short status line for the player, e.g. when a rotation has no room.
signal message(text: String, good: bool)

# Sized so the tallest layout, the Striker's 8 rows (with its back bay and its locked row), fits
# the shop's window beside the tallest shop cards.
const CELL_SIZE := 42.0
const CELL_GAP := 4.0
const CELL_PITCH := CELL_SIZE + CELL_GAP
## How long a newly placed part's open edges stay lit.
const FLASH_SECONDS := 1.6

const CELL_COLOR := Color(0.2, 0.22, 0.26)
const DISABLED_CELL_COLOR := Color(0.07, 0.07, 0.09)
## Locked cells the frame can grow into, and the ones that can open now while there are cells to
## open.
const LOCKED_CELL_COLOR := Color(0.11, 0.12, 0.15)
const LOCK_COLOR := Color(0.36, 0.39, 0.45)
const FRONTIER_COLOR := Color(0.49, 0.91, 0.94)
const BAY_COLOR := Color(0.16, 0.13, 0.14)
const BAY_EDGE_COLOR := Color(0.86, 0.33, 0.31, 0.45)
const OPEN_BAY_COLOR := Color(0.4, 1.0, 0.5)
const FITS_COLOR := Color(0.4, 1.0, 0.5, 0.45)
const BLOCKED_COLOR := Color(1.0, 0.35, 0.35, 0.45)
const EDGE_COLOR := Color(0.96, 0.83, 0.43)
const LABEL_FONT_SIZE := 11
const ROTATE_BUTTON_SIZE := 22.0
const MOVING_ALPHA := 0.3

const _FIT_REASONS := {
	MechGridData.Fit.OUT_OF_BOUNDS: "Doesn't fit on the chassis",
	MechGridData.Fit.DISABLED_CELL: "No frame there",
	MechGridData.Fit.OCCUPIED: "Those slots are occupied",
	MechGridData.Fit.NEEDS_HARDPOINT: "Weapons mount on hardpoints",
	MechGridData.Fit.WRONG_SHAPE: "Doesn't fit this hardpoint",
	MechGridData.Fit.WEAPONS_ONLY: "Only weapons mount here",
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
# The cells drawn: the frame and its bays. Bays sit outside the frame, so its top-left can be
# negative; it's drawn at the control's top-left.
var _layout: Rect2i
# While a weapon is dragged: the bays it could drop into.
var _open_bays: Array[Hardpoint] = []
# While a drag hovers the grid: the drag, the origin it would drop at, and what that would do.
var _drag: PartDragData
var _drag_origin: Vector2i
var _preview: RunState.Preview
# While a drag hovers a copy of itself: the cell it would merge into (see [member _merging]).
var _merge_cell: Vector2i
var _merging: bool:
	get:
		return _preview != null and _preview.merge
# The installed part being dragged away, drawn faded.
var _moving: MechGridData.Placement
# The installed part under the mouse, whose open edges are shown.
var _hovered: MechGridData.Placement
# Open edges lit briefly after a part is placed or moved.
var _flash_edges: Array[Vector2i] = []
var _flash_timer: Timer
# Each placement that can turn -> its rotate button.
var _rotate_buttons: Dictionary[MechGridData.Placement, RotateButton] = {}
# The placement the last tooltip request found, for the popup Godot asks for next.
var _tooltip_placement: MechGridData.Placement


func _ready() -> void:
	_flash_timer = Timer.new()
	_flash_timer.one_shot = true
	_flash_timer.timeout.connect(_end_flash)
	add_child(_flash_timer)


func _get_minimum_size() -> Vector2:
	if run == null:
		return Vector2.ZERO
	return Vector2(_layout.size) * CELL_PITCH - Vector2(CELL_GAP, CELL_GAP)


func _get_drag_data(at_position: Vector2) -> Variant:
	if run == null:
		return null
	var cell := cell_at(at_position)
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
	var origin := _drop_origin(at_position, drag)
	if drag != _drag or origin != _drag_origin:
		_drag = drag
		_drag_origin = origin
		if drag.is_from_shop():
			_preview = run.preview_buy(drag.slot_index, origin)
		elif drag.is_from_stash():
			_preview = run.preview_install(drag.stash_index, origin)
		else:
			_preview = run.preview_move(drag.from_cell, origin)
		# Over a copy of itself, the drop merges instead. An installed part frees its own cells.
		var from_cells: Variant = null
		if drag.is_from_grid():
			from_cells = drag.from_cell
		var merge := run.preview_merge(drag.part, cell_at(at_position), from_cells)
		if merge and _preview.fit != MechGridData.Fit.OK:
			merge.affordable = not drag.is_from_shop() or run.can_afford(drag.part)
			_preview = merge
			_merge_cell = cell_at(at_position)
		preview_changed.emit(_preview.stats if _accepts(_preview) else null)
		queue_redraw()
	return _accepts(_preview)


func _drop_data(at_position: Vector2, data: Variant) -> void:
	var drag: PartDragData = data
	var origin := _drop_origin(at_position, drag)
	var merge_cell := _merge_cell
	var merged := run.grid.get_part_at(merge_cell) if _merging else null
	_clear_preview()
	var first_cell := origin + drag.part.get_shape(drag.rotation)[0]
	if merged:
		var level := merged.level
		var done := false
		if drag.is_from_shop():
			done = run.buy_and_merge(drag.slot_index, merge_cell)
		elif drag.is_from_stash():
			done = run.merge_from_stash(drag.stash_index, merge_cell)
		else:
			done = run.merge_on_grid(drag.from_cell, merge_cell)
		if done:
			message.emit("Merged into %s" % merged.get_display_name(), true)
			_flash(merge_cell)
		elif level == merged.level:
			message.emit("Can't merge those", false)
		return
	if drag.is_from_shop():
		if run.buy(drag.slot_index, origin):
			message.emit("Installed %s · -%dg" % [drag.part.get_display_name(), run.price_of(drag.part)], true)
			_flash(first_cell)
	elif drag.is_from_stash():
		if run.install(drag.stash_index, origin):
			message.emit("Installed %s from the stash" % drag.part.get_display_name(), true)
			_flash(first_cell)
	elif run.move(drag.from_cell, origin):
		_flash(first_cell)


func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click and run and click.pressed and click.button_index == MOUSE_BUTTON_LEFT and open_at(cell_at(click.position)):
		accept_event()
		return
	var motion := event as InputEventMouseMotion
	if motion and run:
		var hovered := run.grid.get_placement_at(cell_at(motion.position))
		if hovered != _hovered:
			_hovered = hovered
			queue_redraw()


# Godot asks for the text under the mouse, then for the popup to show it in. A part's text
# changes with its links, so moving between parts with different numbers refreshes the popup.
# An empty bay says what it mounts, in Godot's plain tooltip.
func _get_tooltip(at_position: Vector2) -> String:
	_tooltip_placement = null
	if run == null or _moving or get_viewport().gui_is_dragging():
		return ""
	var cell := cell_at(at_position)
	_tooltip_placement = run.grid.get_placement_at(cell)
	if _tooltip_placement == null:
		if run.grid.chassis.is_locked(cell):
			return locked_text(cell)
		var hardpoint := run.grid.chassis.get_hardpoint_at(cell)
		return bay_text(hardpoint) if hardpoint else ""
	return PartInfo.text_for(_tooltip_placement.part, _tooltip_placement.rotation, _stats.part_stats[_tooltip_placement])


func _make_custom_tooltip(_for_text: String) -> Object:
	if _tooltip_placement == null:
		return null
	var placement := _tooltip_placement
	return PartInfo.new(placement.part, placement.rotation, _stats.part_stats[placement])


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_DRAG_BEGIN:
			show_open_bays(get_viewport().gui_get_drag_data())
		NOTIFICATION_DRAG_END:
			_set_moving(null)
			_clear_preview()
			show_open_bays(null)
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
			if chassis.is_usable(cell):
				draw_rect(_cell_rect(cell), CELL_COLOR)
			elif chassis.is_locked(cell):
				_draw_locked(cell)
			else:
				draw_rect(_cell_rect(cell), DISABLED_CELL_COLOR)
	if run.cells_to_open > 0:
		for cell in chassis.get_frontier():
			draw_rect(_cell_rect(cell).grow(-1.5), FRONTIER_COLOR, false, 3.0)
	for hardpoint in chassis.hardpoints:
		_draw_bay(hardpoint)
	for cell in _shown_edges():
		_draw_edge(cell)
	for placement in run.grid.get_placements():
		var color := PartShapeView.color_for(placement.part.type)
		if placement == _moving:
			color.a = MOVING_ALPHA
		var cells: Array[Vector2i] = []
		for cell in placement.cells:
			cells.append(cell - _layout.position)
		PartShapeView.draw_cells(self, cells, CELL_SIZE, CELL_GAP, color)
		if placement.part.level > 1:
			PartShapeView.draw_level(self, placement.part, _cell_rect(placement.cells[0]).position, 13)
	if _preview:
		var fill := FITS_COLOR if _accepts(_preview) else BLOCKED_COLOR
		for cell in _preview.cells:
			if _is_drawn(cell):
				draw_rect(_cell_rect(cell), fill)
	for link in _shown_links():
		_draw_link(link)
	if _preview:
		_draw_preview_label()


## Opens the locked [param cell] if the player has a cell to open and it's on the frontier.
## Returns whether it did.
func open_at(cell: Vector2i) -> bool:
	if not run.open_cell(cell):
		return false
	message.emit("Opened a cell on the frame", true)
	_flash(cell)
	return true


## Returns a locked cell's tooltip: how it opens, or that it can open now.
func locked_text(cell: Vector2i) -> String:
	if run.cells_to_open > 0 and cell in run.grid.chassis.get_frontier():
		return "Locked cell\nClick to open it (%d to open)" % run.cells_to_open
	return "Locked cell\nThe frame can grow here: Hangars, some events, and bosses let you open cells."


## Returns the words a hovered drop shows: what it does, or why it can't.
func get_preview_text() -> String:
	if _preview == null:
		return ""
	if _preview.fit != MechGridData.Fit.OK:
		return _FIT_REASONS[_preview.fit]
	if not _preview.affordable:
		return "Not enough gold (need %dg)" % run.price_of(_drag.part)
	if _preview.merge:
		var next := "Merge → Mk %s" % MechPart.NUMERALS[_drag.part.level]
		return "%s · -%dg" % [next, run.price_of(_drag.part)] if _drag.is_from_shop() else next
	if _drag.is_from_shop():
		return "Install · -%dg" % run.price_of(_drag.part)
	return "Install" if _drag.is_from_stash() else "Move here"


## Returns the open edges currently lit: around a droppable hover, else the part under the
## mouse, else a part just placed.
func get_shown_edges() -> Array[Vector2i]:
	return _shown_edges()


## Outlines the bays that [param drag]'s weapon could drop into. Called when any drag starts,
## and with null when it ends; anything but a dragged weapon lights no bays.
func show_open_bays(drag: Variant) -> void:
	_open_bays.clear()
	if run and drag is PartDragData and drag.part.type == MechPart.PartType.WEAPON:
		var moving: MechGridData.Placement = null
		if drag.is_from_grid():
			moving = run.grid.get_placement_at(drag.from_cell)
		_open_bays = run.grid.get_open_hardpoints(drag.part, moving)
	queue_redraw()


## Returns the bays outlined as open to the weapon being dragged.
func get_open_bays() -> Array[Hardpoint]:
	return _open_bays


## Returns the cell under [param at_position], in the frame's coordinates: bays to the left of
## or above the frame have negative ones.
func cell_at(at_position: Vector2) -> Vector2i:
	return Vector2i((at_position / CELL_PITCH).floor()) + _layout.position


## Returns the center of [param cell], in this control's coordinates.
func cell_center(cell: Vector2i) -> Vector2:
	return _cell_rect(cell).get_center()


## Returns what an empty bay's tooltip says, e.g. "Left Arm hardpoint\nMounts a 1×3 weapon".
static func bay_text(hardpoint: Hardpoint) -> String:
	var extent := PartShapeView.shape_extent(MechPart.normalized(hardpoint.shape))
	return "%s hardpoint\nMounts a %d×%d weapon" % [hardpoint.hardpoint_name, extent.x, extent.y]


func _on_run_changed() -> void:
	_stats = run.stats() if run else null
	_layout = run.grid.chassis.get_layout_rect() if run else Rect2i()
	# Moves and rotations replace placements, so drop references to old ones.
	_hovered = null
	_moving = null
	_tooltip_placement = null
	_rebuild_rotate_buttons()
	update_minimum_size()
	queue_redraw()


func _accepts(preview: RunState.Preview) -> bool:
	return preview != null and preview.fit == MechGridData.Fit.OK and preview.affordable


func _clear_preview() -> void:
	if _drag == null:
		return
	_drag = null
	_preview = null
	_merge_cell = Vector2i.ZERO
	preview_changed.emit(null)
	queue_redraw()


func _set_moving(placement: MechGridData.Placement) -> void:
	if _moving and _rotate_buttons.has(_moving):
		_rotate_buttons[_moving].modulate.a = 1.0
	_moving = placement
	if _moving and _rotate_buttons.has(_moving):
		_rotate_buttons[_moving].modulate.a = MOVING_ALPHA
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


func _rebuild_rotate_buttons() -> void:
	for button in _rotate_buttons.values():
		remove_child(button)
		button.queue_free()
	_rotate_buttons.clear()
	if run == null:
		return
	for placement in run.grid.get_placements():
		if placement.part.can_rotate():
			var button := _make_rotate_button(placement)
			add_child(button)
			_rotate_buttons[placement] = button


# A rotate button in the part's top-right corner: the last cell of its top row.
func _make_rotate_button(placement: MechGridData.Placement) -> RotateButton:
	var corner := placement.cells[0]
	for cell in placement.cells:
		if cell.y == corner.y:
			corner.x = maxi(corner.x, cell.x)
	var button := RotateButton.new()
	# PASS lets drags that start or drop on the button reach the grid.
	button.mouse_filter = MOUSE_FILTER_PASS
	button.custom_minimum_size = Vector2.ONE * ROTATE_BUTTON_SIZE
	button.size = button.custom_minimum_size
	button.position = _cell_rect(corner).position + Vector2(CELL_SIZE - ROTATE_BUTTON_SIZE - 4, 4)
	button.pressed.connect(_rotate.bind(placement.cells[0]))
	return button


# A bay's cells, set apart from the frame's by their color and a weapon-red border. While a
# weapon that fits it is dragged, the border lights up green.
# A locked cell: dim, with a small padlock.
func _draw_locked(cell: Vector2i) -> void:
	var rect := _cell_rect(cell)
	draw_rect(rect, LOCKED_CELL_COLOR)
	var center := rect.get_center()
	draw_rect(Rect2(center + Vector2(-7, -2), Vector2(14, 11)), LOCK_COLOR)
	draw_arc(center + Vector2(0, -3), 5.0, PI, TAU, 12, LOCK_COLOR, 2.0)


func _draw_bay(hardpoint: Hardpoint) -> void:
	var edge := OPEN_BAY_COLOR if hardpoint in _open_bays else BAY_EDGE_COLOR
	for cell in hardpoint.get_cells():
		var rect := _cell_rect(cell)
		draw_rect(rect, BAY_COLOR)
		draw_rect(rect.grow(-1), edge, false, 2.0)


# Where a drop at [param at_position] puts the dragged part's top-left: the grabbed cell stays
# under the cursor, except that a weapon over any cell of a bay snaps to that bay.
func _drop_origin(at_position: Vector2, drag: PartDragData) -> Vector2i:
	var cell := cell_at(at_position)
	var hardpoint := run.grid.chassis.get_hardpoint_at(cell)
	if hardpoint and drag.part.type == MechPart.PartType.WEAPON:
		return hardpoint.origin
	return cell - drag.grab_offset


func _draw_edge(cell: Vector2i) -> void:
	var rect := _cell_rect(cell).grow(-2)
	draw_rect(rect, Color(EDGE_COLOR, 0.13))
	var corners := [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
	for i in 4:
		draw_dashed_line(corners[i], corners[(i + 1) % 4], Color(EDGE_COLOR, 0.75), 2.0, 6.0)


# A dot in the rule's color on the edge the linked pair shares.
func _draw_link(link: MechStats.Link) -> void:
	var center := (cell_center(link.contact.cell_a) + cell_center(link.contact.cell_b)) / 2
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


# The first hovered cell drawn on the frame or a bay, else the cell under the cursor.
func _preview_label_cell() -> Vector2i:
	for cell in _preview.cells:
		if _is_drawn(cell):
			return cell
	return _drag_origin + _drag.grab_offset


# Whether [param cell] is drawn: inside the frame, disabled or not, or in a bay.
func _is_drawn(cell: Vector2i) -> bool:
	return run.grid.chassis.contains(cell) or run.grid.chassis.get_hardpoint_at(cell) != null


func _cell_rect(cell: Vector2i) -> Rect2:
	return Rect2(Vector2(cell - _layout.position) * CELL_PITCH, Vector2(CELL_SIZE, CELL_SIZE))
