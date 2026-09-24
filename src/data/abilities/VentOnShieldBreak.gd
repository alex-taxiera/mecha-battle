class_name VentOnShieldBreak
extends PartAbility
## An emergency vent: when the mech's shield breaks, it dumps [member heat] heat.

@export var heat := 40


func on_shield_broken(mech: BattleMech, active: ActivePart) -> void:
	mech.add_heat(-heat)
	mech.announce(active)
