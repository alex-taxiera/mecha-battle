class_name RunStateTest
extends GdUnitTestSuite

const __source: String = "res://src/data/RunState.gd"
const Fixtures := preload("res://test/TestFixtures.gd")

# The armed cross's bays.
const LEFT_ARM := Vector2i(-1, 1)
const RIGHT_ARM := Vector2i(4, 1)
const BACK := Vector2i(1, -2)

var _gatling: MechPart  # 1x3 vertical arm weapon, 4 gold
var _laser: MechPart    # 1x1, 2 gold
var _reactor: MechPart  # 2x1, 3 gold
var _heatsink: MechPart # L, 4 gold
var _run: RunState
var _changes := 0


func before_test() -> void:
	_gatling = Fixtures.gatling()
	_laser = Fixtures.laser()
	_reactor = Fixtures.reactor()
	_heatsink = Fixtures.heatsink()
	_run = _new_run(1234)
	_changes = 0
	_run.changed.connect(func() -> void: _changes += 1)


func test_the_first_shop_offers_each_part_once() -> void:
	for slot in _run.slots:
		assert_bool(slot.sold).is_false()
	assert_array(_parts_of(_run)).has_size(4).contains_same_exactly_in_any_order(_gatling, _laser, _reactor, _heatsink)
	assert_int(_run.gold).is_equal(10)
	assert_int(_run.round_number).is_equal(1)


func test_the_shop_only_offers_weapons_the_chassis_can_mount() -> void:
	# The Bastion's one bay is a 2x2 back: it can mount the missile pod but not the gatling.
	var missile_pod := Fixtures.missile_pod()
	var run := RunState.new(Fixtures.bastion(), [_gatling, missile_pod, _laser, _heatsink], [])
	assert_array(run.catalog).has_size(3).contains_same_exactly_in_any_order([missile_pod, _laser, _heatsink])
	assert_array(_parts_of(run)).not_contains_same([_gatling])
	# The cross has arms and a back, so everything is on offer.
	assert_array(_run.catalog).has_size(4).contains_same_exactly_in_any_order([_gatling, _laser, _reactor, _heatsink])


func test_buying_installs_the_part_and_pays_for_it() -> void:
	var slot := _slot_of(_gatling)
	assert_bool(_run.buy(slot, LEFT_ARM)).is_true() # (-1, 1)-(-1, 3)
	assert_int(_run.gold).is_equal(6)
	assert_bool(_run.slots[slot].sold).is_true()
	var installed := _run.grid.get_part_at(Vector2i(-1, 3))
	assert_str(installed.part_name).is_equal(_gatling.part_name)
	assert_object(installed).is_not_same(_gatling) # its own instance, not the shop's blueprint
	assert_int(_changes).is_equal(1)


func test_a_failed_buy_changes_nothing() -> void:
	var gatling_slot := _slot_of(_gatling)
	assert_bool(_run.buy(gatling_slot, Vector2i(1, 0))).is_false() # weapons only mount on hardpoints
	assert_int(_run.gold).is_equal(10)
	_run.gold = 3
	assert_bool(_run.buy(gatling_slot, LEFT_ARM)).is_false()       # costs 4
	assert_bool(_run.buy(99, LEFT_ARM)).is_false()                 # no such slot
	assert_int(_run.gold).is_equal(3)
	assert_bool(_run.slots[gatling_slot].sold).is_false()
	assert_int(_run.grid.get_used_cell_count()).is_equal(0)
	assert_int(_changes).is_equal(0)
	# The affordable laser still sells, but its slot only sells once.
	var laser_slot := _slot_of(_laser)
	assert_bool(_run.buy(laser_slot, Vector2i(1, 1))).is_true()
	assert_bool(_run.buy(laser_slot, Vector2i(2, 1))).is_false()
	assert_int(_run.gold).is_equal(1)


func test_buying_uses_the_slot_rotation() -> void:
	var slot := _slot_of(_heatsink)
	# Upright at (2, 2), the heatsink's foot would hit the (3, 3) corner.
	assert_bool(_run.buy(slot, Vector2i(2, 2))).is_false()
	assert_bool(_run.rotate_slot(slot)).is_true()
	# Turned once (XX over X.) it fits there.
	assert_bool(_run.buy(slot, Vector2i(2, 2))).is_true()
	for cell: Vector2i in [Vector2i(2, 2), Vector2i(3, 2), Vector2i(2, 3)]:
		assert_object(_run.grid.get_part_at(cell)).is_not_null()


func test_weapon_offers_do_not_rotate() -> void:
	# A weapon must match its hardpoint's shape, so its offer never turns.
	var slot := _slot_of(_gatling)
	assert_bool(_run.rotate_slot(slot)).is_false()
	assert_int(_run.slots[slot].rotation).is_equal(0)
	assert_int(_changes).is_equal(0)
	assert_bool(_run.rotate_slot(_slot_of(_reactor))).is_true() # a 2x1 still turns


