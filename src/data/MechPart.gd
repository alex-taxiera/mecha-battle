class_name MechPart
extends Resource
## The blueprint for every item in the game. Parts are shared Resources, so nothing that
## changes during a fight is stored here: see [ActivePart].

enum PartType { WEAPON, GENERATOR, DEFENSE, UTILITY }
## How rarely the part turns up in loot: rarer parts come up less, except from elites and bosses.
enum Rarity { COMMON, UNCOMMON, RARE }

@export var id: String
@export var part_name: String
@export var type: PartType
@export var cost: int
@export var rarity := Rarity.COMMON
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
