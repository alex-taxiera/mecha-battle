class_name CombatColors
extends RefCounted
## The combat screen's palette, from the Claude Design mockup.

## Text over the scene, and dimmed labels.
const INK := Color("#f1f3f7")
const DIM := Color("#aab2c0")
## Panel fills and the dark outline around text and frames.
const NIGHT := Color("#11131a")
## The letterbox around the stage.
const PAGE := Color("#0b0c11")
## The light border of framed bars and panels.
const FRAME := Color("#c7ced9")
## An empty bar's track.
const TRACK := Color("#2a2f3a")
## Each side's accent: the player's on the left, the opponent's on the right.
const PLAYER := Color("#ffb547")
const OPPONENT := Color("#e0607e")
## Damage popups: hits on the opponent in the player's accent, hits on the player in pink.
const HIT_ON_OPPONENT := Color("#ffb547")
const HIT_ON_PLAYER := Color("#ff8fa3")
const HP := Color("#5fd38a")
const ENERGY := Color("#5aa9ff")
const HEAT := Color("#ff8a3d")
const DANGER := Color("#ff4d4d")
## The yellow of tags and buttons.
const TAG := Color("#f2b134")
## The electrical storm.
const STORM := Color("#8fd3ff")
## Shields: the band on the HP bar and what they soak up.
const SHIELD := Color("#7de8f0")


## Returns the accent of the player's side (left) or the opponent's.
static func accent(left: bool) -> Color:
	return PLAYER if left else OPPONENT
