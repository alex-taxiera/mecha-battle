class_name PartShapeView
extends Control
## Draws a MechPart's footprint as one connected block. The shop, the drag preview, and
## MechGridUI all draw parts through here so a part looks the same everywhere.

const TYPE_COLORS := {
	MechPart.PartType.WEAPON: Color(0.86, 0.33, 0.31),
	MechPart.PartType.GENERATOR: Color(0.94, 0.68, 0.31),
	MechPart.PartType.DEFENSE: Color(0.36, 0.61, 0.84),
	MechPart.PartType.UTILITY: Color(0.36, 0.72, 0.36),
	MechPart.PartType.JUNK: Color(0.45, 0.45, 0.48),
}

@export var cell_size := 20.0
@export var gap := 2.0

var part: MechPart:
	set(value):
		part = value
		update_minimum_size()
		queue_redraw()
## Quarter-turns clockwise to show the part at.
var turns := 0:
	set(value):
		turns = value
		update_minimum_size()
		queue_redraw()
## Draws the part as an outline over a faint fill, so what's beneath it shows through.
var ghost := false:
	set(value):
		ghost = value
		queue_redraw()


func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE


func _get_minimum_size() -> Vector2:
	if part == null or part.grid_shape.is_empty():
		return Vector2.ZERO
	return Vector2(shape_extent(part.get_shape(turns))) * (cell_size + gap) - Vector2(gap, gap)


func _draw() -> void:
	if part == null:
		return
	var shape := part.get_shape(turns)
	var color := color_for(part.type)
	if not ghost:
		draw_cells(self, shape, cell_size, gap, color)
		return
	draw_cells(self, shape, cell_size, gap, Color(color, 0.18))
	for cell in shape:
		draw_rect(Rect2(Vector2(cell) * (cell_size + gap), Vector2(cell_size, cell_size)), color, false, 2.0)


static func color_for(type: MechPart.PartType) -> Color:
	return TYPE_COLORS.get(type, Color.GRAY)

## Returns the width and height, in cells, of a shape anchored at (0, 0).
static func shape_extent(shape: Array[Vector2i]) -> Vector2i:
	var extent := Vector2i.ZERO
	for cell in shape:
		extent = extent.max(cell + Vector2i.ONE)
	return extent


## Returns a drag preview of [param p_part] at grid size, turned [param p_turns], placed so its
## [param grab_offset] cell sits under the cursor.
static func make_drag_preview(p_part: MechPart, p_turns: int, grab_offset: Vector2i) -> Control:
	var shape := PartShapeView.new()
	shape.cell_size = MechGridUI.CELL_SIZE
	shape.gap = MechGridUI.CELL_GAP
	shape.part = p_part
	shape.turns = p_turns
	shape.ghost = true
	# Godot pins the preview's top-left to the cursor, so offset the shape inside it to put the
	# grabbed cell's center under the cursor instead.
	shape.position = -(Vector2(grab_offset) * MechGridUI.CELL_PITCH + Vector2.ONE * MechGridUI.CELL_SIZE / 2)
	var preview := Control.new()
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.add_child(shape)
	return preview


## Fills each cell and the gaps between its orthogonal neighbours, so a multi-cell part
## reads as one piece while separate parts keep a gap between them.
static func draw_cells(canvas: CanvasItem, cells: Array[Vector2i], cell_px: float, gap_px: float, color: Color) -> void:
	var pitch := cell_px + gap_px
	for cell in cells:
		var top_left := Vector2(cell) * pitch
		canvas.draw_rect(Rect2(top_left, Vector2(cell_px, cell_px)), color)
		if cell + Vector2i.RIGHT in cells:
			canvas.draw_rect(Rect2(top_left + Vector2(cell_px, 0), Vector2(gap_px, cell_px)), color)
		if cell + Vector2i.DOWN in cells:
			canvas.draw_rect(Rect2(top_left + Vector2(0, cell_px), Vector2(cell_px, gap_px)), color)
