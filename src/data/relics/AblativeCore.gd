class_name AblativeCore
extends Relic
## The first [member hits] hits the mech takes each fight deal nothing.

@export var hits := 1

var _left := 0


func on_fight_start(_mech: BattleMech) -> bool:
	_left = hits
	return false


func modify_damage_taken(_mech: BattleMech, amount: int) -> int:
	if _left <= 0 or amount <= 0:
		return amount
	_left -= 1
	return 0
