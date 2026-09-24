class_name Overcharged
extends MechStatus
## Overcharged (a buff): the mech's shots deal [member damage_per_charge] more for each charge,
## as a share of their damage.

@export var damage_per_charge := 0.1


func intercepts_hits() -> bool:
	return true


func intercept(hit: HitPipeline.Hit, status: ActiveStatus) -> HitInterceptor.Result:
	hit.damage = roundi(hit.damage * (1.0 + damage_per_charge * status.charges))
	return HitInterceptor.Result.CONTINUE
