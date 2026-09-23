class_name MessageScreenTest
extends GdUnitTestSuite

const __source: String = "res://src/ui/MessageScreen.gd"
const Fixtures := preload("res://test/TestFixtures.gd")


func test_shows_its_message_and_the_button_confirms() -> void:
	var screen: MessageScreen = auto_free(MessageScreen.new("SECTOR CLEARED", Color.GREEN, PackedStringArray(["One", "Two"]), "Onward"))
	add_child(screen)
	assert_str(screen.title_label.text).is_equal("SECTOR CLEARED")
	assert_that(screen.title_label.get_theme_color("font_color")).is_equal(Color.GREEN)
	assert_str(screen.body_label.text).is_equal("One\nTwo")
	assert_str(screen.button.text).is_equal("Onward")
	# Without a run there's no HUD.
	assert_bool(screen.hud.visible).is_false()
	var presses := [0]
	screen.confirmed.connect(func() -> void: presses[0] += 1)
	screen.button.pressed.emit()
	assert_int(presses[0]).is_equal(1)


func test_shows_the_runs_hud_when_given_one() -> void:
	var run := RunState.new(Fixtures.cross_chassis(), [], [], 15)
	var screen: MessageScreen = auto_free(MessageScreen.new("Hangar", Color.WHITE, PackedStringArray(), "Continue", run))
	add_child(screen)
	assert_bool(screen.hud.visible).is_true()
	assert_str(screen.hud.gold_label.text).is_equal("15 gold")
