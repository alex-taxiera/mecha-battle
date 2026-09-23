class_name RewardRollerTest
extends GdUnitTestSuite

const __source: String = "res://src/run/RewardRoller.gd"
const Fixtures := preload("res://test/TestFixtures.gd")

var _common_a: MechPart
var _common_b: MechPart
var _uncommon: MechPart
var _rare: MechPart
var _catalog: Array[MechPart] = []


func before_test() -> void:
	_common_a = _part("Common A", MechPart.Rarity.COMMON)
	_common_b = _part("Common B", MechPart.Rarity.COMMON)
	_uncommon = _part("Uncommon", MechPart.Rarity.UNCOMMON)
	_rare = _part("Rare", MechPart.Rarity.RARE)
	_catalog = [_common_a, _common_b, _uncommon, _rare]


func test_tables_follow_the_enemy_tier() -> void:
	assert_int(RewardRoller.table_for(EnemyLoadout.Tier.NORMAL)).is_equal(RewardRoller.Table.STANDARD)
	assert_int(RewardRoller.table_for(EnemyLoadout.Tier.ELITE)).is_equal(RewardRoller.Table.ELITE)
	assert_int(RewardRoller.table_for(EnemyLoadout.Tier.BOSS)).is_equal(RewardRoller.Table.BOSS)
	# Slay-The-Robot's odds: 55 / 43 / 2 for a standard draft.
	assert_that(RewardRoller.RARITY_WEIGHTS[RewardRoller.Table.STANDARD]).is_equal(
		{MechPart.Rarity.COMMON: 55, MechPart.Rarity.UNCOMMON: 43, MechPart.Rarity.RARE: 2})


func test_a_draft_offers_three_different_parts() -> void:
	for draft_seed in 30:
		var drafted := RewardRoller.new().draft_parts(_seeded(draft_seed), _catalog, RewardRoller.Table.STANDARD)
		assert_array(drafted).append_failure_message("seed %d" % draft_seed).has_size(3)
		var unique := {}
		for part in drafted:
			unique[part] = true
			assert_bool(part in _catalog).is_true()
		assert_int(unique.size()).append_failure_message("seed %d repeats a part" % draft_seed).is_equal(3)


func test_a_small_catalog_gives_a_short_draft() -> void:
	var small: Array[MechPart] = [_common_a, _rare]
	assert_array(RewardRoller.new().draft_parts(_seeded(1), small, RewardRoller.Table.STANDARD)).has_size(2)
	assert_array(RewardRoller.new().draft_parts(_seeded(1), [], RewardRoller.Table.STANDARD)).is_empty()


func test_a_boss_draft_is_rare_when_it_can_be() -> void:
	var extra_rare := _part("Rare B", MechPart.Rarity.RARE)
	_catalog.append(extra_rare)
	var drafted := RewardRoller.new().draft_parts(_seeded(3), _catalog, RewardRoller.Table.BOSS)
	# Two rares, then the nearest rarity below fills the last slot (Slay-The-Robot would stop short).
	assert_array(drafted).has_size(3)
	assert_array(drafted.slice(0, 2)).contains_same_exactly_in_any_order([_rare, extra_rare])
	assert_object(drafted[2]).is_same(_uncommon)


func test_rarities_follow_the_odds() -> void:
	# Many parts of each rarity, so no bucket runs dry: 3000 slots come out near 55 / 43 / 2.
	var big: Array[MechPart] = []
	for i in 40:
		big.append(_part("C%d" % i, MechPart.Rarity.COMMON))
		big.append(_part("U%d" % i, MechPart.Rarity.UNCOMMON))
		big.append(_part("R%d" % i, MechPart.Rarity.RARE))
	var counts := {MechPart.Rarity.COMMON: 0, MechPart.Rarity.UNCOMMON: 0, MechPart.Rarity.RARE: 0}
	var rng := _seeded(9)
	for i in 1000:
		var roller := RewardRoller.new() # no pity, so every draft uses the plain odds
		for part in roller.draft_parts(rng, big, RewardRoller.Table.STANDARD):
			counts[part.rarity] += 1
	assert_int(counts[MechPart.Rarity.COMMON]).is_between(1500, 1800)
	assert_int(counts[MechPart.Rarity.UNCOMMON]).is_between(1150, 1450)
	assert_int(counts[MechPart.Rarity.RARE]).is_between(20, 110)


func test_commons_build_pity_and_a_rare_resets_it() -> void:
	var roller := RewardRoller.new()
	var only_commons: Array[MechPart] = [_common_a, _common_b]
	roller.draft_parts(_seeded(1), only_commons, RewardRoller.Table.STANDARD)
	assert_float(roller.rare_pity).is_equal(3.0) # 1.5 for each common offered
	# Uncommons leave it alone.
	var only_uncommon: Array[MechPart] = [_uncommon]
	roller.draft_parts(_seeded(1), only_uncommon, RewardRoller.Table.STANDARD)
	assert_float(roller.rare_pity).is_equal(3.0)
	var only_rare: Array[MechPart] = [_rare]
	roller.draft_parts(_seeded(1), only_rare, RewardRoller.Table.STANDARD)
	assert_float(roller.rare_pity).is_equal(0.0)


func test_pity_makes_rares_likelier() -> void:
	var rares_with := 0
	var rares_without := 0
	var rng := _seeded(4)
	for i in 400:
		var pitied := RewardRoller.new()
		pitied.rare_pity = 40.0 # common 15, rare 42
		if _rare in pitied.draft_parts(rng, _catalog, RewardRoller.Table.STANDARD, 1):
			rares_with += 1
		if _rare in RewardRoller.new().draft_parts(rng, _catalog, RewardRoller.Table.STANDARD, 1):
			rares_without += 1
	assert_int(rares_with).is_greater(100)
	assert_int(rares_without).is_less(30)


func test_pity_never_takes_more_than_the_commons_weight() -> void:
	var roller := RewardRoller.new()
	roller.rare_pity = 500.0
	# Common can't go below 0: every slot is rare or uncommon, never an error.
	var drafted := roller.draft_parts(_seeded(2), _catalog, RewardRoller.Table.STANDARD, 2)
	for part in drafted:
		assert_int(part.rarity).is_not_equal(MechPart.Rarity.COMMON)


func test_gold_rolls_within_its_range() -> void:
	var rng := _seeded(6)
	var seen := {}
	for i in 200:
		var gold := RewardRoller.roll_gold(rng, Vector2i(8, 12))
		assert_int(gold).is_between(8, 12)
		seen[gold] = true
	assert_int(seen.size()).is_equal(5)
	assert_int(RewardRoller.roll_gold(rng, Vector2i(5, 5))).is_equal(5)


func test_the_same_seed_drafts_the_same_parts() -> void:
	var a := RewardRoller.new().draft_parts(_seeded(12), _catalog, RewardRoller.Table.ELITE)
	var b := RewardRoller.new().draft_parts(_seeded(12), _catalog, RewardRoller.Table.ELITE)
	assert_array(a).contains_same_exactly(b)


func _part(part_name: String, rarity: MechPart.Rarity) -> MechPart:
	var part := Fixtures.laser()
	part.part_name = part_name
	part.rarity = rarity
	return part


func _seeded(rng_seed: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	return rng
