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
	assert_str(screen.result_title()).is_empty()


func test_the_timer_stops_when_the_fight_ends() -> void:
	var screen := _screen(_gunner(), _bare())
	var timer: Timer = screen.get_node("%TickTimer")
	# 8 damage a second takes the bare mech's 30 HP in 4 seconds.
	assert_int(_tick_until_over(screen)).is_equal(40)
	assert_bool(timer.is_stopped()).is_true()
	assert_str(screen.result_line()).is_equal("Left wins with 30/30 HP left")


func test_the_hud_shows_both_mechs() -> void:
	var screen := _screen(_gunner(), _bare())
	var left_hp: HpBar = screen.get_node("%LeftHp")
	var right_hp: HpBar = screen.get_node("%RightHp")
	assert_str(left_hp.mech_name).is_equal("THE SKIRMISHER")
	assert_str(left_hp.owner_text).is_equal("PLAYER")
	assert_bool(left_hp.mirrored).is_false()
	assert_str(right_hp.owner_text).is_equal("OPPONENT")
	assert_bool(right_hp.mirrored).is_true()
	assert_str(right_hp.get_text()).is_equal("30/30")
	# The first shot lands at 1 second, and the bars follow each tick.
	for i in 10:
		screen.get_node("%TickTimer").timeout.emit()
	assert_str(right_hp.get_text()).is_equal("22/30")
	assert_str(left_hp.get_text()).is_equal("30/30")
	assert_str((screen.get_node("%StormTimer") as StormTimer).get_text()).is_equal("19")
	# Each side's weapons get a tag: the gunner's gatling, and nothing for the bare mech.
	var tags := (screen.get_node("%LeftWeapons") as WeaponTags).get_tags()
	assert_array(tags).has_size(1)
	assert_str(tags[0].weapon_name).is_equal("Twin Gatling")
	assert_str(tags[0].slot_name).is_equal("Left Arm")
	assert_array((screen.get_node("%RightWeapons") as WeaponTags).get_tags()).is_empty()
	var right_gauges: MechGauges = screen.get_node("%RightGauges")
	assert_str(right_gauges.energy.get_text()).is_equal("3")


func test_the_result_panel_comes_up_after_a_pause_and_returns_the_winner() -> void:
	var gunner := _gunner()
	var screen := _screen(gunner, _bare())
	var winners := []
	screen.finished.connect(func(winner: BattleMech) -> void: winners.append(winner))
	_tick_until_over(screen)
	# The panel waits a moment, so the last hit can land.
	var result_timer: Timer = screen.get_node("%ResultTimer")
	assert_float(result_timer.wait_time).is_equal(0.8)
	assert_bool(result_timer.one_shot).is_true()
	assert_bool(result_timer.is_stopped()).is_false()
	assert_bool(screen.result_panel.visible).is_false()
	result_timer.timeout.emit()
	assert_bool(screen.result_panel.visible).is_true()
	assert_str(screen.result_panel.title_label.text).is_equal("VICTORY")
	# Four 8-damage shots in 4 seconds, all from the gatling.
	assert_array(screen.result_panel.get_rows()).is_equal([
		["Battle duration", "4.0s"], ["Total damage dealt", "32 DMG"], ["MVP weapon", "Twin Gatling · 32 DMG"]])
	# The screen reports the winner only once the player leaves.
	assert_array(winners).is_empty()
	screen.result_panel.return_button.pressed.emit()
	assert_array(winners).has_size(1)
	assert_object(winners[0]).is_same(gunner)


func test_a_loss_is_a_defeat() -> void:
	var screen := _screen(_bare(), _gunner())
	_tick_until_over(screen)
	assert_str(screen.result_title()).is_equal("DEFEAT")
	# The bare mech never fired.
	assert_array(screen.result_rows()).is_equal([
		["Battle duration", "4.0s"], ["Total damage dealt", "0 DMG"], ["MVP weapon", "—"]])


func test_a_draw_says_so() -> void:
	var screen := _screen(_gunner(), _gunner())
	var winners := []
	screen.finished.connect(func(winner: BattleMech) -> void: winners.append(winner))
	_tick_until_over(screen)
	assert_str(screen.result_line()).is_equal("Draw: both mechs went down together")
	assert_str(screen.result_title()).is_equal("DRAW")
	screen.get_node("%ResultTimer").timeout.emit()
	screen.result_panel.return_button.pressed.emit()
	assert_array(winners).has_size(1)
	assert_object(winners[0]).is_null()


