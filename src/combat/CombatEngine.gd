class_name CombatEngine
extends RefCounted
## Runs a fight between two [BattleMech]s, one tick at a time. Each chassis adds its base
## energy once a turn, and every working part's cooldown counts down. A generator whose
## cooldown runs out adds its energy to its mech; then a weapon whose cooldown has run out
## fires at the other mech, if its own mech can pay for the shot.
## A fight that runs long brings the electrical storm, a sudden death that drains both mechs
## harder and harder. The fight ends on the tick a mech's health reaches 0.

enum State { PRE_GAME, RUNNING, FINISHED }

## Emitted after a weapon's shot has hit, so [param target]'s health already shows it.
signal weapon_fired(attacker: BattleMech, target: BattleMech, damage: int)
## Emitted each time the electrical storm hits both mechs for [param damage].
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


## Advances a running fight by [param delta] seconds. Both mechs' chassis energy, cooldowns,
## and generators go first, so neither side's weapons act before the other has charged; then
## the left mech's weapons fire, then the right's, then the storm strikes if it's up. A tick's
## damage lands together: a mech that goes down still fires back that tick, so the fight is
## only checked for an end once everything has hit.
func process_tick(delta: float) -> void:
	if state != State.RUNNING:
		return
	elapsed += delta
	_tick_turn(delta)
	for mech: BattleMech in [left, right]:
		for active in mech.active_parts:
			_tick_part(mech, active, delta)
	for mech: BattleMech in [left, right]:
		var target := right if mech == left else left
		for active in mech.active_parts:
			_try_fire(mech, target, active)
	_tick_storm()
	_check_for_end()


## Returns the damage of the storm's strike number [param strike], counting from 0.
func get_storm_strike_damage(strike: int) -> int:
	return roundi(storm_damage * pow(storm_growth, strike))


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


# At the end of each turn, every chassis adds its base energy.
func _tick_turn(delta: float) -> void:
	_turn_left = maxf(0.0, _turn_left - delta)
	if _turn_left > TIME_EPSILON:
		return
	for mech: BattleMech in [left, right]:
		mech.current_energy += mech.base_energy
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
# on the first tick its mech can.
func _try_fire(attacker: BattleMech, target: BattleMech, active: ActivePart) -> void:
	if not _is_ready(active, MechPart.PartType.WEAPON):
		return
	if attacker.current_energy < active.energy_cost:
		return
	attacker.current_energy -= active.energy_cost
	active.current_cooldown = active.part.cooldown_max
	target.take_damage(active.damage)
	weapon_fired.emit(attacker, target, active.damage)


# Whether a working part of this type has run out its cooldown. A part with no cooldown never
# activates, rather than activating every tick at whatever rate the ticks arrive.
func _is_ready(active: ActivePart, type: MechPart.PartType) -> bool:
	var part := active.part
	return active.is_active and part.type == type and part.cooldown_max > 0.0 and active.current_cooldown == 0.0
