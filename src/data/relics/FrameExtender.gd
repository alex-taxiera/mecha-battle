class_name FrameExtender
extends Relic
## When found, the frame can open [member cells] more cells; for each it has no room for, the
## run gets [member fallback_hp] max HP instead.

@export var cells := 3
@export var fallback_hp := 40


func on_obtain(run: RunState) -> void:
	var missing := cells - run.grant_cells(cells)
	if missing > 0:
		var upgrade := HullUpgrade.new()
		upgrade.hp = fallback_hp * missing
		run.add_upgrade(upgrade)
