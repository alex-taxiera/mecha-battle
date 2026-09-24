class_name MomentumPassive
extends ChassisPassive
## The mech's weapons fire [member per_second] faster for every second of the fight, up to
## [member max_bonus]: slow to start, hard to stop. A relic can speed the build-up by setting the
## mech's [code]passive_state[RATE][/code].

const RATE := &"momentum_rate"
const SECONDS := &"momentum_seconds"

@export var per_second := 0.02
@export var max_bonus := 0.5


func on_tick(mech: BattleMech, delta: float) -> void:
	mech.passive_state[SECONDS] = mech.passive_state.get(SECONDS, 0.0) + delta


func modify_weapon_speed(mech: BattleMech, speed: float) -> float:
	return speed * (1.0 + get_bonus(mech))


## Returns the share faster [param mech]'s weapons fire now.
func get_bonus(mech: BattleMech) -> float:
	var rate: float = mech.passive_state.get(RATE, 1.0)
	return minf(max_bonus, per_second * rate * mech.passive_state.get(SECONDS, 0.0))
