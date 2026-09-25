class_name RunModifier
extends Resource
## A change to a whole run's rules: a Threat level (the ascension ladder, stacking 1 up to the
## chosen one) or a custom mode picked at frame select, like Glass Cannon. Its numbers stack with
## the run's other modifiers: scales multiply, the rest add. Threat levels live in
## [code]res://resources/threat/[/code], custom modes in [code]res://resources/run_modifiers/[/code].
## Adapted from Slay-The-Robot's RunModifierData and BaseRunModifier (MIT, DesirePathGames): one
## kind of data for difficulty levels and custom modes, with exclusive pairs.

@export var id: String
@export var modifier_name: String
@export_multiline var description: String
## For a Threat level, its number (1 and up); 0 for a custom mode.
@export var threat_level := 0
## Offered as a checkbox at frame select.
@export var is_custom := false
## Added to every run.
@export var is_automatic := false
## Ids of custom modes that can't be on with this one: turning it on turns them off.
@export var exclusive_with: Array[String] = []

@export_group("Enemies")
## Enemies' HP (and shields).
@export var enemy_hp_scale := 1.0
## More affixes on every elite.
@export var elite_affixes_add := 0
## The chance a normal battle rolls an affix too.
@export var normal_affix_chance := 0.0
## Added to every boss phase's threshold: bosses turn sooner.
@export var phase_threshold_add := 0.0

@export_group("Economy")
## Shop prices, for parts and relics.
@export var shop_price_scale := 1.0
## Gold from normal battles.
@export var battle_gold_scale := 1.0
## Added to a Hangar's repair share (e.g. -0.1 repairs 20% instead of 30%).
@export var repair_share_add := 0.0

@export_group("Start")
## The run starts with this share of max HP as hull damage.
@export var start_hull_damage_share := 0.0
## Parts the run starts with in its stash.
@export var start_parts: Array[MechPart] = []

@export_group("Player")
## The player's weapon damage and max HP.
@export var player_damage_scale := 1.0
@export var player_hp_scale := 1.0
## After the last sector, the sectors start over, their enemies tougher each loop.
@export var endless := false
## Every frame's relics can turn up, not just this frame's own (see [member Relic.chassis_id]).
@export var prismatic := false
## No Hangars: every Hangar on the map is a battle instead.
@export var no_hangars := false


## Once, when a run with this modifier starts, after its starter kit is installed. Override for
## anything the numbers can't say.
func on_run_start(_run: RunState) -> void:
	pass


## Returns the Threat levels from 1 to [param threat] of [param levels], lowest first. Only
## levels at or below the chosen one count, as Slay-The-Robot meant (its enemy overrides applied
## at every level).
static func threat_stack(levels: Array[RunModifier], threat: int) -> Array[RunModifier]:
	var stack: Array[RunModifier] = levels.filter(func(level: RunModifier) -> bool:
		return level.threat_level >= 1 and level.threat_level <= threat)
	stack.sort_custom(func(a: RunModifier, b: RunModifier) -> bool: return a.threat_level < b.threat_level)
	return stack


## Returns [param selected] with [param modifier] turned on or off. Turning one on turns off any
## it's exclusive with, either way round.
static func toggle(selected: Array[RunModifier], modifier: RunModifier, on: bool) -> Array[RunModifier]:
	var result: Array[RunModifier] = selected.filter(func(other: RunModifier) -> bool:
		return other != modifier and not (on and (other.id in modifier.exclusive_with or modifier.id in other.exclusive_with)))
	if on:
		result.append(modifier)
	return result
