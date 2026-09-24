class_name StatusFeeder
extends Relic
## Each of the mech's shots that lands on a target already carrying [member status] adds
## [member charges] more, e.g. feeding a Burn.

@export var status: MechStatus
@export var charges := 1


func on_hit_dealt(_mech: BattleMech, hit: HitPipeline.Hit) -> void:
	if status and hit.target and hit.target.get_status(status.id):
		hit.target.add_status(status, charges)
