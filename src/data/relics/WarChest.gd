class_name WarChest
extends Relic
## A boss relic: a pile of gold now, and more from every fight.

@export var gold := 100
## The share added to fight gold: 0.1 is +10%, rounded up.
@export var bonus := 0.1


func on_obtain(run: RunState) -> void:
	run.gold += gold


func modify_gold(amount: int) -> int:
	return ceili(amount * (1.0 + bonus))
