class_name RewardScreen
extends Control
## What a won fight dropped: the gold (already collected), an elite's relic or a boss's choice of
## three (or growing the frame instead), and a draft of parts, one of which the player can take
## into their stash. Anything left
## is skipped. The button at the bottom emits [signal finished].

## Emitted when the player is done with the loot.
signal finished

const THEME := preload("res://resources/ui/theme.tres")
const TITLE_COLOR := Color("#5fd38a")
const DIM_COLOR := Color(0.72, 0.74, 0.78)
const GOLD_COLOR := Color(0.96, 0.83, 0.43)
## The Frame Expansion card's title.
const CELLS_COLOR := Color("#7de8f0")
## Each rarity's name color.
const RARITY_COLORS := {
	MechPart.Rarity.COMMON: Color(0.85, 0.87, 0.9),
	MechPart.Rarity.UNCOMMON: Color("#5aa9ff"),
	MechPart.Rarity.RARE: Color("#f2b134"),
}
const _TITLES := {
	EnemyLoadout.Tier.NORMAL: "SALVAGE",
	EnemyLoadout.Tier.ELITE: "ELITE SALVAGE",
	EnemyLoadout.Tier.BOSS: "BOSS SALVAGE",
}

var run: RunState
var reward: FightReward

var hud := RunHud.new()
var title_label := Label.new()
var gold_label := Label.new()
var relic_label := Label.new()
var relic_cards := HBoxContainer.new()
var draft_label := Label.new()
var cards := HBoxContainer.new()
var done_button := Button.new()


func _init(p_run: RunState = null, p_reward: FightReward = null) -> void:
	run = p_run
	reward = p_reward
	theme = THEME
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	margin.add_child(column)
	hud.run = run
	column.add_child(hud)
	var center := CenterContainer.new()
	center.size_flags_vertical = SIZE_EXPAND_FILL
	column.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	center.add_child(box)
	_add_label(box, title_label, 32, TITLE_COLOR)
	_add_label(box, gold_label, 20, GOLD_COLOR)
	_add_label(box, relic_label, 15, DIM_COLOR)
	relic_cards.add_theme_constant_override("separation", 18)
	relic_cards.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(relic_cards)
	_add_label(box, draft_label, 15, DIM_COLOR)
	cards.add_theme_constant_override("separation", 18)
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(cards)
	done_button.custom_minimum_size = Vector2(200, 44)
	done_button.size_flags_horizontal = SIZE_SHRINK_CENTER
	done_button.pressed.connect(finished.emit)
	box.add_child(done_button)
	if reward:
		title_label.text = _TITLES[reward.tier]
		gold_label.text = "+%d gold" % reward.gold
		_refresh()


## Takes part [param index] of the draft into the stash. Returns false if the draft is closed.
func take(index: int) -> bool:
	if not run.take_reward_part(reward, index):
		return false
	_refresh()
	return true


## Gives the run relic [param index] of the offer. Returns false if the offer is closed.
func take_relic(index: int) -> bool:
	if not run.take_reward_relic(reward, index):
		return false
	_refresh()
	return true


## Takes the boss's offer to grow the frame instead of a relic. Returns false if the group is closed.
func take_cells() -> bool:
	if not run.take_reward_cells(reward):
		return false
	_refresh()
	return true


## Returns the relic offer's cards, left to right.
func get_relic_cards() -> Array[PanelContainer]:
	var found: Array[PanelContainer] = []
	found.assign(relic_cards.get_children())
	return found


## Returns the draft's cards, left to right.
func get_cards() -> Array[PanelContainer]:
	var found: Array[PanelContainer] = []
	found.assign(cards.get_children())
	return found


func _refresh() -> void:
	for card in cards.get_children() + relic_cards.get_children():
		card.get_parent().remove_child(card)
		card.queue_free()
	relic_label.visible = not reward.relics.is_empty() or reward.cells > 0
	if reward.relic_taken == FightReward.CELLS_TAKEN:
		relic_label.text = "Your frame can grow: open %d cells from the map's Loadout." % reward.cells
	elif reward.relic_taken >= 0:
		relic_label.text = "%s is yours." % reward.relics[reward.relic_taken].relic_name
	elif reward.cells > 0:
		relic_label.text = "Choose a relic, or grow your frame:"
	elif reward.relics.size() > 1:
		relic_label.text = "Choose a relic:"
	else:
		relic_label.text = "Recovered a relic:"
	for i in reward.relics.size():
		relic_cards.add_child(_make_relic_card(i))
	if reward.cells > 0:
		relic_cards.add_child(_make_cells_card())
	if reward.parts.is_empty():
		draft_label.text = "Nothing else worth salvaging."
	elif reward.taken >= 0:
		draft_label.text = "%s is in your stash. Install it from the map's Loadout." % reward.parts[reward.taken].get_display_name()
	else:
		draft_label.text = "Salvage one part for your stash:"
	for i in reward.parts.size():
		cards.add_child(_make_card(i))
	done_button.text = "Skip the rest" if reward.is_draft_open() or reward.is_relic_open() else "Continue"


