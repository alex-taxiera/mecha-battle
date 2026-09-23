class_name PixelIconButton
extends BaseButton
## A button that's just a pixel icon with a hard dark outline, after the mockup's playback
## controls. It lifts a pixel when hovered and fades out when disabled.

## Each icon as [x, y, width, height] rects on a 16x16 grid, from the mockup.
const ICONS := {
	"pause": [[3, 2, 4, 12], [9, 2, 4, 12]],
	"play": [[3, 2, 2, 12], [5, 3, 2, 10], [7, 4, 2, 8], [9, 5, 2, 6], [11, 6, 2, 4], [13, 7, 1, 2]],
	"fast_forward": [[1, 3, 2, 10], [3, 4, 2, 8], [5, 5, 2, 6], [7, 6, 1, 4], [8, 3, 2, 10], [10, 4, 2, 8], [12, 5, 2, 6], [14, 6, 1, 4]],
	"skip": [[1, 3, 2, 10], [3, 4, 2, 8], [5, 5, 2, 6], [7, 6, 2, 4], [9, 3, 2, 10], [12, 3, 3, 10]],
}
## Screen pixels per icon grid unit.
const UNIT := 2
const OUTLINE := 2

## The icon to draw, a key of [constant ICONS].
@export var icon_name := "play":
	set(p_icon_name):
		icon_name = p_icon_name
		queue_redraw()
@export var color := Color("#d7dce5"):
	set(p_color):
		color = p_color
		queue_redraw()


func _init() -> void:
	# Space belongs to the screen's pause, so the buttons never take focus.
	focus_mode = FOCUS_NONE
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)


func _get_minimum_size() -> Vector2:
	return Vector2(48, 44)


func _draw() -> void:
	var rects: Array = ICONS.get(icon_name, [])
	var origin := ((size - Vector2(16, 16) * UNIT) / 2.0).floor()
	if is_hovered() and not disabled:
		origin.y -= 1
	var tint := Color(color, 0.4) if disabled else color
	for rect: Array in rects:
		draw_rect(_scaled(origin, rect).grow(OUTLINE), Color(CombatColors.NIGHT, tint.a))
	for rect: Array in rects:
		draw_rect(_scaled(origin, rect), tint)


func _scaled(origin: Vector2, rect: Array) -> Rect2:
	return Rect2(origin + Vector2(rect[0], rect[1]) * UNIT, Vector2(rect[2], rect[3]) * UNIT)
