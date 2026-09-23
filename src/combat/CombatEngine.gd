class_name CombatEngine
extends RefCounted
## Runs a fight between two [BattleMech]s, one tick at a time. Each chassis adds its base
## energy once a turn and its heatsinks vent heat, and every working part's cooldown counts
## down. A generator whose cooldown runs out adds its energy to its mech; then a weapon whose
## cooldown has run out fires at the other mech, if its own mech can pay for the shot, and
## heats its mech up. Chassis passives change this: Thick Plating shrinks every hit taken,
## Overclock doubles the first shot, and Meltdown turns full heat into a big hit and a
## shutdown. A fight that runs long brings the electrical storm, a sudden death that drains both
## mechs harder and harder. The fight ends on the tick a mech's health reaches 0.

enum State { PRE_GAME, RUNNING, FINISHED }

## Emitted after [param weapon]'s shot has hit, so [param target]'s health already shows it.
## [param damage] is what the target took, after any plating.
signal weapon_fired(attacker: BattleMech, weapon: ActivePart, target: BattleMech, damage: int)
## Emitted when a MELTDOWN mech hits full heat and deals [param damage] to [param target].
signal meltdown(mech: BattleMech, target: BattleMech, damage: int)
## Emitted each time the electrical storm hits both mechs for [param damage], before plating.
signal storm_struck(damage: int)
## Emitted once, on the tick a mech goes down. [param winner] is null for a draw: both mechs
## going down in the same tick.
signal battle_ended(winner: BattleMech)

## Times this close count as reached. Adding or subtracting a delta like 0.1 leaves float error
## behind (1.0 minus ten 0.1s is about 1.4e-16, not 0), which would delay things by a tick.
const TIME_EPSILON := 1e-6
## Seconds in a turn. The shop counts energy per turn; in a fight each chassis adds its base
## energy once a turn, so a part that acts every second does what the shop says it does.
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

# Seconds left in the current turn.
var _turn_left := TURN_SECONDS
# Ticks since the storm started, and strikes it has made.
var _storm_ticks := 0
var _storm_strikes := 0


func _init(p_left: BattleMech, p_right: BattleMech) -> void:
	left = p_left
	right = p_right


## Starts the fight. Only a fight that hasn't started yet can start.
func start() -> void:
	if state == State.PRE_GAME:
		state = State.RUNNING


## Advances a running fight by [param delta] seconds. Shutdowns count down first. Then both
## mechs' chassis energy, venting, cooldowns, and generators, so neither side's weapons act
## before the other has charged; then the left mech's weapons fire, then the right's; then
## any mech at full heat melts down, and the storm strikes if it's up. A shut-down mech does
## none of this. A tick's damage lands together: a mech that goes down still fires back that
## tick, so the fight is only checked for an end once everything has hit.
func process_tick(delta: float) -> void:
	if state != State.RUNNING:
		return
	elapsed += delta
	for mech: BattleMech in [left, right]:
		_tick_shutdown(mech, delta)
	_tick_turn(delta)
	for mech: BattleMech in [left, right]:
		if not mech.is_shut_down():
			for active in mech.active_parts:
				_tick_part(mech, active, delta)
	for mech: BattleMech in [left, right]:
		if not mech.is_shut_down():
			for active in mech.active_parts:
				_try_fire(mech, _enemy_of(mech), active)
	for mech: BattleMech in [left, right]:
		_check_meltdown(mech)
	_tick_storm()
	_check_for_end()


## Returns the damage of the storm's strike number [param strike], counting from 0.
func get_storm_strike_damage(strike: int) -> int:
	return roundi(storm_damage * pow(storm_growth, strike))


## Returns the seconds left until the storm starts, or 0 once it's up.
func get_storm_countdown() -> float:
	var left := storm_start - elapsed
	return left if left > TIME_EPSILON else 0.0


func _enemy_of(mech: BattleMech) -> BattleMech:
	return right if mech == left else left


