class_name LastStand
extends Relic
## While the mech is at or below [member threshold] of its max HP, its shots deal
## [member multiplier] times the damage.

@export var threshold := 0.3
@export var multiplier := 1.3


func modify_shot_damage(mech: BattleMech, _weapon: ActivePart, damage: int) -> int:
	if mech.current_health > mech.max_hp * threshold:
		return damage
	return roundi(damage * multiplier)
