class_name VentKit
extends FieldKit
## Vents [member heat] of the mech's heat at once.

@export var heat := 70


func apply(mech: BattleMech, _enemy: BattleMech) -> void:
	mech.add_heat(-heat)
