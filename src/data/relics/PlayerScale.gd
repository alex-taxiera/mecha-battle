class_name PlayerScale
extends Relic
## A run modifier's hidden change to the player's mech, like Glass Cannon's: weapon damage and
## max HP scaled. The run keeps it with its upgrades, not its relics.

@export var damage_scale := 1.0
@export var hp_scale := 1.0


func modify_part_stats(part: MechPart, numbers: MechStats.PartStats) -> void:
	if part.type == MechPart.PartType.WEAPON:
		numbers.damage = roundi(numbers.damage * damage_scale)


func modify_stats(stats: MechStats) -> void:
	stats.hp = roundi(stats.hp * hp_scale)
