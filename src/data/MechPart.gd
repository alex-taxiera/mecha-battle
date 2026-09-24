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
## How much each Mk above I adds to the part's damage, HP, shield, energy made, and cooling, as a
## share of its own: 0.5 makes a Mk II 1.5 times the base and a Mk III twice it. Energy cost and heat
## stay the same, so an upgrade is a pure gain.
@export var upgrade_bonus := 0.5
## The part's Mk, 1 to [constant MAX_LEVEL]. It belongs to the run's own copy of the part, so it
## isn't content: it's kept when the copy is duplicated but never set in a [code].tres[/code].
@export_storage var level := 1
## The run copy's weapon mod, if any: one per weapon. Like [member level], it belongs to the copy.
@export_storage var mod: WeaponMod
## Damage the run copy has earned, e.g. a Trophy Rack's from fights won. It adds to
## [member damage] before the Mk and the mod scale it, and belongs to the copy like [member level].
@export_storage var bonus_damage := 0
## Cells this part covers, relative to a (0, 0) origin (x right, y down).
## For example, a vertical 1x2 is [code][Vector2i(0, 0), Vector2i(0, 1)][/code].
@export var grid_shape: Array[Vector2i]
@export_multiline var description: String
## Kinds a rule can ask for beyond the part's type, e.g. "heatsink" (see
## [member SynergyRule.first_tag]).
@export var tags: Array[String] = []
## What the part does beyond its numbers (e.g. reflecting heavy hits); a mod can add more.
@export var abilities: Array[PartAbility] = []
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
## Heat this part adds to its mech each time it acts: each shot for a weapon, each activation
## for anything else (e.g. a generator that runs hot).
@export var heat: int
## Heat this part vents from its mech each turn.
@export var cooling: int
## Shield points this part adds: a pool that takes hits before the hull and is full again
## every fight.
@export var shield: int
## Energy this part drains each turn to keep working.
@export var upkeep: int


## Returns whether the part carries [param tag].
func has_tag(tag: String) -> bool:
	return tag in tags


## Returns how much the part's [member level] scales its damage, HP, shield, energy made, and
## cooling.
func get_level_scale() -> float:
	return 1.0 + upgrade_bonus * (clampi(level, 1, MAX_LEVEL) - 1)


## Returns the part's abilities, then its mod's.
func get_abilities() -> Array[PartAbility]:
	var all: Array[PartAbility] = abilities.duplicate()
	if mod:
		all.append_array(mod.abilities)
	return all


## Returns the part's name with its mod and its Mk above I, e.g. "Incendiary Twin Gatling Mk II".
func get_display_name() -> String:
	var named := "%s %s" % [mod.prefix, part_name] if mod else part_name
	return named if level <= 1 else "%s Mk %s" % [named, NUMERALS[clampi(level, 1, MAX_LEVEL) - 1]]


## Returns whether [param other] can merge with this part into one a Mk higher: another copy of
## the same part (same id and name, and the same mod or none, so a modded part only merges with
## its own kind) at the same Mk, below the top.
func can_merge_with(other: MechPart) -> bool:
	return other != null and other != self and other.id == id and other.part_name == part_name \
		and _mod_id(other) == _mod_id(self) and other.level == level and level < MAX_LEVEL


static func _mod_id(part: MechPart) -> String:
	return part.mod.id if part.mod else ""


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
