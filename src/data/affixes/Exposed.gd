class_name Exposed
extends Relic
## A boss phase's drawback: every hit the mech takes is [member scale] as big.

@export var scale := 1.2


func modify_damage_taken(_mech: BattleMech, amount: int) -> int:
	return roundi(amount * scale)
