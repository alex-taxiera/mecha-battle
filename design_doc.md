# Mech Auto-Battler: Core Architecture & Design Doc

## 1. Core Mechanics & Grid Rules
- **The Chassis (The Board):** A 4x4 grid representing the player's mech.
- **Disabled Cells:** The top-left, top-right, bottom-left, and bottom-right corners of the 4x4 grid are permanently disabled, creating a "cross" or "plus-sign" shape. Parts cannot overlap these cells.
- **The Parts:** Items with specific grid footprints (1x1, 1x3 vertical, 2x1 horizontal, L-shapes).
- **Placement Rules:** Parts cannot overlap each other, cannot overlap disabled corner cells, and cannot extend out of the 4x4 bounds.
- **Adjacency Logic:** Parts trigger synergies based on orthogonally touching adjacent cells.

## 2. Data Architecture (The "Model")
All game data and grid math must be decoupled from the UI using Godot 4 Custom Resources and pure Reference classes. Content lives in `res://resources/` (`parts/`, `chassis/`, `rules/`).

### `MechPart.gd` (Extends Resource)
The blueprint for every item in the game.
- `@export var id: String`
- `@export var part_name: String`
- `@export var type: PartType` (Enum: WEAPON, GENERATOR, DEFENSE, UTILITY)
- `@export var cost: int`
- `@export var grid_shape: Array[Vector2i]` (Defines the shape relative to a 0,0 origin. E.g., a vertical 1x2 is `[Vector2i(0,0), Vector2i(0,1)]`)
- `@export var description: String`
- Stats: `hp`, `energy` (generated per turn), `energy_draw`, `damage` (per volley).
- `get_shape(turns) -> Array[Vector2i]` (the shape turned clockwise, anchored at its top-left) and `can_rotate() -> bool`.

### `MechChassis.gd` (Extends Resource)
A mech frame: `chassis_name`, `frame_name`, `size`, `disabled_cells`, `base_hp`, `base_energy`. The Skirmisher is the 4x4 cross from section 1.

### `MechGridData.gd` (Extends RefCounted)
The pure math controller for the grid, built on a `MechChassis`. No UI code allowed.
- **State:** A Dictionary tracking which placement (part, origin, rotation, cells) occupies which `Vector2i` coordinate.
- **Functions:**
  - `can_place_part(part: MechPart, origin_coords: Vector2i, rotation := 0) -> bool` (Must check against bounds, overlapping parts, and disabled cells).
  - `check_placement(...) -> Fit` (why a part doesn't fit: OUT_OF_BOUNDS, then DISABLED_CELL, then OCCUPIED).
  - `place_part(...)`, `remove_part(coords)`, `move_part(coords, new_origin)`, `rotate_part(coords)`.
  - `get_adjacent_parts(coords: Vector2i) -> Array[MechPart]`
  - `get_open_edges(cells)` (empty cells a part could still link through) and `get_contacts()` (each touching pair once, with a shared edge).
  - `copy()` (try a change without touching the real grid).
- **Signals:**
  - `grid_updated` (Fired whenever a part is added, moved, rotated, or removed, so the UI knows to redraw).

### `SynergyRule.gd` (Extends Resource)
An adjacency bonus between two part types: which part of the pair gets it, the stat (HP, energy, damage), add or multiply, the amount, and whether it stacks per touching partner. A touching pair links once, however many edges it shares.

### `MechStats.gd` (Extends RefCounted)
`MechStats.calculate(grid, rules)`: HP, energy generated and drawn, and damage per volley (scaled down when weapons draw more energy than is generated), plus each part's numbers and the active links.

### `RunState.gd` (Extends RefCounted)
The shop phase: gold, the round, 4 shop slots (sold state, rotation), and the mech grid. `buy`, `sell` (full refund in the round it was bought, half after), `move`, `rotate_placed`, `rotate_slot`, `reroll` (1 gold), `end_round` (unspent gold carries over, plus income), and `preview_buy` / `preview_move` for hover feedback. Emits `changed`.

## 3. UI Architecture (The "View")
The UI is strictly visual. It reads data from `MechGridData` and emits signals when the player clicks, but it does NOT calculate whether a part fits.

### `ShopScreen.tscn` (Extends Control)
The root node for the shop phase.
- Manages the player's Gold.
- Contains the Shop UI (right side) and the Mech Grid UI (left side).

### `MechGridUI.tscn` (Extends GridContainer or custom Control)
- Visually draws the 4x4 grid.
- Turns the 4 corner cells visually distinct (e.g., darkened or invisible) to indicate they are disabled.
- Listens for Godot's built-in drag-and-drop callbacks (`_can_drop_data` and `_drop_data`).
- When a drop is attempted, it asks `MechGridData.can_place_part()`. If true, it visually snaps the part and tells the data layer to save it.

## 4. Signal Flow & Dependency Direction
- **Rule:** UI nodes can call functions on Data scripts. Data scripts CANNOT call functions on UI nodes.
- **Rule:** Data scripts communicate outward by emitting signals (e.g., `grid_updated`). UI nodes connect to these signals to update visual health, energy, and grid graphics.

## 5. Automated Testing Requirements
Before any UI is built, the following tests MUST be written in GdUnit4 and pass headlessly:
1. `test_part_placement_bounds`: Verify parts fail to place if they hang off the 4x4 edge.
2. `test_disabled_corners`: Verify parts fail to place if any part of their footprint touches the 4 corners.
3. `test_part_overlap`: Verify parts fail to place if they intersect an already placed part.
4. `test_l_shape_placement`: Verify an L-shaped part can be successfully placed in the center of the cross without triggering corner bounds.
