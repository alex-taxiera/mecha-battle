class_name Reflective
extends Relic
## An elite affix: a shot of [member threshold] or more (before the mech's plating) deals
## [member damage] back to the attacker.

@export var threshold := 30
@export var damage := 15


func on_hit_taken(mech: BattleMech, hit: HitPipeline.Hit) -> void:
	if hit.kind == HitPipeline.Kind.SHOT and hit.attacker and hit.outgoing >= threshold:
		hit.attacker.take_damage(damage, HitPipeline.Kind.REFLECT, mech)
		mech.relic_triggered.emit(self)
