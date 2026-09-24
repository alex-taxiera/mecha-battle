class_name Piercing
extends PartAbility
## A weapon whose shots go through plating, a shield, or both.

@export var pierce_plating := true
@export var pierce_shield := true


func modify_hit(hit: HitPipeline.Hit) -> void:
	hit.pierce_plating = hit.pierce_plating or pierce_plating
	hit.pierce_shield = hit.pierce_shield or pierce_shield
