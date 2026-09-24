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
	assert_float(result_timer.wait_time).is_equal(2.0)
	assert_bool(result_timer.one_shot).is_true()
	# Real seconds, whatever the KO's slow motion does to time.
	assert_bool(result_timer.ignore_time_scale).is_true()
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
	var acts: Array[ActData] = [Fixtures.act(), Fixtures.act()]
	var run := RunState.new(Fixtures.armed_cross(), [], [], 10, RunRng.new(1), acts)
	run.next_act()
	assert_bool(run.travel(run.get_reachable()[0])).is_true()
	assert_bool(run.travel(run.get_reachable()[0])).is_true()
	run.fights_won = 2
	var screen := _screen(_gunner(), _bare(), run)
	assert_str((screen.get_node("%RoundBadge") as RoundBadge).get_text()).is_equal("SECTOR 2 · FLOOR 2  2W")
	_tick_until_over(screen)
	assert_str(screen.record_line()).is_equal("SECTOR 2 · FLOOR 2 · WINS 3")
	# A draw adds no win. Outside a run, it's sector 1 with only this fight.
	var draw := _screen(_gunner(), _gunner())
	_tick_until_over(draw)
	assert_str(draw.record_line()).is_equal("SECTOR 1 · WINS 0")


func test_the_readout_shows_heat_and_shutdowns() -> void:
	# A gatling in a Reactor's left arm making 50 heat a shot, against a 200 HP target.
	var gatling := Fixtures.gatling()
	gatling.cooldown_max = 1.0
	gatling.heat = 50
	var grid := MechGridData.new(Fixtures.reactor_frame())
	assert_bool(grid.place_part(gatling, Vector2i(-1, 1))).is_true()
	var target_chassis := Fixtures.cross_chassis()
	target_chassis.base_hp = 200
	var screen := _screen(BattleMech.new(grid), BattleMech.new(MechGridData.new(target_chassis)))
	var timer: Timer = screen.get_node("%TickTimer")
	var heat: GaugeBar = (screen.get_node("%LeftGauges") as MechGauges).heat
	for i in 10:
		timer.timeout.emit()
	# The Reactor banks 27 of its 30 energy a turn.
	assert_str(screen.status_line()).is_equal("[ 1.0s] Left HP 300/300 EN 27 HEAT 50 | Right HP 192/200 EN 3 HEAT 0")
	assert_str(heat.get_text()).is_equal("50")
	assert_bool(heat.hot).is_false()
	# The 2nd shot fills it: 100 damage, and the Reactor shuts down.
	for i in 10:
		timer.timeout.emit()
	assert_str(screen.status_line()).is_equal("[ 2.0s] Left HP 300/300 EN 54 HEAT 0 OFF | Right HP 84/200 EN 6 HEAT 0")
	assert_str(heat.get_text()).is_equal("OFFLINE")
	assert_bool(heat.hot).is_true()
	# The meltdown pops up on its target and shakes the camera hard; the Reactor counts down.
	assert_array(_popup_texts(screen)).contains(["MELTDOWN -100"])
	assert_bool(screen.get_big_shake().is_emitting()).is_true()
	assert_str((screen.get_node("%LeftFighter") as FighterView).get_overheat_text()).is_equal("OVERHEAT 3.0s")
	var tag: WeaponTag = (screen.get_node("%LeftWeapons") as WeaponTags).get_tags()[0]
	assert_int(tag.state).is_equal(WeaponTag.State.OFFLINE)


func test_pausing_holds_the_fight() -> void:
	var screen := _screen(_gunner(), _bare())
	var timer: Timer = screen.get_node("%TickTimer")
	var controls: PlaybackControls = screen.get_node("%Playback")
	var label: Label = screen.get_node("%PlaybackLabel")
	assert_str(label.text).is_empty()
	controls.pause_button.pressed.emit()
	assert_bool(screen.paused).is_true()
	assert_bool(timer.paused).is_true()
	assert_str(label.text).is_equal("PAUSED")
	assert_str(controls.pause_button.icon_name).is_equal("play")
	# Space plays it again.
	screen._unhandled_input(_space())
	assert_bool(screen.paused).is_false()
	assert_bool(timer.paused).is_false()
	assert_str(label.text).is_empty()
	assert_str(controls.pause_button.icon_name).is_equal("pause")


