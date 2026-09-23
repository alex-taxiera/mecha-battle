class_name EnemyLoadout
extends Resource
## An enemy mech: its frame and ready-made build, and which kind of map node it guards. Each
## sector's [ActData] lists the enemies it can send.

enum Tier { NORMAL, ELITE, BOSS }

@export var id: String
@export var enemy_name: String
@export var tier := Tier.NORMAL
@export var chassis: MechChassis
@export var lineup: Array[LoadoutPart] = []
## This enemy's HP, times the sector's scaling (see [method ActData.get_enemy_hp_scale]).
@export var hp_scale := 1.0


## Returns a new grid on [member chassis] holding [member lineup].
func build_grid() -> MechGridData:
	var grid := MechGridData.new(chassis)
	LoadoutPart.place_all(grid, lineup)
	return grid
