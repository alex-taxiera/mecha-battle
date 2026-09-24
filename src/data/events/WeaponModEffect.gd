class_name WeaponModEffect
extends EventEffect
## Fits [member mod] to the mech's hardest-hitting mounted weapon, replacing any mod it had (a
## weapon holds one); without one, a mod rolled from the run's [member RunState.mod_pool] (a
## Hangar's Refit). Only that weapon changes; parts are the run's own copies.

@export var mod: WeaponMod


func apply(run: RunState, result: EventResult) -> void:
	var weapon := strongest_weapon(run)
	var fitting := mod if mod else run.roll_mod()
	if weapon == null or fitting == null or not fitting.fits(weapon):
		return
	var old_name := weapon.get_display_name()
	run.fit_mod(fitting)
	result.lines.append("%s is now the %s" % [old_name, weapon.get_display_name()])


func describe(run: RunState) -> String:
	var weapon := strongest_weapon(run)
	if weapon == null:
		return "No weapon to fit a mod to."
	if mod:
		return "Fit %s to your %s." % [mod.prefix, weapon.get_display_name()]
	return "Fit a random mod to your %s." % weapon.get_display_name()


## Returns the mounted weapon with the most damage a shot, the first placed on a tie, or null.
static func strongest_weapon(run: RunState) -> MechPart:
	var best: MechPart = null
	for placement in run.grid.get_placements():
		var part := placement.part
		if part.type == MechPart.PartType.WEAPON and (best == null or part.damage > best.damage):
			best = part
	return best
