class_name PartsRequirement
extends EventRequirement
## Needs at least [member count] parts owned, stashed or installed.

@export var count := 1


func check(run: RunState) -> bool:
	return run.stash.size() + run.grid.get_placements().size() >= count


func describe() -> String:
	return "Needs %d parts" % count
