class_name RotateButton
extends Button
## A small square button that draws its own clockwise arrow, so it needs no icon file or glyph.


func _init() -> void:
	custom_minimum_size = Vector2(26, 26)
	tooltip_text = "Rotate"


func _draw() -> void:
	var color := get_theme_color("font_color")
	var center := size / 2
	var radius := minf(size.x, size.y) * 0.26
	var start := -PI / 2 + 0.5
	var end := start + TAU * 0.78
	draw_arc(center, radius, start, end, 20, color, 1.8, true)
	# Arrowhead at the end of the arc, pointing the way it turns.
	var tip := center + Vector2.from_angle(end) * radius
	var ahead := Vector2.from_angle(end + PI / 2)
	var outward := Vector2.from_angle(end)
	draw_colored_polygon(PackedVector2Array([tip + ahead * 4.0, tip - outward * 3.2, tip + outward * 3.2]), color)
