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


func test_a_new_run_starts_with_its_gold_and_an_empty_mech() -> void:
	assert_int(_run.gold).is_equal(10)
	assert_int(_run.grid.get_used_cell_count()).is_equal(0) # the fixture frame has no starter kit
	assert_array(_run.stash).is_empty()
	assert_int(_run.hull_damage).is_equal(0)
	assert_int(_run.fights_won).is_equal(0)
	assert_bool(_run.is_over()).is_false()
	assert_object(_run.map).is_null() # no sectors given
	# The open shop offers each part once.
	assert_array(_parts_of(_run)).has_size(4).contains_same_exactly_in_any_order(_gatling, _laser, _reactor, _heatsink)


func test_a_run_starts_with_its_chassis_starter_kit() -> void:
	var chassis := Fixtures.armed_cross()
	chassis.starter_lineup = [LoadoutPart.make(_gatling, LEFT_ARM), LoadoutPart.make(_heatsink, Vector2i(2, 1), 1)]
	var run := RunState.new(chassis, [], [])
	assert_int(run.grid.get_mounted_count()).is_equal(1)
	assert_int(run.grid.get_placement_at(Vector2i(2, 1)).rotation).is_equal(1)
	assert_int(run.grid.get_used_cell_count()).is_equal(3)
	# The kit's parts are the run's own copies.
	assert_object(run.grid.get_part_at(LEFT_ARM)).is_not_same(_gatling)


func test_the_shop_only_offers_weapons_the_chassis_can_mount() -> void:
	# The Bastion's one bay is a 2x2 back: it can mount the missile pod but not the gatling.
	var missile_pod := Fixtures.missile_pod()
	var run := RunState.new(Fixtures.bastion(), [_gatling, missile_pod, _laser, _heatsink], [])
	assert_array(run.catalog).has_size(3).contains_same_exactly_in_any_order([missile_pod, _laser, _heatsink])
	run.open_shop()
	assert_array(_parts_of(run)).not_contains_same([_gatling])
	# The cross has arms and a back, so everything is on offer.
	assert_array(_run.catalog).has_size(4).contains_same_exactly_in_any_order([_gatling, _laser, _reactor, _heatsink])


func test_buying_installs_the_part_and_pays_for_it() -> void:
	var slot := _slot_of(_gatling)
	assert_bool(_run.buy(slot, LEFT_ARM)).is_true() # (-1, 1)-(-1, 3)
	assert_int(_run.gold).is_equal(6)
	assert_bool(_run.shop.slots[slot].sold).is_true()
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
	assert_bool(_run.shop.slots[gatling_slot].sold).is_false()
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
	assert_int(_run.shop.slots[slot].rotation).is_equal(0)
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


func test_selling_refunds_in_full_at_the_same_shop_and_half_later() -> void:
	assert_bool(_run.buy(_slot_of(_gatling), LEFT_ARM)).is_true()       # 10 -> 6
	assert_bool(_run.buy(_slot_of(_reactor), Vector2i(2, 1))).is_true() # 6 -> 3, at (2, 1) (3, 1)
	assert_bool(_run.is_fresh(Vector2i(2, 1))).is_true()
	assert_int(_run.sell_value(Vector2i(-1, 2))).is_equal(4)
	assert_int(_run.sell(Vector2i(-1, 2))).is_equal(4)                  # 3 -> 7
	assert_object(_run.grid.get_part_at(Vector2i(-1, 2))).is_null()

	_run.close_shop()
	# Away from a shop nothing sells.
	assert_int(_run.sell(Vector2i(3, 1))).is_equal(0)
	assert_object(_run.grid.get_part_at(Vector2i(3, 1))).is_not_null()
	_run.open_shop()
	assert_bool(_run.is_fresh(Vector2i(2, 1))).is_false()
	assert_int(_run.sell_value(Vector2i(3, 1))).is_equal(1)             # half of 3, rounded down
	assert_int(_run.sell(Vector2i(3, 1))).is_equal(1)
	assert_int(_run.gold).is_equal(8)
	assert_int(_run.sell(Vector2i(3, 1))).is_equal(0)                   # nothing left there


