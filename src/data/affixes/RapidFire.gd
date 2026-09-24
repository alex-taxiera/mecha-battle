class_name RapidFire
extends Relic
## An elite affix: the mech's weapons cool down [member cooldown_scale] as long.

@export var cooldown_scale := 0.85


func modify_part_stats(part: MechPart, numbers: MechStats.PartStats) -> void:
	if part.type == MechPart.PartType.WEAPON and numbers.cooldown > 0.0:
		numbers.cooldown *= cooldown_scale
