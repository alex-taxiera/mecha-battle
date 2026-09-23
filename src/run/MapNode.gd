class_name MapNode
extends RefCounted
## One stop on a sector's map. The player travels up the map along [member next], one node at
## a time, from the bottom floor to the boss.

enum Type {
	## A fight with one of the sector's normal enemies.
	BATTLE,
	## A fight with a tougher enemy, for better loot.
	ELITE,
	## The Scrap Shop: buy and sell parts.
	SHOP,
	## The Hangar / Refit Bay: repair the hull or reinforce it.
	HANGAR,
	## A choice with risks and rewards.
	EVENT,
	## The sector boss, at the top of the map.
	BOSS,
}

## Unique within a map, e.g. "3_5" (floor 3, column 5), or "boss".
var id: String
## 0 is the bottom floor; the boss's floor is one past the sector's last.
var floor_index: int
## Where the node sits across its floor, 0 on the left.
var column: int
var type := Type.BATTLE
## The nodes the player can travel to from here, on the floor above.
var next: Array[MapNode] = []
## Whether the player has been here.
var visited := false
## The enemy fought here, for fights. A boss's is picked with the map; the others are picked
## the first time the node's fight is needed.
var enemy: EnemyLoadout
## Where the node is drawn, off its lattice point, in fractions of the spacing between points,
## so the map doesn't look like a grid. Rolled with the map.
var jitter := Vector2.ZERO


func _init(p_floor: int, p_column: int, p_type := Type.BATTLE) -> void:
	floor_index = p_floor
	column = p_column
	type = p_type
	id = "%d_%d" % [p_floor, p_column]


## Returns whether this node is a fight: a battle, an elite, or the boss.
func is_fight() -> bool:
	return type in [Type.BATTLE, Type.ELITE, Type.BOSS]


## Returns the enemy tier fought here. Only meaningful for fights.
func get_tier() -> EnemyLoadout.Tier:
	match type:
		Type.ELITE:
			return EnemyLoadout.Tier.ELITE
		Type.BOSS:
			return EnemyLoadout.Tier.BOSS
	return EnemyLoadout.Tier.NORMAL
