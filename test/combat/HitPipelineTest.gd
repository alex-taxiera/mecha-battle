class_name HitPipelineTest
extends GdUnitTestSuite

const __source: String = "res://src/combat/HitPipeline.gd"
const Fixtures := preload("res://test/TestFixtures.gd")


# A status that adds [member amount] to every hit it sees, then answers [member result].
class Plus:
	extends MechStatus
	var amount := 0
	var result := HitInterceptor.Result.CONTINUE

	func intercepts_hits() -> bool:
		return true

	func intercept(hit: HitPipeline.Hit, _status: ActiveStatus) -> HitInterceptor.Result:
		hit.damage += amount
		return result


# A status that multiplies every hit it sees by [member factor].
class Times:
	extends MechStatus
	var factor := 1

	func intercepts_hits() -> bool:
		return true

	func intercept(hit: HitPipeline.Hit, _status: ActiveStatus) -> HitInterceptor.Result:
		hit.damage *= factor
		return HitInterceptor.Result.CONTINUE


func test_interceptors_run_highest_priority_first() -> void:
	var mech := _mech()
	mech.add_status(_plus("plus", 10, 100), 1)
	mech.add_status(_times("times", 2, 50), 1)
	assert_int(mech.get_damage_taken(5)).is_equal(30) # (5 + 10) × 2
	# The other way round: 5 × 2 + 10.
	var swapped := _mech()
	swapped.add_status(_plus("plus", 10, 50), 1)
	swapped.add_status(_times("times", 2, 100), 1)
	assert_int(swapped.get_damage_taken(5)).is_equal(20)


func test_ties_keep_the_order_interceptors_were_added_in() -> void:
	var mech := _mech()
	mech.add_status(_plus("plus", 10, 0), 1)
	mech.add_status(_times("times", 2, 0), 1)
	assert_int(mech.get_damage_taken(5)).is_equal(30)
	var other := _mech()
	other.add_status(_times("times", 2, 0), 1)
	other.add_status(_plus("plus", 10, 0), 1)
	assert_int(other.get_damage_taken(5)).is_equal(20)


func test_a_stopped_hit_skips_the_rest_of_its_side() -> void:
	var stopper := _plus("stopper", 1, 100)
	stopper.result = HitInterceptor.Result.STOPPED
	var mech := _mech()
	mech.add_status(stopper, 1)
	mech.add_status(_times("times", 2, 50), 1)
	assert_int(mech.get_damage_taken(5)).is_equal(6) # the ×2 never runs
	# Positive control: without the stop, it does.
	var open := _mech()
	open.add_status(_plus("plus", 1, 100), 1)
	open.add_status(_times("times", 2, 50), 1)
	assert_int(open.get_damage_taken(5)).is_equal(12)


func test_a_rejected_hit_does_not_land() -> void:
	var wall := _plus("wall", 0, 0)
	wall.result = HitInterceptor.Result.REJECTED
	var mech := _mech([[Fixtures.shield_emitter(), Vector2i(1, 0)]])
	mech.add_status(wall, 1)
	var hit := HitPipeline.Hit.new(HitPipeline.Kind.SHOT, mech, 25)
	assert_int(mech.take_hit(hit)).is_equal(0)
	assert_bool(hit.rejected).is_true()
	assert_int(mech.shield).is_equal(200)
	assert_int(mech.current_health).is_equal(30)
	# Positive control: without it, the shield takes the hit.
	assert_int(_mech([[Fixtures.shield_emitter(), Vector2i(1, 0)]]).take_damage(25)).is_equal(25)


func test_an_interceptor_only_sees_its_kinds_of_hit() -> void:
	var shots_only := _plus("shots", 10, 0)
	shots_only.kinds = [HitPipeline.Kind.SHOT]
	var mech := _mech([[Fixtures.shield_emitter(), Vector2i(1, 0)]])
	mech.add_status(shots_only, 1)
	assert_int(mech.take_damage(5, HitPipeline.Kind.STORM)).is_equal(5)
	assert_int(mech.take_damage(5, HitPipeline.Kind.SHOT)).is_equal(15)


func test_the_attackers_side_runs_first() -> void:
	# The attacker's +10 comes before the target's ×2 whatever their priorities.
	var boost := _plus("boost", 10, 0)
	boost.side = HitInterceptor.Side.ATTACKER
	var attacker := _mech()
	attacker.add_status(boost, 1)
	var target := _mech([[Fixtures.shield_emitter(), Vector2i(1, 0)]])
	target.add_status(_times("times", 2, 100), 1)
	var hit := HitPipeline.Hit.new(HitPipeline.Kind.SHOT, target, 5, attacker)
	assert_int(target.take_hit(hit)).is_equal(30)
	assert_int(hit.outgoing).is_equal(15)
	# An attacker's interceptors don't touch hits on the attacker.
	assert_int(attacker.get_damage_taken(5)).is_equal(5)


func test_piercing_skips_plating_or_the_shield() -> void:
	var bastion := BattleMech.new(MechGridData.new(Fixtures.bastion()))
	var hit := HitPipeline.Hit.new(HitPipeline.Kind.SHOT, bastion, 10)
	assert_int(bastion.take_hit(hit)).is_equal(8)
	assert_int(hit.blocked).is_equal(2)
	var piercing := HitPipeline.Hit.new(HitPipeline.Kind.SHOT, bastion, 10)
	piercing.pierce_plating = true
	assert_int(bastion.take_hit(piercing)).is_equal(10)
	assert_int(piercing.blocked).is_equal(0)
	# Through the shield, straight to the hull.
	var shielded := _mech([[Fixtures.shield_emitter(), Vector2i(1, 0)]])
	var through := HitPipeline.Hit.new(HitPipeline.Kind.SHOT, shielded, 12)
	through.pierce_shield = true
	assert_int(shielded.take_hit(through)).is_equal(12)
	assert_int(shielded.shield).is_equal(200)
	assert_int(shielded.current_health).is_equal(18)
	assert_int(through.absorbed).is_equal(0)


func test_a_preview_changes_nothing() -> void:
	var mech := _mech([[Fixtures.shield_emitter(), Vector2i(1, 0)]])
	mech.add_status(_plus("plus", 5, 0), 1)
	assert_int(mech.get_damage_taken(10)).is_equal(15)
	assert_int(mech.shield).is_equal(200)
	assert_int(mech.current_health).is_equal(30)
	assert_int(mech.last_taken).is_equal(0)


func _mech(placements: Array = []) -> BattleMech:
	var grid := MechGridData.new(Fixtures.cross_chassis()) # 30 HP, no plating
	for entry in placements:
		assert_bool(grid.place_part(entry[0], entry[1])).is_true()
	return BattleMech.new(grid)


func _plus(id: String, amount: int, priority: int) -> Plus:
	var status := Plus.new()
	status.id = id
	status.amount = amount
	status.priority = priority
	status.decay_interval = 0.0
	return status


func _times(id: String, factor: int, priority: int) -> Times:
	var status := Times.new()
	status.id = id
	status.factor = factor
	status.priority = priority
	status.decay_interval = 0.0
	return status
