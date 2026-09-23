class_name FightEffect
extends EventEffect
## Starts a fight against one of the sector's enemies of [member tier], once the player has read
## the outcome. Winning it drops that tier's loot.

@export var tier := EnemyLoadout.Tier.ELITE


func apply(_run: RunState, result: EventResult) -> void:
	result.fight_tier = tier
