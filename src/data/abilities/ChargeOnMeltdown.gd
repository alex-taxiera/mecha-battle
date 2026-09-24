class_name ChargeOnMeltdown
extends PartAbility
## A meltdown capacitor: when the mech melts down, the weapons it touches charge fully, so they
## fire the moment the shutdown ends.


func on_meltdown(mech: BattleMech, active: ActivePart) -> void:
	var charged := false
	for other in active.neighbors:
		if other.is_active and other.part.type == MechPart.PartType.WEAPON:
			other.current_cooldown = 0.0
			charged = true
	if charged:
		mech.announce(active)