func _make_card(index: int) -> PanelContainer:
	var part := reward.parts[index]
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(220, 0)
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	card.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	margin.add_child(box)
	var name_label := Label.new()
	_add_label(box, name_label, 17, RARITY_COLORS[part.rarity])
	name_label.text = part.get_display_name()
	var rarity_label := Label.new()
	_add_label(box, rarity_label, 12, DIM_COLOR)
	rarity_label.text = "%s · %s" % [MechPart.Rarity.find_key(part.rarity).capitalize(), PartInfo.summary(part, 0)]
	var shape_frame := CenterContainer.new()
	shape_frame.custom_minimum_size.y = 58
	var shape := PartShapeView.new()
	shape.cell_size = 18.0
	shape.part = part
	shape_frame.add_child(shape)
	box.add_child(shape_frame)
	var description := Label.new()
	_add_label(box, description, 12, DIM_COLOR)
	description.text = part.description
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.custom_minimum_size.x = 190
	description.size_flags_vertical = SIZE_EXPAND_FILL
	var button := Button.new()
	button.custom_minimum_size.y = 36
	if reward.taken == index:
		button.text = "In your stash"
		button.disabled = true
	elif reward.taken >= 0:
		button.text = "Left behind"
		button.disabled = true
		card.modulate = Color(1, 1, 1, 0.45)
	else:
		button.text = "Take"
		# Deferred: taking rebuilds the cards, this button included.
		button.pressed.connect(take.bind(index), CONNECT_DEFERRED)
	box.add_child(button)
	return card


func _make_relic_card(index: int) -> PanelContainer:
	var relic := reward.relics[index]
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(220, 0)
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	card.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	margin.add_child(box)
	var icon_frame := CenterContainer.new()
	icon_frame.add_child(RelicIcon.new(relic, 36.0))
	box.add_child(icon_frame)
	var name_label := Label.new()
	_add_label(box, name_label, 17, relic.color)
	name_label.text = relic.relic_name
	var rarity_label := Label.new()
	_add_label(box, rarity_label, 12, DIM_COLOR)
	rarity_label.text = "%s relic" % Relic.Rarity.find_key(relic.rarity).capitalize()
	var description := Label.new()
	_add_label(box, description, 12, DIM_COLOR)
	description.text = relic.description
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.custom_minimum_size.x = 190
	_finish_group_card(card, box, reward.relic_taken == index, take_relic.bind(index))
	return card


# The boss's offer to grow the frame, in the relic group.
func _make_cells_card() -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(220, 0)
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	card.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	margin.add_child(box)
	var name_label := Label.new()
	_add_label(box, name_label, 17, CELLS_COLOR)
	name_label.text = "Frame Expansion"
	var kind_label := Label.new()
	_add_label(box, kind_label, 12, DIM_COLOR)
	kind_label.text = "Instead of a relic"
	var description := Label.new()
	_add_label(box, description, 12, DIM_COLOR)
	description.text = "Open %d more cells on your frame, picked on the map's Loadout." % reward.cells
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.custom_minimum_size.x = 190
	_finish_group_card(card, box, reward.relic_taken == FightReward.CELLS_TAKEN, take_cells)
	return card


# A group card's button: Taken, Left behind once something else in the group was, or Take.
func _finish_group_card(card: PanelContainer, box: VBoxContainer, taken: bool, take_action: Callable) -> void:
	var button := Button.new()
	button.custom_minimum_size.y = 36
	if taken:
		button.text = "Taken"
		button.disabled = true
	elif reward.relic_taken != -1:
		button.text = "Left behind"
		button.disabled = true
		card.modulate = Color(1, 1, 1, 0.45)
	else:
		button.text = "Take"
		# Deferred: taking rebuilds the cards, this button included.
		button.pressed.connect(take_action, CONNECT_DEFERRED)
	box.add_child(button)


func _add_label(box: Container, label: Label, font_size: int, color: Color) -> void:
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	box.add_child(label)
