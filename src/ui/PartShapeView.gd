class_name PartShapeView
extends Control
## Draws a MechPart's footprint as one connected block. The shop, the drag preview, and
## MechGridUI all draw parts through here so a part looks the same everywhere.

const TYPE_COLORS := {
	MechPart.PartType.WEAPON: Color(0.86, 0.33, 0.31),
	MechPart.PartType.GENERATOR: Color(0.94, 0.68, 0.31),
	MechPart.PartType.DEFENSE: Color(0.36, 0.61, 0.84),
	MechPart.PartType.UTILITY: Color(0.36, 0.72, 0.36),
}

@export var cell_size := 20.0
@export var gap := 2.0

var part: MechPart:
	set(value):
		part = value
		update_minimum_size()
		queue_redraw()


func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE


func _get_minimum_size() -> Vector2:
	if part == null or part.grid_shape.is_empty():
		return Vector2.ZERO
	var extent := Vector2i.ZERO
	for cell in part.grid_shape:
		extent = extent.max(cell)
	return Vector2(extent + Vector2i.ONE) * (cell_size + gap) - Vector2(gap, gap)


func _draw() -> void:
	if part:
		draw_cells(self, part.grid_shape, cell_size, gap, color_for(part.type))


static func color_for(type: MechPart.PartType) -> Color:
	return TYPE_COLORS.get(type, Color.GRAY)


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
