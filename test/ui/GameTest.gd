class_name GameTest
extends GdUnitTestSuite

const __source: String = "res://src/ui/Game.gd"
const SCENE := preload("res://src/ui/Game.tscn")
const Fixtures := preload("res://test/TestFixtures.gd")
# Enough ticks for any fight here to end; stops a broken flow hanging the run.
const MAX_TICKS := 10000

var _gatling: MechPart  # 8 damage for 3 energy, every second
var _heatsink: MechPart # cools a weapon it touches: damage × 1.5
var _game: Game


func before_test() -> void:
	_gatling = _gun()
	_heatsink = Fixtures.heatsink()
	_game = auto_free(SCENE.instantiate())
	_game.catalog = [_gatling, Fixtures.laser(), Fixtures.reactor(), _heatsink]
	_game.rules = Fixtures.rules()
	_game.make_opponent = func() -> BattleMech: return _bare_mech()
	add_child(_game)


func test_the_run_starts_by_choosing_a_chassis() -> void:
	assert_bool(_game.chassis_select.is_inside_tree()).is_true()
	assert_object(_game.shop).is_null()
	assert_object(_game.combat).is_null()
	# Choosing one opens the shop on it, with the run's parts.
	var bastion := Fixtures.bastion()
	await _choose(bastion)
	assert_object(_game.chassis_select).is_null()
	assert_bool(_game.shop.is_inside_tree()).is_true()
	assert_object(_game.shop.run.grid.chassis).is_same(bastion)
	assert_array(_game.shop.run.catalog).contains_same_exactly_in_any_order(_game.catalog)
	await await_idle_frame() # free the select screen


func test_next_round_fights_the_players_build_then_returns_to_the_shop() -> void:
	await _choose(Fixtures.cross_chassis())
	var run := _game.shop.run
	# A gatling (1, 0)-(1, 2) cooled by a heatsink at (2, 1), (2, 2), (3, 2): 10 -> 2 gold.
	assert_bool(run.buy(_slot_of(_gatling), Vector2i(1, 0))).is_true()
	assert_bool(run.buy(_slot_of(_heatsink), Vector2i(2, 1))).is_true()
	await _press_next_round()
	assert_object(_game.combat).is_not_null()
	assert_bool(_game.combat.is_inside_tree()).is_true()
	assert_bool(_game.shop.is_inside_tree()).is_false()
	# The player's build fights on the left, with its link bonuses.
	var player := _game.combat.engine.left
	assert_array(player.active_parts).has_size(2)
	var gun: ActivePart = player.active_parts.filter(func(active: ActivePart) -> bool: return active.part == run.grid.get_part_at(Vector2i(1, 1)))[0]
	assert_int(gun.damage).is_equal(12)

	await _finish_fight()
	assert_object(_game.combat).is_null()
	assert_bool(_game.shop.is_inside_tree()).is_true()
	assert_int(run.wins).is_equal(1)
	assert_int(run.losses).is_equal(0)
	assert_int(run.round_number).is_equal(2)
	assert_int(run.gold).is_equal(12) # the 2 left over plus 10 income
	assert_str((_game.shop.get_node("%RecordLabel") as Label).text).is_equal("Record: 1 W · 0 L")
	assert_str((_game.shop.get_node("%Toast") as Label).text).is_equal("Won round 1 · +10g income, shop restocked")
	assert_int(run.grid.get_placements().size()).is_equal(2) # the build survives the fight
	await await_idle_frame() # free the combat screen and the shop cards the restock replaced


func test_losing_is_recorded_and_the_next_round_fights_again() -> void:
	# With nothing bought, the player's bare 30 HP falls to a gatling in 4 seconds.
	_game.make_opponent = func() -> BattleMech: return _gun_mech()
	await _choose(Fixtures.cross_chassis())
	await _press_next_round()
	await _finish_fight()
	var run := _game.shop.run
	assert_int(run.losses).is_equal(1)
	assert_int(run.wins).is_equal(0)
	assert_str((_game.shop.get_node("%Toast") as Label).text).is_equal("Lost round 1 · +10g income, shop restocked")
	# The run goes on: Next round starts round 2's fight.
	await _press_next_round()
	assert_object(_game.combat).is_not_null()
	assert_bool(_game.shop.is_inside_tree()).is_false()
	await _finish_fight()
	assert_int(run.losses).is_equal(2)
	assert_int(run.round_number).is_equal(3)
	await await_idle_frame()


# Picks [param chassis] on the select screen and waits for the deferred switch to the shop.
func _choose(chassis: MechChassis) -> void:
	_game.chassis_select.choose(chassis)
	await await_idle_frame()
	assert_object(_game.shop).append_failure_message("choosing a chassis didn't open the shop").is_not_null()


# Presses the shop's Next round button and waits for the deferred switch to combat. The
# combat's real-time timer is stopped so the test ticks the fight itself.
func _press_next_round() -> void:
	(_game.shop.get_node("%NextRoundButton") as Button).pressed.emit()
	await await_idle_frame()
	assert_object(_game.combat).append_failure_message("Next round didn't start a fight").is_not_null()
	_game.combat.print_ticks = false
	(_game.combat.get_node("%TickTimer") as Timer).stop()


# Ticks the fight to its end, skips the result pause, and waits for the switch to the shop.
func _finish_fight() -> void:
	var combat := _game.combat
	var ticks := 0
	while combat.engine.state == CombatEngine.State.RUNNING and ticks < MAX_TICKS:
		(combat.get_node("%TickTimer") as Timer).timeout.emit()
		ticks += 1
	assert_int(combat.engine.state).append_failure_message("the fight never ended").is_equal(CombatEngine.State.FINISHED)
	(combat.get_node("%ResultTimer") as Timer).timeout.emit()
	await await_idle_frame()


func _slot_of(part: MechPart) -> int:
	for i in _game.shop.run.slots.size():
		if _game.shop.run.slots[i].part == part:
			return i
	return -1


func _gun() -> MechPart:
	var gatling := Fixtures.gatling()
	gatling.cooldown_max = 1.0
	return gatling


# A bare Skirmisher: 30 HP and nothing to fight with.
static func _bare_mech() -> BattleMech:
	return BattleMech.new(MechGridData.new(Fixtures.cross_chassis()))


# 30 HP and a gatling at (1, 0)-(1, 2) firing on the Skirmisher's 3 energy a turn.
func _gun_mech() -> BattleMech:
	var grid := MechGridData.new(Fixtures.cross_chassis())
	grid.place_part(_gun(), Vector2i(1, 0))
	return BattleMech.new(grid)
