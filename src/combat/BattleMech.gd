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
## Emitted the first time in a fight that a part's ability acts, e.g. armor reflecting a hit.
signal part_triggered(active: ActivePart)

## The frame, for its passive. Only read.
var chassis: MechChassis
## What the fight calls the mech: its chassis's name, or an enemy's own.
var mech_name: String
## Hull points at full health: the chassis's base HP plus every part's HP, times any HP scale.
var max_hp: int
var current_health: int
## Shield points: taken off before [member current_health], full again every fight. Parts with
## [member MechPart.shield] add to it; it collapses for the fight if their upkeep goes unpaid.
var max_shield := 0
var shield := 0
## Hit and shield absorption of the mech's last hit (see [method take_damage]), for the screen.
var last_taken := 0
var last_absorbed := 0
## Energy stored for parts to spend. A fight starts with none.
var current_energy := 0
## Energy the chassis adds every turn, on top of what generators make, with any relic bonus.
var base_energy: int
## The run's relics, for the player's mech. Enemies have none.
var relics: Array[Relic] = []
## Heat built up by firing, from 0 to [constant MAX_HEAT]. Heatsinks vent it each turn. Above
## [constant THROTTLE_HEAT] it slows the mech's weapons (see [method get_fire_rate]).
var heat := 0
## Heat above which the weapons slow. A thermal regulator raises it for a fight.
var throttle_heat := THROTTLE_HEAT
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

# Parts whose abilities have been announced this fight.
var _announced: Array[ActivePart] = []


## Pass the run's [param rules] so link bonuses count, the same way the shop's stats panel
## counts them: HP bonuses (e.g. Plated) toward [member max_hp], and damage and energy
## bonuses in each [ActivePart]. [param hp_scale] scales [member max_hp] and the shield, rounded,
## for enemies that get tougher up the map. The mech starts at [param start_health], or full
## health if it's below 0; the player's starts where their last fight left it. [param p_relics]
## change its stats and hook into the fight.
func _init(grid: MechGridData, rules: Array[SynergyRule] = [], hp_scale := 1.0, start_health := -1,
		p_relics: Array[Relic] = []) -> void:
	relics.assign(p_relics)
	var stats := MechStats.calculate(grid, rules, relics)
	chassis = grid.chassis
	mech_name = chassis.chassis_name
	max_hp = roundi(stats.hp * hp_scale)
	current_health = max_hp if start_health < 0 else clampi(start_health, 0, max_hp)
	base_energy = stats.base_energy
	max_shield = roundi(stats.shield * hp_scale)
	shield = max_shield
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


## Takes a hit of [param amount], after plating (see [method get_damage_taken]): off the
## [member shield] first, then [member current_health], stopping at 0. Returns the damage taken,
## shield and hull together; [member last_absorbed] is the shield's share.
func take_damage(amount: int) -> int:
	amount = get_damage_taken(amount)
	var absorbed := mini(shield, amount)
	shield -= absorbed
	current_health = maxi(0, current_health - (amount - absorbed))
	last_taken = amount
	last_absorbed = absorbed
	return amount


## Starts a fight: each part ability's [method PartAbility.on_fight_start], then each relic's
## [method Relic.on_fight_start], announcing the relics that act.
func start_fight() -> void:
	for active in get_abilities():
		active.part.ability.on_fight_start(self, active)
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
## [member throttle_heat], falling evenly to [constant MIN_FIRE_RATE] at full heat.
func get_fire_rate() -> float:
	var over := clampf(float(heat - throttle_heat) / maxi(1, MAX_HEAT - throttle_heat), 0.0, 1.0)
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


## Returns the working parts whose abilities act: every one that stacks, and the first of each
## kind that doesn't.
func get_abilities() -> Array[ActivePart]:
	var acting: Array[ActivePart] = []
	var seen := {}
	for active in active_parts:
		var ability := active.part.ability
		if ability == null or not active.is_active:
			continue
		if not ability.stacks:
			var kind: Script = ability.get_script()
			if seen.has(kind):
				continue
			seen[kind] = true
		acting.append(active)
	return acting


## Returns how many seconds sooner the storm starts for this mech's parts.
func get_storm_lead() -> float:
	var lead := 0.0
	for active in get_abilities():
		lead = maxf(lead, active.part.ability.get_storm_lead())
	return lead


## Announces [param active]'s ability the first time it acts in a fight.
func announce(active: ActivePart) -> void:
	if active not in _announced:
		_announced.append(active)
		part_triggered.emit(active)


## Returns the energy the mech's working parts drain each turn.
func get_upkeep() -> int:
	var total := 0
	for active in active_parts:
		if active.is_active:
			total += active.upkeep
	return total


## Drops the shield for the rest of the fight and switches off the parts that paid to keep it up.
func collapse_shield() -> void:
	shield = 0
	for active in active_parts:
		if active.upkeep > 0:
			active.is_active = false


## Takes a storm strike of [param damage]: the mech's abilities change it first (a lightning rod
## grounds half), then it lands like any hit. Returns the damage taken.
func take_storm_strike(damage: int) -> int:
	for active in get_abilities():
		var changed := active.part.ability.modify_storm_strike(self, damage)
		if changed != damage:
			announce(active)
		damage = changed
	return take_damage(damage)
