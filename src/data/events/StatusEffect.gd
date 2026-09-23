class_name StatusEffect
extends EventEffect
## Puts a lasting effect on the run for a few fights.

@export var status: TimedStatus


func apply(run: RunState, result: EventResult) -> void:
	var owned := run.add_status(status)
	result.lines.append("For the next %d fights: %s" % [owned.fights, owned.description])
