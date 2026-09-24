class_name GoldEffect
extends EventEffect
## Gains gold, or pays it when [member amount] is below 0 (never below 0 gold).

@export var amount := 0


func apply(run: RunState, result: EventResult) -> void:
	var paid := mini(-amount, run.gold) if amount < 0 else 0
	run.gold += amount if amount >= 0 else -paid
	run.changed.emit()
	result.lines.append("+%d gold" % amount if amount >= 0 else "-%d gold" % paid)


func describe(_run: RunState) -> String:
	return "%+d gold." % amount
