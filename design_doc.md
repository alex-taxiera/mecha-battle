# Mech Auto-Battler: Core Architecture & Design Doc

## 1. Core Mechanics & Grid Rules
- **The Chassis (The Board):** The grid the player builds their mech on. A run starts by picking one of three frames, each with its own slot layout, base stats, and a passive that works in every fight:

  | Frame | Playstyle | Slot layout | Hardpoints | Base HP | Energy / turn | Passive |
  |---|---|---|---|---|---|---|
  | The Bastion | Tank / Attrition | Wide: 4 across, 3 down, all 12 slots | Back, over (1, 0) and (2, 0) | 450 | 20 | **Thick Plating:** every hit it takes is 2 smaller, never below 0. Weapons, meltdowns, and the storm alike. |
  | The Striker | Glass Cannon / Burst | Tall: 2 across, 5 down, all 10 slots | Left Arm and Right Arm beside rows 1-3, Back over row 0 | 220 | 40 | **Overclock:** the first weapon to fire in a fight fires twice. The second shot is free. |
  | The Reactor | Synergy / Combo | Diamond: the 13 cells of a 5×5 within 2 steps of the center, so the center touches 4 slots | Left Arm and Right Arm beside rows 1-3, each touching only a tip, (0, 2) or (4, 2) | 300 | 30 | **Meltdown:** at 100 heat it deals 100 damage to the enemy, cools to 0, and shuts down for 3 seconds: no part acts and the chassis adds no energy. |
