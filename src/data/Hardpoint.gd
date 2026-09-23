class_name Hardpoint
extends Resource
## A weapon mount on a chassis: a bay beside the grid that holds one weapon of exactly its
## shape. Bays share the grid's cell coordinates, so the parts touching a bay link with its
## weapon the same way touching parts link on the grid.

@export var id: String
## Shown to the player, e.g. "Left Arm".
@export var hardpoint_name: String
## The bay's top-left, in the frame's cell coordinates, e.g. (-1, 1) for a bay just left of
## the frame's second row. Bays sit off the frame's usable cells and don't touch each other.
@export var origin: Vector2i
## Cells the bay covers, relative to [member origin] (x right, y down). An arm is 1x3
## vertical: [code][Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2)][/code].
@export var shape: Array[Vector2i]
## Where a mounted weapon's [member MechPart.battle_sprite] goes on its chassis's
## [member MechChassis.battle_sprite]: the weapon sprite's top-left, in the chassis sprite's
## pixels. It can hang off the chassis sprite's edges.
@export var battle_anchor: Vector2i
## Whether the mounted weapon is drawn behind the chassis sprite, shaded, like a far arm.
@export var battle_behind := false


## Returns the cells the bay covers on its chassis.
func get_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for offset in MechPart.normalized(shape):
		cells.append(origin + offset)
	return cells


## Returns whether [param part] can mount here: a weapon whose unturned shape is the bay's.
func fits(part: MechPart) -> bool:
	return part != null and part.type == MechPart.PartType.WEAPON and part.get_shape() == MechPart.normalized(shape)
