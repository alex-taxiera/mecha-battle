class_name FightReward
extends RefCounted
## What a won fight drops: gold, collected at once, a draft of parts to pick one from (or skip),
## and for elites and bosses, relics: an elite's one, or a choice of a boss's. Rolled by
## [method RunState.roll_reward].

var tier := EnemyLoadout.Tier.NORMAL
var gold := 0
## The parts on offer. Taking one ends the draft.
var parts: Array[MechPart] = []
## Which of [member parts] was taken, or -1.
var taken := -1
## The relics on offer: take one.
var relics: Array[Relic] = []
## Which of [member relics] was taken, or -1.
var relic_taken := -1


func is_draft_open() -> bool:
	return taken < 0 and not parts.is_empty()


func is_relic_open() -> bool:
	return relic_taken < 0 and not relics.is_empty()
