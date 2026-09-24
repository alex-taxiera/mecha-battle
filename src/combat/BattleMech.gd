class_name BattleMech
extends RefCounted
## A mech in a fight, built from a finished [MechGridData]. The grid, its chassis, and its
## parts are only read: everything that changes during combat lives here and in the
## [ActivePart]s.

## Full heat. A chassis with a [MeltdownPassive] melts down when it gets there.
const MAX_HEAT := 100
## Thermal throttling: above this much heat, a mech's weapons cool down slower, down to
## MIN_FIRE_RATE of normal speed at full heat.
const THROTTLE_HEAT := 50
const MIN_FIRE_RATE := 0.5

## Emitted when one of the mech's relics does something the player should see.
signal relic_triggered(relic: Relic)
## One working part's ability, as [method get_abilities] lists them.
class Acting:
	extends RefCounted
	var active: ActivePart
	var ability: PartAbility

	func _init(p_active: ActivePart, p_ability: PartAbility) -> void:
		active = p_active
		ability = p_ability


## Emitted the first time in a fight that a part's ability acts, e.g. armor reflecting a hit.
signal part_triggered(active: ActivePart)
## Emitted when a status's charges wrap past its top, [param times] times at once.
@warning_ignore("unused_signal") # emitted by ActiveStatus
signal status_overflowed(status: ActiveStatus, times: int)
## Emitted when [param amount] charges of a status are added to the mech.
signal status_added(status: ActiveStatus, amount: int)

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
## The run's relics, for the player's mech; an elite's affixes, for an enemy's.
var relics: Array[Relic] = []
## Heat built up by firing, from 0 to [constant MAX_HEAT]. Heatsinks vent it each turn. Above
## [constant THROTTLE_HEAT] it slows the mech's weapons (see [method get_fire_rate]).
var heat := 0
## Heat above which the weapons slow. A thermal regulator raises it for a fight.
var throttle_heat := THROTTLE_HEAT
## Seconds left in a Meltdown shutdown. While it's above 0, none of the mech's parts act and
## its chassis adds no energy.
var shutdown_left := 0.0
## What the chassis's passive keeps for this fight, e.g. whether Overclock is spent (passives are
## shared, so they keep nothing themselves).
var passive_state := {}
## Damage the mech has done to its enemy this fight, from its weapons and meltdowns, after the
## enemy's plating.
var damage_dealt := 0
## One per part on the grid, in the grid's placement order. A mounted weapon knows its bay.
var active_parts: Array[ActivePart] = []
## The statuses on the mech, one of each at most, each with charges.
var statuses: Array[ActiveStatus] = []
## The run's field kits this fight (see [FieldKit]), and the indices of those already used.
var kits: Array[FieldKit] = []
var kits_used: Array[int] = []
## A boss's phases (see [BossPhase]) and the ones it has entered this fight.
var phases: Array[BossPhase] = []
var phases_done: Array[BossPhase] = []
## Added to every phase's threshold, e.g. by Threat (bosses turning sooner).
var phase_threshold_bonus := 0.0

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
	if chassis.passive:
		_interceptors.append_array(chassis.passive.make_interceptors(self))
	for relic in relics:
		_interceptors.append(RelicInterceptor.new(relic, HitInterceptor.Side.ATTACKER))
		_interceptors.append(RelicInterceptor.new(relic, HitInterceptor.Side.TARGET))
	var by_placement := {}
	for placement in grid.get_placements():
		var active := ActivePart.new(placement.part, stats.part_stats[placement])
		active.hardpoint = chassis.get_hardpoint_at(placement.origin)
		active_parts.append(active)
		by_placement[placement] = active
	for contact in grid.get_contacts():
		var a: ActivePart = by_placement[contact.a]
		var b: ActivePart = by_placement[contact.b]
		a.neighbors.append(b)
		b.neighbors.append(a)
	for acting in get_abilities():
		_interceptors.append_array(acting.ability.make_interceptors(self, acting.active))


## Returns what a hit of [param amount] would take off, without taking it: the target's side of
## the [HitPipeline] (a [ThickPlatingPassive] chassis takes its plating off, never below
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
	if chassis.passive:
		chassis.passive.on_fight_start(self)
	for acting in get_abilities():
		acting.ability.on_fight_start(self, acting.active)
	for relic in relics:
		if relic.on_fight_start(self):
			relic_triggered.emit(relic)


## As the fight ends, [param won] saying whether this mech won: its parts' and relics'
## [code]on_fight_end[/code] hooks.
func end_fight(won: bool) -> void:
	for acting in get_abilities():
		acting.ability.on_fight_end(self, acting.active, won)
	for relic in relics:
		relic.on_fight_end(self, won)


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
	for relic in relics:
		if relic.blocks_status(self, status):
			return null
	var active := get_status(status.id)
	if active == null:
		active = ActiveStatus.new(status, self)
		statuses.append(active)
	active.add(amount, secondary)
	if amount != 0:
		status_added.emit(active, amount)
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


