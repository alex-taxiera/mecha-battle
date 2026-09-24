class_name Burn
extends MechStatus
## Burning: [member heat_per_charge] heat a second for each charge, on top of whatever the mech
## makes itself, so it throttles sooner (and a Reactor melts down sooner).

@export var heat_per_charge := 2.0


func on_tick(mech: BattleMech, status: ActiveStatus, delta: float) -> void:
	# Heat is whole numbers, so the fraction carries to the next tick.
	var carry: float = status.values.get("carry", 0.0) + heat_per_charge * status.charges * delta
	var whole := floori(carry + CombatEngine.TIME_EPSILON)
	status.values["carry"] = carry - whole
	mech.add_heat(whole)
