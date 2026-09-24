class_name BlackBoxContract
extends Relic
## [member energy] more energy a turn, but fights drop no gold.

@export var energy := 40


func modify_stats(stats: MechStats) -> void:
	stats.base_energy += energy
	stats.energy_generated += energy


func modify_gold(_amount: int) -> int:
	return 0
