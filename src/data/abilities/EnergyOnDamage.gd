class_name EnergyOnDamage
extends PartAbility
## A kinetic dynamo: every hit the mech takes gives it [member energy].

@export var energy := 3


func on_damaged(mech: BattleMech, active: ActivePart, _damage: int) -> void:
	mech.current_energy += energy
	mech.announce(active)
