class_name ScorchedGround
extends Relic
## A hazard: the mech starts the fight at [member heat] heat.

@export var heat := 30


func on_fight_start(mech: BattleMech) -> bool:
	mech.add_heat(heat)
	return true
