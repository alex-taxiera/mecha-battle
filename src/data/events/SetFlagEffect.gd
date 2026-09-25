class_name SetFlagEffect
extends EventEffect
## Sets the run's flag [member flag] to [member value] (see [member RunState.flags]), so a later
## event can follow up on this one. Says nothing: the story tells it.

@export var flag: String
@export var value := 1


func apply(run: RunState, _result: EventResult) -> void:
	run.flags[flag] = value
