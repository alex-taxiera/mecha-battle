class_name StatsPanelTest
extends GdUnitTestSuite

const __source: String = "res://src/ui/StatsPanel.gd"
const Fixtures := preload("res://test/TestFixtures.gd")
# The armed cross's arms. Only (0, 1) and (0, 2) touch the left one.
const LEFT_ARM := Vector2i(-1, 1)
const RIGHT_ARM := Vector2i(4, 1)

var _panel: StatsPanel
var _chassis: MechChassis
var _rules: Array[SynergyRule] = []


func before_test() -> void:
	_panel = auto_free(StatsPanel.new())
	add_child(_panel)
	_chassis = Fixtures.armed_cross()
	_rules = Fixtures.rules()


func test_shows_totals_and_notes() -> void:
	var grid := _grid_with([[Fixtures.gatling(), LEFT_ARM]])
	_panel.show_stats(MechStats.calculate(grid, _rules), null)
	assert_str(_panel.hp.value.text).is_equal("30")
	assert_str(_panel.hp.note.text).is_equal("30 from chassis")
	assert_str(_panel.energy.value.text).is_equal("0")
	assert_str(_panel.energy.note.text).is_equal("3 generated · 3 drawn")
	assert_str(_panel.damage.value.text).is_equal("8")
	assert_str(_panel.damage.note.text).is_equal("Fully powered")
	for box: StatsPanel.StatBox in [_panel.hp, _panel.energy, _panel.damage, _panel.heat]:
		assert_bool(box.delta.visible).is_false()


func test_the_heat_box_warns_when_heat_outruns_cooling() -> void:
	var gatling := Fixtures.gatling() # 8 damage for 3 energy, once a turn
	gatling.heat = 20
	var heatsink := Fixtures.heatsink()
	heatsink.cooling = 15
	var grid := _grid_with([[gatling, LEFT_ARM]])
	_panel.show_stats(MechStats.calculate(grid, _rules), null)
	assert_str(_panel.heat.value.text).is_equal("+20")
	assert_str(_panel.heat.note.text).is_equal("20 made · 0 vented")
	assert_that(_panel.heat.value.get_theme_color("font_color")).is_equal(StatsPanel.DOWN_COLOR)
	# A heatsink dropping in would cool it: shown as a fall, in green.
	var cooled := grid.copy()
	assert_bool(cooled.place_part(heatsink, Vector2i(2, 1))).is_true()
	_panel.show_stats(MechStats.calculate(grid, _rules), MechStats.calculate(cooled, _rules))
	assert_bool(_panel.heat.delta.visible).is_true()
	assert_str(_panel.heat.delta.text).is_equal("-15")
	assert_that(_panel.heat.delta.get_theme_color("font_color")).is_equal(StatsPanel.UP_COLOR)
	# Once it's in, heat no longer outruns cooling.
	_panel.show_stats(MechStats.calculate(cooled, _rules), null)
	assert_str(_panel.heat.value.text).is_equal("+5")
	var cooler := cooled.copy()
	var second := Fixtures.heatsink()
	second.cooling = 15
	assert_bool(cooler.place_part(second, Vector2i(1, 2))).is_true()
	_panel.show_stats(MechStats.calculate(cooler, _rules), null)
	assert_str(_panel.heat.value.text).is_equal("-10")
	assert_that(_panel.heat.value.get_theme_color("font_color")).is_equal(StatsPanel.TEXT_COLOR)
	await await_idle_frame() # free the link rows each new set of stats replaced


func test_shows_what_a_preview_would_change() -> void:
	var current := MechStats.calculate(_grid_with([]), _rules)
	var preview := MechStats.calculate(_grid_with([[Fixtures.gatling(), LEFT_ARM]]), _rules)
	_panel.show_stats(current, preview)
	assert_bool(_panel.damage.delta.visible).is_true()
	assert_str(_panel.damage.delta.text).is_equal("+8")
	assert_bool(_panel.energy.delta.visible).is_true()
	assert_str(_panel.energy.delta.text).is_equal("-3")
	assert_bool(_panel.hp.delta.visible).is_false() # a gatling adds no HP
	assert_str(_panel.damage.value.text).is_equal("0") # the totals stay current


func test_the_hp_note_shows_the_chassis_hp() -> void:
	_panel.show_stats(MechStats.calculate(_grid_with([[Fixtures.laser(), Vector2i(1, 1)]]), _rules), null)
	assert_str(_panel.hp.value.text).is_equal("42")
	assert_str(_panel.hp.note.text).is_equal("30 from chassis")


func test_power_notes() -> void:
	_panel.show_stats(MechStats.calculate(_grid_with([]), _rules), null)
	assert_str(_panel.damage.note.text).is_equal("No weapons mounted")
	# Two gatlings draw 6 energy against 3.
	var grid := _grid_with([[Fixtures.gatling(), LEFT_ARM], [Fixtures.gatling(), RIGHT_ARM]])
	_panel.show_stats(MechStats.calculate(grid, _rules), null)
	assert_str(_panel.damage.note.text).is_equal("Underpowered · 50% fire rate")
	assert_str(_panel.energy.value.text).is_equal("-3")
	await await_idle_frame() # free the link rows the second call replaced


func test_lists_rules_and_active_links() -> void:
	_panel.show_rules(_rules)
	assert_array(_panel.get_rule_rows()).contains_exactly(
		"Heatsink + Weapon weapon dmg ×1.5", "Reactor + Weapon +3 weapon dmg",
		"Heatsink + Reactor +2 energy", "Laser + Laser +4 HP each")
	_panel.show_stats(MechStats.calculate(_grid_with([]), _rules), null)
	assert_array(_panel.get_link_rows()).contains_exactly(StatsPanel.NO_LINKS_TEXT)
	# A heatsink touching a gatling's bay: one Cooled link.
	var grid := _grid_with([[Fixtures.gatling(), LEFT_ARM], [Fixtures.heatsink(), Vector2i(0, 1)]])
	_panel.show_stats(MechStats.calculate(grid, _rules), null)
	assert_array(_panel.get_link_rows()).contains_exactly("Heatsink + Weapon → weapon dmg ×1.5 ×1")
	await await_idle_frame() # free the rows the lists replaced


# An armed-cross grid with each [part, origin] placed.
func _grid_with(placements: Array) -> MechGridData:
	var grid := MechGridData.new(_chassis)
	for entry in placements:
		assert_bool(grid.place_part(entry[0], entry[1])).is_true()
	return grid
