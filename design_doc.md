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
- Stats: `hp`, `energy_gen` (generated per turn), `energy_cost` (used per turn), `damage` (per volley), `cooldown_max` (seconds between activations in combat).
- Parts are shared Resources: nothing that changes during a fight is stored on them (see `ActivePart`).
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
One run: gold, the round, 4 shop slots (sold state, rotation), the mech grid, and the fight record (`wins`, `losses`, `draws`). `buy`, `sell` (full refund in the round it was bought, half after), `move`, `rotate_placed`, `rotate_slot`, `reroll` (1 gold), `record_fight(FightResult)` (WIN, LOSS, or DRAW), `end_round` (unspent gold carries over, plus income), and `preview_buy` / `preview_move` for hover feedback. Emits `changed`. Nothing ends the run when the record reaches a limit yet.

### Combat (`res://src/combat/`)
Live fight state, built from a finished grid. It reads the grid, chassis, and parts but never writes to them.
- **`ActivePart.gd` (Extends RefCounted):** one placed part in a fight: the `MechPart` it wraps; the `damage`, `energy_gen`, and `energy_cost` it fights with (its own numbers plus the link bonuses it has on its grid, e.g. a cooled gatling's 12 damage); `current_cooldown` (starts at the part's `cooldown_max` and counts down); and `is_active`. The same part placed twice gets two ActiveParts with separate state.
- **`BattleMech.gd` (Extends RefCounted):** `BattleMech.new(grid, rules := [])`. Pass the run's rules so link bonuses count, exactly as in the shop's stats panel: `max_hp` is the chassis's base HP plus every part's HP and HP bonuses (the shop's Hull HP), and each ActivePart gets its linked damage and energy. Holds `current_health` (starts full), `current_energy` (starts at 0), `base_energy` (the chassis's, added each turn), and one `ActivePart` per placed part. `take_damage(amount)` lowers `current_health`, stopping at 0.
- **`CombatEngine.gd` (Extends RefCounted):** `CombatEngine.new(left, right)` runs a fight between two BattleMechs. `state` goes `PRE_GAME` → `RUNNING` (on `start()`) → `FINISHED`, and `process_tick(delta)` does nothing unless the fight is `RUNNING`. `elapsed` counts the seconds fought. A turn is `TURN_SECONDS` (1 second): the shop counts energy per turn, and in a fight each chassis adds its `base_energy` at the end of every turn, so the shop's energy numbers are what a fight does. Each running tick has three phases:
  1. **Energy and cooldowns**: chassis energy if a turn just ended, then each working part, left mech then right: its cooldown drops by `delta`, clamped at 0. A time within `TIME_EPSILON` (1e-6) of its mark counts as reached, so float error doesn't delay anything by a tick. When a generator's cooldown runs out, its ActivePart's `energy_gen` goes to its mech's `current_energy` and the cooldown resets to `cooldown_max`.
  2. **Weapons**, left mech then right: a weapon whose cooldown has run out fires at the other mech if its own mech has at least `energy_cost` energy. The mech pays the cost, the cooldown resets, the target calls `take_damage(damage)` with the ActivePart's linked damage, and the engine emits `weapon_fired(attacker, target, damage)`. A weapon that can't pay stays ready and fires on the first tick its mech can. Weapons can spend energy generated earlier in the same tick.
  3. **The electrical storm**, the sudden death that ends stalemates: from `storm_start` seconds (default 20) it strikes both mechs for the same damage on its first tick and every `storm_interval` ticks (2) after. Strike `n` (from 0) deals `round(storm_damage × storm_growth^n)`: by default 1 × 1.25^n, so 1, 1, 2, 2, 2, 3, 4, 5, 6, 7, 9, 12... Each strike emits `storm_struck(damage)`.

  Switched-off parts (`is_active` false) don't tick or fire, and parts with no `cooldown_max` never activate.

  A tick's damage lands together, so a mech that goes down still fires back that tick. After all three phases, if either mech's health is at 0, the fight is `FINISHED` and the engine emits `battle_ended(winner)` once: the mech still standing, or `null` if both went down in the same tick (a draw). Which side a mech is on never decides the winner.

