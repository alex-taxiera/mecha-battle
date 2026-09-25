class_name ChassisRequirement
extends EventRequirement
## Needs the run to be on the frame with id [member chassis_id], e.g. only the Reactor can siphon a
## leaking core.

@export var chassis_id: String
## The frame's name for the button, e.g. "The Reactor".
@export var chassis_name: String


func check(run: RunState) -> bool:
	return run.grid.chassis.id == chassis_id


func describe() -> String:
	return "Needs %s" % chassis_name