func test_fast_forward_speeds_the_ticks_not_the_fight() -> void:
	var screen := _screen(_gunner(), _bare())
	var timer: Timer = screen.get_node("%TickTimer")
	var controls: PlaybackControls = screen.get_node("%Playback")
	controls.speed_pressed.emit()
	assert_int(screen.speed).is_equal(2)
	assert_float(timer.wait_time).is_equal_approx(0.05, 1e-9)
	assert_str(screen.get_playback_text()).is_equal("FAST FORWARD 2X")
	assert_that(controls.speed_button.color).is_equal(PlaybackControls.FAST_COLOR)
	# The bars glide over the shorter wait, so they keep up.
	assert_float((screen.get_node("%LeftHp") as HpBar).smoothing).is_equal_approx(0.05, 1e-9)
	screen.cycle_speed()
	assert_int(screen.speed).is_equal(4)
	assert_float(timer.wait_time).is_equal_approx(0.025, 1e-9)
	assert_str(screen.get_playback_text()).is_equal("FAST FORWARD 4X")
	# Each tick still moves the fight a tenth of a second.
	timer.timeout.emit()
	assert_float(screen.engine.elapsed).is_equal_approx(0.1, 1e-9)
	# After the fastest, back to normal.
	screen.cycle_speed()
	assert_int(screen.speed).is_equal(1)
	assert_float(timer.wait_time).is_equal_approx(0.1, 1e-9)
	assert_str(screen.get_playback_text()).is_empty()


func test_skipping_plays_out_the_fight_and_shows_the_result_at_once() -> void:
	var screen := _screen(_gunner(), _bare())
	screen.toggle_pause() # skipping works while paused too
	(screen.get_node("%Playback") as PlaybackControls).skip_pressed.emit()
	assert_bool(screen.is_over()).is_true()
	assert_float(screen.engine.elapsed).is_equal_approx(4.0, 1e-9)
	assert_bool((screen.get_node("%TickTimer") as Timer).is_stopped()).is_true()
	assert_bool(screen.result_panel.visible).is_true()
	assert_str(screen.result_panel.title_label.text).is_equal("VICTORY")
	assert_str(screen.get_playback_text()).is_equal("BATTLE OVER")
	assert_str((screen.get_node("%RightHp") as HpBar).get_text()).is_equal("0/30")
	# Once it's over, the controls are off and do nothing.
	var controls: PlaybackControls = screen.get_node("%Playback")
	assert_bool(controls.pause_button.disabled).is_true()
	assert_bool(controls.skip_button.disabled).is_true()
	screen.toggle_pause()
	screen.cycle_speed()
	screen._unhandled_input(_space())
	assert_bool(screen.paused).is_false()
	assert_int(screen.speed).is_equal(1)


func test_a_fight_that_ends_on_its_own_turns_the_controls_off() -> void:
	var screen := _screen(_gunner(), _bare())
	_tick_until_over(screen)
	assert_str(screen.get_playback_text()).is_equal("BATTLE OVER")
	assert_bool((screen.get_node("%Playback") as PlaybackControls).speed_button.disabled).is_true()
	# Positive control: while it runs, they're on.
	var running := _screen(_gunner(), _bare())
	assert_bool((running.get_node("%Playback") as PlaybackControls).speed_button.disabled).is_false()


func test_shots_fly_and_land_with_a_popup() -> void:
	var screen := _screen(_gunner(), _bare())
	var effects: CombatEffects = screen.get_node("%Effects")
	_tick(screen, 10)
	# The gatling fired at 1 second: its tag flashes and a shot is in flight.
	var tag: WeaponTag = (screen.get_node("%LeftWeapons") as WeaponTags).get_tags()[0]
	assert_float(tag.flash).is_greater(0.0)
	assert_array(effects.get_effects()).has_size(1)
	assert_array(_popup_texts(screen)).is_empty()
	await await_millis(int(CombatScreen.FLIGHT_TIME * 1000) + 100)
	# It lands on the bare mech, in the player's accent. A light hit leaves the camera still.
	var popups := _popups(screen)
	assert_array(popups).has_size(1)
	assert_str(popups[0].text).is_equal("-8")
	assert_that(popups[0].color).is_equal(CombatColors.HIT_ON_OPPONENT)
	assert_bool(screen.get_small_shake().is_emitting()).is_false()


func test_hits_landing_together_share_a_popup() -> void:
	# Two gatlings fire on the same tick; their 8s land together as one 16.
	var gatlings := [Fixtures.gatling(), Fixtures.gatling()]
	var grid := MechGridData.new(Fixtures.armed_cross())
	for i in 2:
		gatlings[i].cooldown_max = 1.0
		assert_bool(grid.place_part(gatlings[i], [Vector2i(-1, 1), Vector2i(4, 1)][i])).is_true()
	var twin := BattleMech.new(grid)
	twin.current_energy = 100
	var screen := _screen(twin, _bare())
	_tick(screen, 10)
	await await_millis(int(CombatScreen.FLIGHT_TIME * 1000) + 100)
	assert_array(_popup_texts(screen)).is_equal(["-16"])


