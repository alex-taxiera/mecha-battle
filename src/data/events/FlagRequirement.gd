class_name FlagRequirement
extends EventRequirement
## Needs the run's flag [member flag] at [member value] or more: an earlier event happened.

@export var flag: String
@export var value := 1


func check(run: RunState) -> bool:
	return run.flags.get(flag, 0) >= value


func describe() -> String:
	return "Needs something that hasn't happened yet"
