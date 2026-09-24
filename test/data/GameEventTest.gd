class_name GameEventTest
extends GdUnitTestSuite
## Events through the run: picking choices, outcomes by weight, and each effect and requirement.

const __source: String = "res://src/data/events/GameEvent.gd"
const Fixtures := preload("res://test/TestFixtures.gd")
const LEFT_ARM := Vector2i(-1, 1)

var _run: RunState


func before_test() -> void:
	var acts: Array[ActData] = [Fixtures.act()]
	_run = RunState.new(Fixtures.armed_cross(), [Fixtures.gatling(), Fixtures.laser()], [], 50, RunRng.new(1), acts,
		Fixtures.relics())


func test_a_choice_applies_its_outcome_and_reports_it() -> void:
	var event := Fixtures.gold_event("Cache", 25)
	var result := _run.choose_event_option(event, 0)
	assert_str(result.text).is_equal("You take it.")
	assert_array(result.lines).contains_exactly(["+25 gold"])
	assert_int(result.fight_tier).is_equal(-1)
	assert_int(_run.gold).is_equal(75)
	# A choice that doesn't exist does nothing.
	assert_object(_run.choose_event_option(event, 3)).is_null()
	assert_int(_run.gold).is_equal(75)


func test_a_choice_needs_its_requirement() -> void:
	var pricey := Fixtures.choice("Pay", [Fixtures.outcome("Paid.", [Fixtures.gold_effect(-60)])], Fixtures.gold_requirement(60))
	var event := Fixtures.event("Toll", [pricey])
	assert_bool(pricey.is_available(_run)).is_false()
	assert_str(pricey.requirement.describe()).is_equal("Needs 60 gold")
	assert_object(_run.choose_event_option(event, 0)).is_null()
	assert_int(_run.gold).is_equal(50)
	# Positive control: with the gold it goes through.
	_run.gold = 60
	assert_object(_run.choose_event_option(event, 0)).is_not_null()
	assert_int(_run.gold).is_equal(0)


func test_outcomes_are_picked_by_weight() -> void:
	var counts := {"often": 0, "rarely": 0}
	var event := Fixtures.event("Gamble", [Fixtures.choice("Roll", [
		Fixtures.outcome("often", [], 3), Fixtures.outcome("rarely", [], 1)])])
	for i in 400:
		counts[_run.choose_event_option(event, 0).text] += 1
	assert_int(counts["often"]).is_between(260, 340)
	assert_int(counts["rarely"]).is_between(60, 140)


func test_gold_and_hull_effects() -> void:
	var result := EventResult.new()
	var pay := GoldEffect.new()
	pay.amount = -80 # more than the 50 there is: takes all of it
	pay.apply(_run, result)
	assert_int(_run.gold).is_equal(0)
	_run.hull_damage = 20
	var repair := HullEffect.new()
	repair.amount = 150
	repair.apply(_run, result)
	assert_int(_run.hull_damage).is_equal(0)
	var blast := HullEffect.new()
	blast.amount = -100 # the bare cross has 30: it's left at 1
	blast.apply(_run, result)
	assert_int(_run.get_current_hp()).is_equal(1)
	assert_bool(_run.is_over()).is_false()
	assert_array(result.lines).contains_exactly(["-50 gold", "Repaired 20 hull", "Took 29 damage"])


func test_max_hp_is_an_upgrade_not_a_relic() -> void:
	var effect := MaxHpEffect.new()
	effect.hp = 40
	var result := EventResult.new()
	effect.apply(_run, result)
	assert_int(_run.get_max_hp()).is_equal(70)
	assert_int(_run.make_player_mech().max_hp).is_equal(70)
	assert_array(_run.relics).is_empty()
	assert_array(_run.upgrades).has_size(1)
	assert_array(result.lines).contains_exactly(["+40 max HP"])


func test_max_hp_can_go_down() -> void:
	var effect := MaxHpEffect.new()
	effect.hp = -10
	var result := EventResult.new()
	effect.apply(_run, result)
	assert_int(_run.get_max_hp()).is_equal(20)
	assert_array(result.lines).contains_exactly(["-10 max HP"])


func test_a_relic_effect_can_roll_a_rarity() -> void:
	var effect := RelicEffect.new()
	effect.rarity = Relic.Rarity.RARE
	effect.apply(_run, EventResult.new())
	assert_int(_run.relics[0].rarity).is_equal(Relic.Rarity.RARE)
	# The fixtures have one rare: the next falls back to another rarity.
	effect.apply(_run, EventResult.new())
	assert_array(_run.relics).has_size(2)
	assert_int(_run.relics[1].rarity).is_not_equal(Relic.Rarity.RARE)


