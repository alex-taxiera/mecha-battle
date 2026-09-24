class_name FightEffect
extends EventEffect
## Starts a fight once the player has read the outcome: against [member enemy] if it's set,
## otherwise one of the sector's enemies of [member tier]. Winning it drops that tier's loot (the
## enemy's own tier for a named one), plus a relic of [member relic_rarity] if it's set.

@export var tier := EnemyLoadout.Tier.ELITE
## The enemy to fight, e.g. a pit fighter; null for one of the sector's.
@export var enemy: EnemyLoadout
## A relic of this rarity joins the win's relic choice; -1 for none.
@export var relic_rarity := -1


func apply(_run: RunState, result: EventResult) -> void:
	result.fight_tier = enemy.tier if enemy else tier
	result.fight_enemy = enemy
	result.fight_relic_rarity = relic_rarity
