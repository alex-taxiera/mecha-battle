class_name CombatScreenTest
extends GdUnitTestSuite

const __source: String = "res://src/ui/CombatScreen.gd"
const SCENE := preload("res://src/ui/CombatScreen.tscn")
const Fixtures := preload("res://test/TestFixtures.gd")
# Enough ticks for any fight here to end; stops a broken screen hanging the run.
const MAX_TICKS := 10000


func test_the_timer_ticks_the_fight_every_tenth_of_a_second() -> void:
	var screen := _screen(_gunner(), _bare())
	var timer: Timer = screen.get_node("%TickTimer")
	assert_float(timer.wait_time).is_equal(0.1)
	assert_bool(timer.one_shot).is_false()
	assert_bool(timer.is_stopped()).is_false()
	assert_int(screen.engine.state).is_equal(CombatEngine.State.RUNNING)
	# Each timeout moves the fight 0.1 seconds. At 1 second both chassis add 3 energy; the
	# gunner spends its 3 on the first shot, and the bare mech has nothing to spend it on.
	for i in 10:
		timer.timeout.emit()
	assert_float(screen.engine.elapsed).is_equal_approx(1.0, 1e-9)
	assert_str(screen.status_line()).is_equal("[ 1.0s] Left HP 30/30 EN 0 HEAT 0 | Right HP 22/30 EN 3 HEAT 0")
	assert_str(screen.result_line()).is_empty()


func test_the_timer_stops_when_the_fight_ends() -> void:
	var screen := _screen(_gunner(), _bare())
	var timer: Timer = screen.get_node("%TickTimer")
	# 8 damage a second takes the bare mech's 30 HP in 4 seconds.
	assert_int(_tick_until_over(screen)).is_equal(40)
	assert_bool(timer.is_stopped()).is_true()
	assert_str(screen.result_line()).is_equal("Left wins with 30/30 HP left")


func test_shows_the_fight_and_reports_the_winner_after_a_pause() -> void:
	var gunner := _gunner()
	var screen := _screen(gunner, _bare())
	assert_str(screen.get_status_text()).is_equal("[ 0.0s] Left HP 30/30 EN 0 HEAT 0 | Right HP 30/30 EN 0 HEAT 0")
	var winners := []
	screen.finished.connect(func(winner: BattleMech) -> void: winners.append(winner))
	_tick_until_over(screen)
	# The bare mech banks its 3 chassis energy a turn with nothing to spend it on.
	assert_str(screen.get_status_text()) \
		.is_equal("[ 4.0s] Left HP 30/30 EN 0 HEAT 0 | Right HP 0/30 EN 12 HEAT 0\nLeft wins with 30/30 HP left")
	# The result stays up for 2 seconds before the screen reports it.
	var result_timer: Timer = screen.get_node("%ResultTimer")
	assert_float(result_timer.wait_time).is_equal(2.0)
	assert_bool(result_timer.one_shot).is_true()
	assert_bool(result_timer.is_stopped()).is_false()
	assert_array(winners).is_empty()
	result_timer.timeout.emit()
	assert_array(winners).has_size(1)
	assert_object(winners[0]).is_same(gunner)


func test_the_readout_shows_heat_and_shutdowns() -> void:
	# A Reactor's gatling at (2, 0)-(2, 2) making 20 heat a shot, against a 200 HP target.
	var gatling := Fixtures.gatling()
	gatling.cooldown_max = 1.0
	gatling.heat = 20
	var grid := MechGridData.new(Fixtures.reactor_frame())
	assert_bool(grid.place_part(gatling, Vector2i(2, 0))).is_true()
	var target_chassis := Fixtures.cross_chassis()
	target_chassis.base_hp = 200
	var screen := _screen(BattleMech.new(grid), BattleMech.new(MechGridData.new(target_chassis)))
	var timer: Timer = screen.get_node("%TickTimer")
	for i in 40:
		timer.timeout.emit()
	assert_str(screen.status_line()).is_equal("[ 4.0s] Left HP 30/30 EN 0 HEAT 80 | Right HP 168/200 EN 12 HEAT 0")
	# The 5th shot fills it: 25 damage, and the Reactor shuts down.
	for i in 10:
		timer.timeout.emit()
	assert_str(screen.status_line()).is_equal("[ 5.0s] Left HP 30/30 EN 0 HEAT 0 OFF | Right HP 135/200 EN 15 HEAT 0")


func test_a_draw_says_so() -> void:
	var screen := _screen(_gunner(), _gunner())
	var winners := []
	screen.finished.connect(func(winner: BattleMech) -> void: winners.append(winner))
	_tick_until_over(screen)
	assert_str(screen.result_line()).is_equal("Draw: both mechs went down together")
	screen.get_node("%ResultTimer").timeout.emit()
	assert_array(winners).has_size(1)
	assert_object(winners[0]).is_null()


func test_fights_the_demo_builds_by_default() -> void:
	var screen: CombatScreen = auto_free(SCENE.instantiate())
	screen.print_ticks = false
	add_child(screen)
	assert_object(screen.engine).is_not_null()
	# Every demo part made it onto its grid, and the rules came from their folder.
	assert_array(screen.engine.left.active_parts).has_size(CombatScreen.DEMO_PLAYER.size())
	assert_array(screen.engine.right.active_parts).has_size(CombatScreen.DUMMY.size())
	assert_array(screen.rules).is_not_empty()


func _screen(left: BattleMech, right: BattleMech) -> CombatScreen:
	var screen: CombatScreen = auto_free(SCENE.instantiate())
	screen.print_ticks = false
	screen.setup(left, right)
	add_child(screen)
	return screen


# Fires the screen's timer until the fight is over, and returns how many ticks that took.
func _tick_until_over(screen: CombatScreen) -> int:
	var timer: Timer = screen.get_node("%TickTimer")
	var ticks := 0
	while screen.engine.state == CombatEngine.State.RUNNING and ticks < MAX_TICKS:
		timer.timeout.emit()
		ticks += 1
	return ticks


# 30 HP; a gatling firing 8 damage every second on the Skirmisher's 3 energy a turn.
func _gunner() -> BattleMech:
	var gatling := Fixtures.gatling()
	gatling.cooldown_max = 1.0
	var grid := MechGridData.new(Fixtures.cross_chassis())
	assert_bool(grid.place_part(gatling, Vector2i(1, 0))).is_true()
	return BattleMech.new(grid)


# 30 HP and nothing else.
func _bare() -> BattleMech:
	return BattleMech.new(MechGridData.new(Fixtures.cross_chassis()))
