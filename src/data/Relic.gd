class_name Relic
extends Resource
## An item found during a run that changes the rules a little, for the rest of the run. Each
## relic is a subclass that overrides the hooks it needs; every hook does nothing by default.
## Relics live in [code]res://resources/relics/[/code], each a [code].tres[/code] of its
## subclass with its numbers exported, so tuning stays in data. A run owns its own copies, so a
## relic can keep state (reset in [method on_fight_start]).
## The hooks-on-a-resource shape follows Slay-The-Robot's artifacts (MIT, DesirePathGames).

## How rarely the relic turns up. BOSS relics come only from bosses; SHOP ones only from shops,
## and EVENT ones only from events. AFFIX ones are never found: they're enemy modifiers, like an
## elite's Shielded.
enum Rarity { COMMON, UNCOMMON, RARE, BOSS, SHOP, EVENT, AFFIX }

@export var id: String
@export var relic_name: String
@export_multiline var description: String
@export var rarity := Rarity.COMMON
## The placeholder icon: a short glyph on a badge of this color.
@export var glyph := "*"
@export var color := Color(0.8, 0.8, 0.85)
## Jobs the relic adds to every Hangar (see [HangarJob]).
@export var hangar_jobs: Array[HangarJob] = []


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


## Every tick of a fight, e.g. repairing a little.
func on_tick(_mech: BattleMech, _delta: float) -> void:
	pass


## After [param hit] lands on [param mech] (not a rejected one), e.g. reflecting a heavy shot.
func on_hit_taken(_mech: BattleMech, _hit: HitPipeline.Hit) -> void:
	pass


## After a shot from [param mech] lands, e.g. leaving a status on the target.
func on_hit_dealt(_mech: BattleMech, _hit: HitPipeline.Hit) -> void:
	pass
