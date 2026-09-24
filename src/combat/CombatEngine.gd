class_name CombatEngine
extends RefCounted
## Runs a fight between two [BattleMech]s, one tick at a time. Each chassis's base energy
## flows in and its heatsinks vent heat a little every tick, at their per-turn rates, and every
## working part's cooldown counts down. Any other part whose cooldown runs out (a generator,
## say) adds its energy and heat to its mech; then a weapon whose
## cooldown has run out fires at the other mech, if its own mech can pay for the shot, and
## heats its mech up. A hot mech's weapons cool down slower (thermal throttling). Chassis
## passives change this: Thick Plating shrinks every hit taken,
## Overclock doubles the first shot, and Meltdown turns full heat into a big hit and a
## shutdown. The player's relics can change shots, hits taken, and the fight's start. A fight that runs long brings the electrical storm, a sudden death that drains both
## mechs harder and harder. The fight ends on the tick a mech's health reaches 0.

enum State { PRE_GAME, RUNNING, FINISHED }

## Emitted after [param weapon]'s shot has hit, so [param target]'s health already shows it.
## [param damage] is what the target took, after any plating.
signal weapon_fired(attacker: BattleMech, weapon: ActivePart, target: BattleMech, damage: int)
## Emitted when a MELTDOWN mech hits full heat and deals [param damage] to [param target].
signal meltdown(mech: BattleMech, target: BattleMech, damage: int)
## Emitted when [param mech] uses [param kit], by hand or on its own.
signal kit_used(mech: BattleMech, kit: FieldKit)
## Emitted each time the electrical storm hits both mechs for [param damage], before plating.
signal storm_struck(damage: int)
## Emitted when [param source]'s armor deals [param damage] back to [param target], after its
## plating and shield.
signal reflected(source: BattleMech, target: BattleMech, damage: int)
## Emitted when [param mech] can't pay its parts' upkeep and its shield collapses for the fight.
signal shield_collapsed(mech: BattleMech)
## Emitted when a boss enters [param phase], once its HP drops far enough (or, for a revive, when
## it would have gone down: it's back up, and the fight goes on).
signal phase_changed(mech: BattleMech, phase: BossPhase)
## Emitted once, on the tick a mech goes down. [param winner] is null for a draw: both mechs
## going down in the same tick.
signal battle_ended(winner: BattleMech)

## Times this close count as reached. Adding or subtracting a delta like 0.1 leaves float error
## behind (1.0 minus ten 0.1s is about 1.4e-16, not 0), which would delay things by a tick.
const TIME_EPSILON := 1e-6
## Seconds in a turn. The shop counts energy per turn; in a fight each chassis's base energy
## and each heatsink's cooling arrive over a turn at that rate, so a fight does what the shop
## says it does.
const TURN_SECONDS := 1.0

var left: BattleMech
var right: BattleMech
## Ticks only move the fight while it's RUNNING: [method start] begins it and a mech going
## down finishes it.
var state := State.PRE_GAME
## Seconds fought so far.
var elapsed := 0.0

# The electrical storm.
## Seconds into the fight when the storm starts. Normal fights are over well before it; it's
## there to end stalemates, like two mechs that can't hurt each other.
var storm_start := 20.0
## Ticks from one strike to the next. The first strike lands on the tick the storm starts.
var storm_interval := 2
## Damage of the first strike. Each strike after it hits [member storm_growth] times harder.
var storm_damage := 1.0
var storm_growth := 1.25

# Each mech's energy, venting, and upkeep built up this far but not yet whole:
# mech -> [energy, vent, upkeep].
var _carry := {}
# Seconds sooner the storm starts: the larger lead either mech's parts give it.
var _storm_lead := 0.0
# Ticks since the storm started, and strikes it has made.
var _storm_ticks := 0
var _storm_strikes := 0


