class_name RunStartOption
extends Resource
## One piece of what the Mech Technician can offer at the start of a run: a whole boon
## (COMPLETE), or half of one, an UPSIDE the Technician pairs with a DOWNSIDE. Its effects are
## the events' effects. The options live in [code]res://resources/technician/[/code].
## Adapted from Slay-The-Robot (MIT, DesirePathGames): data/readonly/RunStartOptionData.gd. See
## THIRD_PARTY_NOTICES.md.

enum Kind { UPSIDE, DOWNSIDE, COMPLETE }

@export var id: String
## What the option says: a whole sentence for a COMPLETE one ("Gain a random common relic"), a
## clause for halves ("gain a random rare part", "lose 40 max HP").
@export var text: String
@export var kind := Kind.COMPLETE
@export var effects: Array[EventEffect] = []
