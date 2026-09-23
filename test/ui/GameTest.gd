class_name GameTest
extends GdUnitTestSuite

const __source: String = "res://src/ui/Game.gd"
const SCENE := preload("res://src/ui/Game.tscn")
const Fixtures := preload("res://test/TestFixtures.gd")
# Enough ticks for any fight here to end; stops a broken flow hanging the run.
const MAX_TICKS := 10000
const LEFT_ARM := Vector2i(-1, 1)

var _game: Game


func before_test() -> void:
	_game = auto_free(SCENE.instantiate())
	_game.catalog = [_gun(), Fixtures.laser(), Fixtures.reactor(), Fixtures.heatsink()]
	_game.rules = Fixtures.rules()
	_game.acts = [Fixtures.act(), Fixtures.act()]
	_game.relics = Fixtures.relics()
	_game.run_seed = 1
	add_child(_game)


func test_the_run_starts_by_choosing_a_chassis() -> void:
	assert_object(_game.screen).is_same(_game.chassis_select)
	assert_object(_game.run).is_null()
	await _choose(_armed())
	assert_object(_game.chassis_select).is_null()
	# The run starts on the first sector's map with its frame's starter kit and gold.
	var run := _game.run
	assert_object(run.get_act()).is_same(_game.acts[0])
	assert_int(run.gold).is_equal(20)
	assert_int(run.grid.get_mounted_count()).is_equal(1)
	assert_object(_map_screen()).is_not_null()
	assert_array(_map_screen().get_view().reachable).contains_same_exactly(run.map.floors[0])
	await await_idle_frame() # free the select screen


func test_a_battle_fights_the_sectors_enemy_then_returns_to_the_map() -> void:
	await _choose(_armed())
	var run := _game.run
	var node: MapNode = run.get_reachable()[0]
	await _go(node)
	var combat := _game.combat
	assert_object(combat).is_not_null()
	assert_object(_game.screen).is_same(combat)
	assert_object(combat.run).is_same(run)
	# The player's build on the left, one of the sector's normal enemies on the right.
	assert_int(combat.engine.left.active_parts.size()).is_equal(1)
	assert_int(node.enemy.tier).is_equal(EnemyLoadout.Tier.NORMAL)
	assert_str(combat.engine.right.mech_name).is_equal(node.enemy.enemy_name)
	await _finish_fight()
	# Won: the loot, then back on the map one floor up.
	assert_int(run.fights_won).is_equal(1)
	assert_object(_game.combat).is_null()
	await _collect_loot()
	assert_object(_map_screen()).is_not_null()
	assert_array(_map_screen().get_view().reachable).contains_same_exactly(node.next)
	await await_idle_frame() # free the combat screen


func test_the_hulls_damage_carries_into_and_out_of_fights() -> void:
	# Every enemy shoots back.
	for act in _game.acts:
		for enemy in act.enemies:
			enemy.chassis = Fixtures.armed_cross()
			enemy.lineup = [LoadoutPart.make(_gun(), LEFT_ARM)]
	var chassis := _armed()
	chassis.starter_lineup.append(LoadoutPart.make(Fixtures.laser(), Vector2i(1, 1))) # 30 + 12 HP
	await _choose(chassis)
	var run := _game.run
	run.hull_damage = 5
	await _go(run.get_reachable()[0])
	var player := _game.combat.engine.left
	assert_int(player.max_hp).is_equal(42)
	assert_int(player.current_health).is_equal(37)
	await _finish_fight()
	assert_bool(run.is_over()).is_false()
	await _collect_loot()
	assert_int(run.hull_damage).is_equal(42 - player.current_health)
	assert_int(run.hull_damage).is_greater(5) # the enemy landed hits
	await await_idle_frame()


func test_losing_ends_the_run_and_a_new_one_starts() -> void:
	# An unarmed frame against unarmed enemies: the storm takes both down together, a draw.
	await _choose(Fixtures.cross_chassis())
	await _go(_game.run.get_reachable()[0])
	await _finish_fight()
	assert_int(_game.run.outcome).is_equal(RunState.Outcome.DEFEAT)
	var end := _message()
	assert_str(end.title_label.text).is_equal("MECH DESTROYED")
	assert_str(end.body_label.text).is_equal("The Skirmisher\nFell in Sector 1 · Floor 1\nFights won: 0")
	assert_str(end.button.text).is_equal("New run")
	end.button.pressed.emit()
	await await_idle_frame()
	assert_object(_game.run).is_null()
	assert_object(_game.chassis_select).is_not_null()
	assert_object(_game.screen).is_same(_game.chassis_select)
	# Positive control: the new select screen starts another run.
	await _choose(_armed())
	assert_object(_map_screen()).is_not_null()
	await await_idle_frame()


