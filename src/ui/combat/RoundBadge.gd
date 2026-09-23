class_name RoundBadge
extends Control
## The run so far, in the combat screen's top-left corner: "ROUND 3" and the record, wins in
## green, losses in red, and draws, once there are any, dimmed.

const FONT_SIZE := 16

var round_number := 1
var wins := 0
var losses := 0
var draws := 0


func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE


func set_record(p_round: int, p_wins: int, p_losses: int, p_draws: int) -> void:
	round_number = p_round
	wins = p_wins
	losses = p_losses
	draws = p_draws
	queue_redraw()


## Returns what the badge says, e.g. "ROUND 3  2W 1L".
func get_text() -> String:
	return "  ".join([_round_text(), " ".join(_record_parts().map(func(part: Array) -> String: return part[0]))])


func _round_text() -> String:
	return "ROUND %d" % round_number


# Each part of the record with its color.
func _record_parts() -> Array:
	var parts := [["%dW" % wins, CombatColors.HP], ["%dL" % losses, CombatColors.DANGER]]
	if draws > 0:
		parts.append(["%dD" % draws, CombatColors.DIM])
	return parts


func _get_minimum_size() -> Vector2:
	return Vector2(320, 28)


func _draw() -> void:
	var font := CombatDraw.PIXEL_FONT
	var baseline := 20.0
	var x := 2.0
	CombatDraw.text_at(self, font, Vector2(x, baseline), _round_text(), FONT_SIZE, CombatColors.INK, 2)
	x += CombatDraw.text_width(font, _round_text(), FONT_SIZE) + 20.0
	for part: Array in _record_parts():
		CombatDraw.text_at(self, font, Vector2(x, baseline), part[0], FONT_SIZE, part[1], 2)
		x += CombatDraw.text_width(font, part[0], FONT_SIZE) + 12.0
