class_name StatusOnHitTaken
extends Relic
## Every hit the mech takes gives it [member charges] of [member status], e.g. Fortified.

@export var status: MechStatus
@export var charges := 1


func on_hit_taken(mech: BattleMech, hit: HitPipeline.Hit) -> void:
	if status and hit.taken > 0 and mech.current_health > 0:
		mech.add_status(status, charges)
