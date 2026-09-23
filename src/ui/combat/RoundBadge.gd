class_name RoundBadge
extends Control
## The run so far, in the combat screen's top-left corner: the sector and floor, e.g.
## "SECTOR 1 · FLOOR 5", the fights won, in green, and ELITE or BOSS for those fights.

const FONT_SIZE := 16

var sector := 1
## 0 before the player has picked a node on the map; then it's left out.
var floor_number := 0
var wins := 0
## "ELITE", "BOSS", or "" for a normal fight.
var tag := ""


func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE


func set_progress(p_sector: int, p_floor: int, p_wins: int, p_tag := "") -> void:
	sector = p_sector
	floor_number = p_floor
	wins = p_wins
	tag = p_tag
	queue_redraw()


## Returns what the badge says, e.g. "SECTOR 1 · FLOOR 5  3W", or "SECTOR 1 · FLOOR 13  3W  BOSS".
func get_text() -> String:
	var text := "%s  %s" % [_place_text(), _wins_text()]
	return text if tag.is_empty() else "%s  %s" % [text, tag]


func _place_text() -> String:
	if floor_number > 0:
		return "SECTOR %d · FLOOR %d" % [sector, floor_number]
	return "SECTOR %d" % sector


func _wins_text() -> String:
	return "%dW" % wins


func _get_minimum_size() -> Vector2:
	return Vector2(420, 28)


func _draw() -> void:
	var font := CombatDraw.PIXEL_FONT
	var baseline := 20.0
	var x := 2.0
	CombatDraw.text_at(self, font, Vector2(x, baseline), _place_text(), FONT_SIZE, CombatColors.INK, 2)
	x += CombatDraw.text_width(font, _place_text(), FONT_SIZE) + 20.0
	CombatDraw.text_at(self, font, Vector2(x, baseline), _wins_text(), FONT_SIZE, CombatColors.HP, 2)
	if not tag.is_empty():
		x += CombatDraw.text_width(font, _wins_text(), FONT_SIZE) + 20.0
		CombatDraw.text_at(self, font, Vector2(x, baseline), tag, FONT_SIZE, CombatColors.DANGER, 2)
