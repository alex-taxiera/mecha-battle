class_name PartTypeBonus
extends Relic
## Every part of [member part_type] gets [member hp] more HP.

@export var part_type := MechPart.PartType.DEFENSE
@export var hp := 15


func modify_part_stats(part: MechPart, numbers: MechStats.PartStats) -> void:
	if part.type == part_type:
		numbers.hp += hp
