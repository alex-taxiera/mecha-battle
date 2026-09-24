class_name Afterburner
extends Relic
## The Striker's: the first time the mech falls to [member threshold] of its max HP in a fight,
## its Overclock is ready again.

@export var threshold := 0.5

var _used := false


func on_fight_start(_mech: BattleMech) -> bool:
	_used = false
	return false


func on_hit_taken(mech: BattleMech, _hit: HitPipeline.Hit) -> void:
	if _used or mech.current_health <= 0 or mech.current_health > mech.max_hp * threshold:
		return
	_used = true
	if mech.passive_state.get(OverclockPassive.SPENT, false):
		mech.passive_state[OverclockPassive.SPENT] = false
		mech.relic_triggered.emit(self)