func test_plating_shows_what_it_blocked() -> void:
	# The gunner's 8 against a Bastion's plating of 2.
	var screen := _screen(_gunner(), BattleMech.new(MechGridData.new(Fixtures.bastion())))
	_tick(screen, 10)
	await await_millis(int(CombatScreen.FLIGHT_TIME * 1000) + 100)
	assert_array(_popup_texts(screen)).contains_exactly_in_any_order(["-6", "BLOCK 2"])


func test_heavy_hits_shake_the_camera() -> void:
	var gunner := _gunner()
	gunner.active_parts[0].damage = CombatScreen.HEAVY_HIT
	var screen := _screen(gunner, _bare())
	_tick(screen, 10)
	assert_bool(screen.get_small_shake().is_emitting()).is_false()
	await await_millis(int(CombatScreen.FLIGHT_TIME * 1000) + 50)
	assert_bool(screen.get_small_shake().is_emitting()).is_true()


func test_storm_strikes_flash_the_stage_and_hit_both_mechs() -> void:
	var screen := _screen(_bare(), _bare())
	screen.engine.storm_start = 0.1
	_tick(screen, 1)
	assert_float((screen.get_node("%Effects") as CombatEffects).get_flash_alpha()).is_greater(0.0)
	await await_idle_frame()
	var popups := _popups(screen)
	assert_array(popups.map(func(pop: DamagePopup) -> String: return pop.text)).is_equal(["-1", "-1"])
	assert_that(popups[0].color).is_equal(CombatColors.STORM)
	assert_bool(screen.get_small_shake().is_emitting()).is_true()


func test_the_ko_punches_in_on_the_fallen_mech() -> void:
	var screen := _screen(_gunner(), _bare())
	var main: PhantomCamera2D = screen.get_node("%MainPCam")
	var ko: PhantomCamera2D = screen.get_node("%KoPCam")
	assert_int(ko.priority).is_less(main.priority)
	_tick_until_over(screen)
	# The KO camera takes over, zoomed in on the bare mech that fell, and the camera shakes.
	assert_int(ko.priority).is_greater(main.priority)
	var fallen: FighterView = screen.get_node("%RightFighter")
	var stage: Control = screen.get_node("%Stage")
	assert_vector(ko.position).is_equal(screen.get_ko_focus(stage.position + fallen.get_rest_center()))
	assert_float(ko.position.x).is_greater(main.position.x)
	assert_vector(ko.zoom).is_equal(Vector2.ONE * CombatScreen.KO_ZOOM)
	assert_bool(screen.get_big_shake().is_emitting()).is_true()
	assert_bool((screen.get_node("%StormTimer") as StormTimer).running).is_false()


func test_the_ko_slows_time_then_eases_back() -> void:
	var screen := _screen(_gunner(), _bare())
	assert_float(Engine.time_scale).is_equal(1.0)
	_tick_until_over(screen)
	assert_float(Engine.time_scale).is_equal(CombatScreen.KO_SLOW_MO)
	# On real time, it's back to full speed once the slow motion and the easing are over.
	var real_wait := CombatScreen.KO_SLOW_TIME + CombatScreen.KO_RECOVER_TIME + 0.2
	await get_tree().create_timer(real_wait, true, false, true).timeout
	assert_float(Engine.time_scale).is_equal(1.0)


func test_leaving_mid_slow_motion_restores_full_speed() -> void:
	var screen := _screen(_gunner(), _bare())
	_tick_until_over(screen)
	assert_float(Engine.time_scale).is_less(1.0)
	remove_child(screen)
	assert_float(Engine.time_scale).is_equal(1.0)


func test_the_ko_view_stays_inside_the_stage() -> void:
	var screen := _screen(_gunner(), _bare())
	# Sized by hand, as a window of the stage's own size.
	screen.set_anchors_preset(Control.PRESET_TOP_LEFT)
	screen.size = Vector2(1280, 820)
	var stage: Control = screen.get_node("%Stage")
	var zoomed_half := screen.size / (2.0 * CombatScreen.KO_ZOOM)
	# Either fallen mech is centered on exactly: each stands on its pad.
	for fighter: FighterView in [screen.get_node("%LeftFighter"), screen.get_node("%RightFighter")]:
		var fallen := stage.position + fighter.get_rest_center()
		assert_vector(screen.get_ko_focus(fallen)).is_equal_approx(fallen, Vector2(1e-3, 1e-3))
	# A point in the stage's corner pulls the view only as far as the edges allow.
	var corner := stage.position + Vector2(1270, 810)
	var focus := screen.get_ko_focus(corner)
	assert_float(focus.x + zoomed_half.x).is_equal_approx(stage.position.x + 1280, 1e-3)
	assert_float(focus.y + zoomed_half.y).is_equal_approx(stage.position.y + 820, 1e-3)
	# A window so wide that even zoomed it shows more than the stage centers on the stage across.
	screen.size = Vector2(2800, 820)
	await await_idle_frame()
	assert_float(screen.get_ko_focus(stage.position + Vector2(1200, 400)).x).is_equal_approx(stage.position.x + 640, 1e-3)


