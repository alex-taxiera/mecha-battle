class_name RestScreen
extends MessageScreen
## A Hangar / Refit Bay stop: a button for each of the run's [HangarJob]s (repair the hull,
## reinforce it, raise a part a Mk, grow the frame, and any a relic adds), or the player moves on.
## Doing an exclusive job ends the visit; the others can go alongside it. The bottom button emits
## [signal MessageScreen.confirmed].

const TITLE_COLOR := Color("#5fd38a")
const INTRO := "The refit crew has time for one job before you move on."

var run: RunState
## Each job's button, by the job's id.
var job_buttons := {}
## Whether an exclusive job is done, which ends the visit.
var job_done := false

# The jobs done this visit, so an inclusive one isn't done twice.
var _done: Array[HangarJob] = []
# The Upgrade job waiting for the player to pick a part.
var _upgrading: HangarJob


func _init(p_run: RunState = null) -> void:
	super("HANGAR / REFIT BAY", TITLE_COLOR, PackedStringArray([INTRO]), "Leave", p_run)
	run = p_run
	if run:
		show_jobs()


## Lists the crew's jobs, each off when it can't be done now.
func show_jobs() -> void:
	_clear_options()
	job_buttons.clear()
	for job in run.get_hangar_jobs():
		var job_button := add_option(job.label, job.describe(run), do_job.bind(job))
		job_button.disabled = not can_do(job)
		job_buttons[job.id] = job_button


## Returns whether [param job] can be done now: nothing exclusive done yet, it's available, and
## it isn't a one-off already done.
func can_do(job: HangarJob) -> bool:
	return not job_done and job.is_available(run) \
		and not (job.cost_type != HangarJob.CostType.REPEATABLE and job in _done)


## Does [param job]: an Upgrade lists the parts to pick from; anything else applies its effects.
## Returns false if it can't be done now.
func do_job(job: HangarJob) -> bool:
	if not can_do(job):
		return false
	if job.kind == HangarJob.Kind.UPGRADE:
		show_upgrades(job)
		return true
	var result := EventResult.new()
	for effect in job.effects:
		effect.apply(run, result)
	_pay_and_finish(job, ". ".join(result.lines) + ".")
	return true


## Lists the parts [param job] (by default the first Upgrade job) can raise a Mk, each a button,
## and a way back to the jobs.
func show_upgrades(job: HangarJob = null) -> void:
	_upgrading = job if job else _first_upgrade_job()
	if job_done or _upgrading == null:
		return
	_clear_options()
	body_label.text = "Which part?"
	for part in run.get_upgradable_parts():
		var next := MechPart.NUMERALS[part.level]
		add_option("%s → Mk %s" % [part.get_display_name(), next], "", upgrade.bind(part))
	add_option("Back", "", show_jobs)


## Raises [param part] a Mk, for the Upgrade job being done. Returns false if there's none or it
## can't go up.
func upgrade(part: MechPart) -> bool:
	if _upgrading == null or not can_do(_upgrading) or not run.upgrade_part(part):
		return false
	var job := _upgrading
	_upgrading = null
	_pay_and_finish(job, "Upgraded to %s." % part.get_display_name())
	return true


# Pays for [param job] and shows [param text]: the visit ends if it was exclusive, and the jobs
# come back otherwise.
func _pay_and_finish(job: HangarJob, text: String) -> void:
	if job.cost > 0:
		run.gold -= job.cost
		run.changed.emit()
	_done.append(job)
	body_label.text = text
	if job.cost_type == HangarJob.CostType.EXCLUSIVE:
		job_done = true
		options.visible = false
		button.text = "Continue"
	else:
		show_jobs()


func _first_upgrade_job() -> HangarJob:
	for job in run.get_hangar_jobs():
		if job.kind == HangarJob.Kind.UPGRADE:
			return job
	return null


func _clear_options() -> void:
	for option in options.get_children():
		options.remove_child(option)
		option.queue_free()
