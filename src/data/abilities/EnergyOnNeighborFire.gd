class_name EnergyOnNeighborFire
extends PartAbility
## A capacitor coupler: every [member every]th shot from a weapon it touches gives its mech
## [member energy].

@export var energy := 5
@export var every := 1


func on_neighbor_fired(mech: BattleMech, active: ActivePart, weapon: ActivePart) -> void:
	if weapon.part.type == MechPart.PartType.WEAPON and active.count(self, every):
		mech.current_energy += energy
		mech.announce(active)
