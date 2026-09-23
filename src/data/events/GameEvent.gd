class_name GameEvent
extends Resource
## An Event node's story: a prompt and the choices the player can make. The events live in
## [code]res://resources/events/[/code]. A run's [EventPool] hands them out.
## The shape follows Slay-The-Robot's EventData and dialogue options (MIT, DesirePathGames).

## What the pool does with the event when its [member requirement] fails: keep it where it is,
## drop it for the run, move it to the back, or put it back somewhere random.
enum FailedStrategy { KEEP, REMOVE, APPEND, REINSERT }

@export var id: String
@export var title: String
@export_multiline var text: String
## Must pass for the event to come up, e.g. owning a weapon for an event about weapons.
@export var requirement: EventRequirement
@export var failed_strategy := FailedStrategy.KEEP
## The event to show when no other can come up. A pool keeps one aside.
@export var fallback := false
@export var choices: Array[EventChoice] = []


## Returns whether the event can come up in [param run].
func can_happen(run: RunState) -> bool:
	return requirement == null or requirement.check(run)
