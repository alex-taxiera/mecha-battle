class_name Regenerating
extends Relic
## An elite affix: the mech repairs [member heal_share] of its max HP a second while it stands.

@export var heal_share := 0.01

var _carry := 0.0


func on_fight_start(_mech: BattleMech) -> bool:
	_carry = 0.0
	return false


func on_tick(mech: BattleMech, delta: float) -> void:
	if mech.current_health <= 0:
		return
	_carry += mech.max_hp * heal_share * delta
	var whole := floori(_carry + CombatEngine.TIME_EPSILON)
	_carry -= whole
	mech.current_health = mini(mech.max_hp, mech.current_health + whole)
