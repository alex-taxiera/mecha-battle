class_name RestScreen
extends MessageScreen
## A Hangar / Refit Bay stop: the crew does one job, repairing the hull or reinforcing it for
## good, or the player moves on. The bottom button emits [signal MessageScreen.confirmed].

const TITLE_COLOR := Color("#5fd38a")

var run: RunState
var repair_button: Button
var reinforce_button: Button
## Whether the crew has done its job.
var job_done := false


func _init(p_run: RunState = null) -> void:
	super("HANGAR / REFIT BAY", TITLE_COLOR, PackedStringArray(["The refit crew has time for one job before you move on."]),
		"Leave", p_run)
	run = p_run
	if run == null:
		return
	var repair_amount := mini(ceili(run.get_max_hp() * RunState.REPAIR_SHARE), run.hull_damage)
	repair_button = add_option("Repair", "Repair %d hull (%d%% of max)." % [repair_amount, roundi(RunState.REPAIR_SHARE * 100)], repair)
	repair_button.disabled = run.hull_damage == 0
	reinforce_button = add_option("Reinforce", "+%d max HP for the rest of the run." % RunState.REINFORCE_HP, reinforce)


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


func _finish(text: String) -> void:
	job_done = true
	body_label.text = text
	options.visible = false
	button.text = "Continue"
