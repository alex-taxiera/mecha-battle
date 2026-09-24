class_name RelicHooksTest
extends GdUnitTestSuite
## The relic hooks for a fight's end, the map, and shops.

const __source: String = "res://src/data/Relic.gd"
const Fixtures := preload("res://test/TestFixtures.gd")


# Records every hook it sees, takes 2 off part prices, makes rerolls free, and adds a note to
# each shop it opens.
class Recorder:
	extends Relic

	var seen: Array[String] = []

	func on_fight_end(_mech: BattleMech, won: bool) -> void:
		seen.append("won" if won else "lost")

	func on_node_entered(_run: RunState, node: MapNode) -> void:
		seen.append("entered %s" % node.id)

	func on_shop_opened(_run: RunState, shop: ShopStock) -> void:
		seen.append("shop of %d" % shop.slots.size())

	func modify_part_price(_part: MechPart, price: int) -> int:
		return price - 2

	func modify_reroll_cost(_run: RunState, _cost: int) -> int:
		return 0


func test_relics_hear_how_the_fight_ended() -> void:
	var mine := Recorder.new()
	var theirs := Recorder.new()
	var winner := _gunner([mine])
	var loser := BattleMech.new(MechGridData.new(Fixtures.cross_chassis()), [], 1.0, -1, [theirs] as Array[Relic])
	var engine := CombatEngine.new(winner, loser)
	engine.start()
	while engine.state == CombatEngine.State.RUNNING:
		engine.process_tick(0.1)
	assert_array(mine.seen).contains_exactly(["won"])
	assert_array(theirs.seen).contains_exactly(["lost"])


func test_relics_hear_each_node_entered() -> void:
	var run := _run()
	var relic: Recorder = run.add_relic(Recorder.new())
	var node: MapNode = run.get_reachable()[0]
	assert_bool(run.travel(node)).is_true()
	assert_array(relic.seen).contains_exactly(["entered %s" % node.id])
	# Positive control: a refused step isn't heard.
	assert_bool(run.travel(node)).is_false()
	assert_array(relic.seen).has_size(1)


func test_relics_change_shop_prices_and_hear_it_open() -> void:
	var gun := Fixtures.gatling() # 4 gold
	var run := _run([gun])
	assert_int(run.price_of(gun)).is_equal(4)
	assert_int(run.get_reroll_cost()).is_equal(1)
	var relic: Recorder = run.add_relic(Recorder.new())
	assert_int(run.price_of(gun)).is_equal(2)
	# Never below free.
	assert_int(run.price_of(Fixtures.laser())).is_equal(0)
	run.gold = 5
	run.open_shop()
	assert_array(relic.seen).contains_exactly(["shop of %d" % run.shop.slots.size()])
	assert_int(run.get_reroll_cost()).is_equal(0)
	assert_bool(run.reroll()).is_true()
	assert_int(run.gold).is_equal(5)


func _run(catalog: Array[MechPart] = []) -> RunState:
	var acts: Array[ActData] = [Fixtures.act()]
	return RunState.new(Fixtures.armed_cross(), catalog, [], 10, RunRng.new(1), acts)


func _gunner(relics: Array[Relic]) -> BattleMech:
	var grid := MechGridData.new(Fixtures.armed_cross())
	var gun := Fixtures.part("Gun", MechPart.PartType.WEAPON, Fixtures.ARM_SHAPE, 0, {"damage": 50, "cooldown_max": 0.5})
	assert_bool(grid.place_part(gun, Vector2i(-1, 1))).is_true()
	return BattleMech.new(grid, [], 1.0, -1, relics)
