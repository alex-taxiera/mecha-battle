class_name Drained
extends MechStatus
## Drained: loses [member energy_per_charge] energy a second for each charge, never below 0.

@export var energy_per_charge := 6.0


func on_tick(mech: BattleMech, status: ActiveStatus, delta: float) -> void:
	# Energy is whole numbers, so the fraction carries to the next tick.
	var carry: float = status.values.get("carry", 0.0) + energy_per_charge * status.charges * delta
	var whole := floori(carry + CombatEngine.TIME_EPSILON)
	status.values["carry"] = carry - whole
	mech.current_energy = maxi(0, mech.current_energy - whole)
