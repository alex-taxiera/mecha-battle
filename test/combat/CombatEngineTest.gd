class_name CombatEngineTest
extends GdUnitTestSuite

const __source: String = "res://src/combat/CombatEngine.gd"
const Fixtures := preload("res://test/TestFixtures.gd")
# Enough 0.1-second ticks for any fight here to end; stops a broken engine hanging the run.
const MAX_TICKS := 10000

# The Skirmisher's cross, 30 base HP, with no base energy so that only parts make energy.
# Tests of chassis energy use _energized_chassis().
var _chassis: MechChassis
# What engines made by _engine() emit: each weapon_fired as [attacker, target, damage], each
# storm strike's damage, and each battle_ended's winner.
var _shots: Array = []
var _strikes: Array = []
var _endings: Array = []


func before_test() -> void:
	_chassis = Fixtures.cross_chassis()
	_chassis.base_energy = 0
	_shots = []
	_strikes = []
	_endings = []


func test_a_generator_adds_its_energy_each_time_its_cooldown_runs_out() -> void:
	var mech := _mech([[_reactor(1.0), Vector2i(1, 0)]])
	var engine := _engine(mech, _mech([]))
	var energy_per_tick := []
	for i in 10:
		engine.process_tick(0.1)
		energy_per_tick.append(mech.current_energy)
	# The reactor's 1-second cooldown runs out on the 10th tick: +4 energy, and it starts over.
	assert_array(energy_per_tick).is_equal([0, 0, 0, 0, 0, 0, 0, 0, 0, 4])
	assert_float(mech.active_parts[0].current_cooldown).is_equal(1.0)
	for i in 10:
		engine.process_tick(0.1)
	assert_int(mech.current_energy).is_equal(8)


func test_faster_generators_add_energy_more_often() -> void:
	# Reactors at (1, 0)-(2, 0) on a 1-second cooldown and (1, 1)-(2, 1) on half a second.
	var mech := _mech([[_reactor(1.0), Vector2i(1, 0)], [_reactor(0.5), Vector2i(1, 1)]])
	var engine := _engine(mech, _mech([]))
	var energy_per_tick := []
	for i in 10:
		engine.process_tick(0.1)
		energy_per_tick.append(mech.current_energy)
	assert_array(energy_per_tick).is_equal([0, 0, 0, 0, 4, 4, 4, 4, 4, 12])


func test_both_mechs_tick_and_keep_their_own_energy() -> void:
	var left := _mech([[_reactor(1.0), Vector2i(1, 0)]])
	var right := _mech([[_reactor(0.5), Vector2i(1, 0)]])
	var engine := _engine(left, right)
	for i in 10:
		engine.process_tick(0.1)
	assert_int(left.current_energy).is_equal(4)
	assert_int(right.current_energy).is_equal(8)


func test_only_generators_make_energy() -> void:
	# A defense part with energy_gen set still makes none: the type decides. Its cooldown runs
	# out and stays at 0, while the reactor beside it shows the ticks are happening.
	var plate := Fixtures.part("Odd Plate", MechPart.PartType.DEFENSE, [Vector2i(0, 0)], 0, {"energy_gen": 5, "cooldown_max": 0.3})
	var mech := _mech([[plate, Vector2i(1, 2)], [_reactor(1.0), Vector2i(1, 0)]])
	var engine := _engine(mech, _mech([]))
	for i in 10:
		engine.process_tick(0.1)
	assert_int(mech.current_energy).is_equal(4)
	assert_float(_active_for(mech, plate).current_cooldown).is_equal(0.0)


func test_switched_off_parts_stay_frozen() -> void:
	var off := _reactor(1.0)
	var on := _reactor(1.0)
	var mech := _mech([[off, Vector2i(1, 0)], [on, Vector2i(1, 1)]])
	_active_for(mech, off).is_active = false
	var engine := _engine(mech, _mech([]))
	for i in 10:
		engine.process_tick(0.1)
	assert_int(mech.current_energy).is_equal(4) # only the working reactor
	assert_float(_active_for(mech, off).current_cooldown).is_equal(1.0)


