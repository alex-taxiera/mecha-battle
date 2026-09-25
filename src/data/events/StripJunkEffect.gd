class_name StripJunkEffect
extends EventEffect
## Takes every junk part off the mech and out of the stash, [member gold_each] gold apiece.

@export var gold_each := 15


func apply(run: RunState, result: EventResult) -> void:
	var stripped := 0
	for i in range(run.stash.size() - 1, -1, -1):
		if run.stash[i].part.type == MechPart.PartType.JUNK:
			run.stash.remove_at(i)
			stripped += 1
	for placement in run.grid.get_placements():
		if placement.part.type == MechPart.PartType.JUNK:
			run.grid.remove_part(placement.origin)
			stripped += 1
	run.gold += stripped * gold_each
	run.changed.emit()
	result.lines.append("Stripped %d junk part%s · +%d gold" % [stripped, "" if stripped == 1 else "s", stripped * gold_each])


func describe(run: RunState) -> String:
	var count := junk_of(run).size()
	return "Strip %d junk part%s for %d gold." % [count, "" if count == 1 else "s", count * gold_each]


## Returns every junk part on [param run]'s mech and in its stash.
static func junk_of(run: RunState) -> Array[MechPart]:
	var junk: Array[MechPart] = []
	for entry in run.stash:
		if entry.part.type == MechPart.PartType.JUNK:
			junk.append(entry.part)
	for placement in run.grid.get_placements():
		if placement.part.type == MechPart.PartType.JUNK:
			junk.append(placement.part)
	return junk
