class_name DatabankScreenTest
extends GdUnitTestSuite

const __source: String = "res://src/ui/DatabankScreen.gd"
const Fixtures := preload("res://test/TestFixtures.gd")


func test_lists_everything_and_hides_whats_locked() -> void:
	var gun := Fixtures.gatling()
	var pod := Fixtures.missile_pod()
	var parts: Array[MechPart] = [gun, pod]
	var relics: Array[Relic] = [Fixtures.relic("Lucky Bolt", Relic.Rarity.RARE), Fixtures.armored()]
	var kits: Array[FieldKit] = [Fixtures.shield_cell()]
	var boss := Fixtures.enemy("Big Boss", EnemyLoadout.Tier.BOSS, [LoadoutPart.make(Fixtures.gatling(), Vector2i(-1, 1))])
	boss.chassis = Fixtures.armed_cross()
	boss.phases.assign([Fixtures.boss_phase("Scrap Armor")])
	var act := Fixtures.act()
	act.enemies = [boss]
	var acts: Array[ActData] = [act]
	var unlocks: Array[Unlock] = [Fixtures.unlock("pod", Unlock.Kind.PART, pod.id, {"runs_won": 1}),
		Fixtures.unlock("cell", Unlock.Kind.KIT, "shield_cell", {"runs_won": 1})]
	var screen: DatabankScreen = auto_free(DatabankScreen.new(Profile.new(), unlocks, parts, relics, kits, acts))
	add_child(screen)
	var part_texts := screen.get_entry_texts("Parts")
	assert_array(part_texts).has_size(2)
	# By type, then name: the pod first. Locked, it's a silhouette with how to earn it.
	assert_array(part_texts[0]).contains(["???", "Locked · Do the thing"])
	assert_bool(part_texts[0].has("Missile Pod")).is_false()
	assert_array(part_texts[1]).contains(["Twin Gatling"])
	# Affixes aren't relics a run can find.
	var relic_texts := screen.get_entry_texts("Relics")
	assert_array(relic_texts).has_size(1)
	assert_array(relic_texts[0]).contains(["Lucky Bolt", "Rare relic"])
	assert_array(screen.get_entry_texts("Kits")[0]).contains(["???"])
	var enemy_texts := screen.get_entry_texts("Enemies")
	assert_array(enemy_texts[0]).contains(["TEST SECTOR"])
	assert_array(enemy_texts[1]).contains(["Big Boss", "Boss · on The Skirmisher · parts: Twin Gatling\nPhase: Scrap Armor"])
	# Without a profile nothing is locked.
	var open: DatabankScreen = auto_free(DatabankScreen.new(null, unlocks, parts, relics, kits, acts))
	assert_array(open.get_entry_texts("Parts")[0]).contains(["Missile Pod"])
	await await_idle_frame()