- **Scale and round growth:** HP is in the hundreds and weapons hit for tens (a Twin Gatling 12, a Missile Pod 30), so a fight lasts about 10-14 seconds: long enough for energy, heat, and links to matter before a burst ends it. Each frame's base HP grows 15% a round, compounding and rounded down (`hp_growth`; a Bastion is 450, 517, 595, 684, then 787 in round 5), for every mech in the round's fight, so the damage later shops add doesn't shrink fights back down. Parts' HP doesn't grow.
- **Disabled Cells:** Cells inside a frame's bounds that can never hold a part, like the Reactor's cut-away corners. The original 4x4 frame with its four corners disabled (a "cross") stays as the test chassis for section 5.
- **Hardpoints:** Weapons don't go on the grid. Each frame has its own weapon bays around it: an **arm** is a 1×3 vertical bay beside the grid, a **back** a 2×2 bay above it. A weapon mounts only in a bay of exactly its shape, one weapon per bay, and never turns, so its shape says where it goes (the Twin Gatling is an arm weapon, the Missile Pod a back weapon). Bays share the grid's cell coordinates, e.g. a left arm at (-1, 1)-(-1, 3), and sit off the frame's usable cells without touching each other. The grid is the engine room: generators, heatsinks, and defenses that power, cool, and protect the weapons.
- **The Parts:** Items with specific grid footprints (1x1, 1x3 vertical, 2x1 horizontal, L-shapes).
- **Placement Rules:** Parts cannot overlap each other, cannot overlap disabled cells, and cannot extend out of the frame's bounds. Only weapons go in bays, and weapons go nowhere else.
- **Adjacency Logic:** Parts trigger synergies based on orthogonally touching adjacent cells. A weapon links with the grid parts touching its bay, so where the engine room's parts sit still decides which weapons they boost.
- **Heat:** Each weapon shot adds its `heat` to its mech; at the end of every turn, each heatsink vents its `cooling`. Heat stays between 0 and 100. Every mech builds heat, but only the Reactor does anything with it.

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
- Stats: `hp`, `energy_gen` (generated per turn), `energy_cost` (used per turn), `damage` (per volley), `cooldown_max` (seconds between activations in combat), `heat` (added per shot), `cooling` (heat vented per turn). No rule changes heat or cooling.
- Parts are shared Resources: nothing that changes during a fight is stored on them (see `ActivePart`).
- `get_shape(turns) -> Array[Vector2i]` (the shape turned clockwise, anchored at its top-left), `can_rotate() -> bool` (false for weapons, and for shapes a turn doesn't change), and the static `normalized(cells)` (anchored and sorted, so equal footprints compare equal).

### `Hardpoint.gd` (Extends Resource)
A weapon bay on a chassis: `id`, `hardpoint_name` ("Left Arm"), `origin` (the bay's top-left in the frame's cell coordinates, e.g. (-1, 1)), and `shape`. `get_cells()` and `fits(part)` (a weapon whose unturned shape is the bay's).

### `MechChassis.gd` (Extends Resource)
A mech frame: `id`, `chassis_name`, `frame_name`, `playstyle`, `size`, `disabled_cells`, `base_hp` (round 1's), `hp_growth` (0.15, compounding a round), `base_energy`, `hardpoints`, and its passive: `passive` (Enum: NONE, THICK_PLATING, OVERCLOCK, MELTDOWN), `passive_name` and `passive_text` for the UI, and each passive's numbers (`plating`, `meltdown_damage`, `meltdown_shutdown`). `get_base_hp(round_number)` (the grown base HP), `get_hardpoint_at(cell)`, `can_mount(part)`, and `get_layout_rect()` (the frame and its bays, for drawing). The three frames in section 1 live in `res://resources/chassis/`.

### `MechGridData.gd` (Extends RefCounted)
The pure math controller for the grid, built on a `MechChassis`. No UI code allowed.
- **State:** A Dictionary tracking which placement (part, origin, rotation, cells) occupies which `Vector2i` coordinate. A mounted weapon is a placement over its bay's cells, so contacts, open edges, stats, and combat treat it like any other part.
- **Functions:**
  - `can_place_part(part: MechPart, origin_coords: Vector2i, rotation := 0) -> bool` (Must check against bounds, overlapping parts, and disabled cells; weapons against the bays).
  - `check_placement(...) -> Fit` (why a part doesn't fit. A weapon: NEEDS_HARDPOINT off every bay, WRONG_SHAPE over a bay it doesn't exactly cover or when turned, OCCUPIED in a full bay. Anything else: WEAPONS_ONLY over a bay, then OUT_OF_BOUNDS, then DISABLED_CELL, then OCCUPIED).
  - `place_part(...)`, `remove_part(coords)`, `move_part(coords, new_origin)` (a weapon moves between bays of its shape), `rotate_part(coords)`.
  - `get_adjacent_parts(coords: Vector2i) -> Array[MechPart]`
  - `get_open_edges(cells)` (empty cells a part could still link through) and `get_contacts()` (each touching pair once, with a shared edge).
  - `get_used_cell_count()` (the frame's occupied cells), `get_mounted_count()`, and `get_open_hardpoints(part, moving)` (the bays a weapon could drop into).
  - `copy()` (try a change without touching the real grid).
- **Signals:**
  - `grid_updated` (Fired whenever a part is added, moved, rotated, or removed, so the UI knows to redraw).

### `SynergyRule.gd` (Extends Resource)
An adjacency bonus between two part types: which part of the pair gets it, the stat (HP, energy, damage), add or multiply, the amount, and whether it stacks per touching partner. A touching pair links once, however many edges it shares.

### `MechStats.gd` (Extends RefCounted)
`MechStats.calculate(grid, rules, round_number := 1)`: HP (from the chassis's `base_hp` for the round, kept as `base_hp`, plus the parts'), energy generated and drawn, and damage per volley (scaled down when weapons draw more energy than is generated), plus each part's numbers and the active links.

### `RunState.gd` (Extends RefCounted)
One run: gold, the round, 4 shop slots (sold state, rotation), the mech grid, and the fight record (`wins`, `losses`, `draws`). Its `catalog` leaves out weapons no bay on the chassis can mount. `buy`, `sell` (full refund in the round it was bought, half after), `move`, `rotate_placed`, `rotate_slot` (not for parts that can't turn), `reroll` (1 gold), `record_fight(FightResult)` (WIN, LOSS, or DRAW), `end_round` (unspent gold carries over, plus income), `stats()` for the current round, and `preview_buy` / `preview_move` for hover feedback. Emits `changed`. Nothing ends the run when the record reaches a limit yet.

### Combat (`res://src/combat/`)
Live fight state, built from a finished grid. It reads the grid, chassis, and parts but never writes to them.
- **`ActivePart.gd` (Extends RefCounted):** one placed part in a fight: the `MechPart` it wraps; the `damage`, `energy_gen`, and `energy_cost` it fights with (its own numbers plus the link bonuses it has on its grid, e.g. a cooled gatling's 12 damage); its `heat` and `cooling`; `current_cooldown` (starts at the part's `cooldown_max` and counts down); and `is_active`. The same part placed twice gets two ActiveParts with separate state.
- **`BattleMech.gd` (Extends RefCounted):** `BattleMech.new(grid, rules := [], round_number := 1)`. Pass the run's rules and round so link bonuses and HP growth count, exactly as in the shop's stats panel: `max_hp` is the chassis's base HP for the round plus every part's HP and HP bonuses (the shop's Hull HP), and each ActivePart gets its linked damage and energy. Holds its `chassis` (for the passive), `current_health` (starts full), `current_energy` (starts at 0), `base_energy` (the chassis's, added each turn), `heat` (0 to `MAX_HEAT`, 100; `add_heat` clamps it), `shutdown_left` (seconds left in a Meltdown shutdown; `is_shut_down()`), `overclock_spent`, and one `ActivePart` per placed part, mounted weapons included. `take_damage(amount)` lowers `current_health`, stopping at 0, after Thick Plating on a Bastion, and returns the damage taken.
- **`CombatEngine.gd` (Extends RefCounted):** `CombatEngine.new(left, right)` runs a fight between two BattleMechs. `state` goes `PRE_GAME` → `RUNNING` (on `start()`) → `FINISHED`, and `process_tick(delta)` does nothing unless the fight is `RUNNING`. `elapsed` counts the seconds fought. A turn is `TURN_SECONDS` (1 second): the shop counts energy per turn, and in a fight each chassis adds its `base_energy` at the end of every turn, so the shop's energy numbers are what a fight does. A mech shut down by a meltdown sits out every phase below until its `shutdown_left` runs out, which is counted down first each tick; it acts again on the tick that happens. Each running tick then has four phases:
  1. **Energy and cooldowns**: if a turn just ended, each chassis adds its energy and its working heatsinks vent their cooling. Then each working part, left mech then right: its cooldown drops by `delta`, clamped at 0. A time within `TIME_EPSILON` (1e-6) of its mark counts as reached, so float error doesn't delay anything by a tick. When a generator's cooldown runs out, its ActivePart's `energy_gen` goes to its mech's `current_energy` and the cooldown resets to `cooldown_max`.
  2. **Weapons**, left mech then right: a weapon whose cooldown has run out fires at the other mech if its own mech has at least `energy_cost` energy. The mech pays the cost, the cooldown resets, the shot adds the weapon's heat to its mech, the target calls `take_damage(damage)` with the ActivePart's linked damage, and the engine emits `weapon_fired(attacker, target, damage taken)`. A weapon that can't pay stays ready and fires on the first tick its mech can. Weapons can spend energy generated earlier in the same tick. On a Striker, the fight's first shot fires twice (Overclock), the second for free.
  3. **Meltdowns**, left mech then right: a Reactor at full heat deals `meltdown_damage` to the other mech, cools to 0, shuts down for `meltdown_shutdown` seconds, and the engine emits `meltdown(mech, target, damage taken)`.
  4. **The electrical storm**, the sudden death that ends stalemates: from `storm_start` seconds (default 20) it strikes both mechs for the same damage on its first tick and every `storm_interval` ticks (2) after. Strike `n` (from 0) deals `round(storm_damage × storm_growth^n)`: by default 1 × 1.25^n, so 1, 1, 2, 2, 2, 3, 4, 5, 6, 7, 9, 12... Each strike emits `storm_struck(damage)`, before plating.

  Switched-off parts (`is_active` false) don't tick, fire, or vent, and parts with no `cooldown_max` never activate.

  A tick's damage lands together, so a mech that goes down still fires back that tick. After all four phases, if either mech's health is at 0, the fight is `FINISHED` and the engine emits `battle_ended(winner)` once: the mech still standing, or `null` if both went down in the same tick (a draw). Which side a mech is on never decides the winner.

## 3. UI Architecture (The "View")
The UI is strictly visual. It asks `RunState` what an action would do (`preview_buy` / `preview_move`) and calls it to act, but it does NOT calculate fits, costs, or stats itself. Every screen redraws from `RunState.changed`.

### `ShopScreen.tscn` (Extends Control)
The root node for the shop phase. Builds the `RunState` from its chassis, catalog, and rules (loaded from `res://resources/` when not set).
- Header: round, the record ("Record: 1 W · 0 L", plus draws once there are any), gold, **Next round**. Next round emits `fight_requested`; the round only ends when `finish_round(result)` records the fight, adds income, restocks, and toasts the result ("Won round 1 · +10g income, shop restocked").
- Chassis column: name, "Wide frame · 5 / 12 slots · 1 / 1 hardpoints", the `MechGridUI`, and the frame's passive under it ("Thick Plating: Reduces all incoming flat damage by 1.").
- Parts shop: 4 `ShopItem` slots (a bought slot shows "Sold · Reroll to restock"), **Reroll**. Each slot has a rotate button when the part can turn (never a weapon). Unaffordable parts can still be dragged; the grid explains why they can't drop.
- Sell zone: while an installed part is dragged, the shop panel becomes a drop target showing its sell value.
- `StatsPanel`: hull HP (noting the chassis's share for the round, e.g. "517 from chassis"), energy per turn, and damage per volley, each with a delta while a drop is previewed; active links; the adjacency rules legend.
- Toasts for results that happen off the grid (sold, rerolled, new round, not enough gold).

### `MechGridUI.tscn` (Extends Control)
- Draws the chassis from its size and disabled cells, its hardpoint bays around it (their own color, with a weapon-red border), and each placed part as a colored block with a rotate button in its top-right corner. The layout starts at `get_layout_rect()`'s top-left, so bays left of or above the frame fit; `cell_at` and `cell_center` convert between cells and positions. Parts carry no text: hovering one pops up its `PartInfo` (name, type and size, numbers with links applied, link bonuses, blurb) as the grid's tooltip, and an empty bay's tooltip says what it mounts ("Left Arm hardpoint / Mounts a 1×3 weapon").
- A weapon dragged over any cell of a bay snaps into that bay. While a weapon is dragged, the bays it could drop into (`show_open_bays`) get a green border.
- Drag and drop through Godot's `_get_drag_data`, `_can_drop_data`, and `_drop_data`. The payload (`PartDragData`) says where the part came from (a shop slot or a placed cell), its rotation, and which cell was grabbed.
- While a drag hovers: the footprint in green or red, the reason it can't drop, open edges around it, and link markers for the links it would make. Hovering a placed part shows its open edges; a part that was just placed or moved shows them briefly.
- Dragging a placed part moves it on the grid, or sells it when dropped on the shop.

### `CombatScreen.tscn` (Extends Control)
Plays a fight in real time. A looping `TickTimer` (0.1 seconds) calls `CombatEngine.process_tick` with its wait time, and stops once the fight is over. `setup(left, right)` sets the two BattleMechs, the player's on the left; without it, the screen pits a demo build against the dummy on its `chassis`. For now it shows both mechs' health, energy, and heat as one line of text (`status_line()`, with "OFF" on a shut-down mech), also printed each tick, and adds the result (`result_line()`) at the end. The result stays up for the one-shot `ResultTimer` (2 seconds), then the screen emits `finished(winner)`, null for a draw. `print_ticks` turns the printing off.
- **The dummy** (`DUMMY`, built by `make_dummy(rules, round_number)`) is the opponent until there are real ones: a missile pod in the back bay of its own Bastion (`DUMMY_CHASSIS`), cooled by a heatsink touching the bay, whatever frame the player picked. Its HP grows with the round like the player's.

### `ChassisSelectScreen.tscn` (Extends Control)
Where a run starts: one card per frame in `options` (every chassis in `res://resources/chassis/` when unset, in section 1's order) with its name, playstyle, a `ChassisPreview` of its slot layout and bays, "HP · EN a turn · slots · hardpoints", and its passive. A card's button calls `choose(chassis)`, which emits `chassis_chosen`.

### `Game.tscn` (Extends Node) — the main scene
Plays a run. It opens on the `ChassisSelectScreen`; when a frame is chosen, it frees that screen and creates the run's one `ShopScreen` on it (with `catalog` and `rules` when set, which tests use). The shop lives for the whole run, so the run's `RunState` carries over between screens. Next round builds the player's `BattleMech` from the run's grid, rules, and round as they stand, swaps the shop out of the tree for a new `CombatScreen` (player on the left, `make_opponent` on the right, by default the dummy grown for the same round), and when that screen emits `finished`, frees it, puts the shop back, and calls `finish_round` with the result from the player's side. Every swap is deferred, so a screen never leaves the tree while it's still emitting.

## 4. Signal Flow & Dependency Direction
- **Rule:** UI nodes can call functions on Data scripts. Data scripts CANNOT call functions on UI nodes.
- **Rule:** Data scripts communicate outward by emitting signals (e.g., `grid_updated`). UI nodes connect to these signals to update visual health, energy, and grid graphics.

## 5. Automated Testing Requirements
Before any UI is built, the following tests MUST be written in GdUnit4 and pass headlessly:
1. `test_part_placement_bounds`: Verify parts fail to place if they hang off the 4x4 edge.
2. `test_disabled_corners`: Verify parts fail to place if any part of their footprint touches the 4 corners.
3. `test_part_overlap`: Verify parts fail to place if they intersect an already placed part.
4. `test_l_shape_placement`: Verify an L-shaped part can be successfully placed in the center of the cross without triggering corner bounds.
