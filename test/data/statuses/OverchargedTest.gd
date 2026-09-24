class_name OverchargedTest
extends GdUnitTestSuite

const __source: String = "res://src/data/statuses/Overcharged.gd"
const Fixtures := preload("res://test/TestFixtures.gd")


func test_overcharged_shots_hit_harder() -> void:
	var mech := _armed()
	var gun := mech.active_parts[0]
	# Positive control: a plain shot is its 20 damage.
	assert_int(mech.get_shot_damage(gun)).is_equal(20)
	mech.add_status(Fixtures.overcharged(), 3)
	assert_int(mech.get_shot_damage(gun)).is_equal(26)
	# Capped at its 5 charges.
	mech.add_status(Fixtures.overcharged(), 10)
	assert_int(mech.get_shot_damage(gun)).is_equal(30)


func test_it_only_boosts_shots() -> void:
	var mech := _armed()
	mech.add_status(Fixtures.overcharged(), 5)
	var meltdown := HitPipeline.Hit.new(HitPipeline.Kind.MELTDOWN, null, 100, mech)
	assert_int(HitPipeline.outgoing(meltdown)).is_equal(100)


func _armed() -> BattleMech:
	var grid := MechGridData.new(Fixtures.armed_cross())
	var gun := Fixtures.part("Gun", MechPart.PartType.WEAPON, Fixtures.ARM_SHAPE, 0, {"damage": 20, "cooldown_max": 1.0})
	assert_bool(grid.place_part(gun, Vector2i(-1, 1))).is_true()
	return BattleMech.new(grid)
