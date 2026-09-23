class_name OverdriveCore
extends Relic
## A boss relic: much more chassis energy, but every shot runs hotter.

@export var energy := 20
@export var heat_per_shot := 5


func modify_part_stats(part: MechPart, numbers: MechStats.PartStats) -> void:
	if part.type == MechPart.PartType.WEAPON:
		numbers.heat += heat_per_shot


func modify_stats(stats: MechStats) -> void:
	stats.base_energy += energy
	stats.energy_generated += energy
