class_name CombatEffectsTest
extends GdUnitTestSuite

const __source: String = "res://src/ui/combat/CombatEffects.gd"
# The longest any effect here may take to finish, however slowly frames come.
const TIMEOUT_MS := 2000


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
	var watched: WeakRef = weakref(shot)
	var freed: bool = await _frames_until(func() -> bool: return watched.get_ref() == null)
	assert_bool(freed).append_failure_message("the shot never freed itself").is_true()
	assert_array(landed).has_size(1)
	assert_array(effects.get_effects()).is_empty()


func test_a_delayed_shot_waits_out_of_sight() -> void:
	var effects: CombatEffects = auto_free(CombatEffects.new())
	add_child(effects)
	var shot := effects.shoot(null, Vector2.ZERO, Vector2(300, 0), Color.WHITE, false, 0.1, func() -> void: pass, 0.1)
	assert_bool(shot.visible).is_false()
	# It shows only between its delay and its landing, so a single look can miss it: watch every
	# frame until it frees itself.
	var watched: WeakRef = weakref(shot)
	var seen := [false]
	var freed: bool = await _frames_until(func() -> bool:
		var now: Control = watched.get_ref()
		if now == null:
			return true
		seen[0] = seen[0] or now.visible
		return false)
	assert_bool(seen[0]).append_failure_message("the delayed shot never came into sight").is_true()
	assert_bool(freed).append_failure_message("the shot never freed itself").is_true()


func test_a_popup_floats_away_and_frees_itself() -> void:
	var effects: CombatEffects = auto_free(CombatEffects.new())
	add_child(effects)
	var pop := effects.popup("-28", Vector2(300, 400), CombatColors.HIT_ON_OPPONENT, 0.3)
	assert_str(pop.text).is_equal("-28")
	assert_that(pop.color).is_equal(CombatColors.HIT_ON_OPPONENT)
	# Watch it rise every frame until it frees itself, rather than reading it once and risking a
	# freed popup.
	var start_y := pop.position.y
	var highest := [start_y]
	var watched: WeakRef = weakref(pop)
	var freed: bool = await _frames_until(func() -> bool:
		var now: DamagePopup = watched.get_ref()
		if now == null:
			return true
		highest[0] = minf(highest[0], now.position.y)
		return false)
	assert_float(highest[0]).append_failure_message("the popup never rose").is_less(start_y)
	assert_bool(freed).append_failure_message("the popup never freed itself").is_true()
	assert_array(effects.get_effects()).is_empty()


func test_the_flash_fades() -> void:
	var effects: CombatEffects = auto_free(CombatEffects.new())
	add_child(effects)
	assert_float(effects.get_flash_alpha()).is_equal(0.0)
	effects.flash(Color(CombatColors.STORM, 0.35), 0.1)
	assert_float(effects.get_flash_alpha()).is_equal_approx(0.35, 1e-3)
	var faded: bool = await _frames_until(func() -> bool: return effects.get_flash_alpha() < 1e-3)
	assert_bool(faded).append_failure_message("the flash never faded").is_true()


# Waits a frame at a time until [param done] returns true, for up to [constant TIMEOUT_MS].
# Returns whether it did. Effects free themselves, so [param done] should hold them by weakref:
# a lambda holding a freed object makes Godot log an error.
func _frames_until(done: Callable) -> bool:
	var until := Time.get_ticks_msec() + TIMEOUT_MS
	while Time.get_ticks_msec() < until:
		if done.call():
			return true
		await get_tree().process_frame
	return done.call()
