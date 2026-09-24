class_name ContainmentField
extends Relic
## The Reactor's: each meltdown's shutdown lasts [member shutdown_cut] seconds less.

@export var shutdown_cut := 1.5

var _last_left := 0.0


func on_fight_start(_mech: BattleMech) -> bool:
	_last_left = 0.0
	return false


func on_tick(mech: BattleMech, _delta: float) -> void:
	# A shutdown that just began (longer than last tick's) is cut short once.
	if mech.shutdown_left > _last_left + CombatEngine.TIME_EPSILON:
		mech.shutdown_left = maxf(0.0, mech.shutdown_left - shutdown_cut)
		mech.relic_triggered.emit(self)
	_last_left = mech.shutdown_left
