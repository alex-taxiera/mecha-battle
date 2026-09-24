class_name HeatToEnergy
extends PartAbility
## A thermoelectric generator: its mech gains [member energy_per_heat] energy a second for each
## point of heat it carries, so running hot pays.

@export var energy_per_heat := 0.8

const CARRY := &"heat_to_energy"


func on_tick(mech: BattleMech, active: ActivePart, delta: float) -> void:
	var carry: float = active.counters.get(CARRY, 0.0) + mech.heat * energy_per_heat * delta
	var whole := floori(carry + CombatEngine.TIME_EPSILON)
	active.counters[CARRY] = carry - whole
	if whole > 0:
		mech.current_energy += whole
		mech.announce(active)
