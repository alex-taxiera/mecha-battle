class_name BuffKit
extends FieldKit
## Gives the mech [member charges] of [member status], e.g. Haste.

@export var status: MechStatus
@export var charges := 5


func apply(mech: BattleMech, _enemy: BattleMech) -> void:
	if status:
		mech.add_status(status, charges)
