class_name HangarJob
extends Resource
## One job a Hangar's crew can do, like Repair or Expand: its effects (the event effects), what it
## needs, what it costs, and whether it ends the visit. The jobs live in
## [code]res://resources/hangar_jobs/[/code]; relics can add more ([member Relic.hangar_jobs]).
## Adapted from Slay-The-Robot's rest actions (MIT, DesirePathGames).

## UPGRADE jobs have the player pick a part to raise a Mk; EFFECTS jobs just apply their effects.
enum Kind { EFFECTS, UPGRADE }
## EXCLUSIVE: doing it ends the visit. INCLUSIVE: it doesn't, but it's done once. REPEATABLE: as
## often as the player can pay.
enum CostType { EXCLUSIVE, INCLUSIVE, REPEATABLE }

@export var id: String
## Where the job sits in the Hangar's list, lowest first.
@export var order := 0
@export var label: String
## The button's hint; empty to build it from the effects (see [method describe]).
@export_multiline var hint := ""
@export var kind := Kind.EFFECTS
@export var effects: Array[EventEffect] = []
## What it needs, or null.
@export var requirement: EventRequirement
@export var cost := 0
@export var cost_type := CostType.EXCLUSIVE


## Returns the hint: [member hint], or its effects' descriptions, with the price if it has one.
func describe(run: RunState) -> String:
	var text := hint
	if text.is_empty():
		text = " ".join(effects.map(func(effect: EventEffect) -> String: return effect.describe(run)).filter(
			func(line: String) -> bool: return not line.is_empty()))
	return "%s (%d gold)" % [text, cost] if cost > 0 else text


## Returns whether the run can have the job done now: it meets the requirement and can pay.
func is_available(run: RunState) -> bool:
	return (requirement == null or requirement.check(run)) and run.gold >= cost
