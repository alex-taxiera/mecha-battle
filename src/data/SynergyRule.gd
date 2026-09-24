class_name SynergyRule
extends Resource
## A bonus that two touching parts give, matched by their part types and, optionally, a tag
## each must carry (e.g. only a heatsink, not every utility part).

enum Target { FIRST, SECOND, BOTH }

@export var id: String
## Shown in the rules legend, e.g. "Heatsink + Weapon".
@export var label: String
## Shown next to the label, e.g. "weapon dmg ×1.5".
@export var effect_text: String
## Marks this rule's links on the grid and in the stats panel.
@export var color := Color.WHITE
@export var first_type: MechPart.PartType
## A tag the first part must carry, or empty for any part of [member first_type].
@export var first_tag := ""
@export var second_type: MechPart.PartType
## A tag the second part must carry, or empty for any part of [member second_type].
@export var second_tag := ""
## Which part of the pair gets the bonuses. Use BOTH when the two sides are the same.
@export var target: Target
## What the linked part gets: each a stat, added to or multiplied.
@export var bonuses: Array[RuleBonus] = []
## Whether the bonuses apply once per touching partner (true) or at most once (false).
@export var stacks := true


## Returns whether this rule links [param a] with [param b], in either order.
func matches(a: MechPart, b: MechPart) -> bool:
	return (fits_first(a) and fits_second(b)) or (fits_first(b) and fits_second(a))


## Returns whether [param part] can be the first side of the rule.
func fits_first(part: MechPart) -> bool:
	return part.type == first_type and (first_tag.is_empty() or part.has_tag(first_tag))


## Returns whether [param part] can be the second side of the rule.
func fits_second(part: MechPart) -> bool:
	return part.type == second_type and (second_tag.is_empty() or part.has_tag(second_tag))
