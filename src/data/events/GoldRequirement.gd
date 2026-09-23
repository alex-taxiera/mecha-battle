class_name GoldRequirement
extends EventRequirement
## Needs at least [member gold] gold.

@export var gold := 0


func check(run: RunState) -> bool:
	return run.gold >= gold


func describe() -> String:
	return "Needs %d gold" % gold
