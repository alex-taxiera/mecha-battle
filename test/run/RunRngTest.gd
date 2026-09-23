class_name RunRngTest
extends GdUnitTestSuite

const __source: String = "res://src/run/RunRng.gd"


func test_a_stream_repeats_for_the_same_seed() -> void:
	var a := RunRng.new(42)
	var b := RunRng.new(42)
	assert_array(_rolls(a.stream("loot"), 10)).is_equal(_rolls(b.stream("loot"), 10))
	# The same stream comes back, carrying on where it was.
	assert_object(a.stream("loot")).is_same(a.stream("loot"))
	# Positive control: another seed rolls differently.
	assert_array(_rolls(RunRng.new(43).stream("loot"), 10)).is_not_equal(_rolls(RunRng.new(42).stream("loot"), 10))


func test_streams_with_different_names_roll_differently() -> void:
	# Slay-The-Robot seeded every stream with the run seed alone, so these would match.
	var rng := RunRng.new(42)
	assert_array(_rolls(rng.stream("map"), 10)).is_not_equal(_rolls(rng.stream("loot"), 10))


func test_rolling_one_stream_does_not_shift_another() -> void:
	var a := RunRng.new(7)
	var b := RunRng.new(7)
	_rolls(a.stream("shop"), 25)
	assert_array(_rolls(a.stream("map"), 10)).is_equal(_rolls(b.stream("map"), 10))


func test_state_restores_every_stream() -> void:
	var rng := RunRng.new(9)
	_rolls(rng.stream("map"), 3)
	_rolls(rng.stream("loot"), 5)
	var saved := rng.get_state()
	var expected_map := _rolls(rng.stream("map"), 5)
	var expected_loot := _rolls(rng.stream("loot"), 5)
	var restored := RunRng.new(9)
	restored.restore(saved)
	assert_array(_rolls(restored.stream("map"), 5)).is_equal(expected_map)
	assert_array(_rolls(restored.stream("loot"), 5)).is_equal(expected_loot)


func test_shuffle_keeps_every_item_once_and_repeats_with_the_seed() -> void:
	var items := range(20)
	var shuffled := RunRng.shuffle(_seeded(1), items.duplicate())
	assert_array(shuffled).has_size(20).contains_exactly_in_any_order(items)
	assert_array(shuffled).is_not_equal(items)
	assert_array(RunRng.shuffle(_seeded(1), items.duplicate())).is_equal(shuffled)
	# It shuffles in place, and handles the empty and single cases.
	var in_place := [1, 2, 3, 4, 5, 6]
	assert_object(RunRng.shuffle(_seeded(2), in_place)).is_same(in_place)
	assert_array(RunRng.shuffle(_seeded(3), [])).is_empty()
	assert_array(RunRng.shuffle(_seeded(3), ["only"])).is_equal(["only"])


func test_shuffle_makes_every_order_equally_likely() -> void:
	# 6000 shuffles of three items: each of the 6 orders about 1000 times. Slay-The-Robot's
	# swap-with-any-index shuffle comes out near 890 / 1110 / 1000 and fails this.
	var rng := _seeded(5)
	var counts := {}
	for i in 6000:
		var order := str(RunRng.shuffle(rng, [0, 1, 2]))
		counts[order] = counts.get(order, 0) + 1
	assert_int(counts.size()).is_equal(6)
	for order: String in counts:
		assert_int(counts[order]).append_failure_message(order).is_between(900, 1100)


func test_shuffle_slice() -> void:
	var picked := RunRng.shuffle_slice(_seeded(4), range(10), 3)
	assert_array(picked).has_size(3)
	for item: int in picked:
		assert_bool(item in range(10)).is_true()
	# Asking for more than there are gives them all; a negative count too.
	assert_array(RunRng.shuffle_slice(_seeded(4), [1, 2], 5)).has_size(2)
	assert_array(RunRng.shuffle_slice(_seeded(4), [1, 2, 3], -1)).has_size(3)
	assert_array(RunRng.shuffle_slice(_seeded(4), [1, 2, 3], 0)).is_empty()


func test_weighted_pick_follows_the_weights() -> void:
	var rng := _seeded(11)
	var counts := {"a": 0, "b": 0, "never": 0}
	for i in 10000:
		counts[RunRng.weighted_pick(rng, {"a": 1, "b": 3, "never": 0})] += 1
	# 1 : 3, so about 2500 and 7500.
	assert_int(counts["a"]).is_between(2300, 2700)
	assert_int(counts["b"]).is_between(7300, 7700)
	assert_int(counts["never"]).is_equal(0)


func test_weighted_pick_with_nothing_to_pick() -> void:
	assert_object(RunRng.weighted_pick(_seeded(1), {})).is_null()
	assert_object(RunRng.weighted_pick(_seeded(1), {"a": 0, "b": -3})).is_null()
	# Positive control: one live weight is always the pick.
	assert_str(RunRng.weighted_pick(_seeded(1), {"a": 0, "b": 2})).is_equal("b")


func _rolls(rng: RandomNumberGenerator, count: int) -> Array[int]:
	var rolls: Array[int] = []
	for i in count:
		rolls.append(rng.randi())
	return rolls


func _seeded(rng_seed: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	return rng
