class_name MechChassis
extends Resource
## A mech frame: the grid parts are placed on, the stats it gives before any parts, and its
## passive ability in a fight.

@export var id: String
@export var chassis_name: String
## The frame's shape in a few words, e.g. "Wide frame".
@export var frame_name: String
## How the frame wants to be played, e.g. "Tank / Attrition".
@export var playstyle: String
@export var size := Vector2i(4, 4)
## Cells inside [member size] that can never hold a part.
@export var disabled_cells: Array[Vector2i] = []
## Cells inside [member size] that are locked until a run opens them (see [member opened_cells]):
## the frame grows into them.
@export var expansion_cells: Array[Vector2i] = []
## The expansion cells a run has opened. It belongs to the run's own copy of the chassis, so it's
## kept when the copy is duplicated but never set in a [code].tres[/code].
@export_storage var opened_cells: Array[Vector2i] = []
## Hull points before any parts.
@export var base_hp: int
## Energy generated each turn before any generators.
@export var base_energy := 3
## The weapon bays around the grid. Weapons only mount here, never on the grid.
@export var hardpoints: Array[Hardpoint] = []
## The frame in a fight: a 128x128 pixel sprite facing right, with its bays empty. Each mounted
## weapon's own sprite goes at its bay's [member Hardpoint.battle_anchor].
@export var battle_sprite: Texture2D
## The parts a run on this frame starts with, already installed.
@export var starter_lineup: Array[LoadoutPart] = []
## Other starter kits the frame's mastery unlocks (see [StartingLoadout]).
@export var alt_loadouts: Array[StartingLoadout] = []

@export_group("Passive")
## What the frame does in a fight on its own, with its numbers (see [ChassisPassive]); null for
## none.
@export var passive: ChassisPassive
@export var passive_name: String
@export_multiline var passive_text: String


## Returns whether [param cell] lies inside the frame's bounds, disabled or not.
func contains(cell: Vector2i) -> bool:
	return Rect2i(Vector2i.ZERO, size).has_point(cell)


## Returns whether a part can occupy [param cell]: inside the frame, not disabled, and not locked.
func is_usable(cell: Vector2i) -> bool:
	return contains(cell) and cell not in disabled_cells and not is_locked(cell)


## Returns whether [param cell] is an expansion cell the run hasn't opened yet.
func is_locked(cell: Vector2i) -> bool:
	return cell in expansion_cells and cell not in opened_cells


## Returns the expansion cells still locked.
func get_locked_cells() -> Array[Vector2i]:
	return expansion_cells.filter(func(cell: Vector2i) -> bool: return is_locked(cell))


## Returns the locked cells that can open now: those touching a usable cell, so the frame grows
## outward from itself.
func get_frontier() -> Array[Vector2i]:
	return get_locked_cells().filter(func(cell: Vector2i) -> bool:
		for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			if is_usable(cell + step):
				return true
		return false)


## Opens [param cell] if it's on the frontier. Returns whether it did.
func open_cell(cell: Vector2i) -> bool:
	if cell not in get_frontier():
		return false
	opened_cells.append(cell)
	return true


## Returns how many cells can hold parts.
func get_usable_cell_count() -> int:
	var count := 0
	for y in size.y:
		for x in size.x:
			if is_usable(Vector2i(x, y)):
				count += 1
	return count


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
