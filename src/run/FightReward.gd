class_name FightReward
extends RefCounted
## What a won fight drops: gold, collected at once, and a draft of parts to pick one from (or
## skip). Rolled by [method RunState.roll_reward].

var tier := EnemyLoadout.Tier.NORMAL
var gold := 0
## The parts on offer. Taking one ends the draft.
var parts: Array[MechPart] = []
## Which of [member parts] was taken, or -1.
var taken := -1


func is_draft_open() -> bool:
	return taken < 0 and not parts.is_empty()