func test_a_generator_without_a_cooldown_makes_nothing() -> void:
	# With no cooldown it would otherwise fire every tick, at whatever rate ticks arrive.
	var mech := _mech([[_reactor(0.0), Vector2i(1, 0)], [_reactor(1.0), Vector2i(1, 1)]])
	var engine := _engine(mech, _mech([]))
	for i in 10:
		engine.process_tick(0.1)
	assert_int(mech.current_energy).is_equal(4) # only the reactor with a cooldown


func test_a_weapon_fires_once_it_is_ready_and_paid_for() -> void:
	# Gatling (1, 0)-(1, 2): 8 damage for 3 energy, every second. Reactor (2, 1)-(3, 1): +4
	# every half second.
	var gatling := _on_cooldown(Fixtures.gatling(), 1.0)
	var attacker := _mech([[gatling, Vector2i(1, 0)], [_reactor(0.5), Vector2i(2, 1)]])
	var dummy := _mech([])
	var engine := _engine(attacker, dummy)
	var ticks := 0
	while _shots.is_empty() and ticks < 100:
		engine.process_tick(0.1)
		ticks += 1
	# At 1 second the reactor has charged twice (8 energy) and the shot costs 3.
	assert_int(ticks).is_equal(10)
	assert_array(_shots).has_size(1)
	assert_object(_shots[0][0]).is_same(attacker)
	assert_object(_shots[0][1]).is_same(dummy)
	assert_int(_shots[0][2]).is_equal(8)
	assert_int(attacker.current_energy).is_equal(5)
	assert_int(dummy.current_health).is_equal(22)
	assert_int(attacker.current_health).is_equal(35) # 30 + the reactor's 5, and nothing shot back
	assert_float(_active_for(attacker, gatling).current_cooldown).is_equal(1.0)


func test_weapons_can_spend_energy_generated_the_same_tick() -> void:
	# The reactor's first +4 and the gatling's first shot both come at 1 second.
	var attacker := _mech([[_on_cooldown(Fixtures.gatling(), 1.0), Vector2i(1, 0)], [_reactor(1.0), Vector2i(2, 1)]])
	var engine := _engine(attacker, _mech([]))
	for i in 10:
		engine.process_tick(0.1)
	assert_array(_shots).has_size(1)
	assert_int(attacker.current_energy).is_equal(1)


func test_a_weapon_waits_for_energy() -> void:
	var gatling := _on_cooldown(Fixtures.gatling(), 0.5) # costs 3
	var attacker := _mech([[gatling, Vector2i(1, 0)]])
	var dummy := _mech([])
	var engine := _engine(attacker, dummy)
	for i in 10:
		engine.process_tick(0.1)
	# Ready since 0.5 seconds, but with no generator it can't pay.
	assert_array(_shots).is_empty()
	assert_float(_active_for(attacker, gatling).current_cooldown).is_equal(0.0)
	attacker.current_energy = 2
	engine.process_tick(0.1)
	assert_array(_shots).is_empty()
	# With exactly enough, it fires on the next tick.
	attacker.current_energy = 3
	engine.process_tick(0.1)
	assert_array(_shots).has_size(1)
	assert_int(attacker.current_energy).is_equal(0)
	assert_int(dummy.current_health).is_equal(22)


func test_both_mechs_shoot_each_other() -> void:
	var left := _mech([[_peashooter(), Vector2i(1, 1)]])
	var right := _mech([[_peashooter(), Vector2i(1, 1)]])
	var engine := _engine(left, right)
	for i in 10:
		engine.process_tick(0.1)
	# Two shots each, the left mech's first in each tick.
	var names := {left: "left", right: "right"}
	assert_array(_shots.map(func(shot: Array) -> Array: return [names[shot[0]], names[shot[1]], shot[2]])) \
		.is_equal([["left", "right", 2], ["right", "left", 2], ["left", "right", 2], ["right", "left", 2]])
	assert_int(left.current_health).is_equal(26)
	assert_int(right.current_health).is_equal(26)


