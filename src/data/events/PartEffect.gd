class_name PartEffect
extends EventEffect
## Puts a part in the stash: [member part] if it's set, otherwise one from the run's catalog of
## [member rarity] (the nearest rarity if there's none), weapons only if [member weapon].

@export var part: MechPart
@export var rarity := MechPart.Rarity.COMMON
@export var weapon := false


func apply(run: RunState, result: EventResult) -> void:
	var given := part if part else _pick(run)
	if given == null:
		return
	run.stash_part(given)
	result.lines.append("%s added to your stash" % given.part_name)


func _pick(run: RunState) -> MechPart:
	var pool: Array[MechPart] = run.catalog.filter(func(candidate: MechPart) -> bool:
		return not weapon or candidate.type == MechPart.PartType.WEAPON)
	if pool.is_empty():
		return null
	var rng := run.rng.stream("events")
	for distance in MechPart.Rarity.size():
		for wanted in [rarity - distance, rarity + distance]:
			var matching := pool.filter(func(candidate: MechPart) -> bool: return candidate.rarity == wanted)
			if not matching.is_empty():
				return matching[rng.randi_range(0, matching.size() - 1)]
	return null
