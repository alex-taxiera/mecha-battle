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
## Hull points before any parts, in round 1. See [method get_base_hp] for later rounds.
@export var base_hp: int
## How much [member base_hp] grows each round, compounding: 0.15 is +15% a round. It keeps fights
## from getting shorter as later shops add damage.
@export var hp_growth := 0.15
## Energy generated each turn before any generators.
@export var base_energy := 3
## The weapon bays around the grid. Weapons only mount here, never on the grid.
@export var hardpoints: Array[Hardpoint] = []

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


## Returns the frame's hull points before any parts in round [param round_number]:
## [member base_hp] grown by [member hp_growth] a round, compounding, rounded down. A Bastion's
## 450 is 450, 517, 595, 684, then 787 in round 5.
func get_base_hp(round_number := 1) -> int:
	# The nudge keeps float error from rounding an exact result down: 100 × 1.15 is 114.999....
	return floori(base_hp * pow(1.0 + hp_growth, maxi(round_number, 1) - 1) + 1e-6)


## Returns the hardpoint whose bay covers [param cell], or [code]null[/code].
func get_hardpoint_at(cell: Vector2i) -> Hardpoint:
	for hardpoint in hardpoints:
		if cell in hardpoint.get_cells():
			return hardpoint
	return null


## Returns whether any hardpoint can mount [param part].
func can_mount(part: MechPart) -> bool:
	return hardpoints.any(func(hardpoint: Hardpoint) -> bool: return hardpoint.fits(part))


## Returns the smallest rectangle of cells holding the frame and every bay. Bays sit outside
## the frame, so its top-left can be negative.
func get_layout_rect() -> Rect2i:
	var rect := Rect2i(Vector2i.ZERO, size)
	for hardpoint in hardpoints:
		for cell in hardpoint.get_cells():
			rect = rect.expand(cell).expand(cell + Vector2i.ONE)
	return rect
