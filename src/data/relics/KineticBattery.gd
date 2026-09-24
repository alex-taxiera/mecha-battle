class_name KineticBattery
extends Relic
## Energy left over when a fight ends carries into the next fight, up to [member max_energy].

@export var max_energy := 100

var _stored := 0


func on_fight_start(mech: BattleMech) -> bool:
	if _stored <= 0:
		return false
	mech.current_energy += _stored
	_stored = 0
	return true


func on_fight_end(mech: BattleMech, _won: bool) -> void:
	_stored = clampi(mech.current_energy, 0, max_energy)
