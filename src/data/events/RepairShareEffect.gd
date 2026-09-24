class_name RepairShareEffect
extends EventEffect
## Repairs [member share] of the mech's max HP, rounded up, as far as the hull is damaged.

@export var share := 0.3


func apply(run: RunState, result: EventResult) -> void:
	result.lines.append("Repaired %d hull" % run.heal(ceili(run.get_max_hp() * share)))


func describe(run: RunState) -> String:
	var amount := mini(ceili(run.get_max_hp() * share), run.hull_damage)
	return "Repair %d hull (%d%% of max)." % [amount, roundi(share * 100)]
