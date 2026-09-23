class_name CapacitorBank
extends Relic
## Starts every fight with energy banked.

@export var energy := 50


func on_fight_start(mech: BattleMech) -> bool:
	mech.current_energy += energy
	return true
