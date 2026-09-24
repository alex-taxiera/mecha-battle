class_name DamageCap
extends PartAbility
## A damage limiter: no single hit takes more than [member cap] off its mech, after plating and
## relics.

@export var cap := 60

const PRIORITY := 7000


func make_interceptors(mech: BattleMech, active: ActivePart) -> Array[HitInterceptor]:
	return [CapInterceptor.new(mech, active, cap)]


class CapInterceptor:
	extends HitInterceptor

	var mech: BattleMech
	var active: ActivePart
	var cap: int

	func _init(p_mech: BattleMech, p_active: ActivePart, p_cap: int) -> void:
		mech = p_mech
		active = p_active
		cap = p_cap
		priority = DamageCap.PRIORITY
		side = Side.TARGET

	func intercept(hit: HitPipeline.Hit) -> Result:
		if hit.damage > cap:
			hit.damage = cap
			if not hit.preview:
				mech.announce(active)
		return Result.CONTINUE
