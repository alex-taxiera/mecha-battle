class_name Execute
extends PartAbility
## A guillotine cannon: its weapon's shots deal [member multiplier] times the damage to a target
## at or below [member threshold] of its max HP.

@export var threshold := 0.3
@export var multiplier := 2.0


func modify_hit(hit: HitPipeline.Hit) -> void:
	var target := hit.target
	if target and target.current_health <= target.max_hp * threshold:
		hit.damage = roundi(hit.damage * multiplier)
		if hit.attacker:
			hit.attacker.announce(hit.weapon)
