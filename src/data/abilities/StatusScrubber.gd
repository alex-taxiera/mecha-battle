class_name StatusScrubber
extends PartAbility
## A status scrubber: every [member interval] seconds it clears the debuff on its mech with the
## most charges. Once charged it waits, and clears the next debuff the moment one lands.

@export var interval := 5.0

const TIMER := &"status_scrubber"


func on_tick(mech: BattleMech, active: ActivePart, delta: float) -> void:
	var charged: float = minf(interval, active.counters.get(TIMER, 0.0) + delta)
	active.counters[TIMER] = charged
	if charged < interval - CombatEngine.TIME_EPSILON:
		return
	var worst: ActiveStatus = null
	for status in mech.statuses:
		if status.data.type == MechStatus.Type.DEBUFF and (worst == null or status.charges > worst.charges):
			worst = status
	if worst:
		mech.clear_status(worst)
		active.counters[TIMER] = 0.0
		mech.announce(active)
