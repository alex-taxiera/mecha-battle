class_name MechChassis
extends Resource
## A mech frame: the grid parts are placed on, the stats it gives before any parts, and its
## passive ability in a fight.

## What a frame does in a fight on its own. Each passive's numbers are below it.
enum Passive {
	NONE,
	## Every hit the mech takes, from any source, is [member plating] smaller.
	THICK_PLATING,
	## The first weapon to fire in a fight fires twice.
	OVERCLOCK,
	## At full heat the mech deals [member meltdown_damage] to its enemy, then shuts down for
	## [member meltdown_shutdown] seconds.
	MELTDOWN,
}

@export var id: String
@export var chassis_name: String
## The frame's shape in a few words, e.g. "Wide frame".
@export var frame_name: String
## How the frame wants to be played, e.g. "Tank / Attrition".
@export var playstyle: String
@export var size := Vector2i(4, 4)
## Cells inside [member size] that can never hold a part.
@export var disabled_cells: Array[Vector2i] = []
@export var base_hp: int
## Energy generated each turn before any generators.
@export var base_energy := 3

@export_group("Passive")
@export var passive := Passive.NONE
@export var passive_name: String
@export_multiline var passive_text: String
## THICK_PLATING: damage taken off every hit, never below 0.
@export var plating := 1
## MELTDOWN: damage dealt to the enemy when the mech melts down.
@export var meltdown_damage := 25
## MELTDOWN: seconds the mech's parts and chassis stop after a meltdown.
@export var meltdown_shutdown := 3.0


## Returns whether [param cell] lies inside the frame's bounds, disabled or not.
func contains(cell: Vector2i) -> bool:
	return Rect2i(Vector2i.ZERO, size).has_point(cell)


## Returns whether a part can occupy [param cell]: inside the frame and not disabled.
func is_usable(cell: Vector2i) -> bool:
	return contains(cell) and cell not in disabled_cells


## Returns how many cells can hold parts.
func get_usable_cell_count() -> int:
	var count := 0
	for y in size.y:
		for x in size.x:
			if is_usable(Vector2i(x, y)):
				count += 1
	return count
