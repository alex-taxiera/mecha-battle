class_name StrikeKit
extends FieldKit
## Hits the enemy for [member damage] (through its plating and shield), and leaves [member charges]
## of [member status] if set.

@export var damage := 60
@export var status: MechStatus
@export var charges := 0


func apply(mech: BattleMech, enemy: BattleMech) -> void:
	if enemy == null:
		return
	mech.damage_dealt += enemy.take_damage(damage, HitPipeline.Kind.OTHER, mech)
	if status and charges > 0:
		enemy.add_status(status, charges)
