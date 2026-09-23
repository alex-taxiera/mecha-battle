class_name BattleMech
extends RefCounted
## A mech in a fight, built from a finished [MechGridData]. The grid, its chassis, and its
## parts are only read: everything that changes during combat lives here and in the
## [ActivePart]s.

## Full heat. Only a MELTDOWN chassis does anything when it gets there.
const MAX_HEAT := 100

## The frame, for its passive. Only read.
var chassis: MechChassis
## Hull points at full health: the chassis's base HP for the round plus every part's HP.
var max_hp: int
var current_health: int
## Energy stored for parts to spend. A fight starts with none.
var current_energy := 0
## Energy the chassis adds every turn, on top of what generators make.
var base_energy: int
## Heat built up by firing, from 0 to [constant MAX_HEAT]. Heatsinks vent it each turn.
var heat := 0
## Seconds left in a Meltdown shutdown. While it's above 0, none of the mech's parts act and
## its chassis adds no energy.
var shutdown_left := 0.0
## Whether the Striker's Overclock has been spent this fight.
var overclock_spent := false
## One per part on the grid, in the grid's placement order.
var active_parts: Array[ActivePart] = []


## Pass the run's [param rules] so link bonuses count, the same way the shop's stats panel
## counts them: HP bonuses (e.g. Plated) toward [member max_hp], and damage and energy
## bonuses in each [ActivePart]. The chassis's HP is its [param round_number]'s, grown each
## round (see [method MechChassis.get_base_hp]).
func _init(grid: MechGridData, rules: Array[SynergyRule] = [], round_number := 1) -> void:
	var stats := MechStats.calculate(grid, rules, round_number)
	chassis = grid.chassis
	max_hp = stats.hp
	current_health = max_hp
	base_energy = chassis.base_energy
	for placement in grid.get_placements():
		active_parts.append(ActivePart.new(placement.part, stats.part_stats[placement]))


## Takes a hit of [param amount] off [member current_health], stopping at 0. A THICK_PLATING
## chassis takes [member MechChassis.plating] less, never below 0. Returns the damage taken.
func take_damage(amount: int) -> int:
	if chassis.passive == MechChassis.Passive.THICK_PLATING:
		amount = maxi(0, amount - chassis.plating)
	current_health = maxi(0, current_health - amount)
	return amount


## Adds [param amount] heat, or vents it when negative, keeping it between 0 and
## [constant MAX_HEAT].
func add_heat(amount: int) -> void:
	heat = clampi(heat + amount, 0, MAX_HEAT)


func is_shut_down() -> bool:
	return shutdown_left > 0.0
