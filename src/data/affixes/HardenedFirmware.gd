class_name HardenedFirmware
extends Relic
## An elite affix: the first [member blocks] debuffs the mech would take each fight don't land.

@export var blocks := 1

var _left := 0


func on_fight_start(_mech: BattleMech) -> bool:
	_left = blocks
	return false


func blocks_status(_mech: BattleMech, status: MechStatus) -> bool:
	if _left <= 0 or status.type != MechStatus.Type.DEBUFF:
		return false
	_left -= 1
	return true
