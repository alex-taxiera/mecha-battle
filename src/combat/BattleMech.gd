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
## Emitted when a status's charges wrap past its top, [param times] times at once.
@warning_ignore("unused_signal") # emitted by ActiveStatus
signal status_overflowed(status: ActiveStatus, times: int)

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
## The statuses on the mech, one of each at most, each with charges.
var statuses: Array[ActiveStatus] = []

# Parts whose abilities have been announced this fight.
var _announced: Array[ActivePart] = []
# Thick Plating and the relics, in the hit pipeline.
var _interceptors: Array[HitInterceptor] = []


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
	if chassis.passive == MechChassis.Passive.THICK_PLATING:
		_interceptors.append(PlatingInterceptor.new(chassis.plating))
	for relic in relics:
		_interceptors.append(RelicInterceptor.new(relic, HitInterceptor.Side.ATTACKER))
		_interceptors.append(RelicInterceptor.new(relic, HitInterceptor.Side.TARGET))
	for placement in grid.get_placements():
		var active := ActivePart.new(placement.part, stats.part_stats[placement])
		active.hardpoint = chassis.get_hardpoint_at(placement.origin)
		active_parts.append(active)


## Returns what a hit of [param amount] would take off, without taking it: the target's side of
## the [HitPipeline] (a THICK_PLATING chassis takes [member MechChassis.plating] less, never below
## 0, then relics have their say), as a preview.
func get_damage_taken(amount: int) -> int:
	var hit := HitPipeline.Hit.new(HitPipeline.Kind.OTHER, self, amount)
	hit.preview = true
	return HitPipeline.resolve(hit)


## Takes a hit of [param amount] of [param kind] through the [HitPipeline] (see
## [method take_hit]). Returns the damage taken, shield and hull together.
func take_damage(amount: int, kind := HitPipeline.Kind.OTHER, attacker: BattleMech = null) -> int:
	return take_hit(HitPipeline.Hit.new(kind, self, amount, attacker))


## Takes [param hit]: after the interceptors (plating, relics, statuses), off the [member shield]
## first, then [member current_health], stopping at 0. Returns the damage taken, shield and hull
## together; [member last_absorbed] is the shield's share.
func take_hit(hit: HitPipeline.Hit) -> int:
	return HitPipeline.resolve(hit)


## Starts a fight: each part ability's [method PartAbility.on_fight_start], then each relic's
## [method Relic.on_fight_start], announcing the relics that act.
func start_fight() -> void:
	for active in get_abilities():
		active.part.ability.on_fight_start(self, active)
	for relic in relics:
		if relic.on_fight_start(self):
			relic_triggered.emit(relic)


## Returns the damage a shot from [param weapon] would leave this mech with: its linked damage,
## through this mech's side of the [HitPipeline] (relics). A relic that changes it is announced.
func get_shot_damage(weapon: ActivePart) -> int:
	return HitPipeline.outgoing(HitPipeline.Hit.new(HitPipeline.Kind.SHOT, null, weapon.damage, self, weapon))


## Returns this mech's interceptors for [param side] of a hit: on the attacker's side its relics'
## shot changes; on the target's, Thick Plating and its relics. Then its statuses that change hits.
func get_interceptors(side: HitInterceptor.Side) -> Array[HitInterceptor]:
	var interceptors: Array[HitInterceptor] = []
	for interceptor in _interceptors:
		if interceptor.side == side:
			interceptors.append(interceptor)
	for status in statuses:
		if status.charges != 0 and status.data.side == side and status.data.intercepts_hits():
			interceptors.append(StatusInterceptor.new(status))
	return interceptors


## Adds [param amount] charges of [param status] (and [param secondary] secondary charges), onto
## the one the mech has or a new one. Returns it, or null if it has no charges left.
func add_status(status: MechStatus, amount: int, secondary := 0) -> ActiveStatus:
	var active := get_status(status.id)
	if active == null:
		active = ActiveStatus.new(status, self)
		statuses.append(active)
	active.add(amount, secondary)
	_prune_statuses()
	return active if active in statuses else null


## Returns the mech's status with [param id], or null.
func get_status(id: String) -> ActiveStatus:
	for status in statuses:
		if status.data.id == id:
			return status
	return null


## Returns the charges of the mech's status with [param id], or 0.
func get_status_charges(id: String) -> int:
	var status := get_status(id)
	return status.charges if status else 0


## Ticks every status (see [method ActiveStatus.tick]) and drops the ones worn off.
func tick_statuses(delta: float) -> void:
	for status in statuses.duplicate():
		status.tick(delta)
	_prune_statuses()


func _prune_statuses() -> void:
	statuses = statuses.filter(func(status: ActiveStatus) -> bool: return status.charges != 0)


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
	return take_damage(damage, HitPipeline.Kind.STORM)
