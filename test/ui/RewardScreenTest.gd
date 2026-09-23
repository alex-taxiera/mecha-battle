class_name RewardScreenTest
extends GdUnitTestSuite

const __source: String = "res://src/ui/RewardScreen.gd"
const Fixtures := preload("res://test/TestFixtures.gd")

var _run: RunState
var _reward: FightReward
var _screen: RewardScreen


func before_test() -> void:
	_run = RunState.new(Fixtures.armed_cross(), [], [], 30)
	_reward = FightReward.new()
	_reward.gold = 11
	var heatsink := Fixtures.heatsink()
	var pod := Fixtures.missile_pod()
	pod.rarity = MechPart.Rarity.RARE
	_reward.parts = [Fixtures.laser(), heatsink, pod]
	_screen = auto_free(RewardScreen.new(_run, _reward))
	add_child(_screen)


func test_shows_the_gold_and_the_draft() -> void:
	assert_str(_screen.title_label.text).is_equal("SALVAGE")
	assert_str(_screen.gold_label.text).is_equal("+11 gold")
	assert_str(_screen.draft_label.text).is_equal("Salvage one part for your stash:")
	assert_array(_screen.get_cards()).has_size(3)
	assert_array(_card_texts(2)).contains(["Missile Pod", "Rare · Weapon · 2×2", "Take"])
	assert_str(_screen.done_button.text).is_equal("Skip the rest")
	assert_object(_screen.hud.run).is_same(_run)
	# A normal fight drops no relic.
	assert_bool(_screen.relic_label.visible).is_false()
	assert_array(_screen.get_relic_cards()).is_empty()


func test_taking_a_part_stashes_it_and_closes_the_draft() -> void:
	assert_bool(_screen.take(1)).is_true()
	assert_array(_run.stash).has_size(1)
	assert_str(_run.stash[0].part.part_name).is_equal("L-Shaped Heatsink")
	assert_str(_screen.draft_label.text).is_equal("L-Shaped Heatsink is in your stash. Install it from the map's Loadout.")
	assert_array(_card_texts(1)).contains(["In your stash"])
	assert_array(_card_texts(0)).contains(["Left behind"])
	assert_str(_screen.done_button.text).is_equal("Continue")
	# One per draft.
	assert_bool(_screen.take(0)).is_false()
	assert_array(_run.stash).has_size(1)
	await await_idle_frame() # free the replaced cards


func test_a_card_takes_its_part() -> void:
	var take := _screen.get_cards()[0].find_children("*", "Button", true, false)[0] as Button
	take.pressed.emit()
	await await_idle_frame() # the take is deferred
	assert_int(_reward.taken).is_equal(0)
	await await_idle_frame()


func test_the_button_finishes() -> void:
	var done := [0]
	_screen.finished.connect(func() -> void: done[0] += 1)
	_screen.done_button.pressed.emit()
	assert_int(done[0]).is_equal(1)
	# Skipping takes nothing.
	assert_array(_run.stash).is_empty()


func test_an_elite_relic_can_be_taken() -> void:
	var reward := FightReward.new()
	reward.tier = EnemyLoadout.Tier.ELITE
	reward.relics = [Fixtures.relic("Lucky Bolt", Relic.Rarity.UNCOMMON)]
	var screen: RewardScreen = auto_free(RewardScreen.new(_run, reward))
	add_child(screen)
	assert_str(screen.title_label.text).is_equal("ELITE SALVAGE")
	assert_str(screen.relic_label.text).is_equal("Recovered a relic:")
	var texts := _texts_of(screen.get_relic_cards()[0])
	assert_array(texts).contains(["Lucky Bolt", "Uncommon relic", "Does nothing.", "Take"])
	assert_str(screen.done_button.text).is_equal("Skip the rest")
	assert_bool(screen.take_relic(0)).is_true()
	assert_array(_run.relics).has_size(1)
	assert_str(screen.relic_label.text).is_equal("Lucky Bolt is yours.")
	assert_array(_texts_of(screen.get_relic_cards()[0])).contains(["Taken"])
	assert_str(screen.done_button.text).is_equal("Continue")
	assert_bool(screen.take_relic(0)).is_false()
	await await_idle_frame()


func test_a_boss_offers_a_choice_of_relics() -> void:
	var reward := FightReward.new()
	reward.tier = EnemyLoadout.Tier.BOSS
	reward.relics = [Fixtures.relic("Boss A", Relic.Rarity.BOSS), Fixtures.relic("Boss B", Relic.Rarity.BOSS),
		Fixtures.relic("Boss C", Relic.Rarity.BOSS)]
	var screen: RewardScreen = auto_free(RewardScreen.new(_run, reward))
	add_child(screen)
	assert_str(screen.relic_label.text).is_equal("Choose a relic:")
	assert_array(screen.get_relic_cards()).has_size(3)
	assert_bool(screen.take_relic(2)).is_true()
	assert_str(_run.relics[0].relic_name).is_equal("Boss C")
	assert_array(_texts_of(screen.get_relic_cards()[0])).contains(["Left behind"])
	await await_idle_frame()


func test_bosses_and_empty_drafts() -> void:
	var boss := FightReward.new()
	boss.tier = EnemyLoadout.Tier.BOSS
	boss.gold = 40
	var screen: RewardScreen = auto_free(RewardScreen.new(_run, boss))
	assert_str(screen.title_label.text).is_equal("BOSS SALVAGE")
	assert_str(screen.draft_label.text).is_equal("Nothing else worth salvaging.")
	assert_str(screen.done_button.text).is_equal("Continue")


func _card_texts(index: int) -> Array:
	return _texts_of(_screen.get_cards()[index])


func _texts_of(card: Control) -> Array:
	return card.find_children("*", "", true, false) \
		.filter(func(node: Node) -> bool: return node is Label or node is Button) \
		.map(func(node: Node) -> String: return node.text)
