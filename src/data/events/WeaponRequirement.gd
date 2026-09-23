class_name WeaponRequirement
extends EventRequirement
## Needs a mounted weapon.


func check(run: RunState) -> bool:
	return WeaponModEffect.strongest_weapon(run) != null


func describe() -> String:
	return "Needs a mounted weapon"
