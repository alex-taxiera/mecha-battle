class_name PartAbility
extends Resource
## Something a part does beyond its numbers, like reflecting heavy hits or grounding the storm.
## Each of a part's [member MechPart.abilities] (and its mod's) is a subclass in [code]res://src/data/abilities/[/code]
## with its numbers exported, overriding the hooks it needs; every hook does nothing by default.
## Parts are shared, so an ability keeps no state: what changes in a fight lives on the
## [ActivePart] and the [BattleMech]. The hooks-on-a-resource shape follows [Relic].

## Whether each copy on a mech acts (true), or only one does however many are installed.
@export var stacks := true


## At the start of each fight, for the part's [param active] on [param mech].
func on_fight_start(_mech: BattleMech, _active: ActivePart) -> void:
	pass


## Seconds sooner the electrical storm starts, for both mechs, while the part is installed.
## The fight takes the largest lead either mech has.
func get_storm_lead() -> float:
	return 0.0


## Returns the heat a shot from [param active] (its own weapon) makes, given [param heat] so far.
func modify_shot_heat(_active: ActivePart, heat: int) -> int:
	return heat


## Shapes a shot from the part's own weapon before it lands, e.g. piercing plating.
func modify_hit(_hit: HitPipeline.Hit) -> void:
	pass


## After a shot from the part's own weapon lands (not when it's rejected), e.g. applying a status.
func on_hit(_hit: HitPipeline.Hit) -> void:
	pass


## When [param mech] is hit by a weapon's shot of [param damage] (before plating). Returns
## damage to deal back to the attacker, or 0.
func on_hit_taken(_mech: BattleMech, _active: ActivePart, _damage: int) -> int:
	return 0


## Returns the damage a storm strike of [param damage] does to [param mech] (before plating).
func modify_storm_strike(_mech: BattleMech, damage: int) -> int:
	return damage


## When [param weapon], a neighbor of the part's [param active] on [param mech], fires a shot.
func on_neighbor_fired(_mech: BattleMech, _active: ActivePart, _weapon: ActivePart) -> void:
	pass


## When [param mech]'s shield breaks: a hit takes its last point, or it collapses.
func on_shield_broken(_mech: BattleMech, _active: ActivePart) -> void:
	pass


## When [param mech] melts down, after its hit and before its shutdown runs.
func on_meltdown(_mech: BattleMech, _active: ActivePart) -> void:
	pass


## After any hit of [param damage] lands on [param mech] (shield and hull together, above 0).
func on_damaged(_mech: BattleMech, _active: ActivePart, _damage: int) -> void:
	pass


## Whether, while the part is installed, a shop buys every part back at its full value.
func refunds_in_full() -> bool:
	return false
