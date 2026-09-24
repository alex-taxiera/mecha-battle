class_name Jammed
extends MechStatus
## Jammed: the mech's weapons count down [member slow_per_charge] slower for each charge, down to
## [member min_speed] of their speed.

@export var slow_per_charge := 0.08
@export var min_speed := 0.5


func modify_weapon_speed(_mech: BattleMech, status: ActiveStatus, speed: float) -> float:
	return speed * maxf(min_speed, 1.0 - slow_per_charge * status.charges)
