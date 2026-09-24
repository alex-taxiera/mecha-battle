class_name FeedOnNeighborFire
extends PartAbility
## An ammo feeder: every [member every]th shot from a weapon it touches takes [member seconds]
## off the cooldowns of the other weapons it touches.

@export var every := 3
@export var seconds := 0.5


func on_neighbor_fired(mech: BattleMech, active: ActivePart, weapon: ActivePart) -> void:
	if weapon.part.type != MechPart.PartType.WEAPON or not active.count(self, every):
		return
	var fed := false
	for other in active.neighbors:
		if other != weapon and other.is_active and other.part.type == MechPart.PartType.WEAPON:
			other.current_cooldown = maxf(0.0, other.current_cooldown - seconds)
			fed = true
	if fed:
		mech.announce(active)
