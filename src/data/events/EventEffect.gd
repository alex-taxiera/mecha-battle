class_name EventEffect
extends Resource
## One thing an event outcome does to the run. Subclasses override [method apply], adding a line
## to [param result] saying what happened.


func apply(_run: RunState, _result: EventResult) -> void:
	pass
