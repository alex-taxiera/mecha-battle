class_name EvasionPassive
extends ChassisPassive
## Every [member every]th shot aimed at the mech misses: it doesn't land at all. A relic can make
## it more often by setting the mech's [code]passive_state[EVERY][/code].

const EVERY := &"evasion_every"
const COUNT := &"evasion_count"
## Before anything else in the pipeline: a missed shot never reaches plating or relics.
const PRIORITY := 20000

@export var every := 4


func make_interceptors(mech: BattleMech) -> Array[HitInterceptor]:
	return [EvasionInterceptor.new(mech, self)]


## Returns how often shots miss [param mech]: every this-many-th.
func get_every(mech: BattleMech) -> int:
	return maxi(1, mech.passive_state.get(EVERY, every))


class EvasionInterceptor:
	extends HitInterceptor

	var mech: BattleMech
	var passive: EvasionPassive

	func _init(p_mech: BattleMech, p_passive: EvasionPassive) -> void:
		mech = p_mech
		passive = p_passive
		priority = EvasionPassive.PRIORITY
		side = Side.TARGET
		kinds.assign([HitPipeline.Kind.SHOT])

	func intercept(hit: HitPipeline.Hit) -> Result:
		# A preview can't know which shot it is, so it assumes a hit.
		if hit.preview:
			return Result.CONTINUE
		var count: int = mech.passive_state.get(EvasionPassive.COUNT, 0) + 1
		mech.passive_state[EvasionPassive.COUNT] = count
		return Result.REJECTED if count % passive.get_every(mech) == 0 else Result.CONTINUE
