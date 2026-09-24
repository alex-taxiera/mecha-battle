class_name Corroded
extends MechStatus
## Corroded: every hit the mech takes is [member damage_per_charge] bigger for each charge, before
## its plating. When the charges wrap past the top, the corrosion eats through the shield: it's
## gone for the fight.

@export var damage_per_charge := 3


func intercepts_hits() -> bool:
	return true


func intercept(hit: HitPipeline.Hit, status: ActiveStatus) -> HitInterceptor.Result:
	hit.damage += damage_per_charge * status.charges
	return HitInterceptor.Result.CONTINUE


func on_overflow(mech: BattleMech, _status: ActiveStatus, _times: int) -> void:
	mech.shield = 0
