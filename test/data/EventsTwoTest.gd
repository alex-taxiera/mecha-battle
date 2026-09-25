class_name EventsTwoTest
extends GdUnitTestSuite
## The second round of event tools: pages, flags, gated choices, sector events, junk, recasting,
## and the Sealed Crate.

const __source: String = "res://src/data/events/GameEvent.gd"
const Fixtures := preload("res://test/TestFixtures.gd")

var _run: RunState


func before_test() -> void:
	var acts: Array[ActData] = [Fixtures.act(), Fixtures.act(), Fixtures.act()]
	_run = RunState.new(Fixtures.armed_cross(), [Fixtures.gatling(), Fixtures.laser(), Fixtures.heatsink()], [], 50,
		RunRng.new(1), acts, Fixtures.relics())


func test_an_outcome_can_lead_to_a_next_page() -> void:
	var page := Fixtures.event("Inside", [Fixtures.choice("Grab it", [Fixtures.outcome("Got it.", [Fixtures.gold_effect(5)])])])
	var enter := Fixtures.outcome("You go in.", [])
	enter.next_event = page
	var event := Fixtures.event("Door", [Fixtures.choice("Open it", [enter])])
	var result := _run.choose_event_option(event, 0)
	assert_object(result.next_event).is_same(page)
	# Positive control: an ordinary outcome ends the event.
	assert_object(_run.choose_event_option(page, 0).next_event).is_null()


func test_flags_let_one_event_follow_another() -> void:
	var needs := FlagRequirement.new()
	needs.flag = "boarded"
	assert_bool(needs.check(_run)).is_false()
	var sets := SetFlagEffect.new()
	sets.flag = "boarded"
	sets.apply(_run, EventResult.new())
	assert_bool(needs.check(_run)).is_true()
	needs.value = 2
	assert_bool(needs.check(_run)).is_false()


func test_choices_can_need_a_chassis_or_a_relic() -> void:
	var reactor := ChassisRequirement.new()
	reactor.chassis_id = "reactor"
	reactor.chassis_name = "the Reactor"
	assert_bool(reactor.check(_run)).is_false()
	assert_str(reactor.describe()).is_equal("Needs the Reactor")
	var frame := Fixtures.reactor_frame()
	frame.id = "reactor"
	assert_bool(reactor.check(RunState.new(frame, [], []))).is_true()
	var has_relic := RelicRequirement.new()
	has_relic.relic_id = "rare"
	has_relic.relic_name = "Rare"
	assert_bool(has_relic.check(_run)).is_false()
	_run.add_relic(Fixtures.relic("Rare", Relic.Rarity.RARE))
	assert_bool(has_relic.check(_run)).is_true()


func test_a_sector_event_waits_in_the_pool_for_its_sector() -> void:
	var later := SectorRequirement.new()
	later.first = 2
	later.last = 3
	assert_bool(later.check(_run)).is_false()
	var pool_event := Fixtures.event("Later", [Fixtures.choice("Ok", [])], later)
	var filler := Fixtures.gold_event("Now")
	var events: Array[GameEvent] = [pool_event, filler]
	var pool := EventPool.new(events, RunRng.new(3).stream("events"))
	assert_object(pool.next(_run)).is_same(filler)
	_run.next_act()
	assert_bool(later.check(_run)).is_true()
	assert_object(pool.next(_run)).is_same(pool_event)


func test_all_requirements_must_pass() -> void:
	var flag := FlagRequirement.new()
	flag.flag = "seen"
	var sector := SectorRequirement.new()
	sector.first = 1
	var both := AllRequirement.new()
	both.requirements.assign([sector, flag])
	assert_bool(both.check(_run)).is_false()
	assert_str(both.describe()).is_equal(flag.describe())
	_run.flags["seen"] = 1
	assert_bool(both.check(_run)).is_true()