func test_a_switched_off_weapon_holds_fire() -> void:
	var off := _peashooter()
	var on := _peashooter()
	var attacker := _mech([[off, Vector2i(1, 1)], [on, Vector2i(2, 1)]])
	# Switched off while ready to fire, it still doesn't.
	var off_active := _active_for(attacker, off)
	off_active.current_cooldown = 0.0
	off_active.is_active = false
	var dummy := _mech([])
	var engine := _engine(attacker, dummy)
	for i in 10:
		engine.process_tick(0.1)
	assert_array(_shots).has_size(2) # only the working gun, twice
	assert_int(dummy.current_health).is_equal(26)


func test_ticks_do_nothing_until_the_fight_starts() -> void:
	var mech := _mech([[_reactor(0.5), Vector2i(1, 0)]])
	var engine := CombatEngine.new(mech, _mech([]))
	assert_int(engine.state).is_equal(CombatEngine.State.PRE_GAME)
	for i in 10:
		engine.process_tick(0.1)
	assert_int(mech.current_energy).is_equal(0)
	assert_float(mech.active_parts[0].current_cooldown).is_equal(0.5)
	engine.start()
	assert_int(engine.state).is_equal(CombatEngine.State.RUNNING)
	for i in 10:
		engine.process_tick(0.1)
	assert_int(mech.current_energy).is_equal(8)


func test_a_full_battle_ends_with_the_stronger_mech_winning() -> void:
	# The brawler has 35 HP and deals 8 a second from 1 second on. The turtle has 42 HP and
	# deals 2 every half second from 0.5 seconds on. The brawler needs 6 shots (6 seconds) to
	# win; the turtle would need 18 (9 seconds).
	var brawler := _brawler()
	var turtle := _turtle()
	var engine := _engine(brawler, turtle)
	var ticks := _fight(engine)
	assert_array(_endings).has_size(1)
	assert_object(_endings[0]).is_same(brawler)
	assert_int(engine.state).is_equal(CombatEngine.State.FINISHED)
	assert_int(ticks).is_equal(60)
	assert_int(turtle.current_health).is_equal(0)
	# The turtle's 12th shot still lands on the last tick: 35 - 12 × 2.
	assert_int(brawler.current_health).is_equal(11)
	# Once it's over, ticks and start() change nothing.
	var shots := _shots.size()
	var energy := brawler.current_energy
	engine.start()
	for i in 50:
		engine.process_tick(0.1)
	assert_int(engine.state).is_equal(CombatEngine.State.FINISHED)
	assert_array(_shots).has_size(shots)
	assert_int(brawler.current_health).is_equal(11)
	assert_int(brawler.current_energy).is_equal(energy)
	assert_array(_endings).has_size(1)


func test_the_winner_does_not_depend_on_the_side() -> void:
	var brawler := _brawler()
	var engine := _engine(_turtle(), brawler)
	assert_int(_fight(engine)).is_equal(60)
	assert_array(_endings).has_size(1)
	assert_object(_endings[0]).is_same(brawler)
	assert_int(brawler.current_health).is_equal(11)


func test_both_mechs_going_down_in_the_same_tick_is_a_draw() -> void:
	# Mirror match: 30 HP and 2 damage every half second each, so both drop on the 15th shot.
	var left := _mech([[_peashooter(), Vector2i(1, 1)]])
	var right := _mech([[_peashooter(), Vector2i(1, 1)]])
	var engine := _engine(left, right)
	assert_int(_fight(engine)).is_equal(75)
	assert_array(_endings).has_size(1)
	assert_object(_endings[0]).is_null()
	assert_int(left.current_health).is_equal(0)
	assert_int(right.current_health).is_equal(0)