## 3. UI Architecture (The "View")
The UI is strictly visual. It asks `RunState` what an action would do (`preview_buy` / `preview_move`) and calls it to act, but it does NOT calculate fits, costs, or stats itself. Every screen redraws from `RunState.changed`.

### `ShopScreen.tscn` (Extends Control)
The root node for the shop phase. Builds the `RunState` from its chassis, catalog, and rules (loaded from `res://resources/` when not set).
- Header: round, the record ("Record: 1 W · 0 L", plus draws once there are any), gold, **Next round**. Next round emits `fight_requested`; the round only ends when `finish_round(result)` records the fight, adds income, restocks, and toasts the result ("Won round 1 · +10g income, shop restocked").
- Chassis column: name, "used / total slots used", and the `MechGridUI`.
- Parts shop: 4 `ShopItem` slots (a bought slot shows "Sold · Reroll to restock"), **Reroll**. Each slot has a rotate button when turning changes the shape. Unaffordable parts can still be dragged; the grid explains why they can't drop.
- Sell zone: while an installed part is dragged, the shop panel becomes a drop target showing its sell value.
- `StatsPanel`: hull HP, energy per turn, and damage per volley, each with a delta while a drop is previewed; active links; the adjacency rules legend.
- Toasts for results that happen off the grid (sold, rerolled, new round, not enough gold).

### `MechGridUI.tscn` (Extends Control)
- Draws the chassis from its size and disabled cells, and each placed part as a colored block with a rotate button in its top-right corner. Parts carry no text: hovering one pops up its `PartInfo` (name, type and size, numbers with links applied, link bonuses, blurb) as the grid's tooltip.
- Drag and drop through Godot's `_get_drag_data`, `_can_drop_data`, and `_drop_data`. The payload (`PartDragData`) says where the part came from (a shop slot or a placed cell), its rotation, and which cell was grabbed.
- While a drag hovers: the footprint in green or red, the reason it can't drop, open edges around it, and link markers for the links it would make. Hovering a placed part shows its open edges; a part that was just placed or moved shows them briefly.
- Dragging a placed part moves it on the grid, or sells it when dropped on the shop.

### `CombatScreen.tscn` (Extends Control)
Plays a fight in real time. A looping `TickTimer` (0.1 seconds) calls `CombatEngine.process_tick` with its wait time, and stops once the fight is over. `setup(left, right)` sets the two BattleMechs, the player's on the left; without it, the screen pits a demo build against the dummy on its `chassis`. For now it shows both mechs' health and energy as one line of text (`status_line()`), also printed each tick, and adds the result (`result_line()`) at the end. The result stays up for the one-shot `ResultTimer` (2 seconds), then the screen emits `finished(winner)`, null for a draw. `print_ticks` turns the printing off.
- **The dummy** (`DUMMY`, built by `make_dummy(chassis, rules)`) is the opponent until there are real ones: the gatling and heatsink build from the first shop.

### `Game.tscn` (Extends Node) — the main scene
Plays a run. It holds one `ShopScreen` for the whole run, so the run's `RunState` carries over between screens. Next round builds the player's `BattleMech` from the run's grid and rules as they stand, swaps the shop out of the tree for a new `CombatScreen` (player on the left, `make_opponent` on the right, the dummy by default), and when that screen emits `finished`, frees it, puts the shop back, and calls `finish_round` with the result from the player's side. Both swaps are deferred, so a screen never leaves the tree while it's still emitting.

## 4. Signal Flow & Dependency Direction
- **Rule:** UI nodes can call functions on Data scripts. Data scripts CANNOT call functions on UI nodes.
- **Rule:** Data scripts communicate outward by emitting signals (e.g., `grid_updated`). UI nodes connect to these signals to update visual health, energy, and grid graphics.

## 5. Automated Testing Requirements
Before any UI is built, the following tests MUST be written in GdUnit4 and pass headlessly:
1. `test_part_placement_bounds`: Verify parts fail to place if they hang off the 4x4 edge.
2. `test_disabled_corners`: Verify parts fail to place if any part of their footprint touches the 4 corners.
3. `test_part_overlap`: Verify parts fail to place if they intersect an already placed part.
4. `test_l_shape_placement`: Verify an L-shaped part can be successfully placed in the center of the cross without triggering corner bounds.
