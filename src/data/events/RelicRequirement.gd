class_name RelicRequirement
extends EventRequirement
## Needs the run to have the relic with id [member relic_id].

@export var relic_id: String
@export var relic_name: String


func check(run: RunState) -> bool:
	return run.relics.any(func(relic: Relic) -> bool: return relic.id == relic_id)


func describe() -> String:
	return "Needs the %s" % relic_name
