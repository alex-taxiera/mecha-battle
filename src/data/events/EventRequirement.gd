class_name EventRequirement
extends Resource
## A condition on the run for an event or a choice. Subclasses override both methods.


func check(_run: RunState) -> bool:
	return true


## Returns what's needed, for a choice's disabled button, e.g. "Needs 30 gold".
func describe() -> String:
	return ""
