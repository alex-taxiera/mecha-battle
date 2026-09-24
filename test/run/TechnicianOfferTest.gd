class_name TechnicianOfferTest
extends GdUnitTestSuite

const __source: String = "res://src/run/TechnicianOffer.gd"
const Fixtures := preload("res://test/TestFixtures.gd")

var _options: Array[RunStartOption] = []


func before_test() -> void:
	var up := RunStartOption.Kind.UPSIDE
	var down := RunStartOption.Kind.DOWNSIDE
	var whole := RunStartOption.Kind.COMPLETE
	_options = [
		Fixtures.start_option("gain_a", up), Fixtures.start_option("gain_b", up), Fixtures.start_option("gain_c", up),
		Fixtures.start_option("lose_a", down), Fixtures.start_option("lose_b", down), Fixtures.start_option("lose_c", down),
		Fixtures.start_option("whole_a", whole), Fixtures.start_option("whole_b", whole),
	]


func test_offers_two_pairs_and_a_whole_boon() -> void:
	var boons := TechnicianOffer.roll(_options, _seeded(1))
	assert_array(boons).has_size(3)
	# Pairs read "Upside, but downside"; the whole one stands alone.
	for boon in boons.slice(0, 2):
		assert_bool(boon.text.begins_with("Gain ")).is_true()
		assert_bool(", but lose " in boon.text).is_true()
	assert_bool(boons[2].text.begins_with("Whole ")).is_true()


func test_no_option_is_used_twice() -> void:
	for offer_seed in 20:
		var texts := TechnicianOffer.roll(_options, _seeded(offer_seed)).map(func(boon: TechnicianOffer.Boon) -> String: return boon.text)
		var used := {}
		for text: String in texts:
			for part in text.to_lower().split(", but "):
				assert_bool(used.has(part)).append_failure_message("seed %d: %s twice" % [offer_seed, part]).is_false()
				used[part] = true


func test_the_same_seed_offers_the_same_boons() -> void:
	var a := TechnicianOffer.roll(_options, _seeded(7)).map(func(boon: TechnicianOffer.Boon) -> String: return boon.text)
	var b := TechnicianOffer.roll(_options, _seeded(7)).map(func(boon: TechnicianOffer.Boon) -> String: return boon.text)
	assert_array(a).is_equal(b)


func test_every_whole_option_can_come_up() -> void:
	# Slay-The-Robot never shuffled its complete options, so the same one always showed.
	var seen := {}
	for offer_seed in 30:
		seen[TechnicianOffer.roll(_options, _seeded(offer_seed))[2].text] = true
	assert_array(seen.keys()).contains_exactly_in_any_order(["Whole a", "Whole b"])


func test_short_on_options_offers_fewer() -> void:
	var few: Array[RunStartOption] = [Fixtures.start_option("gain_a", RunStartOption.Kind.UPSIDE)]
	assert_array(TechnicianOffer.roll(few, _seeded(1))).is_empty() # an upside needs a downside
	assert_array(TechnicianOffer.roll([], _seeded(1))).is_empty()


func test_a_downside_applies_before_its_upside() -> void:
	var run := RunState.new(Fixtures.cross_chassis(), [], [], 20)
	var options: Array[RunStartOption] = [
		Fixtures.start_option("windfall", RunStartOption.Kind.UPSIDE, [Fixtures.gold_effect(75)]),
		Fixtures.start_option("empty_pockets", RunStartOption.Kind.DOWNSIDE, [Fixtures.gold_effect(-9999)]),
	]
	var boon: TechnicianOffer.Boon = TechnicianOffer.roll(options, _seeded(1))[0]
	var result := TechnicianOffer.apply(boon, run)
	# Losing all 20 first, then gaining 75.
	assert_int(run.gold).is_equal(75)
	assert_array(result.lines).contains_exactly(["-20 gold", "+75 gold"])


func _seeded(rng_seed: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	return rng
