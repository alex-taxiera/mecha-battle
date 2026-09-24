class_name TechnicianScreen
extends MessageScreen
## The Mech Technician, before a run's first step: the offered boons, one button each. Picking
## one applies it and shows what it did, then the button (Head out) emits
## [signal MessageScreen.confirmed].

const TITLE_COLOR := Color("#f2b134")

var run: RunState
var boons: Array[TechnicianOffer.Boon] = []
## What the picked boon did, once one is picked.
var result: EventResult


func _init(p_run: RunState = null, p_boons: Array[TechnicianOffer.Boon] = []) -> void:
	super("MECH TECHNICIAN", TITLE_COLOR, PackedStringArray(["\"Before you head out, I can do you one favor. Pick carefully.\""]),
		"Head out", p_run)
	run = p_run
	boons.assign(p_boons)
	button.visible = false
	for i in boons.size():
		add_option(boons[i].text, "", choose.bind(i))


## Takes boon [param index]. Returns false if one was already taken or there's no such boon.
func choose(index: int) -> bool:
	if result or index < 0 or index >= boons.size():
		return false
	result = TechnicianOffer.apply(boons[index], run)
	var lines := PackedStringArray([boons[index].text + "."])
	lines.append_array(result.lines)
	body_label.text = "\n".join(lines)
	options.visible = false
	button.visible = true
	return true
