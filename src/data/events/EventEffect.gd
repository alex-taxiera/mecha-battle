class_name EventEffect
extends Resource
## One thing an event outcome does to the run. Subclasses override [method apply], adding a line
## to [param result] saying what happened.


func apply(_run: RunState, _result: EventResult) -> void:
	pass


## Returns what it would do, in a sentence, for a Hangar job's hint (see [HangarJob]); empty for
## effects that don't say.
func describe(_run: RunState) -> String:
	return ""
