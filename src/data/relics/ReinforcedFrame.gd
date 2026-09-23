class_name ReinforcedFrame
extends Relic
## More hull points.

@export var hp := 40


func modify_stats(stats: MechStats) -> void:
	stats.hp += hp
