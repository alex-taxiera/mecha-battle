class_name BattleMech
extends RefCounted
## A mech in a fight, built from a finished [MechGridData]. The grid, its chassis, and its
## parts are only read: everything that changes during combat lives here and in the
## [ActivePart]s.

## Hull points at full health: the chassis's base HP plus every part's HP.
var max_hp: int
var current_health: int
## Energy stored for parts to spend. A fight starts with none.
var current_energy := 0
## Energy the chassis adds every turn, on top of what generators make.
var base_energy: int
## One per part on the grid, in the grid's placement order.
var active_parts: Array[ActivePart] = []


## Pass the run's [param rules] so link bonuses count, the same way the shop's stats panel
## counts them: HP bonuses (e.g. Plated) toward [member max_hp], and damage and energy
## bonuses in each [ActivePart].
func _init(grid: MechGridData, rules: Array[SynergyRule] = []) -> void:
	var stats := MechStats.calculate(grid, rules)
	max_hp = stats.hp
	current_health = max_hp
	base_energy = grid.chassis.base_energy
	for placement in grid.get_placements():
		active_parts.append(ActivePart.new(placement.part, stats.part_stats[placement]))


## Takes [param amount] off [member current_health], stopping at 0.
func take_damage(amount: int) -> void:
	current_health = maxi(0, current_health - amount)