func test_a_scrapper_drone_refunds_everything_in_full() -> void:
	assert_bool(_run.buy(_slot_of(_reactor), Vector2i(2, 1))).is_true() # 3 gold, at (2, 1) (3, 1)
	_run.stash_part(Fixtures.laser())
	_run.close_shop()
	_run.open_shop()
	# Positive control: bought earlier, it sells for half.
	assert_bool(_run.refunds_in_full()).is_false()
	assert_int(_run.sell_value(Vector2i(3, 1))).is_equal(1)
	assert_int(_run.stash_sell_value(0)).is_equal(1)
	# With a drone installed, for its full cost.
	assert_bool(_run.grid.place_part(Fixtures.scrapper_drone(), Vector2i(1, 0))).is_true()
	assert_bool(_run.refunds_in_full()).is_true()
	assert_int(_run.sell_value(Vector2i(3, 1))).is_equal(3)
	assert_int(_run.stash_sell_value(0)).is_equal(2)
	var gold := _run.gold
	assert_int(_run.sell(Vector2i(3, 1))).is_equal(3)
	assert_int(_run.gold).is_equal(gold + 3)
	# A drone in the stash does nothing.
	assert_bool(_run.unequip(Vector2i(1, 0))).is_true()
	assert_bool(_run.refunds_in_full()).is_false()
	assert_int(_run.stash_sell_value(0)).is_equal(1)


func test_the_shop_only_trades_while_open() -> void:
	_run.close_shop()
	assert_bool(_run.can_sell()).is_false()
	assert_bool(_run.buy(0, Vector2i(1, 1))).is_false()
	assert_bool(_run.reroll()).is_false()
	assert_bool(_run.rotate_slot(0)).is_false()
	assert_object(_run.preview_buy(0, Vector2i(1, 1))).is_null()
	assert_int(_run.gold).is_equal(10)
	# Positive control: reopened, it trades again.
	_run.open_shop()
	assert_bool(_run.can_sell()).is_true()
	assert_bool(_run.buy(_slot_of(_laser), Vector2i(1, 1))).is_true()


func test_reroll_costs_gold_and_restocks() -> void:
	assert_bool(_run.buy(_slot_of(_laser), Vector2i(1, 1))).is_true() # 10 -> 8
	assert_bool(_run.reroll()).is_true()
	assert_int(_run.gold).is_equal(7)
	assert_array(_run.shop.slots).has_size(4)
	for slot in _run.shop.slots:
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


func test_hull_damage_carries_over_from_a_won_fight() -> void:
	assert_bool(_run.grid.place_part(Fixtures.laser(), Vector2i(1, 1))).is_true() # 30 + 12 = 42 HP
	var mech := _run.make_player_mech()
	assert_int(mech.max_hp).is_equal(42)
	assert_int(mech.current_health).is_equal(42)
	mech.take_damage(15)
	_run.record_fight(RunState.FightResult.WIN, mech)
	assert_int(_run.hull_damage).is_equal(15)
	assert_int(_run.get_current_hp()).is_equal(27)
	assert_int(_run.fights_won).is_equal(1)
	assert_bool(_run.is_over()).is_false()
	# The next fight starts where this one left off.
	assert_int(_run.make_player_mech().current_health).is_equal(27)


func test_a_lost_or_drawn_fight_ends_the_run() -> void:
	var mech := _run.make_player_mech()
	mech.take_damage(999)
	_run.record_fight(RunState.FightResult.LOSS, mech)
	assert_bool(_run.is_over()).is_true()
	assert_int(_run.outcome).is_equal(RunState.Outcome.DEFEAT)
	assert_int(_run.get_current_hp()).is_equal(0)
	assert_int(_run.fights_won).is_equal(0)
	var draw := _new_run(5)
	var both_down := draw.make_player_mech()
	both_down.take_damage(999)
	draw.record_fight(RunState.FightResult.DRAW, both_down)
	assert_int(draw.outcome).is_equal(RunState.Outcome.DEFEAT)


func test_hp_parts_raise_current_hp_and_reinstalling_does_not_heal() -> void:
	_run.hull_damage = 10
	assert_int(_run.get_current_hp()).is_equal(20) # 30 - 10
	# Two touching lasers, plated: 12 + 4 each.
	assert_bool(_run.grid.place_part(Fixtures.laser(), Vector2i(0, 1))).is_true()
	assert_bool(_run.grid.place_part(Fixtures.laser(), Vector2i(0, 2))).is_true()
	assert_int(_run.get_max_hp()).is_equal(62)
	assert_int(_run.get_current_hp()).is_equal(52) # raised with the max, still 10 down
	# Taking a laser out and putting it back leaves the damage as it was.
	assert_bool(_run.unequip(Vector2i(0, 2))).is_true()
	assert_int(_run.get_current_hp()).is_equal(32)
	assert_bool(_run.install(0, Vector2i(0, 2))).is_true()
	assert_int(_run.get_current_hp()).is_equal(52)
	assert_int(_run.hull_damage).is_equal(10)


