class_name ResultPanelTest
extends GdUnitTestSuite

const __source: String = "res://src/ui/combat/ResultPanel.gd"


func test_starts_hidden_and_shows_a_result() -> void:
	var panel: ResultPanel = auto_free(ResultPanel.new())
	add_child(panel)
	assert_bool(panel.visible).is_false()
	panel.present("VICTORY", CombatColors.HP, "SECTOR 1 · FLOOR 3 · WINS 3",
		[["Battle duration", "16.5s"], ["MVP weapon", "Missile Pod · 254 DMG"]])
	assert_bool(panel.visible).is_true()
	assert_str(panel.title_label.text).is_equal("VICTORY")
	assert_that(panel.title_label.get_theme_color("font_color")).is_equal(CombatColors.HP)
	assert_str(panel.record_label.text).is_equal("SECTOR 1 · FLOOR 3 · WINS 3")
	assert_array(panel.get_rows()).is_equal([["Battle duration", "16.5s"], ["MVP weapon", "Missile Pod · 254 DMG"]])
	# Showing another result replaces the rows.
	panel.present("DEFEAT", CombatColors.DANGER, "", [["Battle duration", "4.0s"]])
	assert_array(panel.get_rows()).is_equal([["Battle duration", "4.0s"]])
	await await_idle_frame() # free the replaced rows


func test_the_button_asks_to_return() -> void:
	var panel: ResultPanel = auto_free(ResultPanel.new())
	var presses := []
	panel.return_pressed.connect(func() -> void: presses.append(true))
	panel.return_button.pressed.emit()
	assert_array(presses).has_size(1)
	assert_str(panel.return_button.text).is_equal("RETURN TO SHOP")
