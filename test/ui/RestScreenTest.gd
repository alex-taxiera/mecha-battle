class_name RestScreenTest
extends GdUnitTestSuite

const __source: String = "res://src/ui/RestScreen.gd"
const Fixtures := preload("res://test/TestFixtures.gd")

var _run: RunState


func before_test() -> void:
	_run = RunState.new(Fixtures.cross_chassis(), [], [], 10) # 30 max HP
	_run.hangar_jobs = Fixtures.hangar_jobs()
	_run.hull_damage = 20


func test_offers_the_runs_jobs() -> void:
	var screen := _screen()
	assert_str(screen.title_label.text).is_equal("HANGAR / REFIT BAY")
	assert_object(screen.hud.run).is_same(_run)
	# 30% of 30 is 9.
	assert_str(screen.job_buttons["repair"].text).is_equal("Repair\nRepair 9 hull (30% of max).")
	assert_str(screen.job_buttons["reinforce"].text).is_equal("Reinforce\n+25 max HP for the rest of the run.")
	assert_str(screen.job_buttons["upgrade"].text).is_equal("Upgrade\nRaise one part a Mk.")
	assert_str(screen.button.text).is_equal("Leave")


func test_repairing_does_the_one_job() -> void:
	var screen := _screen()
	assert_bool(screen.do_job(_job("repair"))).is_true()
	assert_int(_run.hull_damage).is_equal(11)
	assert_str(screen.body_label.text).is_equal("Repaired 9 hull.")
	assert_bool(screen.options.visible).is_false()
	assert_str(screen.button.text).is_equal("Continue")
	# Only one exclusive job.
	assert_bool(screen.do_job(_job("reinforce"))).is_false()
	assert_bool(screen.do_job(_job("repair"))).is_false()
	assert_int(_run.get_max_hp()).is_equal(30)


func test_reinforcing_raises_max_hp() -> void:
	var screen := _screen()
	assert_bool(screen.do_job(_job("reinforce"))).is_true()
	assert_int(_run.get_max_hp()).is_equal(55)
	assert_int(_run.hull_damage).is_equal(20)
	assert_str(screen.body_label.text).is_equal("+25 max HP.")


func test_a_job_is_off_when_its_requirement_fails() -> void:
	_run.hull_damage = 0
	var screen := _screen()
	assert_bool(screen.job_buttons["repair"].disabled).is_true()
	assert_bool(screen.do_job(_job("repair"))).is_false()
	assert_bool(screen.job_buttons["reinforce"].disabled).is_false()


func test_the_buttons_do_their_jobs_and_leave() -> void:
	var screen := _screen()
	screen.job_buttons["repair"].pressed.emit()
	await await_idle_frame() # options are deferred
	assert_int(_run.hull_damage).is_equal(11)
	var done := [0]
	screen.confirmed.connect(func() -> void: done[0] += 1)
	screen.button.pressed.emit()
	assert_int(done[0]).is_equal(1)


func test_upgrading_lists_the_parts_then_raises_one() -> void:
	assert_bool(_run.grid.place_part(Fixtures.laser(), Vector2i(1, 1))).is_true()
	var screen := _screen()
	assert_bool(screen.job_buttons["upgrade"].disabled).is_false()
	assert_bool(screen.do_job(_job("upgrade"))).is_true()
	var labels := screen.options.get_children().map(func(option: Button) -> String: return option.text)
	assert_array(labels).contains_exactly(["Point-Defense Laser → Mk II", "Back"])
	var laser := _run.grid.get_part_at(Vector2i(1, 1))
	assert_bool(screen.upgrade(laser)).is_true()
	assert_int(laser.level).is_equal(2)
	assert_str(screen.body_label.text).is_equal("Upgraded to Point-Defense Laser Mk II.")
	assert_bool(screen.do_job(_job("repair"))).is_false() # one job
	await await_idle_frame()


func test_upgrade_is_off_with_nothing_to_upgrade() -> void:
	assert_bool(_screen().job_buttons["upgrade"].disabled).is_true() # the bare cross owns no parts


func test_expanding_owes_a_cell_to_open() -> void:
	_run = RunState.new(_growable(), [], [], 10)
	_run.hangar_jobs = Fixtures.hangar_jobs()
	var screen := _screen()
	assert_str(screen.job_buttons["expand"].text).is_equal("Expand\nOpen 1 more cell on the frame.")
	assert_bool(screen.do_job(_job("expand"))).is_true()
	assert_int(_run.cells_to_open).is_equal(1)
	assert_str(screen.body_label.text).is_equal("+1 cell to open on the frame (from the Loadout).")
	# Positive control for the requirement: a frame with no locked cells can't grow.
	_run = RunState.new(Fixtures.cross_chassis(), [], [], 10)
	_run.hangar_jobs = Fixtures.hangar_jobs()
	assert_bool(_screen().job_buttons["expand"].disabled).is_true()


func test_inclusive_jobs_leave_the_rest_open_and_paid_jobs_cost_gold() -> void:
	var scrap := Fixtures.hangar_job("scrap", "Strip for scrap", [Fixtures.gold_effect(15)])
	scrap.cost_type = HangarJob.CostType.INCLUSIVE
	var polish := Fixtures.hangar_job("polish", "Polish", [], null, HangarJob.Kind.EFFECTS, "Shiny.")
	polish.cost = 4
	polish.cost_type = HangarJob.CostType.REPEATABLE
	_run.hangar_jobs.append_array([scrap, polish] as Array[HangarJob])
	var screen := _screen()
	assert_str(screen.job_buttons["polish"].text).is_equal("Polish\nShiny. (4 gold)")
	assert_bool(screen.do_job(scrap)).is_true()
	assert_int(_run.gold).is_equal(25)
	# Done once, but the visit goes on.
	assert_bool(screen.do_job(scrap)).is_false()
	assert_bool(screen.job_buttons["repair"].disabled).is_false()
	# A repeatable job goes again while it can be paid for.
	assert_bool(screen.do_job(polish)).is_true()
	assert_bool(screen.do_job(polish)).is_true()
	assert_int(_run.gold).is_equal(17)
	await await_idle_frame()


func test_relics_add_jobs() -> void:
	var rig := Fixtures.relic("Salvage Rig", Relic.Rarity.UNCOMMON)
	rig.hangar_jobs.assign([Fixtures.hangar_job("scrap", "Strip for scrap", [Fixtures.gold_effect(15)])])
	_run.add_relic(rig)
	var ids := _run.get_hangar_jobs().map(func(job: HangarJob) -> String: return job.id)
	assert_array(ids).contains_exactly(["repair", "reinforce", "upgrade", "expand", "scrap"])
	assert_bool(_screen().job_buttons.has("scrap")).is_true()


func _job(id: String) -> HangarJob:
	for job in _run.get_hangar_jobs():
		if job.id == id:
			return job
	return null


# The cross with its bottom row locked: two cells to grow into.
func _growable() -> MechChassis:
	var chassis := Fixtures.open_chassis(Vector2i(3, 3))
	chassis.expansion_cells.assign([Vector2i(0, 2), Vector2i(1, 2)])
	return chassis


func _screen() -> RestScreen:
	var screen: RestScreen = auto_free(RestScreen.new(_run))
	add_child(screen)
	return screen
