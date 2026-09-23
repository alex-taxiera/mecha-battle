class_name RelicEffect
extends EventEffect
## Gives the run a relic: [member relic] if it's set, otherwise one rolled from the run's pool.

@export var relic: Relic


func apply(run: RunState, result: EventResult) -> void:
	var given := relic if relic else run.relic_pool.roll(run.rng.stream("relics"), RelicPool.CHEST_WEIGHTS)
	if given == null:
		return
	run.add_relic(given)
	result.lines.append("Found the %s" % given.relic_name)
