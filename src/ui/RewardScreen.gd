class_name RewardScreen
extends Control
## What a won fight dropped: the gold (already collected) and a draft of parts, one of which the
## player can take into their stash, or skip. The button at the bottom emits [signal finished].

## Emitted when the player is done with the loot.
signal finished

const THEME := preload("res://resources/ui/theme.tres")
const TITLE_COLOR := Color("#5fd38a")
const DIM_COLOR := Color(0.72, 0.74, 0.78)
const GOLD_COLOR := Color(0.96, 0.83, 0.43)
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
	box.add_theme_constant_override("separation", 18)
	center.add_child(box)
	_add_label(box, title_label, 40, TITLE_COLOR)
	_add_label(box, gold_label, 22, GOLD_COLOR)
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


## Returns the draft's cards, left to right.
func get_cards() -> Array[PanelContainer]:
	var found: Array[PanelContainer] = []
	found.assign(cards.get_children())
	return found


func _refresh() -> void:
	for card in cards.get_children():
		cards.remove_child(card)
		card.queue_free()
	if reward.parts.is_empty():
		draft_label.text = "Nothing else worth salvaging."
	elif reward.taken >= 0:
		draft_label.text = "%s is in your stash. Install it from the map's Loadout." % reward.parts[reward.taken].part_name
	else:
		draft_label.text = "Salvage one part for your stash:"
	for i in reward.parts.size():
		cards.add_child(_make_card(i))
	done_button.text = "Skip parts" if reward.is_draft_open() else "Continue"


func _make_card(index: int) -> PanelContainer:
	var part := reward.parts[index]
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(220, 230)
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	card.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)
	var name_label := Label.new()
	_add_label(box, name_label, 17, RARITY_COLORS[part.rarity])
	name_label.text = part.part_name
	var rarity_label := Label.new()
	_add_label(box, rarity_label, 12, DIM_COLOR)
	rarity_label.text = "%s · %s" % [MechPart.Rarity.find_key(part.rarity).capitalize(), PartInfo.summary(part, 0)]
	var shape_frame := CenterContainer.new()
	shape_frame.custom_minimum_size.y = 70
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


func _add_label(box: Container, label: Label, font_size: int, color: Color) -> void:
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	box.add_child(label)
