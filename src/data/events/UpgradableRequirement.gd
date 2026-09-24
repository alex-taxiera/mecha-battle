class_name UpgradableRequirement
extends EventRequirement
## Needs a part that can still go up a Mk.


func check(run: RunState) -> bool:
	return not run.get_upgradable_parts().is_empty()


func describe() -> String:
	return "Needs a part to upgrade"
