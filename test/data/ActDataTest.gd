class_name ActDataTest
extends GdUnitTestSuite

const __source: String = "res://src/data/ActData.gd"
const Fixtures := preload("res://test/TestFixtures.gd")


func test_defaults_match_the_design() -> void:
	var act := ActData.new()
	assert_int(act.floors).is_equal(12)
	assert_int(act.columns).is_equal(7)
	assert_int(act.paths).is_equal(6)
	assert_int(act.min_special_floor).is_equal(4)
	assert_that(act.get_node_weights()).is_equal({
		MapNode.Type.BATTLE: 45, MapNode.Type.EVENT: 22, MapNode.Type.ELITE: 10, MapNode.Type.HANGAR: 12, MapNode.Type.SHOP: 6,
	})


func test_enemies_by_tier() -> void:
	var act := Fixtures.act()
	var normals := act.get_enemies(EnemyLoadout.Tier.NORMAL)
	assert_array(normals.map(func(enemy: EnemyLoadout) -> String: return enemy.enemy_name)).contains_exactly(["Grunt A", "Grunt B"])
	assert_array(act.get_enemies(EnemyLoadout.Tier.ELITE)).has_size(1)
	assert_array(act.get_enemies(EnemyLoadout.Tier.BOSS)).has_size(1)
	assert_array(ActData.new().get_enemies(EnemyLoadout.Tier.BOSS)).is_empty()


func test_enemy_hp_scales_with_the_sector_and_floor() -> void:
	var act := Fixtures.act(1.5, 0.1)
	assert_float(act.get_enemy_hp_scale(0)).is_equal_approx(1.5, 0.0001)
	assert_float(act.get_enemy_hp_scale(4)).is_equal_approx(2.1, 0.0001) # 1.5 × 1.4
