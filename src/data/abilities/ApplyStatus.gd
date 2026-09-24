class_name ApplyStatus
extends PartAbility
## A weapon whose shots leave [member charges] of [member status] on what they hit, e.g. Burn.

@export var status: MechStatus
@export var charges := 1


func on_hit(hit: HitPipeline.Hit) -> void:
	if status:
		hit.target.add_status(status, charges)
