class_name EventScreenTest
extends GdUnitTestSuite

const __source: String = "res://src/ui/EventScreen.gd"
const Fixtures := preload("res://test/TestFixtures.gd")

var _run: RunState
var _event: GameEvent


func before_test() -> void:
	_run = RunState.new(Fixtures.cross_chassis(), [], [], 10)
	var fight := FightEffect.new()
	fight.tier = EnemyLoadout.Tier.ELITE
	_event = Fixtures.event("The Deal", [
		Fixtures.choice("Take the gold", [Fixtures.outcome("Easy money.", [Fixtures.gold_effect(40)])]),
		Fixtures.choice("Buy repairs", [Fixtures.outcome("Patched.", [])], Fixtures.gold_requirement(30)),
		Fixtures.choice("Start a fight", [Fixtures.outcome("Here they come.", [fight])]),
	])


func test_shows_the_story_and_a_button_per_choice() -> void:
	var screen := _screen()
	assert_str(screen.title_label.text).is_equal("The Deal")
	assert_str(screen.body_label.text).is_equal("Something happens.")
	var options := screen.options.get_children()
	assert_array(options).has_size(3)
	assert_str((options[0] as Button).text).is_equal("Take the gold\nIt does something.")
	# A choice the run can't afford is off and says why.
	assert_bool((options[1] as Button).disabled).is_true()
	assert_str((options[1] as Button).text).is_equal("Buy repairs\nIt does something.  (Needs 30 gold)")
	assert_bool((options[0] as Button).disabled).is_false()
	# No way out but a choice.
	assert_bool(screen.button.visible).is_false()


func test_choosing_shows_what_happened() -> void:
	var screen := _screen()
	assert_bool(screen.choose(0)).is_true()
	assert_int(_run.gold).is_equal(50)
	assert_str(screen.body_label.text).is_equal("Easy money.\n+40 gold")
	assert_bool(screen.options.visible).is_false()
	assert_bool(screen.button.visible).is_true()
	assert_str(screen.button.text).is_equal("Continue")
	assert_int(screen.result.fight_tier).is_equal(-1)
	# One choice per event.
	assert_bool(screen.choose(2)).is_false()


func test_a_disabled_choice_does_nothing() -> void:
	var screen := _screen()
	assert_bool(screen.choose(1)).is_false()
	assert_object(screen.result).is_null()
	assert_bool(screen.options.visible).is_true()


func test_a_fight_outcome_says_so() -> void:
	var screen := _screen()
	assert_bool(screen.choose(2)).is_true()
	assert_str(screen.button.text).is_equal("Fight!")
	assert_int(screen.result.fight_tier).is_equal(EnemyLoadout.Tier.ELITE)


func test_a_choice_button_chooses() -> void:
	var screen := _screen()
	(screen.options.get_children()[0] as Button).pressed.emit()
	await await_idle_frame() # options are deferred
	assert_int(_run.gold).is_equal(50)


func _screen() -> EventScreen:
	var screen: EventScreen = auto_free(EventScreen.new(_run, _event))
	add_child(screen)
	return screen
