class_name RestScreenTest
extends GdUnitTestSuite

const __source: String = "res://src/ui/RestScreen.gd"
const Fixtures := preload("res://test/TestFixtures.gd")

var _run: RunState


func before_test() -> void:
	_run = RunState.new(Fixtures.cross_chassis(), [], [], 10) # 30 max HP
	_run.hull_damage = 20


func test_offers_a_repair_or_a_reinforce() -> void:
	var screen := _screen()
	assert_str(screen.title_label.text).is_equal("HANGAR / REFIT BAY")
	assert_object(screen.hud.run).is_same(_run)
	# 30% of 30 is 9.
	assert_str(screen.repair_button.text).is_equal("Repair\nRepair 9 hull (30% of max).")
	assert_str(screen.reinforce_button.text).is_equal("Reinforce\n+25 max HP for the rest of the run.")
	assert_str(screen.button.text).is_equal("Leave")


func test_repairing_does_the_one_job() -> void:
	var screen := _screen()
	assert_bool(screen.repair()).is_true()
	assert_int(_run.hull_damage).is_equal(11)
	assert_str(screen.body_label.text).is_equal("Repaired 9 hull.")
	assert_bool(screen.options.visible).is_false()
	assert_str(screen.button.text).is_equal("Continue")
	# Only one job.
	assert_bool(screen.reinforce()).is_false()
	assert_bool(screen.repair()).is_false()
	assert_int(_run.get_max_hp()).is_equal(30)


func test_reinforcing_raises_max_hp() -> void:
	var screen := _screen()
	assert_bool(screen.reinforce()).is_true()
	assert_int(_run.get_max_hp()).is_equal(55)
	assert_int(_run.hull_damage).is_equal(20)
	assert_str(screen.body_label.text).is_equal("+25 max HP. The hull is sturdier for good.")


func test_a_whole_hull_has_nothing_to_repair() -> void:
	_run.hull_damage = 0
	var screen := _screen()
	assert_bool(screen.repair_button.disabled).is_true()
	assert_bool(screen.reinforce_button.disabled).is_false()


func test_the_buttons_do_their_jobs_and_leave() -> void:
	var screen := _screen()
	screen.repair_button.pressed.emit()
	await await_idle_frame() # options are deferred
	assert_int(_run.hull_damage).is_equal(11)
	var done := [0]
	screen.confirmed.connect(func() -> void: done[0] += 1)
	screen.button.pressed.emit()
	assert_int(done[0]).is_equal(1)


func _screen() -> RestScreen:
	var screen: RestScreen = auto_free(RestScreen.new(_run))
	add_child(screen)
	return screen
