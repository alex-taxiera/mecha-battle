class_name LosePartsEffect
extends EventEffect
## Takes [member count] parts the player owns, at random: stashed ones first, then installed ones.

@export var count := 1


func apply(run: RunState, result: EventResult) -> void:
	var rng := run.rng.stream("events")
	var lost: PackedStringArray = []
	for i in count:
		if not run.stash.is_empty():
			var index := rng.randi_range(0, run.stash.size() - 1)
			lost.append(run.stash[index].part.part_name)
			run.stash.remove_at(index)
		else:
			var placements := run.grid.get_placements()
			if placements.is_empty():
				break
			var placement: MechGridData.Placement = placements[rng.randi_range(0, placements.size() - 1)]
			lost.append(placement.part.part_name)
			run.grid.remove_part(placement.origin)
	run.changed.emit()
	if not lost.is_empty():
		result.lines.append("Lost %s" % ", ".join(lost))
