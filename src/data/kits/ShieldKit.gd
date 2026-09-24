class_name ShieldKit
extends FieldKit
## Adds [member shield] to the mech's shield for the rest of the fight.

@export var shield := 100


func apply(mech: BattleMech, _enemy: BattleMech) -> void:
	mech.max_shield += shield
	mech.shield += shield
