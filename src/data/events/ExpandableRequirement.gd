class_name ExpandableRequirement
extends EventRequirement
## Needs room on the frame to grow: a locked cell not already owed to the player.


func check(run: RunState) -> bool:
	return run.get_expandable_cells() > 0


func describe() -> String:
	return "The frame is fully open"
