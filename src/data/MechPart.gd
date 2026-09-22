class_name MechPart
extends Resource
## The blueprint for every item in the game.

enum PartType { WEAPON, GENERATOR, DEFENSE, UTILITY }

@export var id: String
@export var part_name: String
@export var type: PartType
@export var cost: int
## Cells this part covers, relative to a (0, 0) origin (x right, y down).
## For example, a vertical 1x2 is [code][Vector2i(0, 0), Vector2i(0, 1)][/code].
@export var grid_shape: Array[Vector2i]