func _init(p_left: BattleMech, p_right: BattleMech) -> void:
	left = p_left
	right = p_right
	_carry = {left: [0.0, 0.0, 0.0], right: [0.0, 0.0, 0.0]}
	_storm_lead = maxf(left.get_storm_lead(), right.get_storm_lead())


## Starts the fight, and each mech's relics' fight-start effects. Only a fight that hasn't
## started yet can start.
func start() -> void:
	if state == State.PRE_GAME:
		state = State.RUNNING
		left.start_fight()
		right.start_fight()
		for mech: BattleMech in [left, right]:
			for i in mech.kits.size():
				if mech.kits[i].trigger == FieldKit.Trigger.FIGHT_START:
					_apply_kit(mech, i)


## Advances a running fight by [param delta] seconds. Shutdowns count down first, then statuses
## tick and wear off, and relics tick. Then both mechs' chassis energy and venting for
## [param delta], cooldowns, generators, and upkeep, so neither side's weapons act before the
## other has charged; then the left mech's weapons fire (a hit on reactive armor deals some
## back), then the right's; then
## any mech at full heat melts down, and the storm strikes if it's up. A shut-down mech does
## none of this. A tick's damage lands together: a mech that goes down still fires back that
## tick, so the fight is only checked for an end once everything has hit, and a boss's phases
## (including a revive) come just before that check.
func process_tick(delta: float) -> void:
	if state != State.RUNNING:
		return
	elapsed += delta
	for mech: BattleMech in [left, right]:
		_tick_shutdown(mech, delta)
	for mech: BattleMech in [left, right]:
		mech.tick_statuses(delta)
		mech.tick_relics(delta)
		if not mech.is_shut_down():
			for acting in mech.get_abilities():
				acting.ability.on_tick(mech, acting.active, delta)
	for mech: BattleMech in [left, right]:
		_tick_flow(mech, delta)
	for mech: BattleMech in [left, right]:
		if not mech.is_shut_down():
			for active in mech.active_parts:
				_tick_part(mech, active, delta)
	for mech: BattleMech in [left, right]:
		_pay_upkeep(mech, delta)
	for mech: BattleMech in [left, right]:
		if not mech.is_shut_down():
			for active in mech.active_parts:
				_try_fire(mech, _enemy_of(mech), active)
	for mech: BattleMech in [left, right]:
		_check_meltdown(mech)
	_tick_storm()
	for mech: BattleMech in [left, right]:
		_trigger_kits(mech)
	for mech: BattleMech in [left, right]:
		for phase in mech.check_phases():
			phase_changed.emit(mech, phase)
	_check_for_end()


## Returns the damage of the storm's strike number [param strike], counting from 0.
func get_storm_strike_damage(strike: int) -> int:
	return roundi(storm_damage * pow(storm_growth, strike))


## Returns the seconds into the fight when the storm starts: [member storm_start], sooner by
## the largest lead either mech's parts give it (a lightning rod).
func get_storm_start() -> float:
	return maxf(0.0, storm_start - _storm_lead)


## Returns the seconds left until the storm starts, or 0 once it's up.
func get_storm_countdown() -> float:
	var remaining := get_storm_start() - elapsed
	return remaining if remaining > TIME_EPSILON else 0.0


func _enemy_of(mech: BattleMech) -> BattleMech:
	return right if mech == left else left


# Counts a Meltdown shutdown down. The mech acts again on the tick it runs out.
func _tick_shutdown(mech: BattleMech, delta: float) -> void:
	if not mech.is_shut_down():
		return
	mech.shutdown_left = maxf(0.0, mech.shutdown_left - delta)
	if mech.shutdown_left <= TIME_EPSILON:
		mech.shutdown_left = 0.0


