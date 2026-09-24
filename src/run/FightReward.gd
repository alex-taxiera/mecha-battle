class_name FightReward
extends RefCounted
## What a won fight drops: gold, collected at once, a draft of parts to pick one from (or skip),
## and for elites and bosses, relics: an elite's one, or a choice of a boss's. A boss can also
## offer to grow the frame, in the same group as its relics: take one thing from the group.
## Rolled by [method RunState.roll_reward]. The group is adapted from Slay-The-Robot's reward
## groups (MIT, DesirePathGames).

## [member relic_taken] when the frame's growth was taken instead of a relic.
const CELLS_TAKEN := -2
## [member relic_taken] when the weapon mod was taken instead of a relic.
const MOD_TAKEN := -3

var tier := EnemyLoadout.Tier.NORMAL
var gold := 0
## The parts on offer. Taking one ends the draft.
var parts: Array[MechPart] = []
## Which of [member parts] was taken, or -1.
var taken := -1
## The relics on offer: take one.
var relics: Array[Relic] = []
## Cells to open on the frame, offered in the same group as [member relics] (0 for none).
var cells := 0
## A weapon mod for the mech's strongest weapon, offered in the same group as [member relics]
## (an elite's), or null.
var mod: WeaponMod
## A field kit the fight dropped, taken on its own (not in the relic group), or null.
var kit: FieldKit
var kit_taken := false
## Which of [member relics] was taken, [constant CELLS_TAKEN] for the cells, or -1.
var relic_taken := -1


func is_draft_open() -> bool:
	return taken < 0 and not parts.is_empty()


## Whether the relic group (relics, and any cells) still has something to take.
func is_relic_open() -> bool:
	return relic_taken == -1 and (not relics.is_empty() or cells > 0 or mod != null)
