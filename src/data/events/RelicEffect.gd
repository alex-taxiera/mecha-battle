class_name RelicEffect
extends EventEffect
## Gives the run a relic: [member relic] if it's set, otherwise one rolled from the run's pool,
## of [member rarity] if that's set (falling back to the others when none is left).

@export var relic: Relic
## The rarity to roll, or -1 for the chest odds (mostly common, some uncommon and rare).
@export var rarity := -1


func apply(run: RunState, result: EventResult) -> void:
	var weights := RelicPool.CHEST_WEIGHTS if rarity < 0 else {rarity: 1}
	var given := relic if relic else run.relic_pool.roll(run.rng.stream("relics"), weights)
	if given == null:
		return
	run.add_relic(given)
	result.lines.append("Found the %s" % given.relic_name)
