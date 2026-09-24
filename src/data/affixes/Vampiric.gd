class_name Vampiric
extends Relic
## An elite affix: each of the mech's shots that lands repairs it by [member share] of the damage
## it did.

@export var share := 0.2


func on_hit_dealt(mech: BattleMech, hit: HitPipeline.Hit) -> void:
	mech.heal(roundi(hit.taken * share))
