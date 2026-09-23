class_name TargetingUplink
extends Relic
## The first shot of every fight hits harder.

@export var multiplier := 2.0

var _spent := false


func on_fight_start(_mech: BattleMech) -> bool:
	_spent = false
	return false


func modify_shot_damage(_mech: BattleMech, _weapon: ActivePart, damage: int) -> int:
	if _spent:
		return damage
	_spent = true
	return roundi(damage * multiplier)