func test_part_effects_stash_a_part() -> void:
	var result := EventResult.new()
	var given := PartEffect.new()
	given.part = Fixtures.heatsink()
	given.apply(_run, result)
	assert_str(_run.stash[0].part.part_name).is_equal("L-Shaped Heatsink")
	# Without a part it picks from the catalog: a weapon if asked, of the nearest rarity.
	var weapon := PartEffect.new()
	weapon.rarity = MechPart.Rarity.RARE # the fixtures are all common
	weapon.weapon = true
	weapon.apply(_run, result)
	assert_str(_run.stash[1].part.part_name).is_equal("Twin Gatling")
	assert_array(result.lines).contains_exactly(["L-Shaped Heatsink added to your stash", "Twin Gatling added to your stash"])


func test_losing_parts_takes_from_the_stash_first() -> void:
	_run.stash_part(Fixtures.laser())
	assert_bool(_run.grid.place_part(Fixtures.reactor(), Vector2i(1, 1))).is_true()
	var effect := LosePartsEffect.new()
	effect.count = 2
	var result := EventResult.new()
	effect.apply(_run, result)
	assert_array(_run.stash).is_empty()
	assert_int(_run.grid.get_placements().size()).is_equal(0)
	assert_array(result.lines).contains_exactly(["Lost Point-Defense Laser, Micro-Reactor"])


func test_relic_effects_give_a_relic() -> void:
	var effect := RelicEffect.new()
	effect.relic = Fixtures.relic("Gift", Relic.Rarity.EVENT)
	var result := EventResult.new()
	effect.apply(_run, result)
	assert_str(_run.relics[0].relic_name).is_equal("Gift")
	# Without one it rolls from the pool.
	RelicEffect.new().apply(_run, result)
	assert_array(_run.relics).has_size(2)
	assert_int(_run.relics[1].rarity).is_not_equal(Relic.Rarity.BOSS)


func test_weapon_mods_fit_the_strongest_mounted_weapon() -> void:
	var weak := Fixtures.gatling()     # 8 damage, 3 energy
	var strong := Fixtures.missile_pod() # 14 damage, 5 energy
	assert_bool(_run.grid.place_part(weak, LEFT_ARM)).is_true()
	assert_bool(_run.grid.place_part(strong, Vector2i(1, -2))).is_true()
	assert_object(WeaponModEffect.strongest_weapon(_run)).is_same(strong)
	var effect := WeaponModEffect.new()
	effect.mod = Fixtures.weapon_mod("overclocked", "Overclocked", {"damage_scale": 1.3, "energy_scale": 0.8, "heat_add": 15})
	var result := EventResult.new()
	effect.apply(_run, result)
	assert_object(strong.mod).is_same(effect.mod)
	assert_str(strong.get_display_name()).is_equal("Overclocked Missile Pod")
	# The part's own numbers stay; the mech's stats count the mod.
	assert_int(strong.damage).is_equal(14)
	var numbers := MechStats.calculate(_run.grid, []).part_stats[_run.grid.get_placement_at(Vector2i(1, -2))]
	assert_int(numbers.damage).is_equal(18) # 18.2, rounded
	assert_int(numbers.energy_draw).is_equal(4)
	assert_int(numbers.heat).is_equal(15)
	assert_object(weak.mod).is_null() # the other weapon is untouched
	assert_array(result.lines).contains_exactly(["Missile Pod is now the Overclocked Missile Pod"])
	# A second mod replaces the first: a weapon holds one.
	var cooled := WeaponModEffect.new()
	cooled.mod = Fixtures.weapon_mod("cooled", "Cooled", {"damage_scale": 0.9, "energy_scale": 0.8})
	cooled.apply(_run, result)
	assert_str(strong.get_display_name()).is_equal("Cooled Missile Pod")


func test_upgrade_effects_raise_a_part() -> void:
	var weak := Fixtures.laser()
	var strong := Fixtures.gatling()
	assert_bool(_run.grid.place_part(weak, Vector2i(1, 1))).is_true()
	assert_bool(_run.grid.place_part(strong, LEFT_ARM)).is_true()
	var best := UpgradePartEffect.new()
	best.pick = UpgradePartEffect.Pick.STRONGEST
	var result := EventResult.new()
	best.apply(_run, result)
	assert_int(strong.level).is_equal(2)
	assert_array(result.lines).contains_exactly(["Twin Gatling is now Twin Gatling Mk II"])
	# A random pick raises one of the upgradable parts.
	UpgradePartEffect.new().apply(_run, result)
	assert_int(weak.level + strong.level).is_equal(4)
	# With nothing upgradable, nothing happens.
	var needs := UpgradableRequirement.new()
	assert_bool(needs.check(_run)).is_true()
	var empty := RunState.new(Fixtures.armed_cross(), [], [])
	assert_bool(needs.check(empty)).is_false()
	assert_str(needs.describe()).is_equal("Needs a part to upgrade")
	UpgradePartEffect.new().apply(empty, result)
	assert_array(result.lines).has_size(2)