func test_current_hp_never_drops_below_1_while_the_run_goes_on() -> void:
	assert_bool(_run.grid.place_part(Fixtures.laser(), Vector2i(1, 1))).is_true()
	_run.hull_damage = 40 # of 42
	assert_int(_run.get_current_hp()).is_equal(2)
	assert_bool(_run.unequip(Vector2i(1, 1))).is_true() # the max drops to 30, under the damage
	assert_int(_run.get_current_hp()).is_equal(1)


func test_heal_and_damage_hull() -> void:
	_run.hull_damage = 20
	assert_int(_run.heal(5)).is_equal(5)
	assert_int(_run.hull_damage).is_equal(15)
	assert_int(_run.heal(100)).is_equal(15) # only what's missing
	assert_int(_run.hull_damage).is_equal(0)
	_run.damage_hull(12)
	assert_int(_run.get_current_hp()).is_equal(18)
	# Damage outside a fight leaves at least 1 HP.
	_run.damage_hull(999)
	assert_int(_run.get_current_hp()).is_equal(1)
	assert_bool(_run.is_over()).is_false()
	assert_int(_changes).is_equal(4)


func test_stash_install_and_unequip() -> void:
	_run.stash_part(_heatsink, 1)
	assert_array(_run.stash).has_size(1)
	assert_object(_run.stash[0].part).is_not_same(_heatsink) # the run's own copy
	assert_int(_run.stash[0].rotation).is_equal(1)
	# Upright it would hit the (3, 3) corner at (2, 2); it's stashed turned once, so it fits.
	var preview := _run.preview_install(0, Vector2i(2, 2))
	assert_int(preview.fit).is_equal(MechGridData.Fit.OK)
	assert_object(preview.stats).is_not_null()
	assert_array(_run.stash).has_size(1) # a preview installs nothing
	assert_bool(_run.install(0, Vector2i(2, 2))).is_true()
	assert_array(_run.stash).is_empty()
	for cell: Vector2i in [Vector2i(2, 2), Vector2i(3, 2), Vector2i(2, 3)]:
		assert_object(_run.grid.get_part_at(cell)).is_not_null()
	# Back to the stash, keeping its turn.
	assert_bool(_run.unequip(Vector2i(3, 2))).is_true()
	assert_int(_run.grid.get_used_cell_count()).is_equal(0)
	assert_array(_run.stash).has_size(1)
	assert_int(_run.stash[0].rotation).is_equal(1)
	assert_int(_changes).is_equal(3)


func test_the_stash_rejects_what_does_not_fit() -> void:
	_run.stash_part(_gatling)
	assert_bool(_run.install(0, Vector2i(1, 1))).is_false() # weapons only go in bays
	assert_bool(_run.install(5, LEFT_ARM)).is_false()       # no such stash entry
	assert_bool(_run.unequip(Vector2i(1, 1))).is_false()     # nothing there
	assert_object(_run.preview_install(5, LEFT_ARM)).is_null()
	assert_array(_run.stash).has_size(1)
	# Weapons don't turn in the stash either; other parts do.
	assert_bool(_run.rotate_stashed(0)).is_false()
	_run.stash_part(_reactor)
	assert_bool(_run.rotate_stashed(1)).is_true()
	assert_int(_run.stash[1].rotation).is_equal(1)
	# Positive control: the gatling installs in a bay.
	assert_bool(_run.install(0, LEFT_ARM)).is_true()


func test_sectors_give_a_map_and_the_run_travels_it() -> void:
	var run := _sector_run(3)
	assert_object(run.map).is_not_null()
	assert_object(run.get_act()).is_same(run.acts[0])
	assert_int(run.get_floor_number()).is_equal(0)
	# The whole bottom floor is open at first; nothing else is.
	assert_array(run.get_reachable()).contains_same_exactly(run.map.floors[0])
	var first: MapNode = run.get_reachable()[0]
	assert_bool(run.travel(run.map.boss)).is_false()
	assert_bool(run.travel(first)).is_true()
	assert_bool(first.visited).is_true()
	assert_int(run.get_floor_number()).is_equal(1)
	assert_array(run.get_reachable()).contains_same_exactly(first.next)
	# Nowhere to go once the run is over.
	run.outcome = RunState.Outcome.DEFEAT
	assert_bool(run.travel(first.next[0])).is_false()


