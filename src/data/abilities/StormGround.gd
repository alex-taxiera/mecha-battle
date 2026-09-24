class_name StormGround
extends PartAbility
## A lightning rod: the storm starts [member storm_lead] seconds sooner for both mechs, and this
## mech takes only [member share_taken] of each strike (rounded down), gaining [member energy]
## from it. More rods don't do more.

@export var storm_lead := 6.0
@export var share_taken := 0.5
@export var energy := 30


func _init() -> void:
	stacks = false


func get_storm_lead() -> float:
	return storm_lead


func modify_storm_strike(mech: BattleMech, damage: int) -> int:
	mech.current_energy += energy
	return floori(damage * share_taken)