func test_beating_a_sectors_boss_moves_to_the_next_sector() -> void:
	await _choose(_armed())
	var run := _game.run
	_stand_below_the_boss()
	await _go(run.map.boss)
	assert_str((_game.combat.get_node("%RoundBadge") as RoundBadge).get_text()).is_equal("SECTOR 1 · FLOOR 13  0W  BOSS")
	assert_str(_game.combat.engine.right.mech_name).is_equal("Boss")
	await _finish_fight()
	assert_str((_game.screen as RewardScreen).title_label.text).is_equal("BOSS SALVAGE")
	await _collect_loot()
	assert_int(run.act_index).is_equal(1)
	var cleared := _message()
	assert_str(cleared.title_label.text).is_equal("SECTOR CLEARED")
	cleared.button.pressed.emit()
	await await_idle_frame()
	# The next sector's map, from its bottom floor.
	assert_object(_map_screen().run.map.act).is_same(_game.acts[1])
	assert_array(_map_screen().get_view().reachable).contains_same_exactly(run.map.floors[0])
	await await_idle_frame()


func test_beating_the_last_boss_wins_the_run() -> void:
	await _choose(_armed())
	var run := _game.run
	run.next_act() # straight to the last sector
	_stand_below_the_boss()
	await _go(run.map.boss)
	await _finish_fight()
	await _collect_loot()
	assert_int(run.outcome).is_equal(RunState.Outcome.VICTORY)
	var end := _message()
	assert_str(end.title_label.text).is_equal("RUN COMPLETE")
	assert_str(end.body_label.text).is_equal("The Skirmisher\nCleared all 2 sectors\nFights won: 1")
	await await_idle_frame()


func test_fights_drop_loot_for_the_stash_and_the_loadout_installs_it() -> void:
	await _choose(_armed())
	var run := _game.run
	await _go(run.get_reachable()[0])
	await _finish_fight()
	var loot := _game.screen as RewardScreen
	assert_object(loot).is_not_null()
	assert_int(run.gold).is_equal(20 + loot.reward.gold)
	assert_int(loot.reward.gold).is_between(8, 12)
	assert_array(loot.reward.parts).has_size(3)
	# Three of the four catalog parts, so at least two grid parts (not the gun).
	var grid_part := loot.reward.parts.find_custom(func(part: MechPart) -> bool: return part.type != MechPart.PartType.WEAPON)
	assert_int(grid_part).is_not_equal(-1)
	await _collect_loot(grid_part)
	assert_array(run.stash).has_size(1)
	# From the map, the Loadout: mech and stash, no shop.
	assert_str((_map_screen().get_node("%LoadoutButton") as Button).text).is_equal("Loadout · 1 in stash")
	(_map_screen().get_node("%LoadoutButton") as Button).pressed.emit()
	await await_idle_frame()
	var loadout := _game.screen as LoadoutScreen
	assert_object(loadout).is_not_null()
	assert_object(run.shop).is_null()
	assert_bool(run.install(0, Vector2i(1, 1))).is_true()
	(loadout.get_node("%LeaveButton") as Button).pressed.emit()
	await await_idle_frame()
	# Back on the map, where it was.
	assert_array(_map_screen().get_view().reachable).contains_same_exactly(run.map.current.next)
	assert_int(run.grid.get_used_cell_count()).is_greater(0)
	assert_array(run.stash).is_empty()
	await await_idle_frame()


func test_an_elite_drops_a_relic_that_joins_the_run() -> void:
	await _choose(_armed())
	var run := _game.run
	var node: MapNode = run.get_reachable()[0]
	node.type = MapNode.Type.ELITE
	await _go(node)
	assert_str((_game.combat.get_node("%RoundBadge") as RoundBadge).get_text()).is_equal("SECTOR 1 · FLOOR 1  0W  ELITE")
	await _finish_fight()
	var loot := _game.screen as RewardScreen
	assert_str(loot.title_label.text).is_equal("ELITE SALVAGE")
	assert_array(loot.reward.relics).has_size(1)
	assert_bool(loot.take_relic(0)).is_true()
	await _collect_loot()
	assert_array(run.relics).has_size(1)
	# The map's HUD shows it.
	assert_int((_map_screen().get_node("%RunHud") as RunHud).relic_bar.get_child_count()).is_equal(1)
	# The next fight's mech carries it.
	await _go(run.get_reachable()[0])
	assert_array(_game.combat.engine.left.relics).contains_same_exactly(run.relics)
	await _finish_fight()
	await _collect_loot()
	await await_idle_frame()


