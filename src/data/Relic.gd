class_name Relic
extends Resource
## An item found during a run that changes the rules a little, for the rest of the run. Each
## relic is a subclass that overrides the hooks it needs; every hook does nothing by default.
## Relics live in [code]res://resources/relics/[/code], each a [code].tres[/code] of its
## subclass with its numbers exported, so tuning stays in data. A run owns its own copies, so a
## relic can keep state (reset in [method on_fight_start]).
## The hooks-on-a-resource shape follows Slay-The-Robot's artifacts (MIT, DesirePathGames).

## How rarely the relic turns up. BOSS relics come only from bosses; SHOP ones only from shops,
## and EVENT ones only from events.
enum Rarity { COMMON, UNCOMMON, RARE, BOSS, SHOP, EVENT }

@export var id: String
@export var relic_name: String
@export_multiline var description: String
@export var rarity := Rarity.COMMON
## The placeholder icon: a short glyph on a badge of this color.
@export var glyph := "*"
@export var color := Color(0.8, 0.8, 0.85)


## Once, when the run gets the relic.
func on_obtain(_run: RunState) -> void:
	pass


## Changes one placed part's numbers in [MechStats.calculate], after its links: e.g. more
## cooling from every heatsink. [param part] is the part; [param numbers] what it works with.
func modify_part_stats(_part: MechPart, _numbers: MechStats.PartStats) -> void:
	pass


## Changes a mech's totals at the end of [MechStats.calculate]: e.g. more HP. Keep
## [member MechStats.energy_generated] in step with [member MechStats.base_energy] when
## changing the latter.
func modify_stats(_stats: MechStats) -> void:
	pass


## At the start of each fight. Returns true if the relic did something the player should see.
func on_fight_start(_mech: BattleMech) -> bool:
	return false


## Returns the damage a shot from [param weapon] deals, given its [param damage] so far.
func modify_shot_damage(_mech: BattleMech, _weapon: ActivePart, damage: int) -> int:
	return damage


## Returns the damage [param mech] takes from a hit of [param amount], after its plating.
func modify_damage_taken(_mech: BattleMech, amount: int) -> int:
	return amount


## After each fight the player wins.
func on_fight_won(_run: RunState) -> void:
	pass


## Returns the gold a fight drops, given [param amount] so far.
func modify_gold(amount: int) -> int:
	return amount
