class_name RelicInterceptor
extends HitInterceptor
## A relic's say in a hit: on the attacker's side, [method Relic.modify_shot_damage] for its
## shots, announced when it changes one; on the target's, [method Relic.modify_damage_taken] for
## every hit, after plating.

const SHOT_PRIORITY := 10000
const TAKEN_PRIORITY := 8000

var relic: Relic


func _init(p_relic: Relic, p_side: HitInterceptor.Side) -> void:
	relic = p_relic
	side = p_side
	if side == Side.ATTACKER:
		priority = SHOT_PRIORITY
		kinds = [HitPipeline.Kind.SHOT]
	else:
		priority = TAKEN_PRIORITY


func intercept(hit: HitPipeline.Hit) -> Result:
	if side == Side.TARGET:
		hit.damage = relic.modify_damage_taken(hit.target, hit.damage)
		return Result.CONTINUE
	var changed := relic.modify_shot_damage(hit.attacker, hit.weapon, hit.damage)
	if changed != hit.damage and not hit.preview:
		hit.attacker.relic_triggered.emit(relic)
	hit.damage = changed
	return Result.CONTINUE
