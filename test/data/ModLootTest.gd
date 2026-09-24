class_name ModLootTest
extends GdUnitTestSuite
## Weapon mods as loot: the run's mod pool, an elite's mod offer, shop mods, and the Hangar's Refit.

const __source: String = "res://src/data/RunState.gd"
const Fixtures := preload("res://test/TestFixtures.gd")
const LEFT_ARM := Vector2i(-1, 1)


func test_a_rolled_mod_fits_the_strongest_weapon_and_is_new_to_it() -> void:
	var run := _armed_run([Fixtures.rapid_mod(), Fixtures.siphon_mod()])
	var weapon := WeaponModEffect.strongest_weapon(run)
	weapon.mod = run.mod_pool[0]
	for i in 10:
		assert_object(run.roll_mod()).is_same(run.mod_pool[1])
	# Nothing to offer: no pool, or no weapon.
	assert_object(_armed_run([]).roll_mod()).is_null()
	var bare := RunState.new(Fixtures.armed_cross(), [], [], 10, RunRng.new(1))
	bare.mod_pool.assign([Fixtures.rapid_mod()])
	assert_object(bare.roll_mod()).is_null()


func test_fitting_a_mod_replaces_the_old_one() -> void:
	var run := _armed_run([])
	var rapid := Fixtures.rapid_mod()
	var weapon := run.fit_mod(rapid)
	assert_object(weapon).is_same(WeaponModEffect.strongest_weapon(run))
	assert_object(weapon.mod).is_same(rapid)
	assert_str(weapon.get_display_name()).is_equal("Rapid Twin Gatling")
	run.fit_mod(Fixtures.siphon_mod())
	assert_str(weapon.get_display_name()).is_equal("Siphon Twin Gatling")


func test_an_elite_offers_a_mod_instead_of_its_relic() -> void:
	var run := _armed_run([Fixtures.rapid_mod()], Fixtures.relics())
	var elite := _node_of(run, MapNode.Type.ELITE)
	var reward := run.roll_reward(elite)
	assert_object(reward.mod).is_not_null()
	assert_bool(run.take_reward_mod(reward)).is_true()
	assert_int(reward.relic_taken).is_equal(FightReward.MOD_TAKEN)
	assert_str(WeaponModEffect.strongest_weapon(run).get_display_name()).is_equal("Rapid Twin Gatling")
	# One thing from the group.
	assert_bool(run.take_reward_relic(reward, 0)).is_false()
	assert_array(run.relics).is_empty()
	# Positive control: a normal battle offers no mod.
	assert_object(run.roll_reward(_node_of(run, MapNode.Type.BATTLE)).mod).is_null()


func test_a_shop_sells_a_mod_for_the_strongest_weapon() -> void:
	var run := _armed_run([Fixtures.rapid_mod()])
	run.gold = 100
	run.open_shop()
	assert_array(run.shop.mod_offers).has_size(1)
	var offer: ShopStock.ModOffer = run.shop.mod_offers[0]
	assert_int(offer.price).is_between(RunState.MOD_PRICES.x, RunState.MOD_PRICES.y)
	assert_bool(run.buy_mod(0)).is_true()
	assert_int(run.gold).is_equal(100 - offer.price)
	assert_str(WeaponModEffect.strongest_weapon(run).get_display_name()).is_equal("Rapid Twin Gatling")
	assert_bool(run.buy_mod(0)).is_false()
	# Too dear: nothing changes.
	var poor := _armed_run([Fixtures.rapid_mod()])
	poor.gold = 0
	poor.open_shop()
	assert_bool(poor.buy_mod(0)).is_false()
	assert_object(WeaponModEffect.strongest_weapon(poor).mod).is_null()


func test_a_shop_without_a_weapon_or_mods_sells_none() -> void:
	var bare := RunState.new(Fixtures.armed_cross(), [Fixtures.laser()], [], 10, RunRng.new(1))
	bare.mod_pool.assign([Fixtures.rapid_mod()])
	bare.open_shop()
	assert_array(bare.shop.mod_offers).is_empty()
	var empty := _armed_run([])
	empty.open_shop()
	assert_array(empty.shop.mod_offers).is_empty()


func test_a_refit_fits_a_random_mod() -> void:
	var run := _armed_run([Fixtures.stabilized_mod()])
	var refit := WeaponModEffect.new()
	assert_str(refit.describe(run)).is_equal("Fit a random mod to your Twin Gatling.")
	var result := EventResult.new()
	refit.apply(run, result)
	assert_array(result.lines).contains_exactly(["Twin Gatling is now the Stabilized Twin Gatling"])
	# A named mod says so.
	refit.mod = Fixtures.rapid_mod()
	assert_str(refit.describe(run)).is_equal("Fit Rapid to your Stabilized Twin Gatling.")


# A one-sector run on the armed cross with a gatling in its left arm and [param mods] to offer.
func _armed_run(mods: Array, relics: Array[Relic] = []) -> RunState:
	var chassis := Fixtures.armed_cross()
	chassis.starter_lineup = [LoadoutPart.make(Fixtures.gatling(), LEFT_ARM)]
	var acts: Array[ActData] = [Fixtures.act()]
	var run := RunState.new(chassis, [Fixtures.laser()], [], 10, RunRng.new(3), acts, relics)
	run.mod_pool.assign(mods)
	return run


func _node_of(run: RunState, type: MapNode.Type) -> MapNode:
	for node in run.map.get_nodes():
		if node.type == type:
			return node
	assert_bool(false).append_failure_message("no node of type %d" % type).is_true()
	return null
