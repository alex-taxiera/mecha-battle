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
## A boss's turns partway through a fight (see [BossPhase]).
@export var phases: Array[BossPhase] = []
## Expansion cells its frame has open, for enemies that have grown theirs.
@export var opened_cells: Array[Vector2i] = []
## Changes at Threat levels: level -> {property: value}. Every level up to the run's applies, lowest
## first (see [method with_threat]), e.g. a tougher lineup from Threat 2. Adapted from
## Slay-The-Robot's per-difficulty enemy modifiers, which applied at every level.
@export var threat_overrides: Dictionary[int, Dictionary] = {}


## Returns a new grid on [member chassis] (grown by [member opened_cells], if any) holding
## [member lineup].
func build_grid() -> MechGridData:
	var frame := chassis
	if not opened_cells.is_empty():
		frame = chassis.duplicate()
		frame.opened_cells = opened_cells.duplicate()
	var grid := MechGridData.new(frame)
	LoadoutPart.place_all(grid, lineup)
	return grid


## Returns this enemy at [param threat]: itself without overrides that apply, or a copy with each
## level's [member threat_overrides] from 1 to [param threat] set on it, lowest first.
func with_threat(threat: int) -> EnemyLoadout:
	var levels := threat_overrides.keys().filter(func(level: int) -> bool: return level >= 1 and level <= threat)
	if levels.is_empty():
		return self
	levels.sort()
	var copy: EnemyLoadout = duplicate()
	for level: int in levels:
		var changes: Dictionary = threat_overrides[level]
		for property: String in changes:
			copy.set(property, changes[property])
	return copy
