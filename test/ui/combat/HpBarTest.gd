class_name HpBarTest
extends GdUnitTestSuite

const __source: String = "res://src/ui/combat/HpBar.gd"


func test_shows_health_as_a_number_and_a_fraction() -> void:
	var bar: HpBar = auto_free(HpBar.new())
	bar.set_health(190, 220)
	assert_str(bar.get_text()).is_equal("190/220")
	assert_float(bar.get_fraction()).is_equal_approx(190.0 / 220.0, 1e-6)
	# Out of the tree, the trail just follows.
	assert_float(bar.trail).is_equal_approx(190.0 / 220.0, 1e-6)
	bar.set_health(0, 220)
	assert_float(bar.get_fraction()).is_equal(0.0)


func test_the_fill_turns_red_below_30_percent() -> void:
	var bar: HpBar = auto_free(HpBar.new())
	bar.set_health(66, 220) # exactly 30%
	assert_that(bar.get_fill_color()).is_equal(CombatColors.HP)
	bar.set_health(65, 220)
	assert_that(bar.get_fill_color()).is_equal(CombatColors.DANGER)


func test_the_trail_lingers_after_a_hit() -> void:
	var bar: HpBar = auto_free(HpBar.new())
	add_child(bar)
	bar.set_health(200, 200)
	assert_float(bar.trail).is_equal(1.0)
	bar.set_health(100, 200)
	# The fill drops at once; the trail waits, then catches up.
	assert_float(bar.get_fraction()).is_equal(0.5)
	assert_float(bar.trail).is_equal(1.0)
	await await_millis(int((HpBar.TRAIL_DELAY + HpBar.TRAIL_TIME) * 1000) + 150)
	assert_float(bar.trail).is_equal_approx(0.5, 1e-3)
	# Healing, or a new maximum, moves it at once.
	bar.set_health(150, 200)
	assert_float(bar.trail).is_equal(0.75)


func test_the_fill_glides_to_each_new_value() -> void:
	var bar: HpBar = auto_free(HpBar.new())
	add_child(bar)
	bar.smoothing = 0.2
	bar.set_health(100, 100)
	bar.set_health(50, 100)
	# The number is exact at once; the fill gets there over the smoothing time.
	assert_str(bar.get_text()).is_equal("50/100")
	assert_float(bar.shown).is_equal(1.0)
	await await_millis(300)
	assert_float(bar.shown).is_equal_approx(0.5, 1e-3)