# Counts a Meltdown shutdown down. The mech acts again on the tick it runs out.
func _tick_shutdown(mech: BattleMech, delta: float) -> void:
	if not mech.is_shut_down():
		return
	mech.shutdown_left = maxf(0.0, mech.shutdown_left - delta)
	if mech.shutdown_left <= TIME_EPSILON:
		mech.shutdown_left = 0.0


# At the end of each turn, every running chassis adds its base energy and its working
# heatsinks vent their cooling.
func _tick_turn(delta: float) -> void:
	_turn_left = maxf(0.0, _turn_left - delta)
	if _turn_left > TIME_EPSILON:
		return
	for mech: BattleMech in [left, right]:
		if mech.is_shut_down():
			continue
		mech.current_energy += mech.base_energy
		var cooling := 0
		for active in mech.active_parts:
			if active.is_active:
				cooling += active.cooling
		mech.add_heat(-cooling)
	_turn_left = TURN_SECONDS


# Counts a working part's cooldown down, and runs a generator whose cooldown ran out.
func _tick_part(mech: BattleMech, active: ActivePart, delta: float) -> void:
	if not active.is_active:
		return
	active.current_cooldown = maxf(0.0, active.current_cooldown - delta)
	if active.current_cooldown <= TIME_EPSILON:
		active.current_cooldown = 0.0
	if _is_ready(active, MechPart.PartType.GENERATOR):
		mech.current_energy += active.energy_gen
		active.current_cooldown = active.part.cooldown_max


# Fires a ready weapon if its mech has the energy. One that can't pay stays ready and fires
# on the first tick its mech can. On an OVERCLOCK chassis, the fight's first shot fires twice,
# the second for free.
func _try_fire(attacker: BattleMech, target: BattleMech, active: ActivePart) -> void:
	if not _is_ready(active, MechPart.PartType.WEAPON):
		return
	if attacker.current_energy < active.energy_cost:
		return
	attacker.current_energy -= active.energy_cost
	active.current_cooldown = active.part.cooldown_max
	_shoot(attacker, target, active)
	if attacker.chassis.passive == MechChassis.Passive.OVERCLOCK and not attacker.overclock_spent:
		attacker.overclock_spent = true
		_shoot(attacker, target, active)


func _shoot(attacker: BattleMech, target: BattleMech, active: ActivePart) -> void:
	attacker.add_heat(active.heat)
	var taken := target.take_damage(active.damage)
	active.shots += 1
	active.damage_dealt += taken
	attacker.damage_dealt += taken
	weapon_fired.emit(attacker, active, target, taken)


# A MELTDOWN mech at full heat hits its enemy, cools to 0, and shuts down.
func _check_meltdown(mech: BattleMech) -> void:
	var chassis := mech.chassis
	if chassis.passive != MechChassis.Passive.MELTDOWN or mech.heat < BattleMech.MAX_HEAT or mech.is_shut_down():
		return
	var target := _enemy_of(mech)
	var taken := target.take_damage(chassis.meltdown_damage)
	mech.damage_dealt += taken
	mech.heat = 0
	mech.shutdown_left = chassis.meltdown_shutdown
	meltdown.emit(mech, target, taken)


# Whether a working part of this type has run out its cooldown. A part with no cooldown never
# activates, rather than activating every tick at whatever rate the ticks arrive.
func _is_ready(active: ActivePart, type: MechPart.PartType) -> bool:
	var part := active.part
	return active.is_active and part.type == type and part.cooldown_max > 0.0 and active.current_cooldown == 0.0


# Once the storm is up, strikes both mechs every storm_interval ticks, each strike harder.
func _tick_storm() -> void:
	if elapsed + TIME_EPSILON < storm_start:
		return
	if _storm_ticks % storm_interval == 0:
		var damage := get_storm_strike_damage(_storm_strikes)
		_storm_strikes += 1
		left.take_damage(damage)
		right.take_damage(damage)
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
	battle_ended.emit(winner)