func test_weapons_mount_on_hardpoints() -> void:
	assert_bool(_run.buy(_slot_of(_gatling), LEFT_ARM)).is_true() # 10 -> 6
	# It moves between arms for free, but not onto the frame or the 2x2 back, and never turns.
	assert_bool(_run.move(Vector2i(-1, 2), Vector2i(1, 0))).is_false()
	assert_bool(_run.move(Vector2i(-1, 2), BACK)).is_false()
	assert_bool(_run.rotate_placed(Vector2i(-1, 2))).is_false()
	assert_bool(_run.move(Vector2i(-1, 2), RIGHT_ARM)).is_true()
	assert_object(_run.grid.get_part_at(Vector2i(4, 3))).is_not_null()
	assert_int(_run.gold).is_equal(6)
	# Sold straight out of its bay.
	assert_int(_run.sell(Vector2i(4, 1))).is_equal(4)
	assert_int(_run.grid.get_mounted_count()).is_equal(0)
	assert_int(_changes).is_equal(3) # the buy, the move, and the sale


func test_selling_refunds_in_full_this_round_and_half_later() -> void:
	assert_bool(_run.buy(_slot_of(_gatling), LEFT_ARM)).is_true()       # 10 -> 6
	assert_bool(_run.buy(_slot_of(_reactor), Vector2i(2, 1))).is_true() # 6 -> 3, at (2, 1) (3, 1)
	assert_bool(_run.is_fresh(Vector2i(2, 1))).is_true()
	assert_int(_run.sell_value(Vector2i(-1, 2))).is_equal(4)
	assert_int(_run.sell(Vector2i(-1, 2))).is_equal(4)                  # 3 -> 7
	assert_object(_run.grid.get_part_at(Vector2i(-1, 2))).is_null()

	_run.end_round()                                                     # 7 -> 17
	assert_bool(_run.is_fresh(Vector2i(2, 1))).is_false()
	assert_int(_run.sell_value(Vector2i(3, 1))).is_equal(1)             # half of 3, rounded down
	assert_int(_run.sell(Vector2i(3, 1))).is_equal(1)
	assert_int(_run.gold).is_equal(18)
	assert_int(_run.sell(Vector2i(3, 1))).is_equal(0)                   # nothing left there


func test_end_round_carries_gold_over_and_adds_income() -> void:
	assert_bool(_run.buy(_slot_of(_laser), Vector2i(1, 1))).is_true() # 10 -> 8
	_run.end_round()
	assert_int(_run.round_number).is_equal(2)
	assert_int(_run.gold).is_equal(18) # the unspent 8 plus 10 income
	for slot in _run.slots:
		assert_bool(slot.sold).is_false() # restocked for free
	assert_int(_run.grid.get_used_cell_count()).is_equal(1) # the mech keeps its parts


func test_the_chassis_hp_grows_each_round() -> void:
	assert_bool(_run.grid.place_part(Fixtures.laser(), Vector2i(1, 1))).is_true()
	assert_int(_run.stats().hp).is_equal(30 + 12)
	_run.end_round()
	assert_int(_run.stats().base_hp).is_equal(34) # 30 × 1.15 = 34.5, rounded down
	assert_int(_run.stats().hp).is_equal(34 + 12)
	# Previews count the same round.
	assert_int(_run.preview_move(Vector2i(1, 1), Vector2i(2, 1)).stats.hp).is_equal(34 + 12)


func test_records_each_fight() -> void:
	assert_int(_run.wins).is_equal(0)
	assert_int(_run.losses).is_equal(0)
	assert_int(_run.draws).is_equal(0)
	_run.record_fight(RunState.FightResult.WIN)
	_run.record_fight(RunState.FightResult.WIN)
	_run.record_fight(RunState.FightResult.LOSS)
	_run.record_fight(RunState.FightResult.DRAW)
	assert_int(_run.wins).is_equal(2)
	assert_int(_run.losses).is_equal(1)
	assert_int(_run.draws).is_equal(1)
	assert_int(_changes).is_equal(4) # the shop redraws its record each time
	# Recording a fight doesn't end the round; the shop does that next.
	assert_int(_run.round_number).is_equal(1)


func test_reroll_costs_gold_and_restocks() -> void:
	assert_bool(_run.buy(_slot_of(_laser), Vector2i(1, 1))).is_true() # 10 -> 8
	assert_bool(_run.reroll()).is_true()
	assert_int(_run.gold).is_equal(7)
	assert_array(_run.slots).has_size(4)
	for slot in _run.slots:
		assert_bool(slot.sold).is_false()
	# Without the gold, it fails and keeps the same offers.
	_run.gold = 0
	var offered := _parts_of(_run)
	assert_bool(_run.reroll()).is_false()
	assert_array(_parts_of(_run)).contains_same_exactly(offered)


func test_the_shop_repeats_with_the_same_seed() -> void:
	var a := _new_run(99)
	var b := _new_run(99)
	assert_array(_parts_of(a)).contains_same_exactly(_parts_of(b))
	assert_bool(a.reroll()).is_true()
	assert_bool(b.reroll()).is_true()
	assert_array(_parts_of(a)).contains_same_exactly(_parts_of(b))


