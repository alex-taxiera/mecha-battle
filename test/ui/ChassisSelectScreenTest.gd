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


func test_the_stats_line_counts_the_cells_a_frame_can_grow_into() -> void:
	var chassis := Fixtures.bastion()
	chassis.size = Vector2i(4, 4)
	for x in 4:
		chassis.expansion_cells.append(Vector2i(x, 3))
	assert_str(ChassisSelectScreen.stats_line(chassis)).is_equal("450 HP · 20 EN a turn · 12 slots (+4) · 1 hardpoint")


func test_the_threat_picker_stays_within_what_the_frame_unlocked() -> void:
	var bastion := Fixtures.bastion()
	bastion.id = "bastion"
	var striker := Fixtures.striker()
	striker.id = "striker"
	var screen := _screen([bastion, striker])
	var profile := Profile.new()
	profile.chassis_records = {"bastion": {"runs": 3, "wins": 2, "best_sector": 3, "threat": 2}}
	screen.set_locks(profile, [])
	screen.set_modifiers(Fixtures.threat_levels(), [])
	assert_int(screen.get_max_threat(bastion)).is_equal(2)
	assert_int(screen.get_max_threat(striker)).is_equal(0)
	# Up to what's unlocked, and no further (Slay-The-Robot clamped the old level, not the new one).
	screen.set_threat(bastion, 2)
	assert_int(screen.get_threat(bastion)).is_equal(2)
	screen.set_threat(bastion, 3)
	assert_int(screen.get_threat(bastion)).is_equal(2)
	screen.set_threat(bastion, -1)
	assert_int(screen.get_threat(bastion)).is_equal(0)
	# Each frame keeps its own level.
	screen.set_threat(bastion, 1)
	screen.set_threat(striker, 1)
	assert_int(screen.get_threat(bastion)).is_equal(1)
	assert_int(screen.get_threat(striker)).is_equal(0)
	# The level picked is checked again when the profile changes.
	screen.set_threat(bastion, 2)
	profile.chassis_records["bastion"]["threat"] = 1
	screen.set_locks(profile, [])
	assert_int(screen.get_threat(bastion)).is_equal(1)
	await await_idle_frame() # free the rebuilt cards


func test_the_picker_never_goes_past_the_ladder() -> void:
	var bastion := Fixtures.bastion()
	bastion.id = "bastion"
	var screen := _screen([bastion])
	var profile := Profile.new()
	profile.chassis_records = {"bastion": {"threat": 20}}
	screen.set_locks(profile, [])
	screen.set_modifiers(Fixtures.threat_levels(), [])
	screen.set_threat(bastion, 20)
	assert_int(screen.get_threat(bastion)).is_equal(8)
	# Without a profile every level is open.
	var open := _screen([Fixtures.striker()])
	open.set_modifiers(Fixtures.threat_levels(), [])
	assert_int(open.get_max_threat(open.options[0])).is_equal(8)
	await await_idle_frame()


func test_a_card_shows_its_threat_and_what_it_adds() -> void:
	var bastion := Fixtures.bastion()
	bastion.id = "bastion"
	var screen := _screen([bastion])
	var profile := Profile.new()
	profile.chassis_records = {"bastion": {"threat": 2}}
	screen.set_locks(profile, [])
	var levels := Fixtures.threat_levels()
	levels[1].description = "Shop prices are 15% higher."
	screen.set_modifiers(levels, [])
	assert_array(screen.get_card_texts()[0]).contains(["Threat 0", "Threat 0 · the standard run", "Win at 2 to unlock 3"])
	screen.set_threat(bastion, 2)
	assert_array(screen.get_card_texts()[0]).contains(["Threat 2", "Threat 2 · Shop prices are 15% higher. (+1 below)"])
	# The -/+ buttons step the level.
	var minus: Button = screen.get_node("%Cards").find_children("*", "Button", true, false) \
		.filter(func(button: Button) -> bool: return button.text == "−")[0]
	minus.pressed.emit()
	await await_idle_frame()
	assert_int(screen.get_threat(bastion)).is_equal(1)
	await await_idle_frame()


func test_without_a_ladder_there_is_no_picker() -> void:
	var screen := _screen([Fixtures.bastion()])
	for text in screen.get_card_texts()[0]:
		assert_str(text).not_contains("Threat")
	# Positive control: with one, there is.
	screen.set_modifiers(Fixtures.threat_levels(), [])
	assert_array(screen.get_card_texts()[0]).contains(["Threat 0"])
	await await_idle_frame()


func test_a_run_gets_the_stacked_threat_and_the_modes_turned_on() -> void:
	var bastion := Fixtures.bastion()
	var glass := Fixtures.glass_cannon()
	var endless := Fixtures.endless()
	var sturdy := Fixtures.run_modifier("sturdy", {"is_custom": true, "exclusive_with": ["glass_cannon"] as Array[String]})
	var screen := _screen([bastion])
	var levels := Fixtures.threat_levels()
	screen.set_modifiers(levels, [glass, endless, sturdy])
	screen.set_threat(bastion, 2)
	screen.set_custom(glass, true)
	screen.set_custom(endless, true)
	assert_array(screen.get_run_modifiers(bastion)).contains_same_exactly([levels[0], levels[1], glass, endless])
	screen.set_custom(sturdy, true)
	assert_array(screen.get_custom_modifiers()).contains_same_exactly_in_any_order([endless, sturdy]).has_size(2)
	# A checkbox per mode, ticked as they are.
	var boxes := screen.find_children("*", "CheckBox", true, false)
	assert_array(boxes.map(func(box: CheckBox) -> String: return box.text)).contains_exactly(["Glass Cannon", "Endless", "Sturdy"])
	assert_array(boxes.map(func(box: CheckBox) -> bool: return box.button_pressed)).contains_exactly([false, true, true])
	await await_idle_frame()
