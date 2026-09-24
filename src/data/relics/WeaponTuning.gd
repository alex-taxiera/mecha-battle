class_name WeaponTuning
extends Relic
## Changes every weapon's numbers: damage times [member damage_scale], cooldown times
## [member cooldown_scale] (below 1 fires faster), and [member heat_add] more heat a shot. A shop
## with it stocks [member shop_slots] more (or fewer) parts.

@export var damage_scale := 1.0
@export var cooldown_scale := 1.0
@export var heat_add := 0
@export var shop_slots := 0


func modify_part_stats(part: MechPart, numbers: MechStats.PartStats) -> void:
	if part.type != MechPart.PartType.WEAPON:
		return
	numbers.damage = roundi(numbers.damage * damage_scale)
	if numbers.cooldown > 0.0:
		numbers.cooldown *= cooldown_scale
	numbers.heat += heat_add


func on_shop_opened(_run: RunState, shop: ShopStock) -> void:
	if shop_slots != 0:
		shop.resize(shop.size + shop_slots)
