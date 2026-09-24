class_name ChassisPassive
extends Resource
## What a frame does in a fight on its own, e.g. the Bastion's Thick Plating. A chassis holds one
## (see [member MechChassis.passive]); each kind is a subclass in [code]src/data/passives/[/code]
## overriding the hooks it needs. Passives are shared by every mech on the frame, so any state a
## fight needs lives in the mech's [member BattleMech.passive_state].


## Interceptors the passive adds to [param mech]'s side of the [HitPipeline], made per fight.
func make_interceptors(_mech: BattleMech) -> Array[HitInterceptor]:
	return []


## As [param mech]'s fight starts.
func on_fight_start(_mech: BattleMech) -> void:
	pass


## Every tick of [param mech]'s fight, [param delta] seconds long.
func on_tick(_mech: BattleMech, _delta: float) -> void:
	pass


## Returns how many more times [param weapon] fires, free, right after [param mech] pays for a shot.
func extra_shots(_mech: BattleMech, _weapon: ActivePart) -> int:
	return 0


## Returns [param mech]'s weapon speed (1 is normal) with the passive's change to [param speed].
func modify_weapon_speed(_mech: BattleMech, speed: float) -> float:
	return speed
