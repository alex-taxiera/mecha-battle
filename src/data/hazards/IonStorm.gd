class_name IonStorm
extends Relic
## A hazard: the fight starts with the mech's shield drained. Shields don't refill in a fight, so
## shield parts do nothing here.


func on_fight_start(mech: BattleMech) -> bool:
	if mech.shield <= 0:
		return false
	mech.shield = 0
	return true
