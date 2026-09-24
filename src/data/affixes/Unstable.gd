class_name Unstable
extends Relic
## An elite affix: the mech's weapons hit [member damage_scale] as hard and make [member heat_add]
## more heat a shot.

@export var damage_scale := 1.2
@export var heat_add := 10


func modify_part_stats(part: MechPart, numbers: MechStats.PartStats) -> void:
	if part.type == MechPart.PartType.WEAPON:
		numbers.damage = roundi(numbers.damage * damage_scale)
		numbers.heat += heat_add
