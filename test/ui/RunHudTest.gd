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


func test_a_run_without_sectors_shows_its_frame() -> void:
	var hud: RunHud = auto_free(RunHud.new())
	hud.run = RunState.new(Fixtures.bastion(), [], [])
	assert_str(hud.floor_label.text).is_equal("Run")
	assert_str(hud.sector_label.text).is_equal("The Bastion")
