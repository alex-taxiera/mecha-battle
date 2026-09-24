class_name ApplyStatusTest
extends GdUnitTestSuite

const __source: String = "res://src/data/abilities/ApplyStatus.gd"
const Fixtures := preload("res://test/TestFixtures.gd")


# Turns away every hit.
class Wall:
	extends MechStatus

	func intercepts_hits() -> bool:
		return true

	func intercept(_hit: HitPipeline.Hit, _status: ActiveStatus) -> HitInterceptor.Result:
		return HitInterceptor.Result.REJECTED


func test_a_flamer_hit_leaves_burn() -> void:
	var target := _target()
	var engine := _fight(_armed(Fixtures.flamer()), target)
	for i in 5:
		engine.process_tick(0.1)
	assert_int(target.get_status_charges("burn")).is_equal(2)
	assert_int(target.current_health).is_equal(200 - 4)


func test_a_rejected_hit_leaves_nothing() -> void:
	var target := _target()
	var wall := Wall.new()
	wall.id = "wall"
	wall.decay_interval = 0.0
	target.add_status(wall, 1)
	var engine := _fight(_armed(Fixtures.flamer()), target)
	for i in 5:
		engine.process_tick(0.1)
	assert_int(target.get_status_charges("burn")).is_equal(0)
	assert_int(target.current_health).is_equal(200)


func _armed(weapon: MechPart) -> BattleMech:
	var chassis := Fixtures.armed_cross()
	chassis.base_energy = 1000
	var grid := MechGridData.new(chassis)
	assert_bool(grid.place_part(weapon, Vector2i(-1, 1))).is_true()
	return BattleMech.new(grid)


func _target() -> BattleMech:
	var chassis := Fixtures.cross_chassis()
	chassis.base_hp = 200
	chassis.base_energy = 0
	return BattleMech.new(MechGridData.new(chassis))


func _fight(left: BattleMech, right: BattleMech) -> CombatEngine:
	var engine := CombatEngine.new(left, right)
	engine.start()
	return engine
