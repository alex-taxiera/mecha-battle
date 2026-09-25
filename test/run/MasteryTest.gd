class_name MasteryTest
extends GdUnitTestSuite
## Chassis mastery, the new unlock milestones, and the Prismatic and Iron Man modes.

const __source: String = "res://src/run/Profile.gd"
const Fixtures := preload("res://test/TestFixtures.gd")


func test_mastery_levels_follow_xp() -> void:
	var profile := Profile.new()
	assert_int(profile.get_mastery_level("bastion")).is_equal(1)
	assert_int(profile.get_next_mastery_xp("bastion")).is_equal(10)
	profile.chassis_records["bastion"] = {"xp": 9}
	assert_int(profile.get_mastery_level("bastion")).is_equal(1)
	profile.chassis_records["bastion"] = {"xp": 10}
	assert_int(profile.get_mastery_level("bastion")).is_equal(2)
	assert_int(profile.get_next_mastery_xp("bastion")).is_equal(25)
	profile.chassis_records["bastion"] = {"xp": 45}
	assert_int(profile.get_mastery_level("bastion")).is_equal(4)
	assert_int(profile.get_next_mastery_xp("bastion")).is_equal(-1)
	# Other frames keep their own.
	assert_int(profile.get_mastery_level("striker")).is_equal(1)


func test_a_run_earns_its_frame_mastery_xp() -> void:
	var profile := Profile.new()
	var lost := _run(3, 1)
	lost.fights_won = 7
	lost.outcome = RunState.Outcome.DEFEAT
	# 7 fights and 1 sector: 7 + 5.
	assert_int(Profile.mastery_xp_for(lost)).is_equal(12)
	profile.record_run(lost, [])
	assert_int(profile.get_mastery_xp("bastion")).is_equal(12)
	var won := _run(3, 2)
	won.fights_won = 15
	won.outcome = RunState.Outcome.VICTORY
	# 15 + 3 sectors × 5 + 10 for the win.
	assert_int(Profile.mastery_xp_for(won)).is_equal(40)
	profile.record_run(won, [])
	assert_int(profile.get_mastery_xp("bastion")).is_equal(52)
	assert_int(profile.get_mastery_level("bastion")).is_equal(4)


func test_mastery_survives_a_save() -> void:
	var path := "user://test_mastery_profile.json"
	var profile := Profile.load_from(path)
	profile.chassis_records["reactor"] = {"runs": 1, "wins": 0, "best_sector": 1, "threat": 0, "xp": 27}
	assert_int(profile.save()).is_equal(OK)
	assert_int(Profile.load_from(path).get_mastery_level("reactor")).is_equal(3)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_a_mastery_milestone_needs_that_frames_level() -> void:
	var unlock := Fixtures.unlock("bulkheads", Unlock.Kind.RELIC, "reinforced_bulkheads", {"mastery_level": 3, "with_chassis": "bastion"})
	var profile := Profile.new()
	profile.chassis_records["bastion"] = {"xp": 24}
	assert_bool(unlock.is_met(profile, 0, "bastion")).is_false()
	# Another frame's mastery doesn't count.
	profile.chassis_records["striker"] = {"xp": 99}
	assert_bool(unlock.is_met(profile, 0, "striker")).is_false()
	profile.chassis_records["bastion"] = {"xp": 25}
	assert_bool(unlock.is_met(profile, 0, "striker")).is_true()


func test_threat_and_boss_milestones() -> void:
	var threat := Fixtures.unlock("pit", Unlock.Kind.EVENT, "pit_fight", {"threat_reached": 2})
	var bosses := Fixtures.unlock("siphon", Unlock.Kind.MOD, "siphon", {"bosses_beaten_total": 2})
	var profile := Profile.new()
	assert_bool(threat.is_met(profile, 0, "")).is_false()
	assert_bool(bosses.is_met(profile, 0, "")).is_false()
	profile.chassis_records["striker"] = {"threat": 2}
	profile.bosses_beaten = 2
	assert_bool(threat.is_met(profile, 0, "")).is_true()
	assert_bool(bosses.is_met(profile, 0, "")).is_true()
	# Tied to a frame, only that frame's Threat counts.
	var reactor_threat := Fixtures.unlock("hot", Unlock.Kind.KIT, "reboot_protocol", {"threat_reached": 2, "with_chassis": "reactor"})
	assert_bool(reactor_threat.is_met(profile, 0, "")).is_false()
	profile.chassis_records["reactor"] = {"threat": 3}
	assert_bool(reactor_threat.is_met(profile, 0, "")).is_true()


func test_prismatic_opens_every_frames_relics() -> void:
	var bastion_only := Fixtures.relic("Bulkheads", Relic.Rarity.UNCOMMON)
	bastion_only.chassis_id = "bastion"
	var relics: Array[Relic] = [bastion_only]
	var striker := Fixtures.striker()
	striker.id = "striker"
	var prismatic: Array[RunModifier] = [Fixtures.run_modifier("prismatic", {"is_custom": true, "prismatic": true})]
	var open := RunState.new(striker, [], [], 10, RunRng.new(1), [], relics, [], [], prismatic)
	assert_bool(open.relic_pool.has(bastion_only)).is_true()
	# Positive control: without it, the Bastion's relic stays out.
	assert_bool(RunState.new(striker, [], [], 10, RunRng.new(1), [], relics).relic_pool.has(bastion_only)).is_false()


func test_iron_man_turns_every_hangar_into_a_battle() -> void:
	var acts: Array[ActData] = [Fixtures.act()]
	var iron: Array[RunModifier] = [Fixtures.run_modifier("iron_man", {"is_custom": true, "no_hangars": true})]
	var run := RunState.new(Fixtures.cross_chassis(), [], [], 10, RunRng.new(1), acts, [], [], [], iron)
	for node in run.map.get_nodes():
		assert_int(node.type).append_failure_message(node.id).is_not_equal(MapNode.Type.HANGAR)
	# The floor under the boss is all hangars otherwise; now it's battles.
	for node in run.map.floors[-1]:
		assert_int(node.type).is_equal(MapNode.Type.BATTLE)
	# Positive control: the same map without it has hangars.
	var plain := RunState.new(Fixtures.cross_chassis(), [], [], 10, RunRng.new(1), acts)
	assert_bool(plain.map.get_nodes().any(func(node: MapNode) -> bool: return node.type == MapNode.Type.HANGAR)).is_true()


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
