class_name HistoryTest
extends GdUnitTestSuite
## Run history, the MVP part, what destroyed the mech, and daily run records.

const __source: String = "res://src/run/Profile.gd"
const Fixtures := preload("res://test/TestFixtures.gd")
const LEFT_ARM := Vector2i(-1, 1)


func test_a_run_tracks_each_parts_damage_and_its_mvp() -> void:
	var run := _run()
	assert_object(run.get_mvp()).is_null()
	var mech := run.make_player_mech()
	var gun := mech.active_parts[0]
	gun.damage_dealt = 30
	run.record_fight(RunState.FightResult.WIN, mech, "Grunt")
	mech = run.make_player_mech()
	mech.active_parts[0].damage_dealt = 12
	run.record_fight(RunState.FightResult.WIN, mech, "Grunt")
	assert_object(run.get_mvp()).is_same(gun.part)
	assert_int(run.part_damage[gun.part]).is_equal(42)
	# Winning isn't being destroyed.
	assert_str(run.defeated_by).is_empty()
	run.record_fight(RunState.FightResult.LOSS, run.make_player_mech(), "The Crucible")
	assert_str(run.defeated_by).is_equal("The Crucible")


func test_a_summary_keeps_how_the_run_went() -> void:
	var run := _run()
	var mech := run.make_player_mech()
	mech.active_parts[0].damage_dealt = 50
	run.record_fight(RunState.FightResult.LOSS, mech, "Grunt A")
	var entry := Profile.summarize(run)
	assert_str(entry["chassis_name"]).is_equal("The Skirmisher")
	assert_bool(entry["won"]).is_false()
	assert_str(entry["cause"]).is_equal("Destroyed by Grunt A")
	assert_str(entry["mvp"]).is_equal("Twin Gatling")
	assert_int(entry["mvp_damage"]).is_equal(50)
	assert_int(entry["seed"]).is_equal(7)
	# A cell per cell the parts cover: the gatling's arm bay.
	assert_array(entry["grid"]).has_size(3)
	assert_array(entry["grid"]).contains([[-1, 1, MechPart.PartType.WEAPON]])


func test_history_keeps_the_newest_twenty() -> void:
	var profile := Profile.new()
	for i in 25:
		var run := _run()
		run.fights_won = i
		run.outcome = RunState.Outcome.DEFEAT
		profile.record_run(run, [])
	assert_array(profile.history).has_size(Profile.HISTORY_MAX)
	assert_int(profile.history[0]["fights_won"]).is_equal(24)
	assert_int(profile.history[-1]["fights_won"]).is_equal(5)


func test_history_and_dailies_survive_a_save() -> void:
	var path := "user://test_history_profile.json"
	var profile := Profile.load_from(path)
	var run := _run()
	run.outcome = RunState.Outcome.DEFEAT
	profile.record_run(run, [])
	profile.daily_records["2026-09-27"] = {"sector": 1, "won": false, "fights_won": 4}
	assert_int(profile.save()).is_equal(OK)
	var loaded := Profile.load_from(path)
	assert_array(loaded.history).has_size(1)
	assert_str(loaded.history[0]["chassis_name"]).is_equal("The Skirmisher")
	assert_int(int(loaded.daily_records["2026-09-27"]["fights_won"])).is_equal(4)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	# A reset forgets them.
	loaded.reset()
	assert_array(loaded.history).is_empty()
	assert_bool(loaded.daily_records.is_empty()).is_true()


func test_a_daily_counts_only_toward_its_own_record() -> void:
	var profile := Profile.new()
	var run := _run()
	run.daily = "2026-09-27"
	run.fights_won = 6
	run.act_index = 1
	run.outcome = RunState.Outcome.DEFEAT
	profile.record_daily(run)
	assert_int(profile.runs).is_equal(0)
	assert_int(profile.fights_won).is_equal(0)
	assert_int(profile.get_mastery_xp("")).is_equal(0)
	assert_array(profile.history).has_size(1)
	assert_str(profile.history[0]["daily"]).is_equal("2026-09-27")
	assert_that(profile.daily_records["2026-09-27"]).is_equal({"sector": 1, "won": false, "fights_won": 6})
	# A worse try doesn't replace the best; a better one does.
	run.act_index = 0
	profile.record_daily(run)
	assert_int(profile.daily_records["2026-09-27"]["sector"]).is_equal(1)
	run.outcome = RunState.Outcome.VICTORY
	profile.record_daily(run)
	assert_bool(profile.daily_records["2026-09-27"]["won"]).is_true()


func test_the_daily_is_the_same_all_day_and_changes_by_day() -> void:
	var frames: Array[MechChassis] = [Fixtures.bastion(), Fixtures.striker(), Fixtures.reactor_frame()]
	var modes: Array[RunModifier] = [Fixtures.glass_cannon(), Fixtures.run_modifier("iron_man", {"is_custom": true})]
	var today := Game.daily_setup("2026-09-27", frames, modes)
	var again := Game.daily_setup("2026-09-27", frames, modes)
	assert_int(today["seed"]).is_equal(again["seed"])
	assert_object(today["chassis"]).is_same(again["chassis"])
	assert_object(today["mode"]).is_same(again["mode"])
	var seeds := {}
	for day in range(1, 29):
		seeds[Game.daily_setup("2026-02-%02d" % day, frames, modes)["seed"]] = true
	assert_int(seeds.size()).is_equal(28)


func test_the_history_screen_lists_each_run() -> void:
	var profile := Profile.new()
	var empty: HistoryScreen = auto_free(HistoryScreen.new(profile))
	assert_array(empty.get_entry_texts()).has_size(1)
	var run := _run()
	var mech := run.make_player_mech()
	mech.active_parts[0].damage_dealt = 50
	run.record_fight(RunState.FightResult.LOSS, mech, "Grunt A")
	profile.record_run(run, [])
	var screen: HistoryScreen = auto_free(HistoryScreen.new(profile))
	add_child(screen)
	var lines := screen.get_entry_texts()[0]
	assert_array(lines).contains(["The Skirmisher · Mech destroyed", "Destroyed by Grunt A · Sector 1 · Floor 0",
		"Fights won 0 · MVP: Twin Gatling (50 damage)", "Relics: none"])
	var grids := screen.find_children("*", "Control", true, false).filter(func(node: Node) -> bool: return node is HistoryGridView)
	assert_array(grids).has_size(1)
	assert_that(grids[0].get_combined_minimum_size()).is_equal(Vector2(10, 30))
	await await_idle_frame()


func _run() -> RunState:
	var chassis := Fixtures.armed_cross()
	chassis.starter_lineup = [LoadoutPart.make(Fixtures.gatling(), LEFT_ARM)]
	var acts: Array[ActData] = [Fixtures.act(), Fixtures.act()]
	return RunState.new(chassis, [], [], 10, RunRng.new(7), acts)
