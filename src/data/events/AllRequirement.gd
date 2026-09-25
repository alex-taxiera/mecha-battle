class_name AllRequirement
extends EventRequirement
## Needs every one of [member requirements], e.g. a story flag and a sector. Describes the first
## that fails.

@export var requirements: Array[EventRequirement] = []

var _failed: EventRequirement


func check(run: RunState) -> bool:
	for requirement in requirements:
		if not requirement.check(run):
			_failed = requirement
			return false
	return true


func describe() -> String:
	return _failed.describe() if _failed else (requirements[0].describe() if not requirements.is_empty() else "")
