class_name BattleMech
extends RefCounted
## A mech in a fight, built from a finished [MechGridData]. The grid, its chassis, and its
## parts are only read: everything that changes during combat lives here and in the
## [ActivePart]s.

## Full heat. A MELTDOWN chassis melts down when it gets there.
const MAX_HEAT := 100
## Thermal throttling: above this much heat, a mech's weapons cool down slower, down to
## MIN_FIRE_RATE of normal speed at full heat.
const THROTTLE_HEAT := 50
const MIN_FIRE_RATE := 0.5

## The frame, for its passive. Only read.
var chassis: MechChassis
## Hull points at full health: the chassis's base HP for the round plus every part's HP.
var max_hp: int
var current_health: int
## Energy stored for parts to spend. A fight starts with none.
var current_energy := 0
## Energy the chassis adds every turn, on top of what generators make.
var base_energy: int
## Heat built up by firing, from 0 to [constant MAX_HEAT]. Heatsinks vent it each turn. Above
## [constant THROTTLE_HEAT] it slows the mech's weapons (see [method get_fire_rate]).
var heat := 0
## Seconds left in a Meltdown shutdown. While it's above 0, none of the mech's parts act and
## its chassis adds no energy.
var shutdown_left := 0.0
## Whether the Striker's Overclock has been spent this fight.
var overclock_spent := false
## Damage the mech has done to its enemy this fight, from its weapons and meltdowns, after the
## enemy's plating.
var damage_dealt := 0
## One per part on the grid, in the grid's placement order. A mounted weapon knows its bay.
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
		var active := ActivePart.new(placement.part, stats.part_stats[placement])
		active.hardpoint = chassis.get_hardpoint_at(placement.origin)
		active_parts.append(active)


## Returns what a hit of [param amount] would take off, without taking it: a THICK_PLATING
## chassis takes [member MechChassis.plating] less, never below 0.
func get_damage_taken(amount: int) -> int:
	if chassis.passive == MechChassis.Passive.THICK_PLATING:
		return maxi(0, amount - chassis.plating)
	return amount


## Takes a hit of [param amount] off [member current_health], stopping at 0, after plating (see
## [method get_damage_taken]). Returns the damage taken.
func take_damage(amount: int) -> int:
	amount = get_damage_taken(amount)
	current_health = maxi(0, current_health - amount)
	return amount


## Adds [param amount] heat, or vents it when negative, keeping it between 0 and
## [constant MAX_HEAT].
func add_heat(amount: int) -> void:
	heat = clampi(heat + amount, 0, MAX_HEAT)


func is_shut_down() -> bool:
	return shutdown_left > 0.0


## Returns how fast the mech's weapons cool down, as a share of normal speed: 1 up to
## [constant THROTTLE_HEAT] heat, falling evenly to [constant MIN_FIRE_RATE] at full heat.
func get_fire_rate() -> float:
	var over := clampf(float(heat - THROTTLE_HEAT) / (MAX_HEAT - THROTTLE_HEAT), 0.0, 1.0)
	return lerpf(1.0, MIN_FIRE_RATE, over)


## Returns whether [param active] is a working weapon whose cooldown has run out but that the
## mech can't pay to fire. A shut-down mech's weapons aren't starved, just off.
func is_starved(active: ActivePart) -> bool:
	return active.is_active and active.part.type == MechPart.PartType.WEAPON and active.current_cooldown == 0.0 \
		and current_energy < active.energy_cost and not is_shut_down()


## Returns the weapon that has done the most damage this fight, the first placed on a tie, or
## null if none has done any.
func get_top_weapon() -> ActivePart:
	var top: ActivePart = null
	for active in active_parts:
		if active.part.type == MechPart.PartType.WEAPON and active.damage_dealt > 0 \
				and (top == null or active.damage_dealt > top.damage_dealt):
			top = active
	return top
