class_name TimedStatus
extends Relic
## An effect from an event that lasts a few fights, e.g. starting hot but earning more gold. It
## counts down each time a won fight's loot is rolled, and leaves the run at 0.

## Fights left.
@export var fights := 2
## Heat the mech starts each fight with.
@export var start_heat := 0
## The share added to fight gold: 0.5 is +50%, rounded up.
@export var gold_bonus := 0.0


func on_fight_start(mech: BattleMech) -> bool:
	if start_heat == 0:
		return false
	mech.add_heat(start_heat)
	return true


func modify_gold(amount: int) -> int:
	return ceili(amount * (1.0 + gold_bonus))
