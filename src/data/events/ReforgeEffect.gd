class_name ReforgeEffect
extends EventEffect
## Melts a random stashed part (not junk) down and recasts it as a random catalog part of the next
## rarity up (the same rarity for a rare, or when the catalog has none a rarity up), rolled on the
## run's "events" stream. The new part goes in the stash.


func apply(run: RunState, result: EventResult) -> void:
	var picks: Array[int] = []
	for i in run.stash.size():
		if run.stash[i].part.type != MechPart.PartType.JUNK:
			picks.append(i)
	if picks.is_empty():
		return
	var stream := run.rng.stream("events")
	var index: int = picks[stream.randi_range(0, picks.size() - 1)]
	var old := run.stash[index].part
	var rarity := mini(old.rarity + 1, MechPart.Rarity.RARE)
	var pool := run.catalog.filter(func(part: MechPart) -> bool: return part.rarity == rarity and part.id != old.id)
	# With nothing a rarity up, one of the same rarity.
	if pool.is_empty():
		pool = run.catalog.filter(func(part: MechPart) -> bool: return part.rarity == old.rarity and part.id != old.id)
	if pool.is_empty():
		return
	var recast: MechPart = pool[stream.randi_range(0, pool.size() - 1)]
	run.stash.remove_at(index)
	run.stash_part(recast)
	result.lines.append("Recast the %s into a %s" % [old.get_display_name(), recast.part_name])


func describe(_run: RunState) -> String:
	return "Recast a random stashed part into one of the next rarity up."
