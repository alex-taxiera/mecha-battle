class_name MaxHpEffect
extends EventEffect
## Raises the mech's max HP for the rest of the run, or lowers it when [member hp] is below 0.

@export var hp := 25


func apply(run: RunState, result: EventResult) -> void:
	var upgrade := HullUpgrade.new()
	upgrade.hp = hp
	run.add_upgrade(upgrade)
	result.lines.append("%+d max HP" % hp)
