class_name PartInfoTest
extends GdUnitTestSuite

const __source: String = "res://src/ui/PartInfo.gd"
const Fixtures := preload("res://test/TestFixtures.gd")


func test_lists_everything_about_a_part() -> void:
	var gatling := Fixtures.gatling()
	gatling.description = "8 dmg, draws 3 EN. Heatsink touching: ×1.5. Each reactor touching: +3."
	var numbers := MechStats.PartStats.new()
	numbers.damage = 17
	numbers.energy_draw = 3
	numbers.bonuses[Fixtures.overcharge()] = 3.0
	numbers.bonuses[Fixtures.cooled()] = 1.5
	var info: PartInfo = auto_free(PartInfo.new(gatling, 0, numbers))
	assert_array(info.get_rows()).contains_exactly([
		"Twin Gatling",
		"Weapon · 1×3",
		"17 DMG · -3 EN",
		"Overcharge +3 · Cooled ×1.5",
		"8 dmg, draws 3 EN. Heatsink touching: ×1.5. Each reactor touching: +3.",
	])
	assert_str(PartInfo.text_for(gatling, 0, numbers)).is_equal("\n".join(info.get_rows()))


func test_skips_rows_a_part_has_nothing_for() -> void:
	# No links and no blurb: just the name, summary, and numbers.
	var numbers := MechStats.PartStats.new()
	numbers.hp = 12
	var info: PartInfo = auto_free(PartInfo.new(Fixtures.laser(), 0, numbers))
	assert_array(info.get_rows()).contains_exactly(["Point-Defense Laser", "Defense · 1 block", "+12 HP"])


func test_summary_names_the_type_and_size() -> void:
	assert_str(PartInfo.summary(Fixtures.gatling(), 0)).is_equal("Weapon · 1×3")
	assert_str(PartInfo.summary(Fixtures.reactor(), 0)).is_equal("Generator · 2×1")
	assert_str(PartInfo.summary(Fixtures.reactor(), 1)).is_equal("Generator · 1×2")
	assert_str(PartInfo.summary(Fixtures.laser(), 0)).is_equal("Defense · 1 block")
	assert_str(PartInfo.summary(Fixtures.heatsink(), 0)).is_equal("Utility · 3 blocks")


func test_part_numbers_read_as_short_lines() -> void:
	var weapon := MechStats.PartStats.new()
	weapon.damage = 17
	weapon.energy_draw = 3
	weapon.bonuses[Fixtures.overcharge()] = 3.0
	weapon.bonuses[Fixtures.cooled()] = 1.5
	assert_str(PartInfo.stat_line(weapon)).is_equal("17 DMG · -3 EN")
	assert_str(PartInfo.bonus_line(weapon)).is_equal("Overcharge +3 · Cooled ×1.5")
	var generator := MechStats.PartStats.new()
	generator.energy = 6
	generator.hp = 5
	assert_str(PartInfo.stat_line(generator)).is_equal("+6 EN · +5 HP")
	# Heat a weapon makes goes up; heat a heatsink vents goes down.
	weapon.heat = 20
	assert_str(PartInfo.stat_line(weapon)).is_equal("17 DMG · -3 EN · +20 HEAT")
	var sink := MechStats.PartStats.new()
	sink.cooling = 10
	assert_str(PartInfo.stat_line(sink)).is_equal("-10 HEAT")
	var utility := MechStats.PartStats.new()
	assert_str(PartInfo.stat_line(utility)).is_equal("Not linked")
	assert_str(PartInfo.bonus_line(utility)).is_empty()
	utility.links = 2
	assert_str(PartInfo.stat_line(utility)).is_equal("Links: 2")
