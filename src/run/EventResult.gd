class_name EventResult
extends RefCounted
## What picking an event choice did: the outcome's text, a line per effect, and whether a fight
## follows.

var text := ""
var lines: PackedStringArray = []
## The tier of the fight that follows, or -1 for none.
var fight_tier := -1
## The enemy that fight is against, or null for one of the sector's of [member fight_tier].
var fight_enemy: EnemyLoadout
## A relic of this rarity joins the fight's reward; -1 for none.
var fight_relic_rarity := -1