func test_fights_pick_the_sectors_enemy_of_the_nodes_tier() -> void:
	var run := _sector_run(3)
	var node: MapNode = run.get_reachable()[0]
	assert_bool(run.travel(node)).is_true()
	var enemy := run.get_enemy()
	assert_int(enemy.tier).is_equal(EnemyLoadout.Tier.NORMAL)
	# Picked once, then kept on the node.
	assert_object(run.get_enemy()).is_same(enemy)
	assert_object(node.enemy).is_same(enemy)
	# Its HP is scaled for the sector and the floor: 30 × 1.5 on floor 0. It goes by its name.
	var mech := run.make_enemy_mech()
	assert_int(mech.max_hp).is_equal(45)
	assert_str(mech.mech_name).is_equal(enemy.enemy_name)
	# Two floors up, +10% a floor: 30 × 1.5 × 1.2.
	assert_int(run.make_enemy_mech(MapNode.new(2, 0)).max_hp).is_equal(54)
	# An elite comes from the elites, and the boss was picked with the map, from the bosses.
	assert_int(run.get_enemy(MapNode.new(5, 0, MapNode.Type.ELITE)).tier).is_equal(EnemyLoadout.Tier.ELITE)
	assert_int(run.map.boss.enemy.tier).is_equal(EnemyLoadout.Tier.BOSS)


func test_the_same_enemy_does_not_come_twice_in_a_row() -> void:
	var run := _sector_run(1)
	for i in 20:
		var a := run.get_enemy(MapNode.new(1, 0))
		var b := run.get_enemy(MapNode.new(1, 0))
		assert_object(b).append_failure_message("roll %d" % i).is_not_same(a)


func test_next_act_repairs_half_the_damage_then_ends_in_victory() -> void:
	var run := _sector_run(2)
	var first_map := run.map
	run.hull_damage = 9
	run.next_act()
	assert_int(run.act_index).is_equal(1)
	assert_object(run.map).is_not_same(first_map)
	assert_object(run.map.act).is_same(run.acts[1])
	assert_object(run.map.current).is_null()
	assert_int(run.hull_damage).is_equal(4) # half of 9, rounded up, repaired
	assert_bool(run.is_over()).is_false()
	run.next_act()
	assert_int(run.outcome).is_equal(RunState.Outcome.VICTORY)


func test_a_won_fight_drops_gold_and_a_draft() -> void:
	var run := _loot_run()
	var gold_before := run.gold
	assert_bool(run.travel(run.get_reachable()[0])).is_true()
	var reward := run.roll_reward()
	assert_int(reward.tier).is_equal(EnemyLoadout.Tier.NORMAL)
	# The fixture sector drops 8-12 gold for a battle, added at once.
	assert_int(reward.gold).is_between(8, 12)
	assert_int(run.gold).is_equal(gold_before + reward.gold)
	# Three different parts from the run's catalog.
	assert_array(reward.parts).has_size(3)
	for part in reward.parts:
		assert_bool(part in run.catalog).is_true()
	assert_bool(reward.is_draft_open()).is_true()
	# Elites and bosses drop more.
	assert_int(run.roll_reward(MapNode.new(6, 0, MapNode.Type.ELITE)).gold).is_between(18, 25)
	assert_int(run.roll_reward(run.map.boss).gold).is_between(35, 45)


func test_taking_a_drafted_part_stashes_it_and_closes_the_draft() -> void:
	var run := _loot_run()
	assert_bool(run.travel(run.get_reachable()[0])).is_true()
	var reward := run.roll_reward()
	assert_bool(run.take_reward_part(reward, 5)).is_false() # no such part
	assert_array(run.stash).is_empty()
	assert_bool(run.take_reward_part(reward, 1)).is_true()
	assert_array(run.stash).has_size(1)
	assert_str(run.stash[0].part.part_name).is_equal(reward.parts[1].part_name)
	assert_object(run.stash[0].part).is_not_same(reward.parts[1]) # the run's own copy
	assert_int(reward.taken).is_equal(1)
	assert_bool(reward.is_draft_open()).is_false()
	# Only one per draft.
	assert_bool(run.take_reward_part(reward, 0)).is_false()
	assert_array(run.stash).has_size(1)


