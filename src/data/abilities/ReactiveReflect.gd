class_name ReactiveReflect
extends PartAbility
## Armor that bites back: a shot of [member threshold] damage or more (before plating) deals
## [member damage] back to the attacker.

@export var threshold := 30
@export var damage := 15


func on_hit_taken(_mech: BattleMech, _active: ActivePart, hit: int) -> int:
	return damage if hit >= threshold else 0
