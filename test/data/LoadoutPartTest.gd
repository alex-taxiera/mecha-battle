class_name LoadoutPartTest
extends GdUnitTestSuite

const __source: String = "res://src/data/LoadoutPart.gd"
const Fixtures := preload("res://test/TestFixtures.gd")


func test_place_all_installs_copies_where_the_lineup_says() -> void:
	var gatling := Fixtures.gatling()
	var heatsink := Fixtures.heatsink()
	var grid := MechGridData.new(Fixtures.armed_cross())
	var lineup: Array[LoadoutPart] = [LoadoutPart.make(gatling, Vector2i(-1, 1)), LoadoutPart.make(heatsink, Vector2i(1, 1), 1)]
	assert_bool(LoadoutPart.place_all(grid, lineup)).is_true()
	var mounted := grid.get_placement_at(Vector2i(-1, 2))
	assert_str(mounted.part.part_name).is_equal("Twin Gatling")
	assert_object(mounted.part).is_not_same(gatling)
	# Turned once, the heatsink covers (1, 1) (2, 1) (1, 2).
	var placed := grid.get_placement_at(Vector2i(2, 1))
	assert_int(placed.rotation).is_equal(1)
	assert_array(placed.cells).contains_exactly_in_any_order(Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, 2))
	# Placing the same lineup twice makes separate copies.
	var other := MechGridData.new(Fixtures.armed_cross())
	assert_bool(LoadoutPart.place_all(other, lineup)).is_true()
	assert_object(other.get_part_at(Vector2i(-1, 2))).is_not_same(mounted.part)


func test_an_enemy_builds_its_grid() -> void:
	var lineup: Array[LoadoutPart] = [LoadoutPart.make(Fixtures.missile_pod(), Vector2i(1, -2)), LoadoutPart.make(Fixtures.laser(), Vector2i(0, 0))]
	var enemy := Fixtures.enemy("Pod", EnemyLoadout.Tier.ELITE, lineup)
	enemy.chassis = Fixtures.bastion()
	var grid := enemy.build_grid()
	assert_object(grid.chassis).is_same(enemy.chassis)
	assert_int(grid.get_mounted_count()).is_equal(1)
	assert_int(grid.get_used_cell_count()).is_equal(1)
	# Each build is a new grid.
	assert_object(enemy.build_grid()).is_not_same(grid)
