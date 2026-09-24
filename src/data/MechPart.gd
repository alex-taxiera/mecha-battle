class_name MechPart
extends Resource
## The blueprint for every item in the game. Parts are shared Resources, so nothing that
## changes during a fight is stored here: see [ActivePart].

## JUNK parts do nothing and link with nothing: they only take up room.
enum PartType { WEAPON, GENERATOR, DEFENSE, UTILITY, JUNK }
## How rarely the part turns up in loot: rarer parts come up less, except from elites and bosses.
enum Rarity { COMMON, UNCOMMON, RARE }

## The highest Mk a part can reach by merging or upgrading.
const MAX_LEVEL := 3
const NUMERALS: Array[String] = ["I", "II", "III"]

@export var id: String
@export var part_name: String
@export var type: PartType
@export var cost: int
@export var rarity := Rarity.COMMON
## Whether a shop will buy the part back. Some event parts are stuck with the mech.
@export var sellable := true
## How much each Mk above I adds to the part's damage, HP, energy made, and cooling, as a share
## of its own: 0.5 makes a Mk II 1.5 times the base and a Mk III twice it. Energy cost and heat
## stay the same, so an upgrade is a pure gain.
@export var upgrade_bonus := 0.5
## The part's Mk, 1 to [constant MAX_LEVEL]. It belongs to the run's own copy of the part, so it
## isn't content: it's kept when the copy is duplicated but never set in a [code].tres[/code].
@export_storage var level := 1
## Cells this part covers, relative to a (0, 0) origin (x right, y down).
## For example, a vertical 1x2 is [code][Vector2i(0, 0), Vector2i(0, 1)][/code].
@export var grid_shape: Array[Vector2i]
@export_multiline var description: String
## A weapon in a fight: its pixel sprite facing right, drawn on its bay (see
## [member Hardpoint.battle_anchor]).
@export var battle_sprite: Texture2D
## A weapon's shot in flight, facing right. It's tinted by the shooter's side, so it's drawn
## light.
@export var projectile_sprite: Texture2D

@export_group("Stats")
## Hull points this part adds.
@export var hp: int
## Energy this part generates each turn.
@export var energy_gen: int
## Energy this part uses each turn.
@export var energy_cost: int
## Damage this part deals each volley.
@export var damage: int
## Seconds between the part's activations in combat.
@export var cooldown_max: float
## Heat this part adds to its mech each time it fires.
@export var heat: int
## Heat this part vents from its mech each turn.
@export var cooling: int


## Returns how much the part's [member level] scales its damage, HP, energy made, and cooling.
func get_level_scale() -> float:
	return 1.0 + upgrade_bonus * (clampi(level, 1, MAX_LEVEL) - 1)


## Returns the part's name with its Mk above I, e.g. "Twin Gatling Mk II".
func get_display_name() -> String:
	return part_name if level <= 1 else "%s Mk %s" % [part_name, NUMERALS[clampi(level, 1, MAX_LEVEL) - 1]]


## Returns whether [param other] can merge with this part into one a Mk higher: another copy of
## the same part (same id and name, so a reworked part only merges with its own kind) at the same
## Mk, below the top.
func can_merge_with(other: MechPart) -> bool:
	return other != null and other != self and other.id == id and other.part_name == part_name \
		and other.level == level and level < MAX_LEVEL


## Returns [member grid_shape] turned [param turns] quarter-turns clockwise, shifted so its
## top-left is (0, 0) and sorted row by row. Negative turns go counterclockwise.
func get_shape(turns := 0) -> Array[Vector2i]:
	var shape: Array[Vector2i] = []
	for cell in grid_shape:
		var turned := cell
		for i in posmod(turns, 4):
			turned = Vector2i(-turned.y, turned.x)
		shape.append(turned)
	return normalized(shape)


## Returns whether the part can turn: a quarter-turn changes its footprint and it isn't a
## weapon. Weapons mount on a hardpoint of their exact shape, so they never turn.
func can_rotate() -> bool:
	return type != PartType.WEAPON and get_shape(1) != get_shape()


## Returns [param cells] shifted so their top-left is (0, 0) and sorted row by row, so two
## shapes compare equal when they cover the same cells.
static func normalized(cells: Array[Vector2i]) -> Array[Vector2i]:
	var shape: Array[Vector2i] = cells.duplicate()
	if shape.is_empty():
		return shape
	var top_left := shape[0]
	for cell in shape:
		top_left = top_left.min(cell)
	for i in shape.size():
		shape[i] -= top_left
	shape.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	return shape