func test_the_electrical_storm_ends_a_stalemate() -> void:
	# Neither mech has a weapon. The storm starts at 1 second and strikes every 2 ticks,
	# doubling: 1, 2, 4, 8, 16.
	var bare := _mech([]) # 30 HP
	var plated := _mech([[Fixtures.laser(), Vector2i(1, 1)]]) # 42 HP
	var engine := _stormy_engine(bare, plated)
	for i in 9:
		engine.process_tick(0.1)
	assert_array(_strikes).is_empty()
	assert_int(bare.current_health).is_equal(30)
	# From its first strike on the 10th tick to the 5th on the 18th, 31 damage in all.
	var ticks := 9 + _fight(engine)
	assert_int(ticks).is_equal(18)
	assert_array(_strikes).is_equal([1, 2, 4, 8, 16])
	assert_array(_endings).has_size(1)
	assert_object(_endings[0]).is_same(plated)
	assert_int(bare.current_health).is_equal(0)
	assert_int(plated.current_health).is_equal(11)


func test_the_storm_can_take_both_mechs_down_at_once() -> void:
	# The storm hits both mechs the same, so two with equal health draw.
	var engine := _stormy_engine(_mech([]), _mech([]))
	assert_int(_fight(engine)).is_equal(18)
	assert_array(_endings).has_size(1)
	assert_object(_endings[0]).is_null()


func test_storm_strikes_grow_exponentially() -> void:
	var engine := CombatEngine.new(_mech([]), _mech([]))
	engine.storm_damage = 1.0
	engine.storm_growth = 1.5
	# 1, 1.5, 2.25, 3.375, 5.06, 7.59, rounded.
	var damages := range(6).map(func(strike: int) -> int: return engine.get_storm_strike_damage(strike))
	assert_array(damages).is_equal([1, 2, 2, 3, 5, 8])


func test_each_chassis_adds_its_base_energy_every_turn() -> void:
	var left := _mech([], [], _energized_chassis(3))
	var right := _mech([], [], _energized_chassis(5))
	var engine := _engine(left, right)
	var energy_per_tick := []
	for i in 20:
		engine.process_tick(0.1)
		energy_per_tick.append(left.current_energy)
	# At the end of each 1-second turn.
	assert_array(energy_per_tick).is_equal([0, 0, 0, 0, 0, 0, 0, 0, 0, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 6])
	assert_int(right.current_energy).is_equal(10)


func test_a_weapon_can_run_on_chassis_energy_alone() -> void:
	# The Skirmisher's 3 energy a turn pays for a gatling's 3 a second, with no generator.
	var attacker := _mech([[_on_cooldown(Fixtures.gatling(), 1.0), Vector2i(1, 0)]], [], _energized_chassis(3))
	var dummy := _mech([])
	var engine := _engine(attacker, dummy)
	for i in 10:
		engine.process_tick(0.1)
	# The first turn's energy arrives in time for the first shot.
	assert_array(_shots).has_size(1)
	assert_int(attacker.current_energy).is_equal(0)
	for i in 20:
		engine.process_tick(0.1)
	assert_array(_shots).has_size(3)
	assert_int(dummy.current_health).is_equal(6) # 30 - 3 × 8


func test_weapons_hit_with_their_link_bonuses() -> void:
	# Gatling (1, 0)-(1, 2) cooled by a heatsink at (2, 1), (2, 2), (3, 2): 8 × 1.5.
	var placements := [[_on_cooldown(Fixtures.gatling(), 1.0), Vector2i(1, 0)], [Fixtures.heatsink(), Vector2i(2, 1)]]
	var engine := _engine(_mech(placements, Fixtures.rules(), _energized_chassis(3)), _mech([]))
	for i in 10:
		engine.process_tick(0.1)
	assert_array(_shots).has_size(1)
	assert_int(_shots[0][2]).is_equal(12)
	# Positive control: without the rules, the same build hits for 8.
	_shots = []
	placements = [[_on_cooldown(Fixtures.gatling(), 1.0), Vector2i(1, 0)], [Fixtures.heatsink(), Vector2i(2, 1)]]
	engine = _engine(_mech(placements, [], _energized_chassis(3)), _mech([]))
	for i in 10:
		engine.process_tick(0.1)
	assert_array(_shots).has_size(1)
	assert_int(_shots[0][2]).is_equal(8)