func test_moving_and_rotating_installed_parts_is_free() -> void:
	assert_bool(_run.buy(_slot_of(_heatsink), Vector2i(1, 0))).is_true() # 10 -> 6, (1, 0) (1, 1) (2, 1)
	assert_bool(_run.move(Vector2i(1, 0), Vector2i(1, 1))).is_true()      # (1, 1) (1, 2) (2, 2)
	assert_bool(_run.rotate_placed(Vector2i(2, 2))).is_true()             # (1, 1) (2, 1) (1, 2)
	assert_object(_run.grid.get_part_at(Vector2i(2, 1))).is_not_null()
	assert_object(_run.grid.get_part_at(Vector2i(2, 2))).is_null()
	assert_bool(_run.move(Vector2i(2, 1), Vector2i(2, 3))).is_false()     # its (3, 3) would be a corner
	assert_int(_run.gold).is_equal(6)
	assert_bool(_run.is_fresh(Vector2i(2, 1))).is_true() # still sells for its full cost
	assert_int(_changes).is_equal(3) # the buy, the move, and the turn


func test_preview_buy() -> void:
	var slot := _slot_of(_gatling)
	var preview := _run.preview_buy(slot, LEFT_ARM)
	assert_int(preview.fit).is_equal(MechGridData.Fit.OK)
	assert_bool(preview.affordable).is_true()
	assert_array(preview.cells).contains_exactly_in_any_order(Vector2i(-1, 1), Vector2i(-1, 2), Vector2i(-1, 3))
	# The frame cells touching the bay, where a part would link with the gun; (0, 3) is a corner.
	assert_array(preview.open_edges).has_size(2).contains_exactly_in_any_order(Vector2i(0, 1), Vector2i(0, 2))
	assert_int(preview.stats.damage - _run.stats().damage).is_equal(8) # the hover delta
	# Nothing was bought.
	assert_int(_run.gold).is_equal(10)
	assert_int(_run.grid.get_used_cell_count()).is_equal(0)
	assert_int(_changes).is_equal(0)

	# Where it doesn't fit: the reason, but no edges or stats.
	var blocked := _run.preview_buy(slot, Vector2i(1, 0))
	assert_int(blocked.fit).is_equal(MechGridData.Fit.NEEDS_HARDPOINT)
	assert_array(blocked.open_edges).is_empty()
	assert_object(blocked.stats).is_null()
	assert_int(_run.preview_buy(_slot_of(_laser), Vector2i(0, 3)).fit).is_equal(MechGridData.Fit.DISABLED_CELL)
	# Too expensive but fitting still shows edges; the UI reports the missing gold.
	_run.gold = 1
	var pricey := _run.preview_buy(slot, LEFT_ARM)
	assert_bool(pricey.affordable).is_false()
	assert_int(pricey.fit).is_equal(MechGridData.Fit.OK)
	assert_array(pricey.open_edges).is_not_empty()
	assert_object(_run.preview_buy(99, LEFT_ARM)).is_null()


func test_preview_move() -> void:
	# Two touching lasers, plated for +4 HP each.
	assert_bool(_run.grid.place_part(Fixtures.laser(), Vector2i(0, 1))).is_true()
	assert_bool(_run.grid.place_part(Fixtures.laser(), Vector2i(0, 2))).is_true()
	var hp_now := _run.stats().hp
	# Moving one to (3, 2) splits them: the hover delta is -8 HP.
	var preview := _run.preview_move(Vector2i(0, 2), Vector2i(3, 2))
	assert_int(preview.fit).is_equal(MechGridData.Fit.OK)
	assert_int(preview.stats.hp - hp_now).is_equal(-8)
	assert_array(preview.open_edges).has_size(2).contains_exactly_in_any_order(Vector2i(3, 1), Vector2i(2, 2))
	# Its own cell counts as free; off the grid doesn't fit, nor does a weapon's bay.
	assert_int(_run.preview_move(Vector2i(0, 2), Vector2i(0, 2)).fit).is_equal(MechGridData.Fit.OK)
	assert_int(_run.preview_move(Vector2i(0, 2), Vector2i(4, 0)).fit).is_equal(MechGridData.Fit.OUT_OF_BOUNDS)
	assert_int(_run.preview_move(Vector2i(0, 2), Vector2i(4, 2)).fit).is_equal(MechGridData.Fit.WEAPONS_ONLY)
	assert_object(_run.preview_move(Vector2i(3, 3), Vector2i(1, 1))).is_null() # nothing there
	# Nothing moved.
	assert_object(_run.grid.get_part_at(Vector2i(0, 2))).is_not_null()
	assert_object(_run.grid.get_part_at(Vector2i(3, 2))).is_null()


func _new_run(rng_seed: int) -> RunState:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	return RunState.new(Fixtures.armed_cross(), [_gatling, _laser, _reactor, _heatsink],
		[Fixtures.cooled(), Fixtures.overcharge(), Fixtures.stable(), Fixtures.plated()], 10, rng)


func _slot_of(part: MechPart) -> int:
	for i in _run.slots.size():
		if _run.slots[i].part == part:
			return i
	return -1


func _parts_of(run: RunState) -> Array[MechPart]:
	var parts: Array[MechPart] = []
	for slot in run.slots:
		parts.append(slot.part)
	return parts
