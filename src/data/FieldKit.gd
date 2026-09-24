class_name FieldKit
extends Resource
## A one-use item: the run carries a few (see [constant RunState.KIT_SLOTS]) and a fight spends
## them. A MANUAL kit is a button in the fight, paying its [member energy_cost] from the mech; an
## AUTO kit fires itself when its condition is met (see [method is_due]); a FIGHT_START kit acts as
## the fight begins. A used kit is gone from the run once the fight ends. Each kind is a subclass
## in [code]res://src/data/kits/[/code] overriding [method apply]; kits keep no state. Adapted from
## Slay-The-Robot's consumables (MIT, DesirePathGames): slots, auto-used items, and a use cost,
## with the cost paid by the fight rather than the UI, so an auto-used kit can't skip it.

enum Trigger { MANUAL, AUTO, FIGHT_START }

@export var id: String
@export var kit_name: String
@export_multiline var description: String
@export var trigger := Trigger.MANUAL
## The placeholder icon: a short glyph on a badge of this color.
@export var glyph := "+"
@export var color := Color(0.8, 0.8, 0.85)
## Gold at a Scrap Shop, before Threat.
@export var price := 10
## MANUAL: energy the mech pays to use it.
@export var energy_cost := 0

@export_group("Auto")
## AUTO: fires once the mech is at or below this share of its max HP (0 for never).
@export var hp_below := 0.0
## AUTO: fires once the mech's heat is at least this (0 for never).
@export var heat_above := 0
## AUTO: fires when the mech would go down, before the fight ends (a revive).
@export var on_defeat := false


## Returns whether an AUTO kit's condition is met on [param mech] now.
func is_due(mech: BattleMech) -> bool:
	if on_defeat:
		return mech.current_health <= 0
	if mech.current_health <= 0:
		return false
	if hp_below > 0.0 and mech.current_health <= mech.max_hp * hp_below:
		return true
	return heat_above > 0 and mech.heat >= heat_above


## Does the kit's work for [param mech], whose opponent is [param enemy].
func apply(_mech: BattleMech, _enemy: BattleMech) -> void:
	pass


## Returns when the kit acts, for tooltips, e.g. "Auto: at 25% HP".
func describe_trigger() -> String:
	match trigger:
		Trigger.FIGHT_START:
			return "At the start of the next fight"
		Trigger.AUTO:
			if on_defeat:
				return "Auto: when the mech would go down"
			if hp_below > 0.0:
				return "Auto: at %d%% HP" % roundi(hp_below * 100)
			return "Auto: at %d heat" % heat_above
	return "Use in a fight" + (" · %d EN" % energy_cost if energy_cost > 0 else "")
