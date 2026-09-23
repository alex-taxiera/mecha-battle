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

## Emitted when one of the mech's relics does something the player should see.
signal relic_triggered(relic: Relic)

## The frame, for its passive. Only read.
var chassis: MechChassis
## What the fight calls the mech: its chassis's name, or an enemy's own.
var mech_name: String
## Hull points at full health: the chassis's base HP plus every part's HP, times any HP scale.
var max_hp: int
var current_health: int
## Energy stored for parts to spend. A fight starts with none.
var current_energy := 0
## Energy the chassis adds every turn, on top of what generators make, with any relic bonus.
var base_energy: int
## The run's relics, for the player's mech. Enemies have none.
var relics: Array[Relic] = []
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
## bonuses in each [ActivePart]. [param hp_scale] scales [member max_hp], rounded, for enemies
## that get tougher up the map. The mech starts at [param start_health], or full health if it's
## below 0; the player's starts where their last fight left it. [param p_relics] change its stats
## and hook into the fight.
func _init(grid: MechGridData, rules: Array[SynergyRule] = [], hp_scale := 1.0, start_health := -1,
		p_relics: Array[Relic] = []) -> void:
	relics.assign(p_relics)
	var stats := MechStats.calculate(grid, rules, relics)
	chassis = grid.chassis
	mech_name = chassis.chassis_name
	max_hp = roundi(stats.hp * hp_scale)
	current_health = max_hp if start_health < 0 else clampi(start_health, 0, max_hp)
	base_energy = stats.base_energy
	for placement in grid.get_placements():
		var active := ActivePart.new(placement.part, stats.part_stats[placement])
		active.hardpoint = chassis.get_hardpoint_at(placement.origin)
		active_parts.append(active)


## Returns what a hit of [param amount] would take off, without taking it: a THICK_PLATING
## chassis takes [member MechChassis.plating] less, never below 0, then relics have their say.
func get_damage_taken(amount: int) -> int:
	if chassis.passive == MechChassis.Passive.THICK_PLATING:
		amount = maxi(0, amount - chassis.plating)
	for relic in relics:
		amount = relic.modify_damage_taken(self, amount)
	return amount


## Takes a hit of [param amount] off [member current_health], stopping at 0, after plating (see
## [method get_damage_taken]). Returns the damage taken.
func take_damage(amount: int) -> int:
	amount = get_damage_taken(amount)
	current_health = maxi(0, current_health - amount)
	return amount


## Starts a fight: each relic's [method Relic.on_fight_start], announcing the ones that act.
func start_fight() -> void:
	for relic in relics:
		if relic.on_fight_start(self):
			relic_triggered.emit(relic)


## Returns the damage a shot from [param weapon] deals: its linked damage, changed by the
## relics. A relic that changes it is announced.
func get_shot_damage(weapon: ActivePart) -> int:
	var damage := weapon.damage
	for relic in relics:
		var changed := relic.modify_shot_damage(self, weapon, damage)
		if changed != damage:
			relic_triggered.emit(relic)
		damage = changed
	return damage


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
