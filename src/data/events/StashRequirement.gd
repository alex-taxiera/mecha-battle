class_name StashRequirement
extends EventRequirement
## Needs at least [member count] parts in the stash (junk doesn't count).

@export var count := 1


func check(run: RunState) -> bool:
	return run.stash.filter(func(entry: RunState.StashEntry) -> bool:
		return entry.part.type != MechPart.PartType.JUNK).size() >= count


func describe() -> String:
	return "Needs %d part%s in the stash" % [count, "" if count == 1 else "s"]