func test_rare_pity_carries_between_fights() -> void:
	var run := _loot_run()
	assert_bool(run.travel(run.get_reachable()[0])).is_true()
	# The fixture catalog is all common, so every draft raises the pity for the next.
	run.roll_reward()
	assert_float(run.loot.rare_pity).is_equal(4.5)
	run.roll_reward()
	assert_float(run.loot.rare_pity).is_equal(9.0)


func test_relics_are_the_runs_own_copies_and_leave_the_pool() -> void:
	var run := _loot_run()
	var frame := ReinforcedFrame.new()
	frame.hp = 40
	var pooled := run.relic_pool.size()
	var owned := run.add_relic(frame)
	assert_object(owned).is_not_same(frame)
	assert_array(run.relics).contains_same_exactly([owned])
	# Not in the pool (it wasn't), and the pool keeps the rest.
	assert_int(run.relic_pool.size()).is_equal(pooled)
	# The hull and the fight both count it.
	assert_int(run.get_max_hp()).is_equal(70)
	assert_int(run.make_player_mech().max_hp).is_equal(70)
	assert_array(run.make_player_mech().relics).contains_same_exactly([owned])
	# A relic still in the pool leaves it once found.
	var relics := Fixtures.relics()
	var other := RunState.new(Fixtures.armed_cross(), [], [], 10, RunRng.new(1), [], relics)
	assert_bool(other.relic_pool.has(relics[0])).is_true()
	other.add_relic(relics[0])
	assert_bool(other.relic_pool.has(relics[0])).is_false()
	assert_int(other.relic_pool.size()).is_equal(relics.size() - 1)


func test_elites_drop_a_relic_and_bosses_offer_three() -> void:
	var run := _loot_run()
	assert_bool(run.travel(run.get_reachable()[0])).is_true()
	assert_array(run.roll_reward().relics).is_empty() # a battle drops none
	var elite := run.roll_reward(MapNode.new(6, 0, MapNode.Type.ELITE))
	assert_array(elite.relics).has_size(1)
	assert_int(elite.relics[0].rarity).is_not_equal(Relic.Rarity.BOSS)
	assert_bool(run.relic_pool.has(elite.relics[0])).is_false()
	var boss := run.roll_reward(run.map.boss)
	# The fixtures have two boss relics, so that's all the boss can offer.
	assert_array(boss.relics).has_size(2)
	for relic in boss.relics:
		assert_int(relic.rarity).is_equal(Relic.Rarity.BOSS)
	# Take one; the offer closes.
	assert_bool(run.take_reward_relic(boss, 5)).is_false()
	assert_bool(run.take_reward_relic(boss, 1)).is_true()
	assert_str(run.relics[0].relic_name).is_equal(boss.relics[1].relic_name)
	assert_bool(boss.is_relic_open()).is_false()
	assert_bool(run.take_reward_relic(boss, 0)).is_false()
	assert_array(run.relics).has_size(1)


func test_relics_change_the_gold_a_fight_drops() -> void:
	var run := _loot_run()
	assert_bool(run.travel(run.get_reachable()[0])).is_true()
	var chest := WarChest.new()
	chest.gold = 0
	chest.bonus = 1.0 # doubles it
	run.add_relic(chest)
	var gold_before := run.gold
	var reward := run.roll_reward()
	assert_int(reward.gold).is_between(16, 24) # 8-12, doubled
	assert_int(reward.gold % 2).is_equal(0)
	assert_int(run.gold).is_equal(gold_before + reward.gold)


func test_a_hangar_repairs_or_reinforces() -> void:
	assert_bool(_run.grid.place_part(Fixtures.laser(), Vector2i(1, 1))).is_true() # 42 max HP
	_run.hull_damage = 30
	# Repair: 30% of 42 is 12.6, rounded up to 13.
	assert_int(_run.repair_at_hangar()).is_equal(13)
	assert_int(_run.hull_damage).is_equal(17)
	# Never more than what's missing.
	_run.hull_damage = 5
	assert_int(_run.repair_at_hangar()).is_equal(5)
	# Reinforce: +25 max HP for good, as an upgrade rather than a relic.
	_run.reinforce_at_hangar()
	assert_int(_run.get_max_hp()).is_equal(67)
	assert_array(_run.relics).is_empty()
	assert_array(_run.get_modifiers()).has_size(1)


