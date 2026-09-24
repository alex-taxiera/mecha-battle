class_name Armored
extends Relic
## An elite affix: every hit the mech takes is [member plating] smaller, never below 0.

@export var plating := 3


func modify_damage_taken(_mech: BattleMech, amount: int) -> int:
	return maxi(0, amount - plating)
