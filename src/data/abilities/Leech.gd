class_name Leech
extends PartAbility
## A leech drill: each of its weapon's hits repairs its mech by [member share] of the damage the
## hit did, shield and hull together.

@export var share := 0.25


func on_hit(hit: HitPipeline.Hit) -> void:
	if hit.attacker and hit.attacker.heal(roundi(hit.taken * share)) > 0:
		hit.attacker.announce(hit.weapon)
