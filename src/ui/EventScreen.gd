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
	# Continue turns the page when the outcome leads on; otherwise it's done.
	button.pressed.disconnect(confirmed.emit)
	button.pressed.connect(_on_continue)
	show_page(p_event)


## Shows [param page] of the event: its title, story, and choices, with no choice made yet.
func show_page(page: GameEvent) -> void:
	event = page
	result = null
	button.visible = false
	for option in options.get_children():
		options.remove_child(option)
		option.queue_free()
	options.visible = true
	if event == null:
		return
	title_label.text = event.title
	body_label.text = event.text
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


func _on_continue() -> void:
	if result and result.next_event and result.fight_tier < 0:
		show_page(result.next_event)
	else:
		confirmed.emit()
