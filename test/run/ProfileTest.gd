class_name ProfileTest
extends GdUnitTestSuite

const __source: String = "res://src/run/Profile.gd"
const Fixtures := preload("res://test/TestFixtures.gd")
const SCRATCH := "user://test_profile.json"


func after_test() -> void:
	if FileAccess.file_exists(SCRATCH):
		DirAccess.remove_absolute(SCRATCH)


func test_a_missing_file_gives_a_fresh_profile() -> void:
	var profile := Profile.load_from(SCRATCH)
	assert_str(profile.path).is_equal(SCRATCH)
	assert_int(profile.runs).is_equal(0)
	assert_array(profile.unlocked).is_empty()


func test_it_saves_and_loads_back() -> void:
	var profile := Profile.load_from(SCRATCH)
	profile.runs = 5
	profile.wins = 1
	profile.fights_won = 40
	profile.bosses_beaten = 7
	profile.chassis_records = {"bastion": {"runs": 5, "wins": 1, "best_sector": 3}}
	profile.unlocked.append("striker")
	assert_int(profile.save()).is_equal(OK)
	var loaded := Profile.load_from(SCRATCH)
	assert_int(loaded.runs).is_equal(5)
	assert_int(loaded.wins).is_equal(1)
	assert_int(loaded.fights_won).is_equal(40)
	assert_int(loaded.bosses_beaten).is_equal(7)
	assert_int(int(loaded.chassis_records["bastion"]["best_sector"])).is_equal(3)
	assert_array(loaded.unlocked).contains_exactly(["striker"])


func test_a_broken_file_starts_fresh() -> void:
	var file := FileAccess.open(SCRATCH, FileAccess.WRITE)
	file.store_string("not json")
	file.close()
	var profile := Profile.load_from(SCRATCH)
	assert_int(profile.runs).is_equal(0)


func test_an_in_memory_profile_never_writes() -> void:
	var profile := Profile.new()
	profile.runs = 3
	assert_int(profile.save()).is_equal(OK)
	assert_bool(FileAccess.file_exists(SCRATCH)).is_false()


func test_recording_runs_adds_up() -> void:
	var profile := Profile.new()
	var lost := _run(2, 1) # fell in Sector 2: one sector cleared
	lost.fights_won = 9
	lost.outcome = RunState.Outcome.DEFEAT
	profile.record_run(lost, [])
	var won := _run(3, 2)
	won.fights_won = 20
	won.outcome = RunState.Outcome.VICTORY
	profile.record_run(won, [])
	assert_int(profile.runs).is_equal(2)
	assert_int(profile.wins).is_equal(1)
	assert_int(profile.fights_won).is_equal(29)
	# One sector cleared in the first run, all three in the win.
	assert_int(profile.bosses_beaten).is_equal(4)
	var record: Dictionary = profile.chassis_records["bastion"]
	assert_int(record["runs"]).is_equal(2)
	assert_int(record["wins"]).is_equal(1)
	assert_int(record["best_sector"]).is_equal(3)


func test_recording_earns_the_unlocks_whose_milestones_are_met() -> void:
	var profile := Profile.new()
	var sector_one := Fixtures.unlock("striker", Unlock.Kind.CHASSIS, "striker", {"sectors_cleared": 1})
	var sector_two := Fixtures.unlock("reactor", Unlock.Kind.CHASSIS, "reactor", {"sectors_cleared": 2})
	var unlocks: Array[Unlock] = [sector_one, sector_two]
	var run := _run(2, 1) # fell in Sector 2: one sector cleared
	run.outcome = RunState.Outcome.DEFEAT
	assert_array(profile.record_run(run, unlocks)).contains_same_exactly([sector_one])
	assert_bool(profile.is_unlocked("striker")).is_true()
	# Already earned: not earned again.
	assert_array(profile.record_run(run, unlocks)).is_empty()
	assert_array(profile.unlocked).contains_exactly(["striker"])


func test_availability_follows_unlocks() -> void:
	var profile := Profile.new()
	var unlocks: Array[Unlock] = [Fixtures.unlock("pod", Unlock.Kind.PART, "missile_pod", {"fights_won_total": 5})]
	assert_bool(profile.is_available(Unlock.Kind.PART, "missile_pod", unlocks)).is_false()
	assert_str(profile.get_lock(Unlock.Kind.PART, "missile_pod", unlocks).id).is_equal("pod")
	# Content without an unlock is always there, and kinds don't mix.
	assert_bool(profile.is_available(Unlock.Kind.PART, "laser", unlocks)).is_true()
	assert_bool(profile.is_available(Unlock.Kind.RELIC, "missile_pod", unlocks)).is_true()
	profile.unlocked.append("pod")
	assert_bool(profile.is_available(Unlock.Kind.PART, "missile_pod", unlocks)).is_true()
	assert_object(profile.get_lock(Unlock.Kind.PART, "missile_pod", unlocks)).is_null()


func test_reset_forgets_everything() -> void:
	var profile := Profile.new()
	profile.runs = 2
	profile.chassis_records = {"bastion": {}}
	profile.unlocked.append("striker")
	profile.reset()
	assert_int(profile.runs).is_equal(0)
	assert_bool(profile.chassis_records.is_empty()).is_true()
	assert_array(profile.unlocked).is_empty()


# A run on a Bastion-id frame through [param act_count] fixture sectors, now in sector
# [param act_index] (from 0).
func _run(act_count: int, act_index: int) -> RunState:
	var chassis := Fixtures.bastion()
	chassis.id = "bastion"
	var acts: Array[ActData] = []
	for i in act_count:
		acts.append(Fixtures.act())
	var run := RunState.new(chassis, [], [], 10, RunRng.new(1), acts)
	run.act_index = act_index
	return run
