class_name TechnicianScreenTest
extends GdUnitTestSuite

const __source: String = "res://src/ui/TechnicianScreen.gd"
const Fixtures := preload("res://test/TestFixtures.gd")

var _run: RunState
var _screen: TechnicianScreen


func before_test() -> void:
	_run = RunState.new(Fixtures.cross_chassis(), [], [], 20)
	var gold := TechnicianOffer.Boon.new()
	gold.text = "Gain 30 gold"
	gold.effects = [Fixtures.gold_effect(30)]
	var plating := TechnicianOffer.Boon.new()
	plating.text = "Gain 40 max HP, but lose all your gold"
	var more_hp := MaxHpEffect.new()
	more_hp.hp = 40
	plating.effects = [Fixtures.gold_effect(-9999), more_hp]
	_screen = auto_free(TechnicianScreen.new(_run, [gold, plating]))
	add_child(_screen)


func test_offers_a_button_per_boon() -> void:
	assert_str(_screen.title_label.text).is_equal("MECH TECHNICIAN")
	var labels := _screen.options.get_children().map(func(option: Button) -> String: return option.text)
	assert_array(labels).contains_exactly(["Gain 30 gold", "Gain 40 max HP, but lose all your gold"])
	# A boon has to be picked before heading out.
	assert_bool(_screen.button.visible).is_false()


func test_picking_a_boon_applies_it_once() -> void:
	assert_bool(_screen.choose(1)).is_true()
	assert_int(_run.gold).is_equal(0)
	assert_int(_run.get_max_hp()).is_equal(70)
	assert_str(_screen.body_label.text).is_equal("Gain 40 max HP, but lose all your gold.\n-20 gold\n+40 max HP")
	assert_bool(_screen.button.visible).is_true()
	assert_str(_screen.button.text).is_equal("Head out")
	assert_bool(_screen.choose(0)).is_false()
	assert_int(_run.gold).is_equal(0)


func test_a_button_picks_its_boon() -> void:
	(_screen.options.get_children()[0] as Button).pressed.emit()
	await await_idle_frame() # options are deferred
	assert_int(_run.gold).is_equal(50)
