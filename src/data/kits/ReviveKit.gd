class_name ReviveKit
extends FieldKit
## Brings a mech that just went down back up at [member share] of its max HP.

@export var share := 0.2


func apply(mech: BattleMech, _enemy: BattleMech) -> void:
	mech.current_health = maxi(mech.current_health, maxi(1, roundi(mech.max_hp * share)))
