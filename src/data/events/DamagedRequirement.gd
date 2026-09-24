class_name DamagedRequirement
extends EventRequirement
## Needs hull damage to repair.


func check(run: RunState) -> bool:
	return run.hull_damage > 0


func describe() -> String:
	return "Nothing to repair"
