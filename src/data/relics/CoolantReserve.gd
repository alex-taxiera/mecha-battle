class_name CoolantReserve
extends Relic
## Every part that vents heat vents more.

@export var cooling := 5


func modify_part_stats(_part: MechPart, numbers: MechStats.PartStats) -> void:
	if numbers.cooling > 0:
		numbers.cooling += cooling
