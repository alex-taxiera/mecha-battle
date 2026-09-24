class_name MechStatus
extends Resource
## A status a mech can carry for part of a fight, like Burn or Jammed: charges that do something
## over time, change hits while they last, and wear off. The live copy on a mech is an
## [ActiveStatus]; this is its data. Each status is a subclass overriding the hooks it needs,
## with its numbers exported; the base class only decays.
## Adapted from Slay-The-Robot's StatusEffectData and BaseStatusEffect (MIT, DesirePathGames),
## with turn phases re-timed to seconds.

enum Type { BUFF, DEBUFF, NEUTRAL }
## How charges wear off each [member decay_interval]: LINEAR loses [member decay_amount];
## ZERO_OUT loses them all; HALF_UP and HALF_DOWN halve them, rounding the rest up or down.
enum Decay { LINEAR, ZERO_OUT, HALF_UP, HALF_DOWN }
## What adding secondary charges to ones already there does.
enum Combine { ADD, KEEP, MIN, MAX }

@export var id: String
@export var status_name: String
## What it does, for the tooltip.
@export_multiline var description: String
@export var type := Type.DEBUFF
## The placeholder icon: a short glyph on a badge of this color.
@export var glyph := "*"
@export var color := Color(0.8, 0.8, 0.85)

@export_group("Charges")
@export var lower_bound := 0
@export var upper_bound := 999
## Whether reaching [member upper_bound] wraps the charges back around (by the width of the
## bounds) and fires [method on_overflow] once per wrap, instead of stopping there.
@export var overflows := false
## Popped over the mech when it wraps, e.g. "SHIELD STRIPPED"; empty for none.
@export var overflow_text := ""
@export var secondary_combine := Combine.ADD

@export_group("Decay")
@export var decay := Decay.LINEAR
@export var decay_amount := 1
## Seconds between decays; 0 for a status that doesn't wear off on its own.
@export var decay_interval := 1.0

@export_group("Hits")
## Where the status sits in its mech's [HitPipeline], if it changes hits (see [method intercept]).
@export var side := HitInterceptor.Side.TARGET
@export var priority := 0
## The kinds of hit it sees; empty for every kind.
@export var kinds: Array[HitPipeline.Kind] = []


## Whether the status changes hits, so its mech adds it to the pipeline. Override with
## [method intercept].
func intercepts_hits() -> bool:
	return false


## Changes [param hit] while [param status] has charges, like a [HitInterceptor].
func intercept(_hit: HitPipeline.Hit, _status: ActiveStatus) -> HitInterceptor.Result:
	return HitInterceptor.Result.CONTINUE


## Returns the speed [param mech]'s weapons count down at, given [param speed] so far: e.g. Jammed
## slowing them. Thermal throttling is separate (see [method BattleMech.get_fire_rate]).
func modify_weapon_speed(_mech: BattleMech, _status: ActiveStatus, speed: float) -> float:
	return speed


## Every tick of the fight, before it decays: e.g. heat for each charge of Burn.
func on_tick(_mech: BattleMech, _status: ActiveStatus, _delta: float) -> void:
	pass


## When the charges wrap past [member upper_bound], [param times] times at once.
func on_overflow(_mech: BattleMech, _status: ActiveStatus, _times: int) -> void:
	pass


## Returns how many charges [param status] loses at its next decay.
func get_decay(status: ActiveStatus) -> int:
	match decay:
		Decay.ZERO_OUT:
			return status.charges
		Decay.HALF_UP:
			return floori(status.charges / 2.0)
		Decay.HALF_DOWN:
			return ceili(status.charges / 2.0)
	return decay_amount
