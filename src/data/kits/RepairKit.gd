class_name RepairKit
extends FieldKit
## Repairs [member share] of the mech's max HP.

@export var share := 0.25


func apply(mech: BattleMech, _enemy: BattleMech) -> void:
	mech.heal(roundi(mech.max_hp * share))