func test_a_skipped_fight_plays_no_effects() -> void:
	var screen := _screen(_gunner(), _bare())
	screen.skip()
	assert_array((screen.get_node("%Effects") as CombatEffects).get_effects()).is_empty()
	assert_int((screen.get_node("%KoPCam") as PhantomCamera2D).priority).is_less((screen.get_node("%MainPCam") as PhantomCamera2D).priority)
	assert_bool(screen.get_big_shake().is_emitting()).is_false()
	assert_float(Engine.time_scale).is_equal(1.0)
	assert_bool((screen.get_node("%RightFighter") as FighterView).is_marked_destroyed()).is_true()


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


func test_built_mechs_have_the_chassis_hp_plus_their_parts() -> void:
	# An empty lineup loads no parts: just the chassis's HP.
	assert_int(CombatScreen.build_mech(Fixtures.cross_chassis(), [], []).max_hp).is_equal(30)


func _screen(left: BattleMech, right: BattleMech, run: RunState = null) -> CombatScreen:
	var screen: CombatScreen = auto_free(SCENE.instantiate())
	screen.print_ticks = false
	screen.setup(left, right, run)
	add_child(screen)
	return screen


# Fires the screen's timer [param ticks] times.
func _tick(screen: CombatScreen, ticks: int) -> void:
	for i in ticks:
		screen.get_node("%TickTimer").timeout.emit()


func _popups(screen: CombatScreen) -> Array:
	return (screen.get_node("%Effects") as CombatEffects).get_effects().filter(func(node: Node) -> bool:
		return node is DamagePopup and not node.is_queued_for_deletion())


func _popup_texts(screen: CombatScreen) -> Array:
	return _popups(screen).map(func(pop: DamagePopup) -> String: return pop.text)


func _space() -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = KEY_SPACE
	event.pressed = true
	return event


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


func test_the_opponents_affixes_show_under_its_bar() -> void:
	var foe := BattleMech.new(MechGridData.new(Fixtures.cross_chassis()), [], 1.0, -1, [Fixtures.shielded(), Fixtures.armored()] as Array[Relic])
	var screen := _screen(_gunner(), foe)
	var icons := screen.get_affix_icons()
	assert_array(icons.map(func(icon: RelicIcon) -> String: return icon.relic.relic_name)).contains_exactly(["Shielded", "Armored"])
	assert_str(icons[0].tooltip_text.get_slice("\n", 0)).is_equal("Shielded (Affix)")
	# Positive control: a plain opponent shows none.
	assert_array(_screen(_gunner(), _bare()).get_affix_icons()).is_empty()


func test_a_boss_phase_pops_its_title() -> void:
	var boss := _bare()
	boss.phases.assign([Fixtures.boss_phase("Scrap Armor", 0.5, {"shield_share": 0.3})])
	var screen := _screen(_gunner(), boss)
	# The gunner's 8 a second takes the boss under half at 2 seconds.
	_tick(screen, 20)
	assert_array(_popup_texts(screen)).contains(["SCRAP ARMOR"])
	assert_int(boss.shield).is_equal(9)


func test_the_players_kits_are_buttons_along_the_bottom() -> void:
	var player := _gunner()
	player.kits.assign([Fixtures.micro_missile(), Fixtures.emergency_patch()])
	var foe := _bare()
	var screen := _screen(player, foe)
	assert_object(screen.kit_bar).is_not_null()
	var buttons := screen.kit_bar.get_children()
	assert_array(buttons).has_size(2)
	assert_str((buttons[0] as Button).text).is_equal("Micro-missile · 20 EN")
	assert_str((buttons[1] as Button).text).is_equal("Emergency Patch · auto")
	# Not enough energy yet, and an auto kit is never pressed.
	assert_bool((buttons[0] as Button).disabled).is_true()
	assert_bool((buttons[1] as Button).disabled).is_true()
	player.current_energy = 20
	screen.kit_bar.refresh()
	assert_bool((buttons[0] as Button).disabled).is_false()
	(buttons[0] as Button).pressed.emit()
	assert_int(foe.current_health).is_equal(0)
	assert_str((buttons[0] as Button).text).is_equal("Micro-missile · used")
	assert_bool((buttons[0] as Button).disabled).is_true()
	assert_array(_popup_texts(screen)).contains(["MICRO-MISSILE"])
	# Positive control: no kits, no bar.
	assert_object(_screen(_gunner(), _bare()).kit_bar).is_null()
	await await_idle_frame()
