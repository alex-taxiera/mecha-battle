class_name CombatDraw
extends RefCounted
## Fonts and drawing helpers for the combat screen's widgets, after the mockup's pixel look:
## framed bars, glossy fills, and text with a hard dark outline.

## Silkscreen is an 8-pixel font: sizes in multiples of 8 keep its pixels square.
const PIXEL_FONT := preload("res://assets/fonts/silkscreen/Silkscreen-Regular.ttf")
const PIXEL_BOLD_FONT := preload("res://assets/fonts/silkscreen/Silkscreen-Bold.ttf")
const BODY_FONT := preload("res://assets/fonts/chakra_petch/ChakraPetch-SemiBold.ttf")


## Draws [param text] in [param rect] with a hard [param outline]-pixel outline in
## [constant CombatColors.NIGHT], centered vertically and aligned by [param align].
static func text(canvas: CanvasItem, font: Font, rect: Rect2, value: String, font_size: int, color: Color,
		outline := 2, align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	var baseline := rect.position.y + (rect.size.y + font.get_ascent(font_size) - font.get_descent(font_size)) / 2.0
	text_at(canvas, font, Vector2(rect.position.x, roundf(baseline)), value, font_size, color, outline, align, rect.size.x)


## Draws [param text] with its baseline starting at [param pos] and a hard [param outline]-pixel
## outline. Pass [param width] to align it within that width.
static func text_at(canvas: CanvasItem, font: Font, pos: Vector2, value: String, font_size: int, color: Color,
		outline := 2, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	if outline > 0:
		for dx in [-outline, 0, outline]:
			for dy in [-outline, 0, outline]:
				if dx != 0 or dy != 0:
					canvas.draw_string(font, pos + Vector2(dx, dy), value, align, width, font_size, CombatColors.NIGHT)
	canvas.draw_string(font, pos, value, align, width, font_size, color)


## Returns how wide [param value] is in [param font] at [param font_size].
static func text_width(font: Font, value: String, font_size: int) -> float:
	return font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x


## Draws the mockup's frame around [param rect]: a [constant CombatColors.FRAME] ring, a
## [constant CombatColors.NIGHT] ring outside it, and a drop shadow, with [param rect] itself
## filled dark.
static func frame(canvas: CanvasItem, rect: Rect2, ring := 2.0) -> void:
	var outer := rect.grow(ring * 2.0)
	canvas.draw_rect(Rect2(outer.position + Vector2(0, 5), outer.size), Color(0, 0, 0, 0.35))
	canvas.draw_rect(outer, CombatColors.NIGHT)
	canvas.draw_rect(rect.grow(ring), CombatColors.FRAME)
	canvas.draw_rect(rect, CombatColors.NIGHT)


## Fills [param rect] with [param color] and the mockup's gloss: a light band along the top and
## a dark band along the bottom.
static func glossy(canvas: CanvasItem, rect: Rect2, color: Color, gloss := 3.0) -> void:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	canvas.draw_rect(rect, color)
	var band := minf(gloss, rect.size.y / 3.0)
	canvas.draw_rect(Rect2(rect.position, Vector2(rect.size.x, band)), Color(1, 1, 1, 0.35))
	canvas.draw_rect(Rect2(rect.position + Vector2(0, rect.size.y - band), Vector2(rect.size.x, band)), Color(0, 0, 0, 0.25))


## Returns the part of [param track] a bar filled to [param fraction] covers, growing from the
## left, or from the right when [param from_right].
static func fill_rect(track: Rect2, fraction: float, from_right := false) -> Rect2:
	var width := roundf(track.size.x * clampf(fraction, 0.0, 1.0))
	var x := track.end.x - width if from_right else track.position.x
	return Rect2(x, track.position.y, width, track.size.y)
