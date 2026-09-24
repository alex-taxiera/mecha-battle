class_name WeaponMod
extends Resource
## A lasting change to one weapon, like "Incendiary": its numbers scaled, heat added, abilities
## added, and a word before its name. A weapon holds one mod at a time. The mod is kept on the
## run's copy of the part and its numbers are worked out from the part's own, so taking it off
## is exact. Mods live in [code]res://resources/mods/[/code].
## Adapted from Slay-The-Robot's card decorators (MIT, DesirePathGames), whose value changes
## weren't undone when a decorator was removed.

@export var id: String
## The word before the weapon's name, e.g. "Incendiary".
@export var prefix: String
## What it does, for tooltips, e.g. "+1 Burn a hit, 10% less damage.".
@export_multiline var description: String
@export var damage_scale := 1.0
@export var cooldown_scale := 1.0
@export var energy_scale := 1.0
## Heat added to each shot.
@export var heat_add := 0
@export var abilities: Array[PartAbility] = []


## Returns whether the mod can go on [param part]: weapons only.
func fits(part: MechPart) -> bool:
	return part != null and part.type == MechPart.PartType.WEAPON
