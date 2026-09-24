class_name UpgradePartEffect
extends EventEffect
## Raises one of the player's parts a Mk: a random upgradable one, or the strongest (the most
## damage a shot, then the most HP).

enum Pick { RANDOM, STRONGEST }

@export var pick := Pick.RANDOM


func apply(run: RunState, result: EventResult) -> void:
	var part := choose(run)
	if part == null:
		return
	var old_name := part.get_display_name()
	run.upgrade_part(part)
	result.lines.append("%s is now %s" % [old_name, part.get_display_name()])


## Returns the part this effect would raise in [param run], or null if nothing can go up a Mk.
func choose(run: RunState) -> MechPart:
	var parts := run.get_upgradable_parts()
	if parts.is_empty():
		return null
	if pick == Pick.RANDOM:
		return parts[run.rng.stream("events").randi_range(0, parts.size() - 1)]
	var best := parts[0]
	for part in parts:
		if part.damage > best.damage or (part.damage == best.damage and part.hp > best.hp):
			best = part
	return best