func test_junk_can_be_stripped_for_gold() -> void:
	var junk := Fixtures.glitch()
	var needs := JunkRequirement.new()
	assert_bool(needs.check(_run)).is_false()
	_run.stash_part(junk)
	assert_bool(_run.grid.place_part(Fixtures.glitch(), Vector2i(1, 1))).is_true()
	assert_bool(needs.check(_run)).is_true()
	var strip := StripJunkEffect.new()
	strip.gold_each = 15
	assert_str(strip.describe(_run)).is_equal("Strip 2 junk parts for 30 gold.")
	var result := EventResult.new()
	strip.apply(_run, result)
	assert_int(_run.gold).is_equal(80)
	assert_array(StripJunkEffect.junk_of(_run)).is_empty()
	assert_array(result.lines).contains_exactly(["Stripped 2 junk parts · +30 gold"])


func test_the_furnace_recasts_a_stashed_part_a_rarity_up() -> void:
	var needs := StashRequirement.new()
	assert_bool(needs.check(_run)).is_false()
	# The laser is common: it becomes the uncommon gatling, the catalog's only uncommon.
	var gatling := Fixtures.gatling()
	gatling.rarity = MechPart.Rarity.UNCOMMON
	var acts: Array[ActData] = [Fixtures.act()]
	_run = RunState.new(Fixtures.armed_cross(), [gatling, Fixtures.laser(), Fixtures.heatsink()], [], 50, RunRng.new(1), acts)
	assert_bool(needs.check(_run)).is_false()
	_run.stash_part(Fixtures.laser())
	assert_bool(needs.check(_run)).is_true()
	var result := EventResult.new()
	ReforgeEffect.new().apply(_run, result)
	assert_array(_run.stash).has_size(1)
	assert_str(_run.stash[0].part.part_name).is_equal("Twin Gatling")
	assert_array(result.lines).contains_exactly(["Recast the Point-Defense Laser into a Twin Gatling"])
	# With nothing a rarity up in the catalog, one of the same rarity: the common heatsink becomes
	# the other common, the laser.
	_run.stash.clear()
	_run.stash_part(Fixtures.heatsink())
	_run.catalog.assign([Fixtures.laser(), Fixtures.heatsink()])
	ReforgeEffect.new().apply(_run, EventResult.new())
	assert_str(_run.stash[0].part.part_name).is_equal("Point-Defense Laser")


func test_a_sealed_crate_opens_after_three_wins_installed() -> void:
	var crate := _crate()
	var rare := Fixtures.part("Rare Gem", MechPart.PartType.UTILITY, [Vector2i(0, 0)], 7, {"rarity": MechPart.Rarity.RARE})
	var acts: Array[ActData] = [Fixtures.act()]
	var run := RunState.new(Fixtures.armed_cross(), [Fixtures.laser(), rare], [], 10, RunRng.new(1), acts)
	assert_bool(run.grid.place_part(crate, Vector2i(1, 1))).is_true()
	# A stashed crate doesn't count.
	var stashed := _crate()
	run.stash_part(stashed)
	for i in 2:
		run.record_fight(RunState.FightResult.WIN, run.make_player_mech())
	assert_object(run.grid.get_part_at(Vector2i(1, 1))).is_same(crate)
	assert_int(crate.crate_wins).is_equal(2)
	run.record_fight(RunState.FightResult.WIN, run.make_player_mech())
	assert_object(run.grid.get_part_at(Vector2i(1, 1))).is_null()
	assert_array(run.stash.map(func(entry: RunState.StashEntry) -> String: return entry.part.part_name)) \
		.contains_exactly_in_any_order(["Sealed Crate", "Rare Gem"])
	assert_int(run.stash[0].part.crate_wins).is_equal(0)
	# The next loot screen says so, once.
	var node: MapNode = run.get_reachable()[0]
	assert_array(run.roll_reward(node).notes).contains_exactly(["The Sealed Crate cracked open: a Rare Gem is in your stash."])
	assert_array(run.roll_reward(node).notes).is_empty()


func _crate() -> MechPart:
	var crate := Fixtures.part("Sealed Crate", MechPart.PartType.JUNK, [Vector2i(0, 0), Vector2i(1, 0)], 0, {"sellable": false})
	crate.opens_after_wins = 3
	crate.opens_into = MechPart.Rarity.RARE
	return crate
