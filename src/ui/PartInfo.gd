class_name PartInfo
extends VBoxContainer
## Everything there is to read about a placed part: its name, type and size, its numbers with
## links applied, the bonuses those links give, and its blurb. MechGridUI shows it as a hover
## popup so the grid itself carries no text.

const WIDTH := 260.0
const NAME_FONT_SIZE := 16
const FONT_SIZE := 13
const TEXT_COLOR := Color(0.93, 0.94, 0.96)
const BONUS_COLOR := Color(0.49, 0.88, 0.63)
const DIM_COLOR := Color(0.7, 0.72, 0.76)


func _init(part: MechPart, turns: int, numbers: MechStats.PartStats) -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	custom_minimum_size.x = WIDTH
	add_theme_constant_override("separation", 2)
	var rows := _rows(part, turns, numbers)
	for i in rows.size():
		var label := Label.new()
		label.text = rows[i][0]
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		# Give it its width now: a wrapping label measures its height at its current width, and
		# the popup is sized from that before any layout runs.
		label.size.x = WIDTH
		label.add_theme_font_size_override("font_size", NAME_FONT_SIZE if i == 0 else FONT_SIZE)
		label.add_theme_color_override("font_color", rows[i][1])
		add_child(label)


## Returns the popup's text, one line per row.
static func text_for(part: MechPart, turns: int, numbers: MechStats.PartStats) -> String:
	return "\n".join(_rows(part, turns, numbers).map(func(row: Array) -> String: return row[0]))


## Returns the text of each row shown.
func get_rows() -> PackedStringArray:
	return PackedStringArray(get_children().map(func(label: Label) -> String: return label.text))


## A part's type and size, e.g. "Weapon · 1×3", "Defense · 1 block", or "Utility · 3 blocks".
static func summary(part: MechPart, turns: int) -> String:
	var shape := part.get_shape(turns)
	var extent := PartShapeView.shape_extent(shape)
	var size_text := "%d blocks" % shape.size()
	if shape.size() == 1:
		size_text = "1 block"
	elif extent.x * extent.y == shape.size():
		size_text = "%d×%d" % [extent.x, extent.y]
	return "%s · %s" % [MechPart.PartType.find_key(part.type).capitalize(), size_text]


## A part's numbers in a line, e.g. "17 DMG · -3 EN · +20 HEAT" or "+6 EN · +5 HP".
static func stat_line(numbers: MechStats.PartStats) -> String:
	var bits: PackedStringArray = []
	if numbers.damage:
		bits.append("%d DMG" % numbers.damage)
	if numbers.energy_draw:
		bits.append("-%d EN" % numbers.energy_draw)
	if numbers.energy:
		bits.append("+%d EN" % numbers.energy)
	if numbers.hp:
		bits.append("+%d HP" % numbers.hp)
	if numbers.heat:
		bits.append("+%d HEAT" % numbers.heat)
	if numbers.cooling:
		bits.append("-%d HEAT" % numbers.cooling)
	if numbers.shield:
		bits.append("+%d SHIELD" % numbers.shield)
	if numbers.upkeep:
		bits.append("-%d EN upkeep" % numbers.upkeep)
	# The cadence only when a link changed it; the blurb gives the part's own.
	var cadence := numbers.get_bonus_total(RuleBonus.Stat.COOLDOWN)
	if numbers.cooldown > 0.0 and (not is_zero_approx(cadence[0]) or not is_equal_approx(cadence[1], 1.0)):
		bits.append("every %ss" % snappedf(numbers.cooldown, 0.01))
	if not bits.is_empty():
		return " · ".join(bits)
	return "Links: %d" % numbers.links if numbers.links else "Not linked"


## The bonuses a part gets from its links, e.g. "Overcharge +3 · Cooled ×1.5". A rule with more
## than one bonus names each stat: "Volatile +20 EN / +10 HEAT".
static func bonus_line(numbers: MechStats.PartStats) -> String:
	var bits: PackedStringArray = []
	for rule: SynergyRule in numbers.bonuses:
		var count := numbers.bonuses[rule]
		var parts: PackedStringArray = []
		for bonus in rule.bonuses:
			var text := bonus.describe(count)
			parts.append(text if rule.bonuses.size() == 1 else "%s %s" % [text, RuleBonus.STAT_LABELS[bonus.stat]])
		bits.append("%s %s" % [rule.id.capitalize(), " / ".join(parts)])
	return " · ".join(bits)


# Each row as [text, color]: name, summary, numbers, bonuses (if any), blurb (if any).
static func _rows(part: MechPart, turns: int, numbers: MechStats.PartStats) -> Array:
	var rows := [
		[part.get_display_name(), TEXT_COLOR],
		[summary(part, turns), PartShapeView.color_for(part.type)],
		[stat_line(numbers), TEXT_COLOR],
	]
	var bonuses := bonus_line(numbers)
	if not bonuses.is_empty():
		rows.append([bonuses, BONUS_COLOR])
	if not part.description.is_empty():
		rows.append([part.description, DIM_COLOR])
	return rows
