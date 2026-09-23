class_name WeaponModEffect
extends EventEffect
## Reworks the mech's hardest-hitting mounted weapon, for good: its damage and energy cost scaled,
## its heat per shot raised, and a new name. Only that one weapon changes; parts are the run's
## own copies.

@export var prefix := "Modified"
@export var damage_scale := 1.0
@export var energy_scale := 1.0
@export var heat_add := 0


func apply(run: RunState, result: EventResult) -> void:
	var weapon := strongest_weapon(run)
	if weapon == null:
		return
	var old_name := weapon.part_name
	weapon.damage = roundi(weapon.damage * damage_scale)
	weapon.energy_cost = roundi(weapon.energy_cost * energy_scale)
	weapon.heat += heat_add
	weapon.part_name = "%s %s" % [prefix, old_name]
	run.changed.emit()
	result.lines.append("%s is now the %s" % [old_name, weapon.part_name])


## Returns the mounted weapon with the most damage a shot, the first placed on a tie, or null.
static func strongest_weapon(run: RunState) -> MechPart:
	var best: MechPart = null
	for placement in run.grid.get_placements():
		var part := placement.part
		if part.type == MechPart.PartType.WEAPON and (best == null or part.damage > best.damage):
			best = part
	return best
