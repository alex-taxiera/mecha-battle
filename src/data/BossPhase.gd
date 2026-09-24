class_name BossPhase
extends Resource
## A turn in a boss fight: when the boss drops to [member threshold] of its max HP (or, for a
## [member revive] phase, the first time it would go down), it changes for the rest of the fight.
## A boss's phases are on its [member EnemyLoadout.phases]; each happens once a fight.

@export var title: String
## Shown under the title, e.g. "The Core reroutes everything to its weapons.".
@export_multiline var text: String
## The share of max HP at or below which it happens. Ignored for a revive.
@export var threshold := 0.5
## Instead of a threshold, it happens the first time the boss would go down: it's back up at
## [member heal_share] of its max HP.
@export var revive := false

@export_group("Effects")
## Repairs this share of max HP (for a revive, the HP it comes back with).
@export var heal_share := 0.0
## Adds this share of max HP as shield.
@export var shield_share := 0.0
## Sets the boss's heat, or leaves it at -1.
@export var heat := -1
## Scales its weapons' cooldowns and damage from here on.
@export var cooldown_scale := 1.0
@export var damage_scale := 1.0
## Fight-long effects it gains, like relics (their fight hooks only: stats are set when a fight
## starts).
@export var relics: Array[Relic] = []
