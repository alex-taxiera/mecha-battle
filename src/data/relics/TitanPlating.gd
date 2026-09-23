class_name TitanPlating
extends Relic
## A boss relic: a thicker hull that shrugs off part of every hit.

@export var hp := 100
## Taken off every hit, after the chassis's own plating, never below 0.
@export var plating := 3


func modify_stats(stats: MechStats) -> void:
	stats.hp += hp


func modify_damage_taken(_mech: BattleMech, amount: int) -> int:
	return maxi(0, amount - plating)
