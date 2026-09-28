class_name DatabankScreen
extends Control
## The Databank: a tab each for the game's parts, relics, field kits, and enemies. Content the
## profile hasn't unlocked shows as a silhouette with how to earn it. Enemies are listed by sector
## with their builds and a boss's phases. Built in code; Back emits [signal closed]. The codex
## follows Slay-The-Robot's (MIT, DesirePathGames), with locked entries hidden, not left out.

signal closed

const THEME := preload("res://resources/ui/theme.tres")
const TITLE_COLOR := Color("#5aa9ff")
const TEXT_COLOR := Color(0.93, 0.94, 0.96)
const DIM_COLOR := Color(0.72, 0.74, 0.78)
const LOCKED_COLOR := Color(0.94, 0.42, 0.42)
const TIER_NAMES := {EnemyLoadout.Tier.NORMAL: "Normal", EnemyLoadout.Tier.ELITE: "Elite", EnemyLoadout.Tier.BOSS: "Boss"}

var profile: Profile
var unlocks: Array[Unlock] = []
var tabs := TabContainer.new()
var back_button := Button.new()


## [param relics] may hold affixes and hazards; only the ones a run can find are listed.
func _init(p_profile: Profile = null, p_unlocks: Array[Unlock] = [], parts: Array[MechPart] = [], relics: Array[Relic] = [],
		kits: Array[FieldKit] = [], acts: Array[ActData] = []) -> void:
	profile = p_profile
	unlocks.assign(p_unlocks)
	theme = THEME
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var title := _label("DATABANK", 30, TITLE_COLOR)
	title.size_flags_horizontal = SIZE_EXPAND_FILL
	header.add_child(title)
	back_button.text = "Back"
	back_button.custom_minimum_size = Vector2(140, 40)
	back_button.pressed.connect(closed.emit)
	header.add_child(back_button)
	tabs.size_flags_vertical = SIZE_EXPAND_FILL
	column.add_child(tabs)
	var sorted_parts := parts.duplicate()
	sorted_parts.sort_custom(func(a: MechPart, b: MechPart) -> bool:
		return a.type < b.type or (a.type == b.type and a.part_name < b.part_name))
	_add_tab("Parts", sorted_parts.map(_part_entry))
	var findable := relics.filter(func(relic: Relic) -> bool: return relic.rarity != Relic.Rarity.AFFIX)
	findable.sort_custom(func(a: Relic, b: Relic) -> bool:
		return a.rarity < b.rarity or (a.rarity == b.rarity and a.relic_name < b.relic_name))
	_add_tab("Relics", findable.map(_relic_entry))
	_add_tab("Kits", kits.map(_kit_entry))
	var enemy_entries: Array = []
	for act in acts:
		enemy_entries.append(_label(act.sector_name.to_upper(), 16, TITLE_COLOR))
		var enemies := act.enemies.duplicate()
		enemies.sort_custom(func(a: EnemyLoadout, b: EnemyLoadout) -> bool: return a.tier < b.tier)
		for enemy: EnemyLoadout in enemies:
			enemy_entries.append(_enemy_entry(enemy))
	_add_tab("Enemies", enemy_entries)


## Returns the entries' text on tab [param tab_name], one list per entry.
func get_entry_texts(tab_name: String) -> Array[PackedStringArray]:
	var texts: Array[PackedStringArray] = []
	var list := tabs.get_node(tab_name).get_child(0) as Container
	for entry in list.get_children():
		var lines := PackedStringArray()
		for node in [entry] + entry.find_children("*", "Label", true, false):
			if node is Label:
				lines.append((node as Label).text)
		texts.append(lines)
	return texts


func _add_tab(tab_name: String, entries: Array) -> void:
	var scroll := ScrollContainer.new()
	scroll.name = tab_name
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var list := VBoxContainer.new()
	list.size_flags_horizontal = SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	for entry: Control in entries:
		list.add_child(entry)
	tabs.add_child(scroll)


func _part_entry(part: MechPart) -> Control:
	var lock := _lock(Unlock.Kind.PART, part.id)
	var shape := PartShapeView.new()
	shape.cell_size = 14.0
	shape.part = part
	if lock:
		shape.modulate = Color(0, 0, 0, 0.6)
	var kind := "%s · %s" % [MechPart.Rarity.find_key(part.rarity).capitalize(), PartInfo.summary(part, 0)]
	return _entry(shape, part.part_name, PartShapeView.TYPE_COLORS.get(part.type, TEXT_COLOR), kind, part.description, lock)


func _relic_entry(relic: Relic) -> Control:
	var lock := _lock(Unlock.Kind.RELIC, relic.id)
	var icon := RelicIcon.new(relic, 32.0)
	var kind := "%s relic" % Relic.Rarity.find_key(relic.rarity).capitalize()
	if not relic.chassis_id.is_empty():
		kind += " · %s only" % relic.chassis_id.capitalize()
	return _entry(icon, relic.relic_name, relic.color, kind, relic.description, lock)


func _kit_entry(kit: FieldKit) -> Control:
	var lock := _lock(Unlock.Kind.KIT, kit.id)
	return _entry(KitIcon.new(kit, 32.0), kit.kit_name, kit.color, "Field kit · %s" % kit.describe_trigger(), kit.description, lock)


func _enemy_entry(enemy: EnemyLoadout) -> Control:
	var parts := PackedStringArray()
	for entry in enemy.lineup:
		parts.append(entry.part.part_name)
	var details := "%s · on %s · parts: %s" % [TIER_NAMES[enemy.tier], enemy.chassis.chassis_name, ", ".join(parts)]
	for phase in enemy.phases:
		details += "\nPhase: %s" % phase.title
	return _entry(null, enemy.enemy_name, TEXT_COLOR, "", details, null)


# One row: an icon, the name in its color, a kind line, and its text; a locked one hides the name
# and text behind its unlock's hint.
func _entry(icon: Control, entry_name: String, color: Color, kind: String, text: String, lock: Unlock) -> Control:
	var card := PanelContainer.new()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	card.add_child(row)
	var frame := CenterContainer.new()
	frame.custom_minimum_size = Vector2(80, 0)
	if icon:
		frame.add_child(icon)
	row.add_child(frame)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	box.size_flags_horizontal = SIZE_EXPAND_FILL
	row.add_child(box)
	if lock:
		box.add_child(_label("???", 16, DIM_COLOR))
		box.add_child(_label("Locked · %s" % lock.hint, 12, LOCKED_COLOR))
		return card
	box.add_child(_label(entry_name, 16, color))
	if not kind.is_empty():
		box.add_child(_label(kind, 12, DIM_COLOR))
	var body := _label(text, 12, TEXT_COLOR)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(body)
	return card


func _lock(kind: Unlock.Kind, id: String) -> Unlock:
	return profile.get_lock(kind, id, unlocks) if profile else null


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label
