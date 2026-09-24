class_name PiercingTest
extends GdUnitTestSuite

const __source: String = "res://src/data/abilities/Piercing.gd"
const Fixtures := preload("res://test/TestFixtures.gd")


func test_a_railgun_goes_through_plating_and_shield() -> void:
	var target := _shielded_bastion()
	var engine := _fight(Fixtures.railgun(), target)
	for i in 30:
		engine.process_tick(0.1)
	assert_int(target.shield).is_equal(200)
	assert_int(target.current_health).is_equal(450 - 90)


func test_without_piercing_plating_and_shield_take_their_share() -> void:
	var gun := Fixtures.railgun()
	gun.abilities.clear()
	var target := _shielded_bastion()
	var engine := _fight(gun, target)
	for i in 30:
		engine.process_tick(0.1)
	assert_int(target.shield).is_equal(200 - 88)
	assert_int(target.current_health).is_equal(450)


func _shielded_bastion() -> BattleMech:
	var chassis := Fixtures.bastion()
	chassis.base_energy = 1000 # pays the shield's upkeep
	var grid := MechGridData.new(chassis)
	assert_bool(grid.place_part(Fixtures.shield_emitter(), Vector2i(0, 0))).is_true()
	return BattleMech.new(grid)


func _fight(weapon: MechPart, target: BattleMech) -> CombatEngine:
	var chassis := Fixtures.armed_cross()
	chassis.base_energy = 1000
	var grid := MechGridData.new(chassis)
	assert_bool(grid.place_part(weapon, Vector2i(-1, 1))).is_true()
	var engine := CombatEngine.new(BattleMech.new(grid), target)
	engine.start()
	return engine
