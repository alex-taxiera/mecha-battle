class_name HeatConverter
extends Relic
## Weapons hit harder while the mech runs hot.

## Above this much heat...
@export var threshold := 50
## ...shots deal this much more: 0.2 is +20%, rounded.
@export var bonus := 0.2


func modify_shot_damage(mech: BattleMech, _weapon: ActivePart, damage: int) -> int:
	return roundi(damage * (1.0 + bonus)) if mech.heat > threshold else damage