func test_the_record_line_counts_this_fight() -> void:
	var run := RunState.new(Fixtures.armed_cross(), [], [])
	run.round_number = 3
	run.wins = 2
	run.losses = 1
	var screen := _screen(_gunner(), _bare(), run)
	assert_str((screen.get_node("%RoundBadge") as RoundBadge).get_text()).is_equal("ROUND 3  2W 1L")
	_tick_until_over(screen)
	assert_str(screen.record_line()).is_equal("ROUND 3 · WINS 3 · LOSSES 1")
	# A draw shows the draws. Outside a run, it's round 1 with only this fight.
	var draw := _screen(_gunner(), _gunner())
	_tick_until_over(draw)
	assert_str(draw.record_line()).is_equal("ROUND 1 · WINS 0 · LOSSES 0 · DRAWS 1")


func test_the_readout_shows_heat_and_shutdowns() -> void:
	# A gatling in a Reactor's left arm making 20 heat a shot, against a 200 HP target.
	var gatling := Fixtures.gatling()
	gatling.cooldown_max = 1.0
	gatling.heat = 20
	var grid := MechGridData.new(Fixtures.reactor_frame())
	assert_bool(grid.place_part(gatling, Vector2i(-1, 1))).is_true()
	var target_chassis := Fixtures.cross_chassis()
	target_chassis.base_hp = 200
	var screen := _screen(BattleMech.new(grid), BattleMech.new(MechGridData.new(target_chassis)))
	var timer: Timer = screen.get_node("%TickTimer")
	var heat: GaugeBar = (screen.get_node("%LeftGauges") as MechGauges).heat
	for i in 40:
		timer.timeout.emit()
	# The Reactor banks 27 of its 30 energy a turn.
	assert_str(screen.status_line()).is_equal("[ 4.0s] Left HP 300/300 EN 108 HEAT 80 | Right HP 168/200 EN 12 HEAT 0")
	assert_str(heat.get_text()).is_equal("80")
	assert_bool(heat.hot).is_false()
	# The 5th shot fills it: 100 damage, and the Reactor shuts down.
	for i in 10:
		timer.timeout.emit()
	assert_str(screen.status_line()).is_equal("[ 5.0s] Left HP 300/300 EN 135 HEAT 0 OFF | Right HP 60/200 EN 15 HEAT 0")
	assert_str(heat.get_text()).is_equal("OFFLINE")
	assert_bool(heat.hot).is_true()
	var tag: WeaponTag = (screen.get_node("%LeftWeapons") as WeaponTags).get_tags()[0]
	assert_int(tag.state).is_equal(WeaponTag.State.OFFLINE)


func test_leaving_resets_the_view() -> void:
	var screen := _screen(_gunner(), _bare())
	get_viewport().canvas_transform = Transform2D(0.0, Vector2(12, -7))
	remove_child(screen)
	assert_that(get_viewport().canvas_transform).is_equal(Transform2D.IDENTITY)
	# Positive control: the transform does take other values.
	get_viewport().canvas_transform = Transform2D(0.0, Vector2(3, 3))
	assert_that(get_viewport().canvas_transform).is_not_equal(Transform2D.IDENTITY)
	get_viewport().canvas_transform = Transform2D.IDENTITY


func test_fights_the_demo_builds_by_default() -> void:
	var screen: CombatScreen = auto_free(SCENE.instantiate())
	screen.print_ticks = false
	add_child(screen)
	assert_object(screen.engine).is_not_null()
	# Every demo part made it onto its grid, and the rules came from their folder.
	assert_array(screen.engine.left.active_parts).has_size(CombatScreen.DEMO_PLAYER.size())
	assert_array(screen.engine.right.active_parts).has_size(CombatScreen.DUMMY.size())
	assert_array(screen.rules).is_not_empty()


func test_built_mechs_grow_with_the_round() -> void:
	# An empty lineup loads no parts: just the chassis's HP for the round.
	assert_int(CombatScreen.build_mech(Fixtures.cross_chassis(), [], [], 2).max_hp).is_equal(34)
	assert_int(CombatScreen.build_mech(Fixtures.cross_chassis(), [], []).max_hp).is_equal(30)


func _screen(left: BattleMech, right: BattleMech, run: RunState = null) -> CombatScreen:
	var screen: CombatScreen = auto_free(SCENE.instantiate())
	screen.print_ticks = false
	screen.setup(left, right, run)
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


# 30 HP; a gatling in the left arm firing 8 damage every second on the Skirmisher's 3 energy a
# turn.
func _gunner() -> BattleMech:
	var gatling := Fixtures.gatling()
	gatling.cooldown_max = 1.0
	var grid := MechGridData.new(Fixtures.armed_cross())
	assert_bool(grid.place_part(gatling, Vector2i(-1, 1))).is_true()
	return BattleMech.new(grid)


# 30 HP and nothing else.
func _bare() -> BattleMech:
	return BattleMech.new(MechGridData.new(Fixtures.cross_chassis()))