func test_generators_make_energy_with_their_link_bonuses() -> void:
	# Reactor (1, 0)-(2, 0) with a heatsink at (1, 1), (1, 2), (2, 2): Stable, 4 + 2.
	var mech := _mech([[_reactor(1.0), Vector2i(1, 0)], [Fixtures.heatsink(), Vector2i(1, 1)]], Fixtures.rules())
	var engine := _engine(mech, _mech([]))
	for i in 10:
		engine.process_tick(0.1)
	assert_int(mech.current_energy).is_equal(6)


# A started engine whose storm starts at 1 second with strikes of 1, 2, 4, 8...
func _stormy_engine(left: BattleMech, right: BattleMech) -> CombatEngine:
	var engine := _engine(left, right)
	engine.storm_start = 1.0
	engine.storm_damage = 1.0
	engine.storm_growth = 2.0
	return engine


# A started engine, with what it emits recorded in _shots, _strikes, and _endings.
func _engine(left: BattleMech, right: BattleMech) -> CombatEngine:
	var engine := CombatEngine.new(left, right)
	engine.weapon_fired.connect(func(attacker: BattleMech, target: BattleMech, damage: int) -> void:
		_shots.append([attacker, target, damage]))
	engine.storm_struck.connect(func(damage: int) -> void: _strikes.append(damage))
	engine.battle_ended.connect(func(winner: BattleMech) -> void: _endings.append(winner))
	engine.start()
	return engine


# Ticks a fight 0.1 seconds at a time until it ends, and returns how many ticks that took.
func _fight(engine: CombatEngine) -> int:
	var ticks := 0
	while _endings.is_empty() and ticks < MAX_TICKS:
		engine.process_tick(0.1)
		ticks += 1
	return ticks


# 35 HP (30 + the reactor's 5). The gatling (1, 0)-(1, 2) deals 8 for 3 energy every second;
# the reactor (2, 1)-(3, 1) makes 4 every second, so it can always pay.
func _brawler() -> BattleMech:
	return _mech([[_on_cooldown(Fixtures.gatling(), 1.0), Vector2i(1, 0)], [_reactor(1.0), Vector2i(2, 1)]])


# 42 HP (30 + the laser's 12), with a peashooter.
func _turtle() -> BattleMech:
	return _mech([[_peashooter(), Vector2i(1, 1)], [Fixtures.laser(), Vector2i(2, 1)]])


# A Micro-Reactor (+4 energy) on a cooldown of [param seconds].
func _reactor(seconds: float) -> MechPart:
	return _on_cooldown(Fixtures.reactor(), seconds)


# A free 1x1 gun: 2 damage every half second, no energy needed.
func _peashooter() -> MechPart:
	return Fixtures.part("Peashooter", MechPart.PartType.WEAPON, [Vector2i(0, 0)], 0, {"damage": 2, "cooldown_max": 0.5})


func _on_cooldown(part: MechPart, seconds: float) -> MechPart:
	part.cooldown_max = seconds
	return part


# A BattleMech with each [part, origin] placed, on _chassis unless [param chassis] is given,
# fighting with [param rules]' link bonuses.
func _mech(placements: Array, rules: Array[SynergyRule] = [], chassis: MechChassis = null) -> BattleMech:
	var grid := MechGridData.new(chassis if chassis else _chassis)
	for entry in placements:
		assert_bool(grid.place_part(entry[0], entry[1])).append_failure_message("placing %s at %s" % [entry[0].part_name, entry[1]]).is_true()
	return BattleMech.new(grid, rules)


# The cross chassis with [param energy] base energy a turn.
func _energized_chassis(energy: int) -> MechChassis:
	var chassis := Fixtures.cross_chassis()
	chassis.base_energy = energy
	return chassis


func _active_for(mech: BattleMech, part: MechPart) -> ActivePart:
	for active in mech.active_parts:
		if active.part == part:
			return active
	return null
