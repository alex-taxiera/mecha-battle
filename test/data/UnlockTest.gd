class_name UnlockTest
extends GdUnitTestSuite

const __source: String = "res://src/data/Unlock.gd"
const Fixtures := preload("res://test/TestFixtures.gd")

var _profile: Profile


func before_test() -> void:
	_profile = Profile.new()


func test_no_milestone_is_met_at_once() -> void:
	assert_bool(Fixtures.unlock("free", Unlock.Kind.NPC, "x").is_met(_profile, 0, "")).is_true()


func test_sectors_cleared_in_the_run() -> void:
	var unlock := Fixtures.unlock("u", Unlock.Kind.CHASSIS, "striker", {"sectors_cleared": 2})
	assert_bool(unlock.is_met(_profile, 1, "bastion")).is_false()
	assert_bool(unlock.is_met(_profile, 2, "bastion")).is_true()
	assert_bool(unlock.is_met(_profile, 3, "reactor")).is_true()


func test_sectors_with_a_chassis() -> void:
	var unlock := Fixtures.unlock("u", Unlock.Kind.RELIC, "titan", {"sectors_cleared": 1, "with_chassis": "bastion"})
	assert_bool(unlock.is_met(_profile, 1, "striker")).is_false()
	assert_bool(unlock.is_met(_profile, 0, "bastion")).is_false()
	assert_bool(unlock.is_met(_profile, 1, "bastion")).is_true()


func test_totals_across_runs() -> void:
	var runs := Fixtures.unlock("u", Unlock.Kind.NPC, "x", {"runs_finished": 2})
	var fights := Fixtures.unlock("u", Unlock.Kind.PART, "x", {"fights_won_total": 5})
	var wins := Fixtures.unlock("u", Unlock.Kind.CHASSIS, "x", {"runs_won": 1})
	_profile.runs = 1
	_profile.fights_won = 4
	assert_bool(runs.is_met(_profile, 0, "")).is_false()
	assert_bool(fights.is_met(_profile, 0, "")).is_false()
	assert_bool(wins.is_met(_profile, 0, "")).is_false()
	_profile.runs = 2
	_profile.fights_won = 5
	_profile.wins = 1
	assert_bool(runs.is_met(_profile, 0, "")).is_true()
	assert_bool(fights.is_met(_profile, 0, "")).is_true()
	assert_bool(wins.is_met(_profile, 0, "")).is_true()


func test_every_set_part_must_be_met() -> void:
	var both := Fixtures.unlock("u", Unlock.Kind.NPC, "x", {"sectors_cleared": 1, "fights_won_total": 10})
	_profile.fights_won = 3
	assert_bool(both.is_met(_profile, 2, "")).is_false()
	_profile.fights_won = 10
	assert_bool(both.is_met(_profile, 2, "")).is_true()