## Runs each relic's [method Relic.on_tick].
func tick_relics(delta: float) -> void:
	if chassis.passive:
		chassis.passive.on_tick(self, delta)
	for relic in relics.duplicate():
		relic.on_tick(self, delta)


## Gives the mech [param relic] partway through a fight, e.g. from a boss phase: its fight hooks
## and hit changes from now on (stats were set when the fight began).
func add_relic(relic: Relic) -> void:
	relics.append(relic)
	_interceptors.append(RelicInterceptor.new(relic, HitInterceptor.Side.ATTACKER))
	_interceptors.append(RelicInterceptor.new(relic, HitInterceptor.Side.TARGET))


## Enters each of the mech's [member phases] whose moment has come: a revive the first time it's
## down, any other once its HP is at or below its threshold (and above 0). Returns the phases it
## entered, in order.
func check_phases() -> Array[BossPhase]:
	var entered: Array[BossPhase] = []
	for phase in phases:
		if phase in phases_done:
			continue
		var due := current_health <= 0 if phase.revive else \
			current_health > 0 and current_health <= max_hp * (phase.threshold + phase_threshold_bonus)
		if due:
			_enter_phase(phase)
			entered.append(phase)
	return entered


func _enter_phase(phase: BossPhase) -> void:
	phases_done.append(phase)
	if phase.revive:
		current_health = maxi(1, roundi(max_hp * phase.heal_share))
	elif phase.heal_share > 0.0:
		current_health = mini(max_hp, current_health + roundi(max_hp * phase.heal_share))
	if phase.shield_share > 0.0:
		var extra := roundi(max_hp * phase.shield_share)
		max_shield += extra
		shield += extra
	if phase.heat >= 0:
		heat = clampi(phase.heat, 0, MAX_HEAT)
	for active in active_parts:
		if active.part.type == MechPart.PartType.WEAPON:
			active.cooldown_max *= phase.cooldown_scale
			active.current_cooldown = minf(active.current_cooldown, active.cooldown_max)
			active.damage = roundi(active.damage * phase.damage_scale)
	for relic in phase.relics:
		add_relic(relic.duplicate())


## Returns whether kit [param index] is there and not yet used this fight.
func can_use_kit(index: int) -> bool:
	return index >= 0 and index < kits.size() and index not in kits_used


## Repairs up to [param amount] of the hull, never past [member max_hp], and only while the mech
## stands. Returns what it repaired.
func heal(amount: int) -> int:
	if current_health <= 0 or amount <= 0:
		return 0
	var healed := mini(amount, max_hp - current_health)
	current_health += healed
	return healed


## Takes [param status] off the mech at once, whatever its charges.
func clear_status(status: ActiveStatus) -> void:
	statuses.erase(status)


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


## Returns how fast the mech's weapons count down: [method get_fire_rate] from heat, as the mech's
## statuses change it (e.g. Jammed).
func get_weapon_speed() -> float:
	var speed := get_fire_rate()
	if chassis.passive:
		speed = chassis.passive.modify_weapon_speed(self, speed)
	for status in statuses:
		speed = status.data.modify_weapon_speed(self, status, speed)
	return maxf(0.0, speed)


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


## Returns the working parts' abilities that act, part by part: every one that stacks, and the
## first of each kind that doesn't.
func get_abilities() -> Array[Acting]:
	var acting: Array[Acting] = []
	var seen := {}
	for active in active_parts:
		if not active.is_active:
			continue
		for ability in active.part.get_abilities():
			if not ability.stacks:
				var kind: Script = ability.get_script()
				if seen.has(kind):
					continue
				seen[kind] = true
			acting.append(Acting.new(active, ability))
	return acting


## Returns how many seconds sooner the storm starts for this mech's parts.
func get_storm_lead() -> float:
	var lead := 0.0
	for acting in get_abilities():
		lead = maxf(lead, acting.ability.get_storm_lead())
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
	var had_shield := shield > 0
	shield = 0
	for active in active_parts:
		if active.upkeep > 0:
			active.is_active = false
	if had_shield:
		_break_shield()


## After [param hit] lands on this mech: its relics' [method Relic.on_hit_taken], the abilities
## that answer damage, and those that answer the shield breaking if this hit took its last point. [param shield_before] is the shield it had.
func on_hit_landed(hit: HitPipeline.Hit, shield_before: int) -> void:
	for relic in relics.duplicate():
		relic.on_hit_taken(self, hit)
	if hit.taken <= 0:
		return
	for acting in get_abilities():
		acting.ability.on_damaged(self, acting.active, hit.taken)
	if shield_before > 0 and shield == 0:
		_break_shield()


func _break_shield() -> void:
	for acting in get_abilities():
		acting.ability.on_shield_broken(self, acting.active)


## Takes a storm strike of [param damage]: the mech's abilities change it first (a lightning rod
## grounds half), then it lands like any hit. Returns the damage taken.
func take_storm_strike(damage: int) -> int:
	for acting in get_abilities():
		var changed := acting.ability.modify_storm_strike(self, damage)
		if changed != damage:
			announce(acting.active)
		damage = changed
	return take_damage(damage, HitPipeline.Kind.STORM)
