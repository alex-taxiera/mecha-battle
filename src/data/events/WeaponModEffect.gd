class_name WeaponModEffect
extends EventEffect
## Fits [member mod] to the mech's hardest-hitting mounted weapon, replacing any mod it had (a
## weapon holds one). Only that weapon changes; parts are the run's own copies.

@export var mod: WeaponMod


func apply(run: RunState, result: EventResult) -> void:
	var weapon := strongest_weapon(run)
	if weapon == null or mod == null or not mod.fits(weapon):
		return
	var old_name := weapon.get_display_name()
	weapon.mod = mod
	run.changed.emit()
	result.lines.append("%s is now the %s" % [old_name, weapon.get_display_name()])


## Returns the mounted weapon with the most damage a shot, the first placed on a tie, or null.
static func strongest_weapon(run: RunState) -> MechPart:
	var best: MechPart = null
	for placement in run.grid.get_placements():
		var part := placement.part
		if part.type == MechPart.PartType.WEAPON and (best == null or part.damage > best.damage):
			best = part
	return best
