class_name HullEffect
extends EventEffect
## Repairs the hull, or damages it when [member amount] is below 0. Damage never destroys the
## mech: it leaves at least 1 HP.

@export var amount := 0


func apply(run: RunState, result: EventResult) -> void:
	if amount >= 0:
		result.lines.append("Repaired %d hull" % run.heal(amount))
	else:
		var before := run.get_current_hp()
		run.damage_hull(-amount)
		result.lines.append("Took %d damage" % (before - run.get_current_hp()))
