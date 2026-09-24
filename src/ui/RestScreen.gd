class_name RestScreen
extends MessageScreen
## A Hangar / Refit Bay stop: the crew does one job, repairing the hull, reinforcing it for good,
## or raising one part a Mk, or the player moves on. The bottom button emits
## [signal MessageScreen.confirmed].

const TITLE_COLOR := Color("#5fd38a")
const INTRO := "The refit crew has time for one job before you move on."

var run: RunState
var repair_button: Button
var reinforce_button: Button
var upgrade_button: Button
## Whether the crew has done its job.
var job_done := false


func _init(p_run: RunState = null) -> void:
	super("HANGAR / REFIT BAY", TITLE_COLOR, PackedStringArray([INTRO]), "Leave", p_run)
	run = p_run
	if run:
		show_jobs()


## Lists the crew's three jobs.
func show_jobs() -> void:
	_clear_options()
	body_label.text = INTRO
	var repair_amount := mini(ceili(run.get_max_hp() * RunState.REPAIR_SHARE), run.hull_damage)
	repair_button = add_option("Repair", "Repair %d hull (%d%% of max)." % [repair_amount, roundi(RunState.REPAIR_SHARE * 100)], repair)
	repair_button.disabled = run.hull_damage == 0
	reinforce_button = add_option("Reinforce", "+%d max HP for the rest of the run." % RunState.REINFORCE_HP, reinforce)
	upgrade_button = add_option("Upgrade", "Raise one part a Mk.", show_upgrades)
	upgrade_button.disabled = run.get_upgradable_parts().is_empty()


## Lists the parts the crew can upgrade, each a button, and a way back to the jobs.
func show_upgrades() -> void:
	if job_done:
		return
	_clear_options()
	body_label.text = "Which part?"
	for part in run.get_upgradable_parts():
		var next := MechPart.NUMERALS[part.level]
		add_option("%s → Mk %s" % [part.get_display_name(), next], "", upgrade.bind(part))
	add_option("Back", "", show_jobs)


## Repairs the hull. Returns false if the crew's job is already done.
func repair() -> bool:
	if job_done:
		return false
	var repaired := run.repair_at_hangar()
	_finish("Repaired %d hull." % repaired)
	return true


## Reinforces the hull. Returns false if the crew's job is already done.
func reinforce() -> bool:
	if job_done:
		return false
	run.reinforce_at_hangar()
	_finish("+%d max HP. The hull is sturdier for good." % RunState.REINFORCE_HP)
	return true


## Raises [param part] a Mk. Returns false if the crew's job is already done or it can't go up.
func upgrade(part: MechPart) -> bool:
	if job_done or not run.upgrade_part(part):
		return false
	_finish("Upgraded to %s." % part.get_display_name())
	return true


func _finish(text: String) -> void:
	job_done = true
	body_label.text = text
	options.visible = false
	button.text = "Continue"


func _clear_options() -> void:
	for option in options.get_children():
		options.remove_child(option)
		option.queue_free()
