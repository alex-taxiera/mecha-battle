class_name Burning
extends Relic
## An elite affix: the mech's shots leave [member charges] of [member status] (Burn) on what they hit.

@export var status: MechStatus
@export var charges := 1


func on_hit_dealt(_mech: BattleMech, hit: HitPipeline.Hit) -> void:
	if status and hit.kind == HitPipeline.Kind.SHOT:
		hit.target.add_status(status, charges)
