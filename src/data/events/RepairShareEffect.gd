class_name RepairShareEffect
extends EventEffect
## Repairs [member share] of the mech's max HP (as the run's modifiers change the share), rounded
## up, as far as the hull is damaged.

@export var share := 0.3


func apply(run: RunState, result: EventResult) -> void:
	result.lines.append("Repaired %d hull" % run.heal(ceili(run.get_max_hp() * run.get_repair_share(share))))


func describe(run: RunState) -> String:
	var actual := run.get_repair_share(share)
	var amount := mini(ceili(run.get_max_hp() * actual), run.hull_damage)
	return "Repair %d hull (%d%% of max)." % [amount, roundi(actual * 100)]
