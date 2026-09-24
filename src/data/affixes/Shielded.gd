class_name Shielded
extends Relic
## An elite affix: the mech starts every fight with a shield of [member shield_share] of its max HP.

@export var shield_share := 0.25


func on_fight_start(mech: BattleMech) -> bool:
	var extra := roundi(mech.max_hp * shield_share)
	mech.max_shield += extra
	mech.shield += extra
	return extra > 0