func test_weapon_requirement() -> void:
	var needs_weapon := WeaponRequirement.new()
	assert_bool(needs_weapon.check(_run)).is_false()
	assert_str(needs_weapon.describe()).is_equal("Needs a mounted weapon")
	assert_bool(_run.grid.place_part(Fixtures.gatling(), LEFT_ARM)).is_true()
	assert_bool(needs_weapon.check(_run)).is_true()


func test_parts_requirement_counts_stash_and_grid() -> void:
	var needs_two := PartsRequirement.new()
	needs_two.count = 2
	_run.stash_part(Fixtures.laser())
	assert_bool(needs_two.check(_run)).is_false()
	assert_bool(_run.grid.place_part(Fixtures.laser(), Vector2i(1, 1))).is_true()
	assert_bool(needs_two.check(_run)).is_true()
	assert_str(needs_two.describe()).is_equal("Needs 2 parts")


func test_fight_effects_ask_for_a_fight() -> void:
	var effect := FightEffect.new()
	effect.tier = EnemyLoadout.Tier.ELITE
	var result := EventResult.new()
	effect.apply(_run, result)
	assert_int(result.fight_tier).is_equal(EnemyLoadout.Tier.ELITE)
	assert_object(result.fight_enemy).is_null()
	assert_int(result.fight_relic_rarity).is_equal(-1)


func test_a_fight_effect_can_name_its_enemy_and_prize() -> void:
	var champion := Fixtures.enemy("Pit Champion", EnemyLoadout.Tier.ELITE)
	var effect := FightEffect.new()
	effect.tier = EnemyLoadout.Tier.NORMAL # the named enemy's own tier wins
	effect.enemy = champion
	effect.relic_rarity = Relic.Rarity.RARE
	var result := EventResult.new()
	effect.apply(_run, result)
	assert_int(result.fight_tier).is_equal(EnemyLoadout.Tier.ELITE)
	assert_object(result.fight_enemy).is_same(champion)
	assert_int(result.fight_relic_rarity).is_equal(Relic.Rarity.RARE)


func test_a_status_lasts_its_fights() -> void:
	var storm := TimedStatus.new()
	storm.relic_name = "Storm"
	storm.description = "start hot, earn more."
	storm.fights = 2
	storm.start_heat = 30
	storm.gold_bonus = 1.0 # doubles gold
	var effect := StatusEffect.new()
	effect.status = storm
	var result := EventResult.new()
	effect.apply(_run, result)
	assert_array(result.lines).contains_exactly(["For the next 2 fights: start hot, earn more."])
	assert_array(_run.statuses).has_size(1)
	assert_object(_run.statuses[0]).is_not_same(storm)
	# It heats the mech at the start of a fight.
	var mech := _run.make_player_mech()
	mech.start_fight()
	assert_int(mech.heat).is_equal(30)
	# Two fights' loot use it up, each doubled.
	assert_bool(_run.travel(_run.get_reachable()[0])).is_true()
	assert_int(_run.roll_reward().gold).is_between(16, 24)
	assert_int(_run.statuses[0].fights).is_equal(1)
	assert_int(_run.roll_reward().gold % 2).is_equal(0)
	assert_array(_run.statuses).is_empty()
	assert_int(_run.roll_reward().gold).is_between(8, 12)


func test_events_can_need_something_to_come_up() -> void:
	var event := Fixtures.event("Armory", [], WeaponRequirement.new())
	assert_bool(event.can_happen(_run)).is_false()
	assert_bool(_run.grid.place_part(Fixtures.gatling(), LEFT_ARM)).is_true()
	assert_bool(event.can_happen(_run)).is_true()
	assert_bool(Fixtures.gold_event("Anywhere").can_happen(_run)).is_true()


func test_a_node_keeps_its_event() -> void:
	var events: Array[GameEvent] = [Fixtures.gold_event("A"), Fixtures.gold_event("B")]
	var acts: Array[ActData] = [Fixtures.act()]
	var run := RunState.new(Fixtures.armed_cross(), [], [], 10, RunRng.new(2), acts, [], events)
	var node: MapNode = run.get_reachable()[0]
	assert_bool(run.travel(node)).is_true()
	var event := run.get_event()
	assert_bool(event in events).is_true()
	assert_object(run.get_event()).is_same(event)
	assert_object(node.event).is_same(event)
