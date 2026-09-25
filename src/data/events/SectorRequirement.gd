class_name SectorRequirement
extends EventRequirement
## Needs the run to be in sectors [member first] to [member last] (from 1): an event that belongs
## to part of the run. Put on an event with the KEEP strategy, it waits in the pool until then.

@export var first := 1
@export var last := 99


func check(run: RunState) -> bool:
	var sector := run.act_index + 1
	return sector >= first and sector <= last


func describe() -> String:
	return "Not in this sector"
