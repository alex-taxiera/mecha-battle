class_name EventScreen
extends MessageScreen
## An Event stop: the event's story and a button per choice. A choice whose requirement isn't
## met is off and says why. After a choice, the outcome shows with a button that emits
## [signal MessageScreen.confirmed]: "Fight!" when the outcome starts a fight (see [member result]).

const TITLE_COLOR := Color("#5aa9ff")

var run: RunState
var event: GameEvent
## What the choice did, once one is made.
var result: EventResult


func _init(p_run: RunState = null, p_event: GameEvent = null) -> void:
	super(p_event.title if p_event else "", TITLE_COLOR, PackedStringArray([p_event.text if p_event else ""]), "Continue", p_run)
	run = p_run
	event = p_event
	button.visible = false
	if event == null:
		return
	for i in event.choices.size():
		var choice := event.choices[i]
		var option := add_option(choice.label, choice.hint, choose.bind(i))
		if not choice.is_available(run):
			option.disabled = true
			option.text += "  (%s)" % choice.requirement.describe()


## Picks choice [param index]. Returns false if a choice was already made, or this one can't be.
func choose(index: int) -> bool:
	if result:
		return false
	result = run.choose_event_option(event, index)
	if result == null:
		return false
	var lines := PackedStringArray([result.text])
	lines.append_array(result.lines)
	body_label.text = "\n".join(lines)
	options.visible = false
	button.visible = true
	button.text = "Fight!" if result.fight_tier >= 0 else "Continue"
	return true
