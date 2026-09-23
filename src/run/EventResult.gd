class_name EventResult
extends RefCounted
## What picking an event choice did: the outcome's text, a line per effect, and whether a fight
## follows.

var text := ""
var lines: PackedStringArray = []
## The tier of the fight that follows, or -1 for none.
var fight_tier := -1