# A running chassis's base energy flows in and its working heatsinks vent, [param delta]'s
# share of a turn's worth. Energy and heat are whole numbers, so the fractions carry over to
# the next tick: 3 energy a turn arrives as +1 at 0.4, 0.7, and 1.0 seconds.
func _tick_flow(mech: BattleMech, delta: float) -> void:
	if mech.is_shut_down():
		return
	var share := delta / TURN_SECONDS
	var cooling := 0
	for active in mech.active_parts:
		if active.is_active:
			cooling += active.cooling
	var carry: Array = _carry[mech]
	carry[0] += mech.base_energy * share
	carry[1] += cooling * share
	var energy := floori(carry[0] + TIME_EPSILON)
	var vent := floori(carry[1] + TIME_EPSILON)
	carry[0] -= energy
	carry[1] -= vent
	mech.current_energy += energy
	mech.add_heat(-vent)


# Pays [param delta]'s share of a turn's upkeep from a running mech's energy, before its weapons
# fire. A mech that can't pay loses its shield for the rest of the fight, and the parts that
# kept it up switch off.
func _pay_upkeep(mech: BattleMech, delta: float) -> void:
	if mech.is_shut_down():
		return
	var carry: Array = _carry[mech]
	carry[2] += mech.get_upkeep() * delta / TURN_SECONDS
	var due := floori(carry[2] + TIME_EPSILON)
	carry[2] -= due
	if due <= 0:
		return
	if mech.current_energy < due:
		carry[2] = 0.0
		mech.collapse_shield()
		shield_collapsed.emit(mech)
		return
	mech.current_energy -= due


# Counts a working part's cooldown down, and runs any other part whose cooldown ran out: it adds
# its energy and heat to its mech. Weapons count down at their mech's fire rate, so heat slows
# them, and fire in [method _try_fire].
func _tick_part(mech: BattleMech, active: ActivePart, delta: float) -> void:
	if not active.is_active:
		return
	var rate := mech.get_weapon_speed() if active.part.type == MechPart.PartType.WEAPON else 1.0
	active.current_cooldown = maxf(0.0, active.current_cooldown - delta * rate)
	if active.current_cooldown <= TIME_EPSILON:
		active.current_cooldown = 0.0
	if _is_ready(active) and active.part.type != MechPart.PartType.WEAPON:
		mech.current_energy += active.energy_gen
		mech.add_heat(active.heat)
		active.current_cooldown = active.cooldown_max


# Fires a ready weapon if its mech has the energy. One that can't pay stays ready and fires
# on the first tick its mech can. The chassis's passive can make it fire again for free (the
# Striker's Overclock).
func _try_fire(attacker: BattleMech, target: BattleMech, active: ActivePart) -> void:
	if not _is_ready(active) or active.part.type != MechPart.PartType.WEAPON:
		return
	if attacker.current_energy < active.energy_cost:
		# Waiting for energy breaks a firing streak.
		active.streak = 0
		return
	attacker.current_energy -= active.energy_cost
	active.current_cooldown = active.cooldown_max
	_shoot(attacker, target, active)
	if attacker.chassis.passive:
		for i in attacker.chassis.passive.extra_shots(attacker, active):
			_shoot(attacker, target, active)


# A shot: its heat (as the weapon's abilities change it), its hit (shaped by them, e.g. piercing,
# and followed by their on-hit effects), and any damage the target's armor deals back.
func _shoot(attacker: BattleMech, target: BattleMech, active: ActivePart) -> void:
	var abilities := active.part.get_abilities()
	var heat := active.heat
	for ability in abilities:
		heat = ability.modify_shot_heat(active, heat)
	attacker.add_heat(heat)
	active.streak += 1
	var hit := HitPipeline.Hit.new(HitPipeline.Kind.SHOT, target, active.damage, attacker, active)
	for ability in abilities:
		ability.modify_hit(hit)
	var taken := target.take_hit(hit)
	active.last_shot = hit.outgoing
	active.last_missed = hit.rejected
	active.shots += 1
	active.damage_dealt += taken
	attacker.damage_dealt += taken
	weapon_fired.emit(attacker, active, target, taken)
	if not hit.rejected:
		for ability in abilities:
			ability.on_hit(hit)
		for relic in attacker.relics:
			relic.on_hit_dealt(attacker, hit)
	for neighbor in active.neighbors:
		if neighbor.is_active:
			for ability in neighbor.part.get_abilities():
				ability.on_neighbor_fired(attacker, neighbor, active)
	for armor in target.get_abilities():
		var back := armor.ability.on_hit_taken(target, armor.active, active.last_shot)
		if back <= 0:
			continue
		var returned := attacker.take_damage(back, HitPipeline.Kind.REFLECT, target)
		target.damage_dealt += returned
		target.announce(armor.active)
		reflected.emit(target, attacker, returned)


