class_name EventChoice
extends Resource
## One way out of an event: its button's text, what it needs, and what can happen.

@export var label: String
## What the choice does, under its label, e.g. "Gain 25 gold and a common part."
@export_multiline var hint: String
## Must pass for the choice to be picked; otherwise its button is off and says why.
@export var requirement: EventRequirement
## What happens, one outcome picked by weight.
@export var outcomes: Array[EventOutcome] = []


## Returns whether the choice can be picked in [param run].
func is_available(run: RunState) -> bool:
	return requirement == null or requirement.check(run)