func test_a_shop_sells_relics_from_the_back_of_the_pool() -> void:
	var run := _loot_run()
	run.open_shop()
	var offers := run.shop.relic_offers
	assert_array(offers).has_size(2)
	for offer in offers:
		assert_bool(offer.relic.rarity in [Relic.Rarity.COMMON, Relic.Rarity.UNCOMMON, Relic.Rarity.RARE]).is_true()
		assert_bool(run.relic_pool.has(offer.relic)).is_false()
	# Buying one pays its price and gives the relic.
	run.gold = offers[0].price
	assert_bool(run.buy_relic(0)).is_true()
	assert_int(run.gold).is_equal(0)
	assert_str(run.relics[0].relic_name).is_equal(offers[0].relic.relic_name)
	assert_bool(offers[0].sold).is_true()
	# Sold, unaffordable, or no such offer: nothing.
	run.gold = 1000
	assert_bool(run.buy_relic(0)).is_false()
	assert_bool(run.buy_relic(5)).is_false()
	run.gold = offers[1].price - 1
	assert_bool(run.buy_relic(1)).is_false()
	assert_array(run.relics).has_size(1)


func test_buying_into_the_stash() -> void:
	var slot := _slot_of(_heatsink)
	assert_bool(_run.rotate_slot(slot)).is_true()
	assert_bool(_run.buy_to_stash(slot)).is_true()
	assert_int(_run.gold).is_equal(6)
	assert_array(_run.stash).has_size(1)
	assert_int(_run.stash[0].rotation).is_equal(1)
	assert_bool(_run.shop.slots[slot].sold).is_true()
	# Bought here, so it sells back in full.
	assert_bool(_run.is_stash_fresh(0)).is_true()
	assert_int(_run.stash_sell_value(0)).is_equal(4)
	# A sold slot or too little gold buys nothing.
	assert_bool(_run.buy_to_stash(slot)).is_false()
	_run.gold = 0
	assert_bool(_run.buy_to_stash(_slot_of(_laser))).is_false()
	assert_array(_run.stash).has_size(1)


func test_unsellable_parts_stay() -> void:
	var junk := Fixtures.part("Glitch", MechPart.PartType.JUNK, [Vector2i(0, 0)], 4)
	junk.sellable = false
	_run.stash_part(junk)
	assert_bool(_run.can_sell_part(_run.stash[0].part)).is_false()
	assert_int(_run.sell_stashed(0)).is_equal(0)
	assert_array(_run.stash).has_size(1)
	assert_bool(_run.install(0, Vector2i(1, 1))).is_true()
	assert_int(_run.sell(Vector2i(1, 1))).is_equal(0)
	assert_object(_run.grid.get_part_at(Vector2i(1, 1))).is_not_null()
	# Positive control: a sellable part sells.
	_run.stash_part(_laser)
	assert_int(_run.sell_stashed(0)).is_equal(1)


func test_merging_from_the_stash_raises_the_installed_part() -> void:
	assert_bool(_run.grid.place_part(Fixtures.laser(), Vector2i(1, 1))).is_true()
	_run.stash_part(Fixtures.laser())
	var target := _run.grid.get_part_at(Vector2i(1, 1))
	assert_bool(_run.merge_from_stash(0, Vector2i(1, 1))).is_true()
	assert_int(target.level).is_equal(2)
	assert_array(_run.stash).is_empty()
	assert_int(_run.get_max_hp()).is_equal(48) # 30 + 12 × 1.5
	# A different part, an empty cell, or no such stash entry: nothing.
	_run.stash_part(Fixtures.reactor())
	assert_bool(_run.merge_from_stash(0, Vector2i(1, 1))).is_false()
	assert_bool(_run.merge_from_stash(0, Vector2i(2, 2))).is_false()
	assert_bool(_run.merge_from_stash(4, Vector2i(1, 1))).is_false()
	assert_array(_run.stash).has_size(1)


func test_merging_on_the_grid_frees_the_source() -> void:
	assert_bool(_run.grid.place_part(Fixtures.laser(), Vector2i(1, 1))).is_true()
	assert_bool(_run.grid.place_part(Fixtures.laser(), Vector2i(2, 2))).is_true()
	assert_bool(_run.merge_on_grid(Vector2i(2, 2), Vector2i(1, 1))).is_true()
	assert_object(_run.grid.get_part_at(Vector2i(2, 2))).is_null()
	assert_int(_run.grid.get_part_at(Vector2i(1, 1)).level).is_equal(2)
	# A Mk II doesn't take a Mk I.
	assert_bool(_run.grid.place_part(Fixtures.laser(), Vector2i(2, 2))).is_true()
	assert_bool(_run.merge_on_grid(Vector2i(2, 2), Vector2i(1, 1))).is_false()
	assert_bool(_run.merge_on_grid(Vector2i(1, 1), Vector2i(1, 1))).is_false() # not into itself


