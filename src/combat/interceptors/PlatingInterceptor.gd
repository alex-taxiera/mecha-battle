class_name PlatingInterceptor
extends HitInterceptor
## Thick Plating: every hit the mech takes is [member plating] smaller, never below 0, unless
## it pierces plating.

const PRIORITY := 9000

var plating: int


func _init(p_plating: int) -> void:
	plating = p_plating
	priority = PRIORITY
	side = Side.TARGET


func intercept(hit: HitPipeline.Hit) -> Result:
	if not hit.pierce_plating:
		hit.damage = maxi(0, hit.damage - plating)
	return Result.CONTINUE
