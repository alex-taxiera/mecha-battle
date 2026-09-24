class_name HeatRamp
extends PartAbility
## A weapon that heats up the longer it fires without a break: each shot in a row makes
## [member ramp] more heat than the last, up to [member max_extra] more. The streak ends when
## the weapon has to wait for energy, or its mech shuts down.

@export var ramp := 1
@export var max_extra := 10


func modify_shot_heat(active: ActivePart, heat: int) -> int:
	return heat + mini(active.streak * ramp, max_extra)