func test_merging_within_and_into_the_stash() -> void:
	_run.stash_part(Fixtures.heatsink())
	_run.stash_part(Fixtures.heatsink())
	assert_bool(_run.merge_stash(1, 0)).is_true()
	assert_array(_run.stash).has_size(1)
	assert_int(_run.stash[0].part.level).is_equal(2)
	assert_bool(_run.merge_stash(0, 0)).is_false()
	# An installed Mk II merges into a stashed Mk II, leaving the grid.
	var installed := Fixtures.heatsink()
	installed.level = 2
	assert_bool(_run.grid.place_part(installed, Vector2i(1, 1))).is_true()
	assert_bool(_run.merge_into_stash(Vector2i(1, 1), 0)).is_true()
	assert_int(_run.stash[0].part.level).is_equal(3)
	assert_int(_run.grid.get_used_cell_count()).is_equal(0)


func test_buying_straight_into_a_merge() -> void:
	var laser_slot := _slot_of(_laser)
	assert_bool(_run.grid.place_part(Fixtures.laser(), Vector2i(1, 1))).is_true()
	assert_bool(_run.buy_and_merge(laser_slot, Vector2i(1, 1))).is_true()
	assert_int(_run.gold).is_equal(8)
	assert_int(_run.grid.get_part_at(Vector2i(1, 1)).level).is_equal(2)
	assert_array(_run.stash).is_empty()
	assert_bool(_run.shop.slots[laser_slot].sold).is_true()
	# A part it can't merge with costs nothing.
	assert_bool(_run.buy_and_merge(_slot_of(_reactor), Vector2i(1, 1))).is_false()
	assert_int(_run.gold).is_equal(8)


func test_preview_merge_shows_the_stats_without_merging() -> void:
	assert_bool(_run.grid.place_part(Fixtures.laser(), Vector2i(1, 1))).is_true()
	var preview := _run.preview_merge(Fixtures.laser(), Vector2i(1, 1))
	assert_bool(preview.merge).is_true()
	assert_int(preview.fit).is_equal(MechGridData.Fit.OK)
	assert_int(preview.stats.hp).is_equal(48)
	assert_int(_run.grid.get_part_at(Vector2i(1, 1)).level).is_equal(1) # nothing changed
	assert_object(_run.preview_merge(Fixtures.reactor(), Vector2i(1, 1))).is_null()


func test_upgrades_and_what_can_take_one() -> void:
	assert_bool(_run.grid.place_part(Fixtures.laser(), Vector2i(1, 1))).is_true()
	_run.stash_part(Fixtures.heatsink())
	var junk := Fixtures.part("Glitch", MechPart.PartType.JUNK, [Vector2i(0, 0)])
	_run.stash_part(junk)
	var upgradable := _run.get_upgradable_parts()
	assert_array(upgradable.map(func(part: MechPart) -> String: return part.part_name)) \
		.contains_exactly(["Point-Defense Laser", "L-Shaped Heatsink"]) # installed first, no junk
	var laser := upgradable[0]
	assert_bool(_run.upgrade_part(laser)).is_true()
	assert_bool(_run.upgrade_part(laser)).is_true()
	assert_bool(_run.upgrade_part(laser)).is_false() # Mk III is the top
	assert_array(_run.get_upgradable_parts()).has_size(1)


func test_a_higher_mk_sells_for_more() -> void:
	var laser := Fixtures.laser() # 2 gold
	laser.level = 3
	_run.stash_part(laser)
	assert_int(_run.stash_sell_value(0)).is_equal(3) # 2 × 3, halved
	# Bought here and merged with a part bought here: a full refund on both halves.
	var slot := _slot_of(_laser)
	assert_bool(_run.buy(slot, Vector2i(1, 1))).is_true()
	_run.shop.slots[slot].sold = false
	assert_bool(_run.buy_and_merge(slot, Vector2i(1, 1))).is_true()
	assert_int(_run.sell_value(Vector2i(1, 1))).is_equal(4)


