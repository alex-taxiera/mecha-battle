class_name ActivePart
extends RefCounted
## One placed part's live state in a fight. The [MechPart] it wraps is a shared blueprint and
## is only read, never written, so two copies of a part on a grid keep separate cooldowns.

var part: MechPart
## What the part does in this fight: its own numbers plus the link bonuses it gets from the
## parts it touches, e.g. a cooled gatling's 12 damage instead of 8.
var damage: int
var energy_gen: int
var energy_cost: int
## Heat added each activation (each shot, for a weapon) and vented per turn: the part's own, as
## links and relics change them.
var heat: int
var cooling: int
## Shield points the part adds, and energy it drains each turn to keep working.
var shield: int
var upkeep: int
## Seconds between activations: the part's [member MechPart.cooldown_max] as links change it.
var cooldown_max: float
## Seconds until the part activates. It starts a fight at [member cooldown_max] and counts
## down.
var current_cooldown: float
## Whether the part still works. Combat switches it off, e.g. when the part is knocked out.
var is_active := true
## The bay a weapon is mounted in, or null for a part on the grid.
var hardpoint: Hardpoint
## Shots the part has fired this fight, and the damage they did after the target's plating.
var shots := 0
var damage_dealt := 0
## What the part's last shot hit for, before the target's plating: its damage as relics changed it.
var last_shot := 0
## Shots fired in a row without waiting for energy or a shutdown in between.
var streak := 0


## [param numbers] are the part's stats on its grid, links applied; without them the part
## fights with its own numbers.
func _init(p_part: MechPart, numbers: MechStats.PartStats = null) -> void:
	part = p_part
	if numbers:
		damage = numbers.damage
		energy_gen = numbers.energy
		energy_cost = numbers.energy_draw
		heat = numbers.heat
		cooling = numbers.cooling
		shield = numbers.shield
		upkeep = numbers.upkeep
		# PartStats built by hand may leave the cooldown unset.
		cooldown_max = numbers.cooldown if numbers.cooldown > 0.0 else p_part.cooldown_max
	else:
		damage = p_part.damage
		energy_gen = p_part.energy_gen
		energy_cost = p_part.energy_cost
		heat = p_part.heat
		cooling = p_part.cooling
		shield = p_part.shield
		upkeep = p_part.upkeep
		cooldown_max = p_part.cooldown_max
	current_cooldown = cooldown_max


## Returns how far the part's cooldown has run, from 0 just after it activates to 1 when it's
## ready. A part with no cooldown never activates, so it stays at 0.
func get_charge() -> float:
	if cooldown_max <= 0.0:
		return 0.0
	return clampf(1.0 - current_cooldown / cooldown_max, 0.0, 1.0)
