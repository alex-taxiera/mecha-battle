class_name StatusImmunity
extends Relic
## The mech never takes the status with id [member status_id], e.g. Drained.

@export var status_id := ""


func blocks_status(_mech: BattleMech, status: MechStatus) -> bool:
	return status.id == status_id
