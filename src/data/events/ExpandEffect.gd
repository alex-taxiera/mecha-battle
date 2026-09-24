class_name ExpandEffect
extends EventEffect
## Lets the player open [member cells] more cells on the frame (from the Loadout). A frame with no
## room left to grow gets [member fallback_hp] max HP instead.

@export var cells := 1
@export var fallback_hp := 40


func apply(run: RunState, result: EventResult) -> void:
	var granted := run.grant_cells(cells)
	if granted > 0:
		result.lines.append("+%d %s to open on the frame (from the Loadout)" % [granted, "cell" if granted == 1 else "cells"])
	elif fallback_hp > 0:
		var upgrade := HullUpgrade.new()
		upgrade.hp = fallback_hp
		run.add_upgrade(upgrade)
		result.lines.append("The frame can't grow any more: +%d max HP instead" % fallback_hp)


func describe(_run: RunState) -> String:
	return "Open %d more %s on the frame." % [cells, "cell" if cells == 1 else "cells"]
