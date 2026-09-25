class_name Unlock
extends Resource
## Something a profile earns by reaching a milestone: a chassis; a part, relic, weapon mod, or
## field kit for loot and shops; an event for the event pool; or an NPC. Content without an unlock is always available; content with one is locked
## until its milestone is met. The unlocks live in [code]res://resources/unlocks/[/code].

## New kinds go at the end: unlocks save them as numbers.
enum Kind { CHASSIS, PART, RELIC, NPC, EVENT, MOD, KIT }

@export var id: String
@export var kind := Kind.CHASSIS
## The id of what it unlocks: a chassis, part, relic, event, mod, or kit id, or an NPC's (e.g.
## "technician").
@export var target_id: String
## What the player sees once it's earned, e.g. "The Striker".
@export var title: String
## How to earn it, shown while it's locked, e.g. "Clear Sector 1".
@export var hint: String

@export_group("Milestone")
## Sectors to clear in one run (0 for none).
@export var sectors_cleared := 0
## The chassis that run has to be on (empty for any); also the frame [member mastery_level] and
## [member threat_reached] count on.
@export var with_chassis := ""
## Runs finished in total, won or lost.
@export var runs_finished := 0
## Fights won in total, across every run.
@export var fights_won_total := 0
## Runs won in total.
@export var runs_won := 0
## Bosses beaten in total, across every run.
@export var bosses_beaten_total := 0
## The highest Threat unlocked, on [member with_chassis] or on any frame (0 for none).
@export var threat_reached := 0
## The mastery level reached on [member with_chassis] (0 for none; see [method Profile.get_mastery_level]).
@export var mastery_level := 0


## Returns whether the milestone is met by [param profile]'s totals and the run just finished:
## [param sectors] cleared on the chassis with id [param chassis_id]. Every set part must be met.
func is_met(profile: Profile, sectors: int, chassis_id: String) -> bool:
	if sectors_cleared > 0 and (sectors < sectors_cleared or (not with_chassis.is_empty() and chassis_id != with_chassis)):
		return false
	if mastery_level > 0 and profile.get_mastery_level(with_chassis) < mastery_level:
		return false
	if threat_reached > 0 and _best_threat(profile) < threat_reached:
		return false
	return profile.runs >= runs_finished and profile.fights_won >= fights_won_total and profile.wins >= runs_won \
		and profile.bosses_beaten >= bosses_beaten_total


# The highest Threat unlocked on [member with_chassis], or on any frame without one.
func _best_threat(profile: Profile) -> int:
	if not with_chassis.is_empty():
		return profile.get_threat_unlocked(with_chassis)
	var best := 0
	for chassis_id: String in profile.chassis_records:
		best = maxi(best, profile.get_threat_unlocked(chassis_id))
	return best
