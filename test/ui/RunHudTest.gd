class_name RunHudTest
extends GdUnitTestSuite

const __source: String = "res://src/ui/RunHud.gd"
const Fixtures := preload("res://test/TestFixtures.gd")

var _run: RunState
var _hud: RunHud


func before_test() -> void:
	var acts: Array[ActData] = [Fixtures.act(), Fixtures.act(), Fixtures.act()]
	_run = RunState.new(Fixtures.cross_chassis(), [], [], 20, RunRng.new(1), acts)
	_hud = auto_free(RunHud.new())
	_hud.run = _run
	add_child(_hud)


func test_shows_the_sector_hull_and_gold() -> void:
	assert_str(_hud.floor_label.text).is_equal("Sector 1 of 3")
	assert_str(_hud.sector_label.text).is_equal("Test Sector")
	assert_str(_hud.hp_label.text).is_equal("Hull 30 / 30 HP")
	assert_float(_hud.hp_bar.value).is_equal(30.0)
	assert_float(_hud.hp_bar.max_value).is_equal(30.0)
	assert_str(_hud.gold_label.text).is_equal("20 gold")


func test_follows_the_run_as_it_changes() -> void:
	assert_bool(_run.travel(_run.get_reachable()[0])).is_true()
	assert_str(_hud.floor_label.text).is_equal("Sector 1 of 3 · Floor 1")
	_run.damage_hull(12)
	assert_str(_hud.hp_label.text).is_equal("Hull 18 / 30 HP")
	assert_float(_hud.hp_bar.value).is_equal(18.0)
	assert_that((_hud.hp_bar.get_theme_stylebox("fill") as StyleBoxFlat).bg_color).is_equal(RunHud.HP_COLOR)
	# Below 30% the bar turns red.
	_run.damage_hull(10)
	assert_that((_hud.hp_bar.get_theme_stylebox("fill") as StyleBoxFlat).bg_color).is_equal(RunHud.LOW_HP_COLOR)
	_run.next_act()
	assert_str(_hud.floor_label.text).is_equal("Sector 2 of 3")


func test_shows_each_relic_with_a_tooltip() -> void:
	assert_int(_hud.relic_bar.get_child_count()).is_equal(0)
	var relic := Fixtures.relic("Lucky Bolt", Relic.Rarity.RARE)
	_run.add_relic(relic)
	var icons := _hud.relic_bar.get_children()
	assert_array(icons).has_size(1)
	var icon: RelicIcon = icons[0]
	assert_str(icon.relic.relic_name).is_equal("Lucky Bolt")
	assert_str(icon.tooltip_text).is_equal("Lucky Bolt (Rare)\nDoes nothing.")
	await await_idle_frame()


func test_statuses_show_with_their_fights_left() -> void:
	var storm := TimedStatus.new()
	storm.relic_name = "Radiation Storm"
	storm.description = "start fights hot."
	storm.fights = 2
	_run.add_status(storm)
	var icons := _hud.relic_bar.get_children()
	assert_array(icons).has_size(1)
	assert_str((icons[0] as RelicIcon).tooltip_text).is_equal("Radiation Storm (2 fights left)\nStart fights hot.")
	await await_idle_frame()


func test_a_run_without_sectors_shows_its_frame() -> void:
	var hud: RunHud = auto_free(RunHud.new())
	hud.run = RunState.new(Fixtures.bastion(), [], [])
	assert_str(hud.floor_label.text).is_equal("Run")
	assert_str(hud.sector_label.text).is_equal("The Bastion")


func test_kits_show_after_the_relics() -> void:
	_run.add_relic(Fixtures.relic("Lucky Bolt", Relic.Rarity.RARE))
	_run.add_kit(Fixtures.shield_cell())
	var icons := _hud.relic_bar.get_children()
	assert_array(icons).has_size(2)
	var icon: KitIcon = icons[1]
	assert_str(icon.tooltip_text).is_equal("Shield Cell (field kit)\nUse in a fight · 10 EN\nShield Cell")
	await await_idle_frame()
