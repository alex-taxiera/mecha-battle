class_name ThickPlatingPassive
extends ChassisPassive
## Every hit the mech takes, from any source, is [member plating] smaller, never below 0, unless
## it pierces plating.

@export var plating := 2


func make_interceptors(_mech: BattleMech) -> Array[HitInterceptor]:
	return [PlatingInterceptor.new(plating)]
