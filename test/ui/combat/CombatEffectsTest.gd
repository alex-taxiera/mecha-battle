class_name CombatEffectsTest
extends GdUnitTestSuite

const __source: String = "res://src/ui/combat/CombatEffects.gd"


func test_a_shot_flies_lands_and_frees_itself() -> void:
	var effects: CombatEffects = auto_free(CombatEffects.new())
	add_child(effects)
	var landed := []
	var texture := ImageTexture.create_from_image(Image.create(18, 7, false, Image.FORMAT_RGBA8))
	var shot := effects.shoot(texture, Vector2(100, 200), Vector2(500, 220), Color.ORANGE, true, 0.1,
		func() -> void: landed.append(true))
	# At 2x, facing left, tinted, and centered on its start.
	assert_that(shot.size).is_equal(Vector2(36, 14))
	assert_bool((shot as TextureRect).flip_h).is_true()
	assert_that(shot.modulate).is_equal(Color.ORANGE)
	assert_that(shot.position).is_equal(Vector2(82, 193))
	assert_array(effects.get_effects()).has_size(1)
	assert_array(landed).is_empty()
	await await_millis(250)
	assert_array(landed).has_size(1)
	await await_idle_frame()
	assert_array(effects.get_effects()).is_empty()


func test_a_delayed_shot_waits_out_of_sight() -> void:
	var effects: CombatEffects = auto_free(CombatEffects.new())
	add_child(effects)
	var shot := effects.shoot(null, Vector2.ZERO, Vector2(300, 0), Color.WHITE, false, 0.1, func() -> void: pass, 0.1)
	assert_bool(shot.visible).is_false()
	await await_millis(150)
	assert_bool(shot.visible).is_true()
	await await_millis(200)
	await await_idle_frame()


func test_a_popup_floats_away_and_frees_itself() -> void:
	var effects: CombatEffects = auto_free(CombatEffects.new())
	add_child(effects)
	var pop := effects.popup("-28", Vector2(300, 400), CombatColors.HIT_ON_OPPONENT, 0.3)
	assert_str(pop.text).is_equal("-28")
	assert_that(pop.color).is_equal(CombatColors.HIT_ON_OPPONENT)
	var start_y := pop.position.y
	await await_millis(200)
	assert_float(pop.position.y).is_less(start_y)
	await await_millis(250)
	await await_idle_frame()
	assert_array(effects.get_effects()).is_empty()


func test_the_flash_fades() -> void:
	var effects: CombatEffects = auto_free(CombatEffects.new())
	add_child(effects)
	assert_float(effects.get_flash_alpha()).is_equal(0.0)
	effects.flash(Color(CombatColors.STORM, 0.35), 0.1)
	assert_float(effects.get_flash_alpha()).is_equal_approx(0.35, 1e-3)
	await await_millis(200)
	assert_float(effects.get_flash_alpha()).is_equal_approx(0.0, 1e-3)
