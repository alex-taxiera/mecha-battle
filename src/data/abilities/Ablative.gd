class_name Ablative
extends PartAbility
## Ablative plating: the first [member hits] shots its mech takes each fight deal nothing. It
## goes before plating, so a Bastion's plating isn't wasted on them.

@export var hits := 2

const PRIORITY := 9100


func make_interceptors(mech: BattleMech, active: ActivePart) -> Array[HitInterceptor]:
	return [AblativeInterceptor.new(mech, active, hits)]


class AblativeInterceptor:
	extends HitInterceptor

	const SPENT := &"ablative_spent"

	var mech: BattleMech
	var active: ActivePart
	var hits: int

	func _init(p_mech: BattleMech, p_active: ActivePart, p_hits: int) -> void:
		mech = p_mech
		active = p_active
		hits = p_hits
		priority = Ablative.PRIORITY
		side = Side.TARGET
		kinds.assign([HitPipeline.Kind.SHOT])

	func intercept(hit: HitPipeline.Hit) -> Result:
		var spent: int = active.counters.get(SPENT, 0)
		# A shot another plate already stopped doesn't use this one up.
		if spent >= hits or hit.damage <= 0:
			return Result.CONTINUE
		hit.damage = 0
		if not hit.preview:
			active.counters[SPENT] = spent + 1
			mech.announce(active)
		return Result.CONTINUE
