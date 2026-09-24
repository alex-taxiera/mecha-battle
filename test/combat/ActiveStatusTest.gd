class_name ActiveStatusTest
extends GdUnitTestSuite

const __source: String = "res://src/combat/ActiveStatus.gd"
const Fixtures := preload("res://test/TestFixtures.gd")


# Heats its mech 1 a charge each tick, and counts its overflows.
class Scorch:
	extends MechStatus
	var overflowed := 0

	func on_tick(mech: BattleMech, status: ActiveStatus, _delta: float) -> void:
		mech.add_heat(status.charges)

	func on_overflow(_mech: BattleMech, _status: ActiveStatus, times: int) -> void:
		overflowed += times


func test_charges_stay_within_bounds() -> void:
	var mech := _mech()
	var status := mech.add_status(_status("capped", 0, 5), 3)
	status.add(10)
	assert_int(status.charges).is_equal(5)
	assert_int(mech.get_status_charges("capped")).is_equal(5)


func test_an_overflowing_status_wraps_and_fires() -> void:
	# Bounds 0-5: reaching 5 wraps back by 5, once per time over.
	var scorch := Scorch.new()
	scorch.id = "scorch"
	scorch.upper_bound = 5
	scorch.overflows = true
	scorch.decay_interval = 0.0
	var mech := _mech()
	var overflows := []
	mech.status_overflowed.connect(func(status: ActiveStatus, times: int) -> void: overflows.append([status.data.id, times]))
	var status := mech.add_status(scorch, 4)
	assert_int(scorch.overflowed).is_equal(0)
	status.add(3) # 7: wraps to 2
	assert_int(status.charges).is_equal(2)
	assert_int(scorch.overflowed).is_equal(1)
	status.add(10) # 12: wraps twice to 2
	assert_int(status.charges).is_equal(2)
	assert_int(scorch.overflowed).is_equal(3)
	assert_array(overflows).contains_exactly([["scorch", 1], ["scorch", 2]])


func test_secondary_charges_combine_by_strategy() -> void:
	var expected := {
		MechStatus.Combine.ADD: 7,
		MechStatus.Combine.KEEP: 4,
		MechStatus.Combine.MIN: 3,
		MechStatus.Combine.MAX: 4,
	}
	for combine: MechStatus.Combine in expected:
		var data := _status("s", 0, 999)
		data.secondary_combine = combine
		var status := _mech().add_status(data, 1, 4) # the first is taken as it is
		assert_int(status.secondary).is_equal(4)
		status.add(1, 3)
		assert_int(status.secondary).append_failure_message(MechStatus.Combine.find_key(combine)).is_equal(expected[combine])


func test_statuses_decay_by_their_type() -> void:
	var expected := {
		MechStatus.Decay.LINEAR: [5, 4, 3, 2],
		MechStatus.Decay.ZERO_OUT: [5, 0, 0, 0],
		MechStatus.Decay.HALF_UP: [5, 3, 2, 1],
		MechStatus.Decay.HALF_DOWN: [5, 2, 1, 0],
	}
	for decay: MechStatus.Decay in expected:
		var data := _status("s", 0, 999)
		data.decay = decay
		data.decay_interval = 1.0
		var mech := _mech()
		mech.add_status(data, 5)
		var seen := [mech.get_status_charges("s")]
		for second in 3:
			for i in 10:
				mech.tick_statuses(0.1)
			seen.append(mech.get_status_charges("s"))
		assert_array(seen).append_failure_message(MechStatus.Decay.find_key(decay)).is_equal(expected[decay])


func test_a_status_without_an_interval_never_decays() -> void:
	var data := _status("s", 0, 999)
	data.decay_interval = 0.0
	var mech := _mech()
	mech.add_status(data, 5)
	for i in 50:
		mech.tick_statuses(0.1)
	assert_int(mech.get_status_charges("s")).is_equal(5)


func test_a_worn_off_status_is_gone() -> void:
	var mech := _mech()
	mech.add_status(_status("s", 0, 999), 2)
	for i in 20:
		mech.tick_statuses(0.1)
	assert_object(mech.get_status("s")).is_null()
	assert_array(mech.statuses).is_empty()
	# Adding none at all leaves nothing behind either.
	assert_object(mech.add_status(_status("t", 0, 999), 0)).is_null()


func test_statuses_tick_in_a_fight() -> void:
	# Scorch with 3 charges heats 3 a tick, then decays 1 a second.
	var scorch := Scorch.new()
	scorch.id = "scorch"
	var mech := _mech()
	mech.add_status(scorch, 3)
	var engine := CombatEngine.new(mech, _mech())
	engine.start()
	for i in 10:
		engine.process_tick(0.1)
	assert_int(mech.heat).is_equal(30)
	assert_int(mech.get_status_charges("scorch")).is_equal(2)
	# Positive control: a mech without it stays cool.
	assert_int(engine.right.heat).is_equal(0)


func test_adding_stacks_onto_the_status_already_there() -> void:
	var mech := _mech()
	var data := _status("s", 0, 999)
	var first := mech.add_status(data, 2)
	var second := mech.add_status(data, 3)
	assert_object(second).is_same(first)
	assert_array(mech.statuses).has_size(1)
	assert_int(first.charges).is_equal(5)


func _mech() -> BattleMech:
	return BattleMech.new(MechGridData.new(Fixtures.cross_chassis()))


func _status(id: String, lower: int, upper: int) -> MechStatus:
	var status := MechStatus.new()
	status.id = id
	status.lower_bound = lower
	status.upper_bound = upper
	return status