func test_stashed_parts_sell_at_a_shop() -> void:
	_run.stash_part(_heatsink) # 4 gold, not bought here: half
	assert_int(_run.stash_sell_value(0)).is_equal(2)
	assert_bool(_run.is_stash_fresh(0)).is_false()
	assert_int(_run.sell_stashed(3)).is_equal(0) # no such part
	assert_int(_run.sell_stashed(0)).is_equal(2)
	assert_array(_run.stash).is_empty()
	assert_int(_run.gold).is_equal(12)
	# A part bought here and stored in the stash still sells back in full.
	assert_bool(_run.buy(_slot_of(_laser), Vector2i(1, 1))).is_true() # 12 -> 10
	assert_bool(_run.unequip(Vector2i(1, 1))).is_true()
	assert_bool(_run.is_stash_fresh(0)).is_true()
	assert_int(_run.stash_sell_value(0)).is_equal(2)
	# Away from a shop, nothing sells.
	_run.close_shop()
	assert_int(_run.sell_stashed(0)).is_equal(0)
	assert_array(_run.stash).has_size(1)


func test_a_sector_can_lay_out_its_own_map() -> void:
	# A generator that makes just a boss, standing in for a sector's own layout.
	var script := GDScript.new()
	script.source_code = "extends MapGenerator\n\nfunc generate(act: ActData, _rng: RandomNumberGenerator) -> MapGraph:\n" \
		+ "\tvar graph := MapGraph.new()\n\tgraph.act = act\n\tgraph.boss = MapNode.new(0, 0, MapNode.Type.BOSS)\n\treturn graph\n"
	assert_int(script.reload()).is_equal(OK)
	var act := Fixtures.act()
	act.generator = script
	var acts: Array[ActData] = [act]
	var run := RunState.new(Fixtures.cross_chassis(), [], [], 10, RunRng.new(1), acts)
	assert_array(run.map.floors).is_empty()
	assert_array(run.map.get_nodes()).contains_same_exactly([run.map.boss])
	# Positive control: without one, it's the standard map.
	assert_array(_sector_run(1).map.floors).has_size(12)


func test_the_same_seed_gives_the_same_run() -> void:
	var a := _sector_run(2, 77)
	var b := _sector_run(2, 77)
	assert_array(_map_summary(a.map)).is_equal(_map_summary(b.map))
	assert_str(a.map.boss.enemy.enemy_name).is_equal(b.map.boss.enemy.enemy_name)
	# Positive control: another seed gives another map.
	assert_array(_map_summary(_sector_run(2, 78).map)).is_not_equal(_map_summary(a.map))


func _new_run(rng_seed: int) -> RunState:
	var run := RunState.new(Fixtures.armed_cross(), [_gatling, _laser, _reactor, _heatsink],
		[Fixtures.cooled(), Fixtures.overcharge(), Fixtures.stable(), Fixtures.plated()], 10, RunRng.new(rng_seed))
	run.open_shop()
	return run


# A run on the bare cross (30 HP) through [param act_count] of the fixture sectors, with enemy
# HP ×1.5 and +10% a floor.
func _sector_run(act_count: int, rng_seed := 1) -> RunState:
	var acts: Array[ActData] = []
	for i in act_count:
		acts.append(Fixtures.act(1.5, 0.1))
	return RunState.new(Fixtures.cross_chassis(), [], [], 10, RunRng.new(rng_seed), acts)


# A run through one fixture sector, with the four fixture parts (all common) to loot.
func _loot_run() -> RunState:
	var acts: Array[ActData] = [Fixtures.act()]
	return RunState.new(Fixtures.armed_cross(), [_gatling, _laser, _reactor, _heatsink], [], 10, RunRng.new(3), acts,
		Fixtures.relics())


# Each node's id, type, and links, to compare two maps.
func _map_summary(map: MapGraph) -> Array[String]:
	var summary: Array[String] = []
	for node in map.get_nodes():
		summary.append("%s:%d:%s" % [node.id, node.type, ",".join(node.next.map(func(n: MapNode) -> String: return n.id))])
	return summary


func _slot_of(part: MechPart) -> int:
	for i in _run.shop.slots.size():
		if _run.shop.slots[i].part == part:
			return i
	return -1


func _parts_of(run: RunState) -> Array[MechPart]:
	var parts: Array[MechPart] = []
	for slot in run.shop.slots:
		parts.append(slot.part)
	return parts
