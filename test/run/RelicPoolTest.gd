class_name RelicPoolTest
extends GdUnitTestSuite

const __source: String = "res://src/run/RelicPool.gd"
const Fixtures := preload("res://test/TestFixtures.gd")

var _relics: Array[Relic] = []


func before_test() -> void:
	_relics = Fixtures.relics()


func test_holds_every_relic_once_in_a_seeded_order() -> void:
	var pool := RelicPool.new(_relics, _seeded(1))
	assert_int(pool.size()).is_equal(_relics.size())
	for relic in _relics:
		assert_bool(pool.has(relic)).is_true()
	var again := RelicPool.new(_relics, _seeded(1))
	assert_array(_names(pool.take(99, RelicPool.STANDARD))).is_equal(_names(again.take(99, RelicPool.STANDARD)))


func test_take_pops_matching_relics_without_repeats() -> void:
	var pool := RelicPool.new(_relics, _seeded(2))
	var bosses := pool.take(3, [Relic.Rarity.BOSS])
	# The fixtures have two boss relics: both come out, and nothing else.
	assert_array(bosses).has_size(2)
	for relic in bosses:
		assert_int(relic.rarity).is_equal(Relic.Rarity.BOSS)
		assert_bool(pool.has(relic)).is_false()
	assert_array(pool.take(3, [Relic.Rarity.BOSS])).is_empty()
	assert_int(pool.size()).is_equal(_relics.size() - 2)


func test_shops_take_from_the_back() -> void:
	var front := RelicPool.new(_relics, _seeded(3))
	var back := RelicPool.new(_relics, _seeded(3))
	var from_front := front.take(1, RelicPool.STANDARD)
	var from_back := back.take(1, RelicPool.STANDARD, true)
	assert_object(from_front[0]).is_not_same(from_back[0])
	# The back one is the last standard relic of the front pool's order.
	var rest := front.take(99, RelicPool.STANDARD)
	assert_object(rest[-1]).is_same(from_back[0])


func test_roll_follows_the_weights_and_falls_back() -> void:
	var pool := RelicPool.new(_relics, _seeded(4))
	# Only rares weighted: the fixtures' one rare comes first.
	var rare := pool.roll(_seeded(1), {Relic.Rarity.RARE: 1})
	assert_int(rare.rarity).is_equal(Relic.Rarity.RARE)
	# With no rares left, the roll falls back to a common, then an uncommon.
	assert_int(pool.roll(_seeded(1), {Relic.Rarity.RARE: 1}).rarity).is_equal(Relic.Rarity.COMMON)
	# Boss relics never come from a roll.
	var rolled := {}
	while pool.size() > 2:
		var relic := pool.roll(_seeded(pool.size()), RelicPool.ELITE_WEIGHTS)
		if relic == null:
			break
		rolled[relic.rarity] = true
	assert_bool(rolled.has(Relic.Rarity.BOSS)).is_false()
	assert_object(pool.roll(_seeded(1), RelicPool.ELITE_WEIGHTS)).is_null()


func test_remove_takes_a_relic_out() -> void:
	var pool := RelicPool.new(_relics, _seeded(5))
	pool.remove(_relics[0])
	assert_bool(pool.has(_relics[0])).is_false()
	assert_int(pool.size()).is_equal(_relics.size() - 1)


func _names(relics: Array[Relic]) -> Array:
	return relics.map(func(relic: Relic) -> String: return relic.relic_name)


func _seeded(rng_seed: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	return rng
