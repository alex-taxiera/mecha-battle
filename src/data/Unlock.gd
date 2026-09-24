class_name Unlock
extends Resource
## Something a profile earns by reaching a milestone: a chassis, a part or relic for loot and
## shops, or an NPC. Content without an unlock is always available; content with one is locked
## until its milestone is met. The unlocks live in [code]res://resources/unlocks/[/code].

enum Kind { CHASSIS, PART, RELIC, NPC }

@export var id: String
@export var kind := Kind.CHASSIS
## The id of what it unlocks: a chassis, part, or relic id, or an NPC's (e.g. "technician").
@export var target_id: String
## What the player sees once it's earned, e.g. "The Striker".
@export var title: String
## How to earn it, shown while it's locked, e.g. "Clear Sector 1".
@export var hint: String

@export_group("Milestone")
## Sectors to clear in one run (0 for none).
@export var sectors_cleared := 0
## The chassis that run has to be on (empty for any).
@export var with_chassis := ""
## Runs finished in total, won or lost.
@export var runs_finished := 0
## Fights won in total, across every run.
@export var fights_won_total := 0
## Runs won in total.
@export var runs_won := 0


## Returns whether the milestone is met by [param profile]'s totals and the run just finished:
## [param sectors] cleared on the chassis with id [param chassis_id]. Every set part must be met.
func is_met(profile: Profile, sectors: int, chassis_id: String) -> bool:
	if sectors_cleared > 0 and (sectors < sectors_cleared or (not with_chassis.is_empty() and chassis_id != with_chassis)):
		return false
	return profile.runs >= runs_finished and profile.fights_won >= fights_won_total and profile.wins >= runs_won
