class_name Fortified
extends MechStatus
## Fortified (a buff): every hit the mech takes is [member block_per_charge] smaller for each
## charge, never below 0.

@export var block_per_charge := 2


func intercepts_hits() -> bool:
	return true


func intercept(hit: HitPipeline.Hit, status: ActiveStatus) -> HitInterceptor.Result:
	hit.damage = maxi(0, hit.damage - block_per_charge * status.charges)
	return HitInterceptor.Result.CONTINUE
