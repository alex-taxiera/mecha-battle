class_name EventPoolTest
extends GdUnitTestSuite

const __source: String = "res://src/run/EventPool.gd"
const Fixtures := preload("res://test/TestFixtures.gd")

var _run: RunState


func before_test() -> void:
	_run = RunState.new(Fixtures.armed_cross(), [], [], 10)


func test_hands_out_each_event_once_before_refilling() -> void:
	var events: Array[GameEvent] = [Fixtures.gold_event("A"), Fixtures.gold_event("B"), Fixtures.gold_event("C")]
	var pool := EventPool.new(events, _seeded(1))
	var first_round := {}
	for i in 3:
		first_round[pool.next(_run)] = true
	assert_int(first_round.size()).is_equal(3)
	# Then it refills and they come around again.
	assert_bool(pool.next(_run) in events).is_true()
	assert_array(pool.get_queue()).has_size(2)


func test_the_same_seed_gives_the_same_order() -> void:
	var events: Array[GameEvent] = [Fixtures.gold_event("A"), Fixtures.gold_event("B"), Fixtures.gold_event("C"), Fixtures.gold_event("D")]
	var a := EventPool.new(events, _seeded(7))
	var b := EventPool.new(events, _seeded(7))
	for i in 4:
		assert_object(a.next(_run)).is_same(b.next(_run))


func test_the_fallback_is_kept_aside_for_when_nothing_can_happen() -> void:
	var rich_only := Fixtures.event("Rich", [], Fixtures.gold_requirement(100))
	var fallback := Fixtures.event("Fallback", [], null, GameEvent.FailedStrategy.KEEP, true)
	var pool := EventPool.new([rich_only, fallback], _seeded(1))
	assert_object(pool.fallback).is_same(fallback)
	assert_object(pool.next(_run)).is_same(fallback) # 10 gold isn't enough
	# Positive control: with the gold, the real event comes up, and the fallback never does
	# while it can.
	_run.gold = 100
	assert_object(pool.next(_run)).is_same(rich_only)
	# Without a fallback there's nothing.
	assert_object(EventPool.new([], _seeded(1)).next(_run)).is_null()


func test_failed_events_follow_their_strategy() -> void:
	var needs_gold := Fixtures.gold_requirement(100)
	var kept := Fixtures.event("Kept", [], needs_gold, GameEvent.FailedStrategy.KEEP)
	var removed := Fixtures.event("Removed", [], needs_gold, GameEvent.FailedStrategy.REMOVE)
	var appended := Fixtures.event("Appended", [], needs_gold, GameEvent.FailedStrategy.APPEND)
	var reinserted := Fixtures.event("Reinserted", [], needs_gold, GameEvent.FailedStrategy.REINSERT)
	var fallback := Fixtures.event("Fallback", [], null, GameEvent.FailedStrategy.KEEP, true)
	var pool := EventPool.new([kept, removed, appended, reinserted, fallback], _seeded(3))
	# With 10 gold every event fails, so each strategy runs.
	assert_object(pool.next(_run)).is_same(fallback)
	var queue := pool.get_queue()
	# REMOVE drops it for the run; the others stay for later.
	assert_bool(removed in queue).is_false()
	assert_array(queue).has_size(3).contains_same_exactly_in_any_order([kept, appended, reinserted])
	# Once the gold is there, the removed one never comes back, even after a refill.
	_run.gold = 100
	var seen := {}
	for i in 8:
		seen[pool.next(_run)] = true
	assert_bool(seen.has(removed)).is_false()
	assert_bool(seen.has(kept) and seen.has(appended) and seen.has(reinserted)).is_true()


func test_append_sends_a_failed_event_to_the_back() -> void:
	var needs_gold := Fixtures.gold_requirement(100)
	for pool_seed in 6:
		var appended := Fixtures.event("Appended", [], needs_gold, GameEvent.FailedStrategy.APPEND)
		var kept := Fixtures.event("Kept", [], needs_gold, GameEvent.FailedStrategy.KEEP)
		var pool := EventPool.new([appended, kept], _seeded(pool_seed))
		assert_object(pool.next(_run)).is_null()
		assert_array(pool.get_queue()).append_failure_message("seed %d" % pool_seed).contains_same_exactly([kept, appended])


func _seeded(rng_seed: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	return rng
