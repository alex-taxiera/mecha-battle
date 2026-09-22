class_name SynergyRule
extends Resource
## A bonus that two touching parts give, matched by their part types.

enum Target { FIRST, SECOND, BOTH }
enum Stat { HP, ENERGY, DAMAGE }
enum Op { ADD, MULTIPLY }

@export var id: String
## Shown in the rules legend, e.g. "Heatsink + Weapon".
@export var label: String
## Shown next to the label, e.g. "weapon dmg ×1.5".
@export var effect_text: String
@export var first_type: MechPart.PartType
@export var second_type: MechPart.PartType
## Which part of the pair gets the bonus. Use BOTH when the two types are the same.
@export var target: Target
@export var stat: Stat
@export var op: Op
@export var amount: float
## Whether the bonus applies once per touching partner (true) or at most once (false).
@export var stacks := true


## Returns whether this rule links a part of [param type_a] with one of [param type_b], in
## either order.
func matches(type_a: MechPart.PartType, type_b: MechPart.PartType) -> bool:
	return (type_a == first_type and type_b == second_type) \
		or (type_a == second_type and type_b == first_type)
