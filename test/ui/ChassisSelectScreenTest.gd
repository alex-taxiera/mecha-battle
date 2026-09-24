class_name ChassisSelectScreenTest
extends GdUnitTestSuite

const __source: String = "res://src/ui/ChassisSelectScreen.gd"
const SCENE := preload("res://src/ui/ChassisSelectScreen.tscn")
const Fixtures := preload("res://test/TestFixtures.gd")


func test_shows_a_card_per_frame() -> void:
	var screen := _screen([Fixtures.bastion(), Fixtures.striker(), Fixtures.reactor_frame()])
	var cards := screen.get_card_texts()
	assert_array(cards).has_size(3)
	assert_array(cards[0]).contains_exactly(["The Bastion", "Tank / Attrition", "450 HP · 20 EN a turn · 12 slots · 1 hardpoint",
		"Thick Plating", "Reduces all incoming flat damage by 2.", "Choose The Bastion"])
	assert_array(cards[1]).contains_exactly(["The Striker", "Glass Cannon / Burst", "220 HP · 40 EN a turn · 10 slots · 3 hardpoints",
		"Overclock", "The first weapon to fire each battle fires twice.", "Choose The Striker"])
	assert_array(cards[2]).contains_exactly(["The Reactor", "Synergy / Combo", "300 HP · 30 EN a turn · 13 slots · 2 hardpoints",
		"Meltdown", "When heat reaches 100%, deal massive damage and shut down for 3 seconds.", "Choose The Reactor"])
	# Each card draws its frame's layout.
	var previews := screen.find_children("*", "Control", true, false).filter(func(node: Node) -> bool: return node is ChassisPreview)
	assert_array(previews.map(func(preview: ChassisPreview) -> String: return preview.chassis.chassis_name)) \
		.contains_exactly(["The Bastion", "The Striker", "The Reactor"])


func test_a_cards_button_chooses_its_frame() -> void:
	var striker := Fixtures.striker()
	var screen := _screen([Fixtures.bastion(), striker])
	var chosen := []
	screen.chassis_chosen.connect(func(chassis: MechChassis) -> void: chosen.append(chassis))
	var buttons := screen.get_node("%Cards").find_children("*", "Button", true, false)
	assert_array(buttons).has_size(2)
	buttons[1].pressed.emit()
	assert_array(chosen).has_size(1)
	assert_object(chosen[0]).is_same(striker)


func test_loads_the_frames_in_design_order_by_default() -> void:
	var screen: ChassisSelectScreen = auto_free(SCENE.instantiate())
	add_child(screen)
	assert_array(screen.options.map(func(chassis: MechChassis) -> String: return chassis.id)) \
		.contains_exactly(["bastion", "striker", "reactor"])


func test_without_a_profile_nothing_is_locked_and_there_is_no_footer() -> void:
	var screen := _screen([Fixtures.bastion()])
	assert_object(screen.get_lock(screen.options[0])).is_null()
	var reset := screen.find_children("*", "Button", true, false).filter(func(b: Button) -> bool: return b.text == "Reset progress")
	assert_bool((reset[0] as Button).visible).is_false()


func test_a_locked_frame_is_greyed_out_and_cannot_be_chosen() -> void:
	var bastion := Fixtures.bastion()
	bastion.id = "bastion"
	var striker := Fixtures.striker()
	striker.id = "striker"
	var screen := _screen([bastion, striker])
	var locks: Array[Unlock] = [Fixtures.unlock("striker", Unlock.Kind.CHASSIS, "striker", {"sectors_cleared": 1})]
	var profile := Profile.new()
	profile.runs = 2
	screen.set_locks(profile, locks)
	var cards := screen.get_card_texts()
	assert_array(cards[1]).contains(["Locked · Do the thing", "Locked"])
	assert_array(cards[0]).contains(["Choose The Bastion"])
	var chosen := []
	screen.chassis_chosen.connect(func(chassis: MechChassis) -> void: chosen.append(chassis))
	screen.choose(striker)
	assert_array(chosen).is_empty()
	# Positive control: the open frame can be chosen, and once earned, so can the other.
	screen.choose(bastion)
	assert_array(chosen).contains_same_exactly([bastion])
	profile.unlocked.append("striker")
	screen.set_locks(profile, locks)
	screen.choose(striker)
	assert_array(chosen).has_size(2)
	await await_idle_frame() # free the rebuilt cards


func test_the_footer_shows_totals_and_asks_to_reset() -> void:
	var screen := _screen([Fixtures.bastion()])
	var profile := Profile.new()
	profile.runs = 3
	profile.wins = 1
	profile.fights_won = 17
	profile.bosses_beaten = 4
	screen.set_locks(profile, [])
	var labels := screen.find_children("*", "Label", true, false).map(func(label: Label) -> String: return label.text)
	assert_array(labels).contains(["Runs 3 · Wins 1 · Fights won 17 · Bosses beaten 4"])
	var asked := [0]
	screen.reset_requested.connect(func() -> void: asked[0] += 1)
	screen.reset_progress()
	assert_int(asked[0]).is_equal(1)
	await await_idle_frame()


func _screen(options: Array) -> ChassisSelectScreen:
	var screen: ChassisSelectScreen = auto_free(SCENE.instantiate())
	screen.options.assign(options)
	add_child(screen)
	return screen
