class_name FrameExpansionTest
extends GdUnitTestSuite
## Locked cells a frame grows into, and the run opening them.

const __source: String = "res://src/data/MechChassis.gd"
const Fixtures := preload("res://test/TestFixtures.gd")


func test_locked_cells_hold_nothing_until_opened() -> void:
	var chassis := _growable()
	assert_bool(chassis.is_locked(Vector2i(0, 2))).is_true()
	assert_bool(chassis.is_usable(Vector2i(0, 2))).is_false()
	assert_int(chassis.get_usable_cell_count()).is_equal(6)
	var grid := MechGridData.new(chassis)
	assert_bool(grid.can_place_part(Fixtures.laser(), Vector2i(0, 2))).is_false()
	assert_bool(grid.can_place_part(Fixtures.laser(), Vector2i(0, 1))).is_true() # positive control
	assert_bool(chassis.open_cell(Vector2i(0, 2))).is_true()
	assert_bool(chassis.is_usable(Vector2i(0, 2))).is_true()
	assert_bool(grid.can_place_part(Fixtures.laser(), Vector2i(0, 2))).is_true()


func test_only_cells_touching_the_frame_open() -> void:
	# Row 2 touches the frame; row 3 only touches row 2.
	var chassis := _growable()
	assert_array(chassis.get_frontier()).contains_exactly_in_any_order([Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2)])
	assert_bool(chassis.open_cell(Vector2i(0, 3))).is_false()
	assert_bool(chassis.open_cell(Vector2i(0, 2))).is_true()
	assert_bool(Vector2i(0, 3) in chassis.get_frontier()).is_true()
	assert_bool(chassis.open_cell(Vector2i(0, 3))).is_true()
	# An open cell doesn't open twice.
	assert_bool(chassis.open_cell(Vector2i(0, 2))).is_false()


func test_a_run_grows_its_own_copy_of_the_frame() -> void:
	var chassis := _growable()
	var run := RunState.new(chassis, [], [], 10)
	assert_object(run.grid.chassis).is_not_same(chassis)
	assert_int(run.grant_cells(2)).is_equal(2)
	assert_int(run.cells_to_open).is_equal(2)
	assert_bool(run.open_cell(Vector2i(1, 2))).is_true()
	assert_int(run.cells_to_open).is_equal(1)
	assert_bool(run.grid.chassis.is_usable(Vector2i(1, 2))).is_true()
	# The shared chassis never changes.
	assert_bool(chassis.is_locked(Vector2i(1, 2))).is_true()
	assert_array(chassis.opened_cells).is_empty()


func test_opening_needs_a_cell_to_open_and_a_frontier_cell() -> void:
	var run := RunState.new(_growable(), [], [], 10)
	assert_bool(run.open_cell(Vector2i(1, 2))).is_false() # none to open
	run.grant_cells(1)
	assert_bool(run.open_cell(Vector2i(1, 3))).is_false() # not touching the frame
	assert_bool(run.open_cell(Vector2i(1, 1))).is_false() # already open
	assert_bool(run.open_cell(Vector2i(1, 2))).is_true()
	assert_bool(run.open_cell(Vector2i(0, 2))).is_false() # none left


func test_cells_are_only_granted_while_the_frame_has_room() -> void:
	var run := RunState.new(_growable(), [], [], 10) # 6 locked cells
	assert_int(run.get_expandable_cells()).is_equal(6)
	assert_int(run.grant_cells(4)).is_equal(4)
	assert_int(run.grant_cells(4)).is_equal(2)
	assert_int(run.cells_to_open).is_equal(6)
	assert_int(run.get_expandable_cells()).is_equal(0)


func test_expanding_with_no_room_left_gives_hp_instead() -> void:
	var effect := ExpandEffect.new()
	effect.cells = 1
	effect.fallback_hp = 40
	var full := RunState.new(Fixtures.cross_chassis(), [], [], 10) # 30 HP, nothing locked
	var result := EventResult.new()
	effect.apply(full, result)
	assert_int(full.cells_to_open).is_equal(0)
	assert_int(full.get_max_hp()).is_equal(70)
	assert_array(result.lines).contains_exactly(["The frame can't grow any more: +40 max HP instead"])
	# Positive control: with room, a cell to open.
	var roomy := RunState.new(_growable(), [], [], 10)
	effect.apply(roomy, result)
	assert_int(roomy.cells_to_open).is_equal(1)
	assert_int(roomy.get_max_hp()).is_equal(30)


func test_a_boss_offers_cells_in_the_relic_group() -> void:
	var run := RunState.new(_growable(), [], [], 10)
	var reward := FightReward.new()
	reward.relics = [Fixtures.relic("Boss A", Relic.Rarity.BOSS)]
	reward.cells = 2
	assert_bool(run.take_reward_cells(reward)).is_true()
	assert_int(run.cells_to_open).is_equal(2)
	# The group is closed: no relic as well.
	assert_bool(reward.is_relic_open()).is_false()
	assert_bool(run.take_reward_relic(reward, 0)).is_false()
	assert_bool(run.take_reward_cells(reward)).is_false()


func test_an_enemy_can_fight_on_a_grown_frame() -> void:
	var enemy := Fixtures.enemy("Grown", EnemyLoadout.Tier.NORMAL, [LoadoutPart.make(Fixtures.laser(), Vector2i(0, 2))])
	enemy.chassis = _growable()
	enemy.opened_cells.assign([Vector2i(0, 2)])
	var grid := enemy.build_grid()
	assert_object(grid.get_part_at(Vector2i(0, 2))).is_not_null()
	assert_bool(enemy.chassis.is_locked(Vector2i(0, 2))).is_true()


# A 3x4 open frame whose bottom two rows are locked: 6 usable cells, 6 to grow into.
func _growable() -> MechChassis:
	var chassis := Fixtures.open_chassis(Vector2i(3, 4))
	for y in [2, 3]:
		for x in 3:
			chassis.expansion_cells.append(Vector2i(x, y))
	return chassis
