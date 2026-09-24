class_name ActiveStatus
extends RefCounted
## A [MechStatus] on a mech in a fight: its charges, its secondary charges (e.g. intensity), and
## any values it keeps. A mech carries at most one of each status; adding more stacks onto it.
## Adapted from Slay-The-Robot's BaseStatusEffect (MIT, DesirePathGames).

var data: MechStatus
var mech: BattleMech
## Kept within the status's bounds; reaching the top of an overflowing status wraps it around.
var charges := 0:
	set = set_charges
var secondary := 0
## Anything else the status keeps for the fight.
var values := {}

# Seconds since the last decay.
var _decay_clock := 0.0
# Whether nothing has been added yet, so the first secondary charges are taken as they are.
var _fresh := true


func _init(p_data: MechStatus, p_mech: BattleMech) -> void:
	data = p_data
	mech = p_mech


## Sets the charges within the status's bounds. An overflowing status that reaches its top wraps
## back down by the width of its bounds, once per time over, and runs [method MechStatus.on_overflow].
func set_charges(value: int) -> void:
	var span := data.upper_bound - data.lower_bound
	var times := 0
	if data.overflows and span > 0:
		while value >= data.upper_bound:
			value -= span
			times += 1
	charges = clampi(value, data.lower_bound, data.upper_bound)
	if times > 0:
		data.on_overflow(mech, self, times)
		mech.status_overflowed.emit(self, times)


## Adds [param amount] charges, and [param p_secondary] secondary charges the way the status
## combines them.
func add(amount: int, p_secondary := 0) -> void:
	if _fresh:
		_fresh = false
		secondary = p_secondary
		charges += amount
		return
	match data.secondary_combine:
		MechStatus.Combine.ADD:
			secondary += p_secondary
		MechStatus.Combine.MIN:
			secondary = mini(secondary, p_secondary)
		MechStatus.Combine.MAX:
			secondary = maxi(secondary, p_secondary)
	charges += amount


## Runs a tick: the status's own effect, then its decay once [member MechStatus.decay_interval]
## has passed.
func tick(delta: float) -> void:
	data.on_tick(mech, self, delta)
	if data.decay_interval <= 0.0:
		return
	_decay_clock += delta
	while _decay_clock + CombatEngine.TIME_EPSILON >= data.decay_interval and charges != 0:
		_decay_clock -= data.decay_interval
		charges -= data.get_decay(self)
