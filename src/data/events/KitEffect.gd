class_name KitEffect
extends EventEffect
## Puts [member kit] in a free kit slot, or, without one, a kit rolled from the run's
## [member RunState.kit_pool]. With every slot full, nothing.

@export var kit: FieldKit


func apply(run: RunState, result: EventResult) -> void:
	var found := kit if kit else run.roll_kit()
	if found == null:
		return
	if run.add_kit(found):
		result.lines.append("Got a %s" % found.kit_name)
	else:
		result.lines.append("No room for the %s: every kit slot is full" % found.kit_name)


func describe(_run: RunState) -> String:
	return "Get a %s." % kit.kit_name if kit else "Get a random field kit."
