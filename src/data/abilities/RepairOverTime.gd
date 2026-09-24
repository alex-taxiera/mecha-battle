class_name RepairOverTime
extends PartAbility
## A nanite repair bay: its mech repairs [member share] of its max HP a second while it stands.

@export var share := 0.01

const CARRY := &"repair_over_time"


func on_tick(mech: BattleMech, active: ActivePart, delta: float) -> void:
	var carry: float = active.counters.get(CARRY, 0.0) + mech.max_hp * share * delta
	var whole := floori(carry + CombatEngine.TIME_EPSILON)
	active.counters[CARRY] = carry - whole
	if mech.heal(whole) > 0:
		mech.announce(active)
