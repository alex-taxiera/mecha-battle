class_name EventOutcome
extends Resource
## What happens when a choice is picked: text for the player and effects on the run. A choice
## with several outcomes picks one by weight.

@export var weight := 1
@export_multiline var text: String
@export var effects: Array[EventEffect] = []
## The event's next page, shown in place of this one after the outcome; null ends the event.
@export var next_event: GameEvent
