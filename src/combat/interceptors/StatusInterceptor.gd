class_name StatusInterceptor
extends HitInterceptor
## A status's say in a hit while it has charges (see [method MechStatus.intercept]).

var status: ActiveStatus


func _init(p_status: ActiveStatus) -> void:
	status = p_status
	priority = status.data.priority
	side = status.data.side
	kinds.assign(status.data.kinds)


func intercept(hit: HitPipeline.Hit) -> Result:
	return status.data.intercept(hit, status)
