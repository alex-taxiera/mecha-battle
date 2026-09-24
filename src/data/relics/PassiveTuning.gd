class_name PassiveTuning
extends Relic
## A chassis relic that sets [member key] in the mech's passive state to [member value] at the
## start of each fight, e.g. the Phantom evading more often.

@export var key: StringName
@export var value: float


func on_fight_start(mech: BattleMech) -> bool:
	mech.passive_state[key] = value
	return false