## Uses [param mech]'s MANUAL kit [param index], paying its energy. Returns false, using
## nothing, unless the fight is running, the kit is unused and manual, the mech isn't shut down,
## and it has the energy. A kit that finishes the enemy ends the fight at once.
func use_kit(mech: BattleMech, index: int) -> bool:
	if state != State.RUNNING or not mech.can_use_kit(index) or mech.is_shut_down():
		return false
	var kit := mech.kits[index]
	if kit.trigger != FieldKit.Trigger.MANUAL or mech.current_energy < kit.energy_cost:
		return false
	mech.current_energy -= kit.energy_cost
	_apply_kit(mech, index)
	_check_for_end()
	return true


# Fires each of [param mech]'s unused AUTO kits whose condition is met. Runs before boss phases
# and the end check, so a revive can catch a mech that just went down.
func _trigger_kits(mech: BattleMech) -> void:
	for i in mech.kits.size():
		var kit := mech.kits[i]
		if kit.trigger == FieldKit.Trigger.AUTO and mech.can_use_kit(i) and kit.is_due(mech):
			_apply_kit(mech, i)


func _apply_kit(mech: BattleMech, index: int) -> void:
	var kit := mech.kits[index]
	mech.kits_used.append(index)
	kit.apply(mech, _enemy_of(mech))
	kit_used.emit(mech, kit)


# A mech with a [MeltdownPassive] at full heat hits its enemy, cools to 0, and shuts down.
func _check_meltdown(mech: BattleMech) -> void:
	var passive := mech.chassis.passive as MeltdownPassive
	if passive == null or mech.heat < BattleMech.MAX_HEAT or mech.is_shut_down():
		return
	var target := _enemy_of(mech)
	var taken := target.take_damage(passive.damage, HitPipeline.Kind.MELTDOWN, mech)
	mech.damage_dealt += taken
	mech.heat = 0
	mech.shutdown_left = passive.shutdown
	for active in mech.active_parts:
		active.streak = 0
	for acting in mech.get_abilities():
		acting.ability.on_meltdown(mech, acting.active)
	meltdown.emit(mech, target, taken)


# Whether a working part has run out its cooldown. A part with no cooldown never activates,
# rather than activating every tick at whatever rate the ticks arrive.
func _is_ready(active: ActivePart) -> bool:
	return active.is_active and active.cooldown_max > 0.0 and active.current_cooldown == 0.0


# Once the storm is up, strikes both mechs every storm_interval ticks, each strike harder.
func _tick_storm() -> void:
	if elapsed + TIME_EPSILON < get_storm_start():
		return
	if _storm_ticks % storm_interval == 0:
		var damage := get_storm_strike_damage(_storm_strikes)
		_storm_strikes += 1
		left.take_storm_strike(damage)
		right.take_storm_strike(damage)
		storm_struck.emit(damage)
	_storm_ticks += 1


# Finishes the fight if a mech is down; the other one wins, or no one if both are.
func _check_for_end() -> void:
	var left_down := left.current_health <= 0
	var right_down := right.current_health <= 0
	if not left_down and not right_down:
		return
	state = State.FINISHED
	var winner: BattleMech = null
	if not left_down:
		winner = left
	elif not right_down:
		winner = right
	left.end_fight(winner == left)
	right.end_fight(winner == right)
	battle_ended.emit(winner)
