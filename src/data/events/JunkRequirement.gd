class_name JunkRequirement
extends EventRequirement
## Needs a junk part on the mech or in the stash, e.g. a Glitch.


func check(run: RunState) -> bool:
	return not StripJunkEffect.junk_of(run).is_empty()


func describe() -> String:
	return "Needs a junk part"
