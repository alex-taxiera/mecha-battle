class_name Haste
extends MechStatus
## Haste (a buff): the mech's weapons count down [member speed_per_charge] faster for each
## charge, up to [member max_speed] of their speed.

@export var speed_per_charge := 0.1
@export var max_speed := 1.5


func modify_weapon_speed(_mech: BattleMech, status: ActiveStatus, speed: float) -> float:
	return speed * minf(max_speed, 1.0 + speed_per_charge * status.charges)
