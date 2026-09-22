# Mech Auto-Battler: Core Architecture & Design Doc

## 1. Core Mechanics & Grid Rules
- **The Chassis (The Board):** A 4x4 grid representing the player's mech.
- **Disabled Cells:** The top-left, top-right, bottom-left, and bottom-right corners of the 4x4 grid are permanently disabled, creating a "cross" or "plus-sign" shape. Parts cannot overlap these cells.
- **The Parts:** Items with specific grid footprints (1x1, 1x3 vertical, 2x1 horizontal, L-shapes).
- **Placement Rules:** Parts cannot overlap each other, cannot overlap disabled corner cells, and cannot extend out of the 4x4 bounds.
- **Adjacency Logic:** Parts trigger synergies based on orthogonally touching adjacent cells.

## 2. Data Architecture (The "Model")
All game data and grid math must be decoupled from the UI using Godot 4 Custom Resources and pure Reference classes.

### `MechPart.gd` (Extends Resource)
The blueprint for every item in the game.
- `@export var id: String`
- `@export var part_name: String`
- `@export var type: PartType` (Enum: WEAPON, GENERATOR, DEFENSE, UTILITY)
- `@export var cost: int`
- `@export var grid_shape: Array[Vector2i]` (Defines the shape relative to a 0,0 origin. E.g., a vertical 1x2 is `[Vector2i(0,0), Vector2i(0,1)]`)

### `MechGridData.gd` (Extends RefCounted)
The pure math controller for the grid. No UI code allowed.
- **State:** Maintains a 2D Array or Dictionary tracking which `MechPart` occupies which `Vector2i` coordinate.
- **Functions:**
  - `can_place_part(part: MechPart, origin_coords: Vector2i) -> bool` (Must check against bounds, overlapping parts, and the 4 disabled corner cells).
  - `place_part(...)`
  - `remove_part(...)`
  - `get_adjacent_parts(coords: Vector2i) -> Array[MechPart]`
- **Signals:**
  - `grid_updated` (Fired whenever a part is added or removed, so the UI knows to redraw).

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