func test_a_shop_opens_the_scrap_shop_in_the_run() -> void:
	await _choose(_armed())
	var run := _game.run
	var node: MapNode = run.get_reachable()[0]
	node.type = MapNode.Type.SHOP
	await _go(node)
	var shop := _game.screen as LoadoutScreen
	assert_object(shop).is_not_null()
	assert_object(shop.run).is_same(run)
	assert_object(run.shop).is_not_null()
	(shop.get_node("%LeaveButton") as Button).pressed.emit()
	await await_idle_frame()
	assert_object(run.shop).is_null()
	assert_object(_map_screen()).is_not_null()
	assert_array(_map_screen().get_view().reachable).contains_same_exactly(node.next)
	await await_idle_frame()


func test_hangars_and_events_show_a_placeholder_for_now() -> void:
	await _choose(_armed())
	var run := _game.run
	var hangar: MapNode = run.get_reachable()[0]
	hangar.type = MapNode.Type.HANGAR
	await _go(hangar)
	assert_str(_message().title_label.text).is_equal("Hangar / Refit Bay")
	assert_object(_message().hud.run).is_same(run)
	_message().button.pressed.emit()
	await await_idle_frame()
	var event: MapNode = run.get_reachable()[0]
	event.type = MapNode.Type.EVENT
	await _go(event)
	assert_str(_message().title_label.text).is_equal("Unknown Signal")
	_message().button.pressed.emit()
	await await_idle_frame()
	assert_object(_map_screen()).is_not_null()
	assert_int(run.fights_won).is_equal(0)
	await await_idle_frame()


# The armed cross with a gun in its left arm to start with: it beats the bare fixture enemies.
func _armed() -> MechChassis:
	var chassis := Fixtures.armed_cross()
	chassis.starter_lineup = [LoadoutPart.make(_gun(), LEFT_ARM)]
	return chassis


# A gatling firing once a second, 8 damage for 3 energy.
func _gun() -> MechPart:
	var gatling := Fixtures.gatling()
	gatling.cooldown_max = 1.0
	return gatling


# Puts the player on the top floor, as if they'd climbed there.
func _stand_below_the_boss() -> void:
	var top: MapNode = _game.run.map.floors[-1][0]
	top.visited = true
	_game.run.map.current = top


# Picks [param chassis] on the select screen and waits for the deferred switch to the map.
func _choose(chassis: MechChassis) -> void:
	_game.chassis_select.choose(chassis)
	await await_idle_frame()
	assert_object(_game.run).append_failure_message("choosing a chassis didn't start a run").is_not_null()


# Travels to [param node] on the map and waits for what's there to open. A fight's real-time
# timer is stopped so the test ticks it itself.
func _go(node: MapNode) -> void:
	assert_bool(_map_screen().choose(node)).append_failure_message("can't travel to %s" % node.id).is_true()
	await await_idle_frame()
	if _game.combat:
		_game.combat.print_ticks = false
		(_game.combat.get_node("%TickTimer") as Timer).stop()


# Ticks the fight to its end, skips the pause before the result panel, presses Continue, and
# waits for the next screen.
func _finish_fight() -> void:
	var combat := _game.combat
	var ticks := 0
	while combat.engine.state == CombatEngine.State.RUNNING and ticks < MAX_TICKS:
		(combat.get_node("%TickTimer") as Timer).timeout.emit()
		ticks += 1
	assert_int(combat.engine.state).append_failure_message("the fight never ended").is_equal(CombatEngine.State.FINISHED)
	(combat.get_node("%ResultTimer") as Timer).timeout.emit()
	assert_bool(combat.result_panel.visible).append_failure_message("the result panel didn't come up").is_true()
	combat.result_panel.return_button.pressed.emit()
	await await_idle_frame()


# On the loot screen after a win: takes draft part [param take] if it's 0 or more, presses the
# button, and waits for the next screen.
func _collect_loot(take := -1) -> void:
	var loot := _game.screen as RewardScreen
	assert_object(loot).append_failure_message("a won fight didn't show its loot").is_not_null()
	if take >= 0:
		assert_bool(loot.take(take)).is_true()
	loot.done_button.pressed.emit()
	await await_idle_frame()


func _map_screen() -> MapScreen:
	return _game.screen as MapScreen


func _message() -> MessageScreen:
	return _game.screen as MessageScreen
