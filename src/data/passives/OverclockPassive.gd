class_name OverclockPassive
extends ChassisPassive
## The first weapon to fire in a fight fires twice, the second shot free.

const SPENT := &"overclock_spent"


func extra_shots(mech: BattleMech, _weapon: ActivePart) -> int:
	if mech.passive_state.get(SPENT, false):
		return 0
	mech.passive_state[SPENT] = true
	return 1
