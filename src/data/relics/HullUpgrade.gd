class_name HullUpgrade
extends Relic
## A permanent bump to max HP from a Hangar's Reinforce or an event. The run keeps these apart
## from its relics, so they don't show in the relic bar.

@export var hp := 25


func modify_stats(stats: MechStats) -> void:
	stats.hp += hp
