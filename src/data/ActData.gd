class_name ActData
extends Resource
## One sector of a run: the shape of its map, how often each kind of node comes up, the enemies
## it sends, and how much tougher they get the deeper the player goes. The sectors live in
## [code]res://resources/acts/[/code].

@export var id: String
## e.g. "The Scavenger Junkyards".
@export var sector_name: String

@export_group("Map")
## Floors of nodes before the boss.
@export var floors := 12
## Nodes across each floor of the map's lattice.
@export var columns := 7
## Paths walked up the lattice. Only what they walk becomes the map.
@export var paths := 6
## The first floor (0 is the bottom) where elites and hangars can appear.
@export var min_special_floor := 4
## Builds the map. Left empty, it's [MapGenerator]; a sector can name a subclass of it to lay out
## its map its own way.
@export var generator: Script

@export_group("Node weights")
## How often each kind of node comes up on the floors that don't have a fixed kind.
@export var battle_weight := 45
@export var event_weight := 22
@export var elite_weight := 10
@export var hangar_weight := 12
@export var shop_weight := 6

@export_group("Enemies")
## Every enemy the sector can send, of all tiers. Bosses guard the top of its map.
@export var enemies: Array[EnemyLoadout] = []
## Enemy HP in this sector, times each enemy's own [member EnemyLoadout.hp_scale].
@export var enemy_hp_scale := 1.0
## How much enemy HP grows each floor up the map: 0.03 is +3% of the sector's a floor.
@export var enemy_hp_per_floor := 0.03


## Returns the weight of each [enum MapNode.Type] that can be rolled for a node.
func get_node_weights() -> Dictionary[MapNode.Type, int]:
	return {
		MapNode.Type.BATTLE: battle_weight,
		MapNode.Type.EVENT: event_weight,
		MapNode.Type.ELITE: elite_weight,
		MapNode.Type.HANGAR: hangar_weight,
		MapNode.Type.SHOP: shop_weight,
	}


## Returns the sector's enemies of [param tier].
func get_enemies(tier: EnemyLoadout.Tier) -> Array[EnemyLoadout]:
	return enemies.filter(func(enemy: EnemyLoadout) -> bool: return enemy.tier == tier)


## Returns how much an enemy's HP is scaled on floor [param floor_index] (0 is the bottom).
func get_enemy_hp_scale(floor_index: int) -> float:
	return enemy_hp_scale * (1.0 + enemy_hp_per_floor * floor_index)
