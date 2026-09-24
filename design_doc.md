# Mech Auto-Battler: Core Architecture & Design Doc

## 1. Core Mechanics & Grid Rules
- **The Chassis (The Board):** The grid the player builds their mech on. A run starts by picking one of five frames (the last two unlocked later), each with its own slot layout, base stats, and a passive that works in every fight:

  | Frame | Playstyle | Slot layout | Hardpoints | Base HP | Energy / turn | Passive |
  |---|---|---|---|---|---|---|
  | The Bastion | Tank / Attrition | Wide: 4 across, 3 down, all 12 slots, and a locked row of 4 under them | Back, over (1, 0) and (2, 0) | 450 | 20 | **Thick Plating:** every hit it takes is 2 smaller, never below 0. Weapons, meltdowns, and the storm alike. |
  | The Striker | Glass Cannon / Burst | Tall: 2 across, 5 down, all 10 slots, and a locked row of 2 at the bottom | Left Arm and Right Arm beside rows 1-3, Back over row 0 | 220 | 40 | **Overclock:** the first weapon to fire in a fight fires twice. The second shot is free. |
  | The Reactor | Synergy / Combo | Diamond: the 13 cells of a 5×5 within 2 steps of the center, so the center touches 4 slots; the 12 corner cells are locked | Left Arm and Right Arm beside rows 1-3, each touching only a tip, (0, 2) or (4, 2) | 300 | 30 | **Meltdown:** at 100 heat it deals 100 damage to the enemy, cools to 0, and shuts down for 3 seconds: no part acts and the chassis adds no energy. |
  | The Phantom | Evasion / Tempo | Slim: 3 across, 4 down with the top corners cut, 10 slots, and a locked row of 3 at the bottom | Left Arm and Right Arm beside rows 1-3; no back | 250 | 45 | **Evasion:** every 4th shot aimed at it misses: it doesn't land at all (the fight shows MISS). Only shots; storm strikes, meltdowns, and reflections still land. |
  | The Juggernaut | Siege / Momentum | Heavy: 5 across, 3 down, all 15 slots, and a locked row of 5 under them | Back Left over (0, 0)-(1, 0) and Back Right over (3, 0)-(4, 0), and arms beside rows 1-2 | 450 | 15 | **Momentum:** its weapons fire 2% faster for every second of the fight, up to 30%; throttling still slows them. Its low energy means it can't power every bay. |
- **Scale:** HP is in the hundreds and weapons hit for tens a second (a Twin Gatling 6 every half second, a Missile Pod 60 every 2 seconds: 12 and 30 a second), so a fight lasts about 10-14 seconds: long enough for energy, heat, and links to matter before a burst ends it. A frame's HP doesn't grow on its own: the player's max HP rises only from parts (and, later, relics, events, and Hangar nodes), while enemies get tougher by sector and floor (section 1b).
- **Starter kits:** each frame starts a run with a few parts already installed (`starter_lineup`), so its first fight isn't an empty mech: the Bastion a Missile Pod in its back, a heatsink at (1, 0), and a reactor at (2, 0); the Striker a Twin Gatling in its left arm, a Missile Pod in its back, and a reactor at (0, 1); the Reactor a Twin Gatling in each arm, a reactor at (0, 2), and a heatsink at (3, 1); the Phantom a Twin Gatling and a Scrap Repeater in its arms, a reactor at (0, 1), and a Capacitor Coupler at (2, 1); the Juggernaut a Siege Cannon in its left back, an upright reactor at (0, 0), and a heatsink at (1, 0).
- **Frame expansion:** each frame has locked cells it can grow into (drawn dim with a padlock; its card says "12 slots (+4)"). Hangars (Expand), the Derelict Titan, and bosses give cells to open; the player opens each on the Loadout by clicking a glowing locked cell that touches the frame (the frontier). The Loadout's frame line says how many are left to open, and so does the map's Loadout button. A frame with no room left gets 40 max HP instead of a cell. Each run grows its own copy of the frame.
- **Disabled Cells:** Cells inside a frame's bounds that can never hold a part, like the Reactor's cut-away corners. The original 4x4 frame with its four corners disabled (a "cross") stays as the test chassis for section 5.
- **Hardpoints:** Weapons don't go on the grid. Each frame has its own weapon bays around it: an **arm** is a 1×3 vertical bay beside the grid, a **back** a 2×2 bay above it. A weapon mounts only in a bay of exactly its shape, one weapon per bay, and never turns, so its shape says where it goes (the Twin Gatling is an arm weapon, the Missile Pod a back weapon). Bays share the grid's cell coordinates, e.g. a left arm at (-1, 1)-(-1, 3), and sit off the frame's usable cells without touching each other. The grid is the engine room: generators, heatsinks, and defenses that power, cool, and protect the weapons.
- **The Parts:** Items with specific grid footprints (1x1, 1x3 vertical, 2x1 horizontal, L-shapes).
- **Placement Rules:** Parts cannot overlap each other, cannot overlap disabled cells, and cannot extend out of the frame's bounds. Only weapons go in bays, and weapons go nowhere else.
- **Adjacency Logic:** Parts trigger synergies based on orthogonally touching adjacent cells. A weapon links with the grid parts touching its bay, so where the engine room's parts sit still decides which weapons they boost. A rule matches part types, and can also ask for a tag (Cooled and Stable only link a part tagged `heatsink`, so other utility parts don't count as heatsinks). The rules (`res://resources/rules/`):

  | Rule | Pair | Effect |
  |---|---|---|
  | Cooled | Heatsink + Weapon | the weapon's damage ×1.5, once |
  | Overcharge | Generator + Weapon | the weapon +5 damage per generator |
  | Stable | Heatsink + Generator | the generator +20 energy per heatsink |
  | Plated | Defense + Defense | each +40 HP per partner |
  | Overclocked | Chip + Weapon | the weapon's cooldown ×0.9 and energy cost ×1.2, per chip |
  | Volatile | Generator + Generator | each +20 energy and +10 heat an activation, per partner |
  | Insulated | Utility + Defense | the defense part's HP ×1.1, per utility part |
  | Targeted | Targeting + Weapon | the weapon's damage ×1.1, per targeting part |
- **The part catalog** (`res://resources/parts/`; placeholder numbers, a second = a turn):

  | Part | Type · shape | Cost · rarity | Does |
  |---|---|---|---|
  | Twin Gatling | Weapon, arm 1×3 | 4 · Uncommon | every 0.5 s: 6 dmg, 15 EN, 10 heat |
  | Plasma Lance | Weapon, arm 1×3 | 7 · Rare | every 4 s: 150 dmg, 160 EN, 90 heat |
  | Flamer | Weapon, arm 1×3 | 5 · Uncommon | every 0.5 s: 4 dmg, 12 EN, 6 heat; 2 Burn a hit |
  | Railgun | Weapon, arm 1×3 | 7 · Rare | every 3 s: 90 dmg, 120 EN, 60 heat; through plating and shields |
  | Missile Pod | Weapon, back 2×2 | 6 · Rare | every 2 s: 60 dmg, 100 EN, 70 heat |
  | Acid Sprayer | Weapon, back 2×2 | 5 · Uncommon | every 1 s: 10 dmg, 25 EN, 15 heat; 1 Corroded a hit |
  | Ion Cannon | Weapon, back 2×2 | 7 · Rare | every 2 s: 30 dmg, 80 EN, 30 heat; 3 Drained a hit |
  | Rotary Autocannon | Weapon, back 2×2 | 5 · Uncommon | every 0.25 s: 4 dmg, 8 EN, 2 heat, +1 heat for each shot in a row before it (up to +10); the streak ends when it waits for energy or its mech shuts down |
  | Micro-Reactor | Generator 2×1 | 3 · Common | 40 EN a second, +50 HP |
  | Combustion Core | Generator 2×2 | 5 · Uncommon | 80 EN and 10 heat a second |
  | Point-Defense Laser | Defense 1×1 | 2 · Common | +120 HP |
  | Solar Plating | Defense 2×1 | 3 · Common | +100 HP and 15 EN a second |
  | Energy Shield Emitter | Defense 1×2 | 4 · Uncommon | a 200-point shield; upkeep 10 EN a second |
  | Reactive Armor | Defense 1×1 | 2 · Common | +40 HP; a shot of 30+ (before plating) deals 15 back |
  | L-Shaped Heatsink | Utility (`heatsink`) L of 3 | 4 · Common | vents 15 heat a second |
  | Coolant Flush Tank | Utility 1×1 | 2 · Common | vents 5 heat a second; no tag, so it's no heatsink |
  | Overdrive Logic Chip | Utility (`chip`) 1×1 | 3 · Uncommon | nothing alone; Overclocked |
  | Thermal Regulator | Utility 2×1 | 4 · Uncommon | throttling starts at 80 heat instead of 50 (one works) |
  | Lightning Rod | Utility 1×3 | 4 · Rare | the storm starts 6 s sooner for both mechs; strikes on this mech do half damage (rounded down) and give it +30 EN (one works) |
  | Scrapper Drone | Utility 1×1 | 3 · Uncommon | while installed, shops buy every part back in full |
  | Capacitor Coupler | Utility 1×1 | 3 · Common | +5 EN each time a weapon it touches fires |
  | Ammo Feeder | Utility 2×1 | 4 · Rare | every 3rd shot from a weapon it touches takes 0.5 s off the other touching weapons' cooldowns |
  | Emergency Vent | Utility 1×2 | 4 · Uncommon | vents 40 heat when the shield breaks or collapses |
  | Meltdown Capacitor | Generator 1×1 | 3 · Uncommon | on a meltdown, the weapons it touches charge fully |
  | Kinetic Dynamo | Defense 1×2 | 3 · Common | +40 HP; +3 EN for every hit taken |
  | Scrap Repeater | Weapon, arm 1×3 | 3 · Common | every 1 s: 14 dmg, 25 EN, 12 heat |
  | Rivet Mortar | Weapon, back 2×2 | 4 · Common | every 2.5 s: 35 dmg, 40 EN, 20 heat |
  | Shock Lance | Weapon, arm 1×3 | 5 · Uncommon | every 1 s: 12 dmg, 20 EN, 10 heat; 2 Jammed a hit |
  | Leech Drill | Weapon, arm 1×3 | 5 · Uncommon | every 0.5 s: 10 dmg, 15 EN, 8 heat; each hit repairs a quarter of its damage (rounded) |
  | Guillotine Cannon | Weapon, back 2×2 | 7 · Rare | every 2.5 s: 50 dmg, 90 EN, 50 heat; double against a target at 30% HP or less |
  | Trophy Rack | Weapon, back 2×2 | 6 · Rare | every 2 s: 30 dmg, 60 EN, 30 heat; +2 dmg for the rest of the run for every fight won with it, up to +40 (before its Mk scales it) |
  | Siege Cannon | Weapon, back 2×2 | 8 · Rare | every 4 s: 120 dmg, 150 EN, 80 heat |
  | Thermoelectric Generator | Generator 2×1 | 4 · Uncommon | +0.8 EN a second for each point of heat |
  | Capacitor Battery | Generator 1×1 | 3 · Common | every 4th shot from a weapon it touches releases 40 EN |
  | Fusion Cell | Generator 2×2 | 7 · Rare | 150 EN and 25 heat a second |
  | Nanite Repair Bay | Defense 1×2 | 5 · Uncommon | +20 HP; repairs 1% of max HP a second in a fight |
  | Ablative Plating | Defense 1×1 | 2 · Common | +20 HP; the first 2 shots each fight deal nothing (before plating; a shot another plate stopped doesn't use one up) |
  | Damage Limiter | Defense 1×1 | 5 · Rare | no single hit takes more than 60, after plating and relics (one works) |
  | Status Scrubber | Utility 1×1 | 4 · Uncommon | every 5 s, clears the debuff with the most charges (once charged, the next one the moment it lands) |
  | Targeting Computer | Utility (`targeting`) 1×1 | 4 · Uncommon | nothing alone; Targeted |
- **Triggers:** some parts act on events in a fight rather than all the time. A part's neighbors are the parts touching it, a weapon's the parts touching its bay; "touching" triggers (the Coupler, the Feeder, the Meltdown Capacitor) only answer their neighbors. Counted triggers ("every 3rd shot") keep their count per part for the fight.
- **Statuses** (`res://resources/statuses/`) are what weapons and mods leave on a target, for a while. Each shows as an icon with its charges under the mech's gauges:

  | Status | Effect | Charges |
  |---|---|---|
  | Burn | +2 heat a second per charge | up to 10; −1 a second |
  | Jammed | weapons count down 8% slower per charge, down to half speed (on top of throttling) | up to 6; −1 a second |
  | Drained | −6 energy a second per charge, never below 0 | up to 10; −1 a second |
  | Corroded | every hit taken is 3 bigger per charge, before plating; reaching 5 eats the shield away for the fight and starts over | 5 wraps; −1 every 3 s |

  Buffs, for the mech that carries them (nothing gives them yet; relics, parts, and kits will):

  | Buff | Effect | Charges |
  |---|---|---|
  | Overcharged | its shots deal 10% more per charge | up to 5; −1 a second |
  | Fortified | every hit taken is 2 smaller per charge, after plating, never below 0 | up to 10; −1 a second |
  | Haste | weapons count down 10% faster per charge, up to half again as fast (throttling and Jammed still apply) | up to 5; −1 a second |
- **Weapon mods** (`res://resources/mods/`): a weapon holds one mod, which changes its numbers and can add abilities, and goes before its name. A modded weapon merges only with the same mod. Incendiary (+1 Burn a hit, −10% damage), Concussive (+1 Jammed a hit, fires 10% slower), Armor-Piercing (ignores plating, −10% damage), Overclocked (+30% damage, +15 heat a shot), Cooled (−20% energy a shot, −10% damage), Rapid (fires 25% faster, −15% damage), Stabilized (−10 heat a shot, −10% damage), Siphon (each hit repairs a tenth of its damage), and Corrosive (+1 Corroded a hit, −10% damage). Mods come from events, a Hangar's **Refit** (a random mod the weapon doesn't have), a Scrap Shop's mod offer (one a visit, 12-18 gold before Threat), and elites, whose relic group also offers a mod instead. Bought or taken, a mod goes on the strongest mounted weapon.
- **Shields:** a mech's shield (its parts' `shield`) takes hits after plating and relics but before the hull, and is full again every fight, so it protects the run's carried-over hull. Parts with `upkeep` drain it from the mech's energy each tick, before weapons fire; a mech that can't pay loses its shield for the rest of the fight, and those parts switch off.
- **Weapon rhythm:** Each weapon has its own cadence (`cooldown_max`), so fights don't beat on the second: the Twin Gatling rattles off small shots every half second, the Missile Pod lands a big one every 2 seconds.
- **Heat:** Each weapon shot adds its `heat` to its mech; each heatsink vents its `cooling` over every turn, a little each tick. Heat stays between 0 and 100. **Thermal throttling:** above 50 heat a mech's weapons cool down slower, evenly down to half speed at 100, so a build that makes more heat than it vents fires slower as a fight goes on; generators and chassis energy don't slow. The Reactor also melts down at 100 (its passive), which resets its heat. A Thermal Regulator moves the throttle line to 80. Generators that run hot (the Combustion Core, or Volatile links) add their heat each time they activate.

## 1b. The Run (Slay the Spire–style)
A run crosses three **sectors** (acts), each a branching map climbed one node at a time to a boss. Placeholder sectors: The Scavenger Junkyards, The Orbital Foundry, The Core Citadel (`res://resources/acts/`).
- **The map:** 12 floors of nodes, then the sector boss. The player starts on any bottom-floor node and each step moves to a node linked on the floor above.
- **Node kinds:** Battle (a normal enemy), Elite (a tougher enemy), Scrap Shop (buy and sell), Hangar (repair or reinforce), Event (a choice), and the Boss. The bottom floor is all battles and the floor under the boss all hangars; elites and hangars don't appear before floor 5; an Elite, Hangar, or Shop never follows another of its kind on a path; elsewhere kinds are weighted (Battle 45, Event 22, Elite 10, Hangar 12, Shop 6; Sector 1 has Shop 8, Sector 3 Battle 43 and Elite 12), and the nodes a fork leads to differ where they can.
- **HP carries over.** A fight starts at the hull's current HP and its damage stays after it. Losing or drawing a fight destroys the mech and ends the run. Beating a sector's boss repairs half the hull's damage (rounded up) and moves on to the next sector's map; beating the last sector's boss wins the run.
- **Enemies** come from the sector's pool for the node's tier (a boss is picked with the map), never the same one twice in a row. Their HP is their build's, times the sector's `enemy_hp_scale` (1, 1.4, 1.8 for now) and +3% of that a floor up the map, times the enemy's own `hp_scale`.
- **Loot:** every won fight drops gold at once (by tier, per sector: battle 8-12 / 10-14 / 12-16, elite 18-25 / 22-30 / 26-34, boss 35-45 / 40-50 / 45-55) and a draft of 3 different parts from the run's catalog to take one of into the stash, or skip. Each slot's rarity is rolled from the tier's odds (common / uncommon / rare: battle 55 / 43 / 2, elite 50 / 40 / 10, boss all rare), falling back to the nearest rarity with parts left. A pity counter grows 1.5 for every common offered and moves that much (whole) weight from common to rare until a rare comes up, which resets it. Each part's rarity is in the catalog table in section 1.
- **Field kits** (`res://resources/kits/`): one-use items the run carries in 3 slots, shown square in the HUD and listed under the chassis on the Loadout (with a Discard each, to free a slot). A **manual** kit is a button along the bottom of the fight, paid in the mech's energy; an **auto** kit fires itself the moment its condition is met; a **fight-start** kit acts as the next fight begins. A used kit is gone once the fight ends. Kits come from Scrap Shops (2 a visit, in a slim row under the relics), fights (15% of normal battles and 35% of elites drop one, taken on its own if a slot is free), events (`KitEffect`), and the Technician's "two random field kits". Placeholder kits:

  | Kit | When | Does | Price |
  |---|---|---|---|
  | Emergency Patch | auto, at 25% HP | repairs 25% of max HP | 10 |
  | Coolant Flush | auto, at 90 heat | vents 70 heat | 8 |
  | Reboot Protocol | auto, when the mech would go down | back up at 20% HP, before the fight ends | 20 |
  | Micro-missile | manual, 20 EN | 60 damage to the enemy (through its plating and shield) | 8 |
  | Flak Burst | manual, 30 EN | 30 damage and 3 Jammed to the enemy | 10 |
  | Shield Cell | manual, 10 EN | +100 shield for the rest of the fight | 10 |
  | Overdrive Injector | manual | 5 Haste | 10 |
  | Overcharge Capsule | fight start | 5 Overcharged | 8 |
  | Foam Armor | fight start | 6 Fortified | 8 |
- **The stash** holds parts the player owns but hasn't installed. From the map, the **Loadout** moves parts between the grid and the stash freely; buying and selling only happen at a Scrap Shop, which sells from the stash too.
- **Playing it:** a run starts with 20 gold. Battles, elites, and the boss play on the combat screen; a Scrap Shop opens the shop; a Hangar repairs or reinforces; an Event plays its story. Beating a boss shows SECTOR CLEARED, then the next map; the run ends on MECH DESTROYED or RUN COMPLETE, then a new run starts at the frame select.
- **Elite affixes** (`res://resources/affixes/`): each elite rolls one affix when the map is made (on the run's "affixes" stream, so the same seed rolls the same), named in its map tooltip and shown as badges under its HP bar in the fight. An affixed elite drops 20% more gold per affix. Affixes are relics of rarity AFFIX that ride on the enemy's mech:

  | Affix | Effect |
  |---|---|
  | Shielded | starts each fight with a shield of a quarter of its max HP |
  | Rapid-Fire | its weapons fire 15% faster |
  | Reflective | a shot of 30+ deals 15 back |
  | Regenerating | repairs 1% of its max HP a second |
  | Unstable | its weapons hit 20% harder and make 10 more heat a shot |
  | Armored | every hit it takes is 3 smaller |
  | Burning | its shots leave 1 Burn |
  | Ablative | the first hit on it each fight deals nothing |
  | Hardened Firmware | the first debuff on it each fight doesn't land |
  | Vampiric | its shots repair it by a fifth of their damage |
  | Jamming | its shots leave 1 Jammed |
- **Boss phases:** each sector boss turns partway through its fight (a `BossPhase`, once a fight), with its title across the stage:

  | Boss | Phase |
  |---|---|
  | The Junkyard King | Scrap Armor at half HP: a shield of 30% of its max HP |
  | The Crucible | Meltdown Protocol at half HP: heat to 90, weapons 20% faster |
  | The Core | Overload at half HP: weapons 30% faster, but Exposed (hits on it 20% bigger); Last Protocol: the first time it would go down, it reboots at 30% HP |
- **Relics** change the rules for the rest of the run. An elite drops one (rolled common / uncommon / rare at 25 / 50 / 25, from Slay-The-Robot's elite odds); a boss offers three boss relics to choose one from, or, in the same group, 2 cells to open on the frame instead (while it has room). Each run shuffles every relic once and hands them out without repeats. They show as icons in the run's HUD (hover for what they do) and pop their name up in a fight when they act. Placeholder relics (`res://resources/relics/`):

  | Relic | Rarity | Effect |
  |---|---|---|
  | Reinforced Frame | Common | +40 max HP. |
  | Capacitor Bank | Common | Start every fight with 50 energy. |
  | Coolant Reserve | Common | Every heatsink vents 5 more heat a turn. |
  | Salvage Drone | Uncommon | Fights drop 25% more gold (rounded up). |
  | Field Repair Kit | Uncommon | Repair 20 hull after every won fight. |
  | Targeting Uplink | Uncommon | The first shot of every fight deals double damage. |
  | Heat Converter | Rare | Above 50 heat, shots deal 20% more damage. |
  | Overdrive Core | Boss | +20 energy a turn; every shot makes 5 more heat. |
  | Titan Plating | Boss | +100 max HP; every hit taken is 3 smaller (after Thick Plating). |
  | War Chest | Boss | Gain 100 gold now; fights drop 10% more gold. |
  | Salvage Rig | Uncommon | Every Hangar can also strip wreckage for 15 gold, on top of its one job. |
  | Last Stand | Rare | At 30% HP or less, shots deal 30% more damage. |
  | Ablative Core | Rare | The first hit taken each fight deals nothing. |
  | Kinetic Battery | Rare | Energy left when a fight ends carries into the next, up to 100. |
  | Recycler | Rare | Every part sold brings 3 more gold. |
  | Pyromaniac | Rare | Each shot that lands on a burning enemy adds 1 more Burn. |
  | Insulated Wiring | Rare | Can't be Drained. |
  | Black Box Contract | Boss | +40 energy a turn, but fights drop no gold. |
  | Auto-Loader | Boss | Weapons fire 15% faster; shops stock one part fewer. |
  | Bulwark Core | Boss | Start each fight with a shield of 20% of max HP. |
  | Frame Extender | Boss | Open 3 more cells (+40 max HP for each the frame has no room for). |
  | Heavy Payload | Boss | Weapons deal 25% more damage but fire 15% slower. |
  | Adaptive Armor | Boss | Every hit taken gives 1 Fortified. |
  | Loyalty Card | Shop | Parts cost 1 gold less. |
  | Membership Chip | Shop | The first reroll at each shop is free. |
  | Spare Parts Crate | Shop | Shops stock one more part. |
  | Reinforced Bulkheads | Uncommon (Bastion only) | Each defense part gives 15 more HP. |
  | Afterburner | Uncommon (Striker only) | The first time the mech falls to half HP in a fight, Overclock is ready again. |
  | Containment Field | Uncommon (Reactor only) | Each Meltdown shutdown lasts 1.5 s less. |
  | Phase Cloak | Uncommon (Phantom only) | Every 3rd shot aimed at you misses, not every 4th. |
  | Inertial Core | Uncommon (Juggernaut only) | Momentum builds twice as fast. |

  A relic with a `chassis_id` only turns up in runs on that frame.
- **Scrap Shop:** 4 different parts, each slot's rarity rolled with the shop's odds (55 / 40 / 5) and priced at the part's `cost`; 2 relics from the back of the relic pool, priced by rarity (Slay-The-Robot's ranges scaled by a quarter to this game's gold: common 12-20, uncommon 21-29, rare 30-35, shop 37-50); a weapon mod for the strongest weapon (12-18 gold); a reroll for 1 gold (parts only). Parts can be bought straight onto the mech or into the stash; parts from the mech or the stash sell back (full price if bought at this shop, half otherwise), unless they're unsellable.
- **Hangar / Refit Bay:** one job from the Hangar's list (`res://resources/hangar_jobs/`): **Repair** 30% of max HP (rounded up; off with nothing to repair), **Reinforce** for +25 max HP for the rest of the run, **Upgrade** one part a Mk, **Expand** (one more cell to open; off once the frame is fully open), or **Refit** (a random mod on the strongest weapon; off without one). Or leave. Relics can add jobs that go alongside the one job (the Salvage Rig's Strip for scrap, +15 gold).
- **Part upgrades (Mk I-III):** two copies of the same part at the same Mk merge into one a Mk up: drag one onto the other on the mech, in the stash, or straight from the shop (buying it). Each Mk above I adds the part's `upgrade_bonus` (50%) of its own damage, HP, energy made, and cooling: a Mk II is ×1.5 and a Mk III ×2. Energy cost and heat don't change. Mk III is the top. Parts show their Mk as a numeral on the mech and "Mk II" in their names, and sell for their cost times their Mk (halved unless bought at this shop). A reworked part ("Overclocked ...") only merges with its own kind.
- **Events:** each Event node draws the next event the run can have from its pool (shuffled once, then refilled when used up; an event that can't happen yet is kept, dropped, sent to the back, or put back at random, by its own strategy; when none can, the fallback shows). An event is a story with choices; a choice can need something (gold, a mounted weapon, some parts) and says so when it's off. A choice's outcome is picked by weight and applies its effects: gold, hull repair or damage (never below 1 HP), max HP, a part into the stash, losing random parts (stash first), a relic, reworking the strongest mounted weapon, a status for a few fights, or a fight (with its tier's loot). The events, from the design notes (`res://resources/events/`):

  | Event | Choices |
  |---|---|
  | The Derelict Titan | Pry it open: +25 gold and a Point-Defense Laser. Cut into the core: 60% a cell to open on the frame (or +40 max HP when it's fully open), 40% 100 damage. Leave. |
  | The Rogue Field Engineer (needs a mounted weapon; put back at random if not) | Overclock: the strongest weapon gets the Overclocked mod. Cooling lines: the Cooled mod. Decline. |
  | The Armorer (needs a mounted weapon; put back at random if not) | For 20 gold each, the strongest weapon gets the Incendiary, Concussive, or Armor-Piercing mod. Move on. |
  | The Black Market AI Chip | Install: the Overdrive Logic Chip (from the catalog; a way to get it before it's unlocked) and a Glitch (a 1×1 JUNK part that does nothing, links with nothing, and can't be sold). Report the vendor: +40 gold. |
  | The Salvage Deal | Trade 2 random parts (needs 2) for a rare weapon the frame can mount. Buy repairs: 30 gold for 150 hull (needs 30 gold). Start a fight: an elite. |
  | The Unstable Radiation Zone | Push through: for 2 fights, start at +30 heat and earn +50% gold. Take the long way: fight a patrol (a normal battle; standing in for adding a node to the map). |
  | The Tinkerer's Bench (needs a part to upgrade; put back at random if not) | Let them tinker: a random part goes up a Mk. Point at your best part: 25 gold, your strongest part goes up a Mk. Leave. |
  | Abandoned Cache (the fallback) | +15 gold. |
- **Progress between runs:** a profile, saved at `user://profile.json`, counts runs, wins, fights won, and bosses beaten, each frame's record, and the unlocks earned. When a run ends, each unlock whose milestone is now met is earned and listed on the end screen ("Unlocked: The Striker"). Locked frames are greyed out on the frame select with how to earn them; locked parts and relics stay out of loot and shops (a starter kit keeps its parts). Content without an unlock is always available. The frame select also shows the totals and a Reset progress button (with a confirm). The placeholder track (`res://resources/unlocks/`):

  | Unlock | Kind | Milestone |
  |---|---|---|
  | The Mech Technician | NPC | Finish a run |
  | The Striker | Chassis | Clear Sector 1 |
  | The Phantom | Chassis | Win a run with the Striker |
  | The Juggernaut | Chassis | Clear Sector 2 with the Bastion |
  | The Reactor | Chassis | Clear Sector 2 |
  | Missile Pods in loot and shops | Part | Win 5 fights in total |
  | Plasma Lances in loot and shops | Part | Clear Sector 1 with the Striker |
  | Combustion Cores in loot and shops | Part | Clear Sector 2 with the Striker |
  | Overdrive Logic Chips in loot and shops | Part | Win 25 fights in total |
  | Rotary Autocannons in loot and shops | Part | Win 10 fights in total |
  | Energy Shield Emitters in loot and shops | Part | Finish 2 runs |
  | Thermal Regulators in loot and shops | Part | Clear Sector 1 with the Reactor |
  | Lightning Rods in loot and shops | Part | Clear Sector 2 with the Bastion |
  | Scrapper Drones in loot and shops | Part | Finish 3 runs |
  | Flamers in loot and shops | Part | Clear Sector 1 with the Reactor |
  | Acid Sprayers in loot and shops | Part | Win 15 fights in total |
  | Ion Cannons in loot and shops | Part | Win a run |
  | Railguns in loot and shops | Part | Clear Sector 3 with the Striker |
  | Emergency Vents in loot and shops | Part | Win 20 fights in total |
  | Meltdown Capacitors in loot and shops | Part | Clear Sector 2 with the Reactor |
  | Ammo Feeders in loot and shops | Part | Clear Sector 2 with the Striker |
  | The Heat Converter relic | Relic | Win 15 fights in total |
  | The Titan Plating relic | Relic | Clear Sector 1 with the Bastion |
  | Shock Lances in loot and shops | Part | Win 8 fights in total |
  | Leech Drills in loot and shops | Part | Finish 4 runs |
  | Guillotine Cannons in loot and shops | Part | Clear Sector 2 with the Bastion |
  | Trophy Racks in loot and shops | Part | Win 2 runs |
  | Siege Cannons in loot and shops | Part | Clear Sector 3 with the Bastion |
  | Thermoelectric Generators in loot and shops | Part | Win 35 fights in total |
  | Fusion Cells in loot and shops | Part | Clear Sector 3 with the Reactor |
  | Nanite Repair Bays in loot and shops | Part | Finish 5 runs |
  | Damage Limiters in loot and shops | Part | Win 3 runs |
  | Status Scrubbers in loot and shops | Part | Win 40 fights in total |
  | The Black Box Contract relic | Relic | Win a run |
  | The Pyromaniac relic | Relic | Win 20 fights in total |
  | The Kinetic Battery relic | Relic | Clear Sector 2 with the Striker |
- **The Mech Technician** (once unlocked): after the frame is chosen, before the map, offers three boons to pick one of: two pair an upside with a downside ("Gain 75 gold, but start with 60 hull damage"; the downside applies first), one is whole ("Gain a random common relic"). None repeats within an offer. The placeholder options (`res://resources/technician/`), each using the event effects:

  | Kind | Options |
  |---|---|
  | Whole | a random common relic; +40 max HP; +30 gold; two random field kits |
  | Upside | a random rare part; a random uncommon relic; upgrade your strongest weapon a Mk; +75 gold |
  | Downside | -40 max HP; lose all gold; start with 60 hull damage; a Glitch in the stash |
- **Threat levels** (the ascension ladder, `res://resources/threat/`): each frame's card on the frame select has a -/+ Threat picker, from 0 up to the highest level that frame has unlocked. Winning a run at Threat N unlocks Threat N+1 on that frame ("Unlocked: Threat 3 for The Striker" on the end screen); losses unlock nothing. A run at Threat N plays with every level from 1 to N. The HUD reads "Threat 3 · Sector 1 of 3 · Floor 4", and hovering it lists the run's modifiers. Placeholder ladder:

  | Threat | Name | Effect |
  |---|---|---|
  | 1 | Hardened | Enemies have 10% more HP (and shields). |
  | 2 | Price Gouging | Shop prices (parts and relics) are 15% higher, rounded up, so every part costs at least 1 gold more. |
  | 3 | Lean Pickings | Normal battles drop 25% less gold. |
  | 4 | Veterans | Elites roll one more affix. |
  | 5 | Short Shifts | Hangar repairs mend 10% less of max HP (20% instead of 30%; never below 5%). |
  | 6 | Hair Trigger | Boss phases trigger at 16% more HP (a 50% phase at 66%). |
  | 7 | Hunted | Normal battles have a 25% chance to roll an affix. |
  | 8 | Bad Start | Start with 10% hull damage and a Glitch in the stash. |
- **Custom modes** (`res://resources/run_modifiers/`): checkboxes in the frame select's footer, on top of any Threat. A mode can name others it's `exclusive_with`; ticking it unticks them.

  | Mode | Effect |
  |---|---|
  | Glass Cannon | Your weapons deal 50% more damage, but your mech has half the HP. |
  | Endless | After the last boss the sectors start over ("Loop 2"), their enemies 50% more HP each loop. The run only ends when the mech falls, so it never unlocks a Threat level. |
- Content still to come: more parts, enemies, relics, and events, and balance.

## 2. Data Architecture (The "Model")
All game data and grid math must be decoupled from the UI using Godot 4 Custom Resources and pure Reference classes. Content lives in `res://resources/` (`parts/`, `chassis/`, `rules/`, `enemies/`, `acts/`). Run logic that isn't content lives in `res://src/run/`; parts of it are adapted from Slay-The-Robot (MIT, see `THIRD_PARTY_NOTICES.md`). Art and fonts live in `res://assets/`: `combat/` holds the fight's pixel art (the 640×410 arena, 128×128 chassis sprites facing right with empty bays, weapon sprites, and projectiles, all drawn at 2×), `fonts/` the OFL fonts (Silkscreen, Chakra Petch, JetBrains Mono, each beside its `OFL.txt`), and `shaders/` the battle sprite shader.

### `MechPart.gd` (Extends Resource)
The blueprint for every item in the game.
- `@export var id: String`
- `@export var part_name: String`
- `@export var type: PartType` (Enum: WEAPON, GENERATOR, DEFENSE, UTILITY, JUNK; JUNK parts do nothing and match no rule)
- `@export var cost: int`
- `@export var rarity: Rarity` (Enum: COMMON, UNCOMMON, RARE), for loot and shop odds
- `@export var sellable: bool` (false for parts no shop takes back, like the Glitch)
- `@export var upgrade_bonus: float` (0.5) and `level` (the run copy's Mk, 1-3, `@export_storage` so copies keep it; `MAX_LEVEL`, `NUMERALS`). `get_level_scale()`, `get_display_name()` ("Twin Gatling Mk II"), and `can_merge_with(other)` (same id and name, same Mk, below the top, not itself).
- `@export var grid_shape: Array[Vector2i]` (Defines the shape relative to a 0,0 origin. E.g., a vertical 1x2 is `[Vector2i(0,0), Vector2i(0,1)]`)
- `@export var description: String`
- `battle_sprite` (a weapon's sprite on its bay in a fight) and `projectile_sprite` (its shot in flight, tinted by side).
- `@export var tags: Array[String]` (kinds a rule can ask for, e.g. "heatsink"; `has_tag(tag)`)
- Stats: `hp`, `energy_gen` (generated each activation), `energy_cost` (paid each shot), `damage` (each shot), `cooldown_max` (seconds between activations in combat), `heat` (added each activation: each shot for a weapon), `cooling` (heat vented per turn), `shield` (shield points), `upkeep` (energy drained per turn). Rules can change heat and cooldowns, but not cooling. A part's Mk scales its shield like its HP.
- `@export var abilities: Array[PartAbility]` (what the part does beyond its numbers) and `mod` (the run copy's `WeaponMod`, `@export_storage` like `level`). `get_abilities()` is its own and its mod's; `get_display_name()` puts the mod first ("Incendiary Twin Gatling Mk II"); `can_merge_with` needs the same mod.

### `WeaponMod.gd` (Extends Resource)
A lasting change to one weapon: `id`, `prefix`, `description`, `damage_scale`, `cooldown_scale`, `energy_scale`, `heat_add`, and `abilities`; `fits(part)` (weapons). `MechStats` works the modded numbers out from the part's own before links, so taking a mod off is exact. Adapted from Slay-The-Robot's card decorators.
- Parts are shared Resources: nothing that changes during a fight is stored on them (see `ActivePart`).

### `PartAbility.gd` (Extends Resource)
Something a part does beyond its numbers. Each is a subclass in `res://src/data/abilities/` with its numbers exported, overriding the hooks it needs (every hook does nothing by default), the same shape as `Relic`. Abilities keep no state; `stacks` (false: only the first of its kind on a mech acts). Hooks: `on_fight_start(mech, active)`, `get_storm_lead()`, `modify_shot_heat(active, heat)`, `modify_hit(hit)` and `on_hit(hit)` (a shot from the part's own weapon, before it lands and after, unless rejected), `make_interceptors(mech, active)` (added to the mech's side of the hit pipeline as it's built: Ablative, DamageCap), `on_tick(mech, active, delta)` (every tick while the part works and its mech isn't shut down), `on_fight_end(mech, active, won)` (the part is the run's own, so a change to it lasts), the triggers `on_neighbor_fired(mech, active, weapon)`, `on_shield_broken(mech, active)` (a hit takes the last point, or the shield collapses), `on_meltdown(mech, active)`, and `on_damaged(mech, active, damage)` (any hit that lands for more than 0), `on_hit_taken(mech, active, damage) -> int` (damage back), `modify_storm_strike(mech, damage)`, and `refunds_in_full()`. The abilities: `HeatRamp` (`ramp`, `max_extra`; the autocannon), `ReactiveReflect` (`threshold`, `damage`), `ThrottleRaise` (`throttle_heat`), `StormGround` (`storm_lead`, `share_taken`, `energy`), `FullRefund`, `EnergyOnNeighborFire` (`energy`, `every`), `FeedOnNeighborFire` (`every`, `seconds`), `VentOnShieldBreak` (`heat`), `ChargeOnMeltdown`, `EnergyOnDamage` (`energy`), `ApplyStatus` (`status`, `charges`: leaves a status on each hit), `Piercing` (`pierce_plating`, `pierce_shield`), `Leech` (`share`), `Execute` (`threshold`, `multiplier`), `TrophyGrowth` (`damage`, `max_bonus`: into the part's `bonus_damage`), `HeatToEnergy` (`energy_per_heat`), `RepairOverTime` (`share`), `Ablative` (`hits`), `DamageCap` (`cap`), and `StatusScrubber` (`interval`). `BattleMech.get_abilities()` lists them as `Acting` pairs (the part and one of its abilities).
- `get_shape(turns) -> Array[Vector2i]` (the shape turned clockwise, anchored at its top-left), `can_rotate() -> bool` (false for weapons, and for shapes a turn doesn't change), and the static `normalized(cells)` (anchored and sorted, so equal footprints compare equal).

### `Hardpoint.gd` (Extends Resource)
A weapon bay on a chassis: `id`, `hardpoint_name` ("Left Arm"), `origin` (the bay's top-left in the frame's cell coordinates, e.g. (-1, 1)), and `shape`. For fights, `battle_anchor` (where a mounted weapon's sprite goes on the chassis sprite, in its pixels) and `battle_behind` (drawn behind the body, like a far arm). `get_cells()` and `fits(part)` (a weapon whose unturned shape is the bay's).

### `MechChassis.gd` (Extends Resource)
A mech frame: `id`, `chassis_name`, `frame_name`, `playstyle`, `size`, `disabled_cells`, `base_hp`, `base_energy`, `hardpoints`, `battle_sprite`, `starter_lineup` (the run's starting parts, as `LoadoutPart`s), and its passive: `passive` (a `ChassisPassive`, or null for none) with `passive_name` and `passive_text` for the UI. `get_hardpoint_at(cell)`, `can_mount(part)`, and `get_layout_rect()` (the frame and its bays, for drawing). `expansion_cells` (inside `size`, locked until opened) and `opened_cells` (the run copy's, `@export_storage`); `is_locked(cell)`, `get_locked_cells()`, `get_frontier()` (locked cells touching a usable one), and `open_cell(cell)` (a frontier cell only). The three frames in section 1 live in `res://resources/chassis/`.

### `ChassisPassive.gd` (Extends Resource)
What a frame does in a fight on its own. Each kind is a subclass in `res://src/data/passives/` with its numbers exported, overriding the hooks it needs: `make_interceptors(mech)` (added to the mech's side of the hit pipeline), `on_fight_start(mech)`, `on_tick(mech, delta)`, `extra_shots(mech, weapon) -> int` (free shots right after a paid one), and `modify_weapon_speed(mech, speed)`. A passive is shared by every mech on its frame, so a fight's state lives in `BattleMech.passive_state`. The passives: `ThickPlatingPassive` (`plating`, 2: a target-side interceptor, priority 9000, skipped by pierce), `OverclockPassive` (the first paid shot of a fight gets one extra), `MeltdownPassive` (`damage` 100, `shutdown` 3 s; the engine runs the meltdown for a chassis that has one), `EvasionPassive` (`every` 4: a target-side interceptor, priority 20000, SHOT only, that rejects every 4th real shot; previews don't count; `passive_state[EVERY]` overrides it), and `MomentumPassive` (`per_second` 0.02, `max_bonus` 0.3, counted from the fight's ticks; `passive_state[RATE]` speeds it). A rejected shot marks its weapon's `ActivePart.last_missed`, and the fight shows MISS instead of a hit.

### `Relic.gd` (Extends Resource)
A relic: `id`, `relic_name`, `description`, `rarity` (Enum: COMMON, UNCOMMON, RARE, BOSS, SHOP, EVENT), and a placeholder icon (`glyph` on a badge of `color`). Each relic is a subclass in `res://src/data/relics/` with its numbers exported, overriding the hooks it needs; every hook does nothing by default:
- `on_obtain(run)`: once, when found.
- `modify_part_stats(part, numbers)` and `modify_stats(stats)`: in `MechStats.calculate`, after links (a part's numbers) and at the end (the totals, e.g. `hp`, `base_energy`).
- `on_fight_start(mech) -> bool` (true if it did something to show), `modify_shot_damage(mech, weapon, damage)`, `modify_damage_taken(mech, amount)`: in fights.
- `on_fight_won(run)` and `modify_gold(amount)`: after fights.
A run owns its own copies, so a relic can keep state for a fight (reset in `on_fight_start`). More hooks: `on_tick(mech, delta)`, `on_hit_taken(mech, hit)`, `on_hit_dealt(mech, hit)`, `on_fight_end(mech, won)`, and on the run: `on_node_entered(run, node)` (after a step on the map), `on_shop_opened(run, shop)` (stocked, priced), `modify_part_price(part, price)` (after Threat; prices never go below 0), `modify_reroll_cost(run, cost)`, `on_reroll(run)`, `modify_sell_value(part, value)`, and `blocks_status(mech, status)` (checked by `BattleMech.add_status`). `chassis_id` keeps a relic to one frame's runs. Rarity AFFIX marks an enemy's affix (`res://src/data/affixes/`: `Shielded`, `RapidFire`, `Reflective`, `Regenerating`, `Unstable`, `Armored`, `Burning`, and the phase-only `Exposed`); a fight gets its own copies.

### `FieldKit.gd` (Extends Resource)
A one-use item: `id`, `kit_name`, `description`, `trigger` (MANUAL, AUTO, FIGHT_START), a placeholder `glyph` and `color`, `price`, and `energy_cost` (MANUAL). AUTO conditions: `hp_below` (share of max HP), `heat_above`, `on_defeat`; `is_due(mech)`. `apply(mech, enemy)` does the work; `describe_trigger()` ("Auto: at 25% HP", "Use in a fight · 20 EN"). Kinds in `res://src/data/kits/`: `RepairKit` (`share`), `ReviveKit` (`share`), `VentKit` (`heat`), `ShieldKit` (`shield`), `StrikeKit` (`damage`, `status`, `charges`: an OTHER hit), and `BuffKit` (`status`, `charges`). Kits keep no state. Adapted from Slay-The-Robot's consumables, with the use cost paid by the fight (STR paid it in the UI, so auto-used items skipped it).

### `BossPhase.gd` (Extends Resource)
A boss's turn: `title`, `text`, `threshold` (share of max HP) or `revive` (the first time it would go down), and effects: `heal_share` (for a revive, the HP it comes back with), `shield_share`, `heat` (-1 for none), `cooldown_scale` and `damage_scale` for its weapons, and `relics` it gains (fight hooks only). `EnemyLoadout.phases` holds a boss's; `BattleMech.check_phases()` enters those due (a threshold one only while the boss stands), once each, and `phase_threshold_bonus` moves every threshold up.

Hidden relics: `HullUpgrade` (`hp`; a Reinforce or an event's max HP) and `TimedStatus` (`fights`, `start_heat`, `gold_bonus`; an event's status, counting down as each won fight's loot is rolled). The run keeps them apart from its relics.

### Events (`res://src/data/events/`, Resources)
- **`GameEvent.gd`:** `id`, `title`, `text`, an optional `requirement` for coming up at all, a `failed_strategy` (KEEP, REMOVE, APPEND, REINSERT) for when it can't, `fallback`, and `choices`. `can_happen(run)`.
- **`EventChoice.gd`:** `label`, `hint`, an optional `requirement`, and weighted `outcomes`. `is_available(run)`.
- **`EventOutcome.gd`:** `weight`, `text`, and `effects`.
- **`EventEffect.gd`** subclasses, each `apply(run, result)` adding a line to the `EventResult`: `GoldEffect`, `HullEffect`, `MaxHpEffect` (down, too, when negative), `UpgradePartEffect` (a random or the strongest upgradable part), `PartEffect` (a given part, or one of a rarity from the catalog, weapons only if asked), `LosePartsEffect`, `RelicEffect` (a given relic, or one rolled from the pool, of a `rarity` if set), `WeaponModEffect` (fits a `WeaponMod` to the strongest mounted weapon, replacing its mod), `StatusEffect`, and `FightEffect` (sets the result's `fight_tier`; with an `enemy` the fight is against that enemy, at its own tier, and a `relic_rarity` of 0 or more adds a relic of that rarity to the win's relic choice: an event's prize fight).
- **`EventRequirement.gd`** subclasses, each `check(run)` and `describe()`: `GoldRequirement`, `WeaponRequirement`, `PartsRequirement`, `UpgradableRequirement`.

### `Unlock.gd` (Extends Resource)
Something a profile earns: `id`, `kind` (CHASSIS, PART, RELIC, NPC), `target_id` (the chassis, part, relic, or NPC id), `title` ("The Striker"), `hint` ("Clear Sector 1"), and a milestone whose set fields must all be met: `sectors_cleared` in one run (optionally `with_chassis`), `runs_finished`, `fights_won_total`, and `runs_won` in total. `is_met(profile, sectors, chassis_id)`.

### `RunStartOption.gd` (Extends Resource)
One of the Technician's options: `id`, `text` (a sentence for a whole boon, a clause for a half), `kind` (UPSIDE, DOWNSIDE, COMPLETE), and `effects` (event effects). Adapted from Slay-The-Robot's `RunStartOptionData`.

### `LoadoutPart.gd` (Extends Resource)
One part of a ready-made build: `part`, `origin`, `rotation`. `LoadoutPart.place_all(grid, lineup)` places a copy of each, so builds never share part instances, and reports (push_error) the first that doesn't fit.

### `RunModifier.gd` (Extends Resource)
A change to a whole run: a Threat level or a custom mode. `id`, `modifier_name`, `description`, `threat_level` (1 and up for a Threat level, 0 for a mode), `is_custom` (a frame-select checkbox), `is_automatic` (every run gets it), `exclusive_with` (mode ids). Its numbers: `enemy_hp_scale`, `elite_affixes_add`, `normal_affix_chance`, `phase_threshold_add`, `shop_price_scale`, `battle_gold_scale`, `repair_share_add`, `start_hull_damage_share`, `start_parts`, `player_damage_scale`, `player_hp_scale`, and `endless`; a run's modifiers stack, scales multiplying and the rest adding. `on_run_start(run)` for anything the numbers can't say. `RunModifier.threat_stack(levels, threat)` (levels 1 to `threat`, lowest first) and `RunModifier.toggle(selected, modifier, on)` (exclusive either way). Adapted from Slay-The-Robot's `RunModifierData` and `BaseRunModifier`, with its level off-by-one fixed.

### `EnemyLoadout.gd` (Extends Resource)
An enemy: `id`, `enemy_name`, `tier` (Enum: NORMAL, ELITE, BOSS), `chassis`, `lineup` (`LoadoutPart`s), `hp_scale`, a boss's `phases`, `opened_cells` for an enemy on a grown frame, and `threat_overrides` (Threat level -> `{property: value}`, e.g. `{2: {"hp_scale": 1.5}}`). `build_grid()`; `with_threat(threat)` returns the enemy itself, or a copy with the overrides of every level from 1 to `threat` set, lowest first (Slay-The-Robot applied them at every level). The placeholder roster (4 normals, 2 elites, and a boss a sector) is in `res://resources/enemies/`. The second round added a status-weapon normal and a second elite to each sector: the Rust Sparker (Striker, a Shock Lance) and the Junk Tyrant (Striker, Scrap Repeater, Shock Lance, Rivet Mortar, Ablative Plating, a Capacitor Battery) in Sector 1; the Acid Crawler (Bastion, an Acid Sprayer, hp ×0.75) and the Slag Reaver (Reactor, Flamer and Leech Drill, a Thermoelectric Generator and a Nanite Repair Bay, hp ×0.9) in Sector 2; the Ion Lancer (Striker, an Ion Cannon and a Shock Lance by a Targeting Computer) and the Siege Warden (Bastion, a Siege Cannon on a Fusion Cell, a Damage Limiter, a Status Scrubber, hp ×0.85) in Sector 3. Two normals ride the new frames: the Wraith (Phantom, a Shock Lance and a Flamer, hp ×1.6) in Sector 2 and the Iron Juggernaut (Juggernaut, two Rivet Mortars, hp ×0.7) in Sector 3. Sector 1 uses the first five parts (its elite adds Reactive Armor); later sectors mix in the new ones, whatever the profile has unlocked, so players see what's out there: the Smelter (Plasma Lance, Combustion Core, Flush Tank), the Foundry Overseer (Rotary Autocannon overclocked by a chip, Reactive Armor), the Crucible (Thermal Regulator), the Citadel Lancer (Plasma Lance and a chip), the Core Warden (an Energy Shield Emitter), the Praetorian (a Lightning Rod), and The Core (an Energy Shield Emitter).

### `ActData.gd` (Extends Resource)
A sector: `id`, `sector_name`; the map's shape (`floors` 12, `columns` 7, `paths` 6, `min_special_floor` 4, and an optional `generator` script extending `MapGenerator`); node weights (`battle_weight` ... `shop_weight`, `get_node_weights()`); `enemies` of every tier (`get_enemies(tier)`); enemy scaling (`enemy_hp_scale`, `enemy_hp_per_floor`, `get_enemy_hp_scale(floor_index)`); and loot gold (`battle_gold`, `elite_gold`, `boss_gold`, each x to y; `get_gold_range(tier)`).

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
An adjacency bonus between two part types, each side optionally needing a tag (`first_tag`, `second_tag`; `matches(a, b)`, `fits_first`, `fits_second`): which part of the pair gets it, its `bonuses` (each a `RuleBonus`: a stat, HP, ENERGY, DAMAGE, HEAT, COOLDOWN, ENERGY_COST, COOLING, or SHIELD, added or multiplied by an amount), and whether it stacks per touching partner. A touching pair links once, however many edges it shares.

### `MechStats.gd` (Extends RefCounted)
`MechStats.calculate(grid, rules, relics := [])`: HP (the chassis's `base_hp`, kept as `base_hp`, plus the parts', each part's own numbers scaled by its Mk first), the chassis's energy a turn (`base_energy`), energy generated and drawn a turn, damage a turn (scaled down when weapons draw more energy than is generated), heat a turn (`heat_made` by the weapons at their cadence, scaled by power like damage, plus any other part that runs hot at its own, unscaled, against `heat_vented` by the heatsinks; `get_net_heat()`), and `shield` (upkeep counts toward `energy_drawn`), plus each part's numbers, per activation, and the active links. The relics' stat hooks apply last. Turn totals count each part as often as it acts in a turn (`activations_per_turn(cooldown)`: a turn's length over its cooldown as links change it; a part with none counts once), so a gatling firing every half second counts twice.

### `RunState.gd` (Extends RefCounted)
One run: `RunState.new(chassis, catalog, rules, start_gold, rng, acts)`. It installs the chassis's starter kit and generates the first sector's map. Emits `changed` after every change below.
- **State:** `rng` (a `RunRng`), `relics` (the run's own copies) and `relic_pool`, the mech `grid`, the `stash` (`StashEntry`: part and rotation), `gold`, `hull_damage`, the `catalog` (leaving out weapons no bay on the chassis can mount), `rules`, `acts`, `act_index`, the current `map`, the open `shop` (a `ShopStock`, or null), `fights_won`, and `outcome` (ONGOING, VICTORY, DEFEAT; `is_over()`).
- **Hull:** HP is kept as damage, so parts that add HP raise current HP with the max and taking a part out and back in never heals. `get_max_hp()` (from `stats()`), `get_current_hp()` (max less damage, never below 1 while the run goes on, 0 once destroyed), `heal(amount)`, `damage_hull(amount)` (outside fights; leaves at least 1).
- **Fights:** `make_player_mech()` (the build at its current HP), `get_enemy(node)` (picked from the sector's pool for the node's tier on first use and kept on the node; not the last one picked when there's a choice), `make_enemy_mech(node)` (named for the enemy, HP scaled for the sector and floor, with copies of the node's affixes as its relics and a boss's phases), `record_fight(FightResult, mech)` (WIN, LOSS, or DRAW: the mech's damage carries over, and anything but a win ends the run in DEFEAT).
- **Map:** `get_act()`, `get_floor_number()` (from 1; 0 before the first step), `get_reachable()`, `travel(node)`, and `next_act()` after a boss (repairs half the damage, rounded up, and generates the next map, or ends in VICTORY after the last sector).
- **Loot:** `loot` (the run's `RewardRoller`, so the pity carries over), `roll_reward(node, relic_rarity := -1)` (a `FightReward`: gold for the tier as relics change it, added at once; a draft from the catalog with the tier's odds; an elite's rolled relic or a boss's three boss relics), `take_reward_part(reward, index)` (stashes a copy and closes the draft), `take_reward_relic(reward, index)`, `take_reward_mod(reward)` (an elite's mod, instead of its relic). Mods: `mod_pool`, `roll_mod()` (one the strongest weapon doesn't have, on the "mods" stream), `fit_mod(mod)`, and `buy_mod(index)` at a shop.
- **Field kits:** `kits` (up to `KIT_SLOTS`, 3), `kit_pool`, `add_kit(kit)`, `has_kit_room()`, `discard_kit(index)`, `roll_kit()` (on the "kits" stream), `take_reward_kit(reward)`, and `buy_kit(index)` (a shop's `kit_offers`, `SHOP_KITS` 2 a visit at their price as Threat scales it). `make_player_mech()` hands the fight the kits; `record_fight` removes the ones it used. `roll_reward` drops a kit at `KIT_DROP_CHANCES` (normal 15%, elite 35%, boss 0).
- **Relics:** `add_relic(relic)` (a copy, out of the pool, `on_obtain` run), `add_upgrade(upgrade)`, `add_status(status)` (a copy). `get_modifiers()` is the relics, upgrades, and statuses together: `stats()`, `make_player_mech()`, previews, fight gold, and a won fight's `on_fight_won` all use them.
- **Upgrades:** `merge_from_stash(index, coords)`, `merge_stash(from, into)`, `merge_on_grid(from_coords, into_coords)`, `merge_into_stash(coords, into)`, `buy_and_merge(slot, coords)` (the target goes up a Mk, the source is used up; a merged part sells back in full only if both halves were bought at this shop), `preview_merge(part, into_coords, from_coords)` (a `Preview` with `merge` set), `upgrade_part(part)`, and `get_upgradable_parts()` (installed then stashed, below Mk III, no junk).
- **Modifiers:** `run_modifiers` (passed last to `new`), `get_threat()`, `get_mod_product(field)`, `get_mod_sum(field)`, `is_endless()`, `loops`. They scale enemy HP (and by `ENDLESS_HP_PER_LOOP` 0.5 a loop) and boss phase thresholds in `make_enemy_mech`, shop prices (`price_of(part)`, `scale_price(price)`, rounded up; buying, affordability, relic offers, and a fresh part's refund use them), normal battles' gold in `roll_reward`, elite and normal affixes when a map is made, and a Hangar repair's share (`get_repair_share(share)`, never below `MIN_REPAIR_SHARE` 0.05). At the start they add a hidden `PlayerScale` upgrade (weapon damage and max HP), hull damage, and stash parts, then call each one's `on_run_start`.
- **Frame:** the run grows its own copy of the chassis. `cells_to_open`, `get_expandable_cells()` (locked cells not already owed), `grant_cells(count)` (as many as there's room for), and `open_cell(cell)`.
- **Stops:** `hangar_jobs` and `get_hangar_jobs()` (the Hangar's, then its relics' `hangar_jobs`); `get_event(node)` (drawn from `event_pool` on first use and kept on the node), `choose_event_option(event, index)` (an `EventResult`, or null if the choice isn't available).
- **Stash:** `stash_part(part, rotation)` (a copy), `install(index, origin)`, `unequip(coords)` (keeps the part's turn), `rotate_stashed(index)`, `preview_install(index, origin)`.
- **Shop:** `open_shop()` (with `SHOP_RELICS` relics from the back of the pool) / `close_shop()`. While one is open: `buy(slot, origin)`, `buy_to_stash(slot)`, `buy_relic(index)`, `rotate_slot`, `reroll` (`get_reroll_cost()`: 1 gold, as relics change it), and `sell(coords)` and `sell_stashed(index)` (a full refund for parts bought at this shop or while a part that `refunds_in_full()` is installed, half otherwise, never for unsellable parts; `sell_value`, `stash_sell_value`, `is_fresh`, `is_stash_fresh`, `can_sell`, `can_sell_part`). `preview_buy` / `preview_move` for hover feedback; moving and turning installed parts (`move`, `rotate_placed`) is free anywhere.

### Run logic (`res://src/run/`)
- **`RunRng.gd`:** the run's seed split into named streams (`stream("map")`, "enemies", "shop", ...), each seeded from the seed and its name so no two streams roll alike, with `get_state()` / `restore()`. Static helpers: `shuffle(rng, array)` (Fisher-Yates), `shuffle_slice(rng, array, count)`, and `weighted_pick(rng, {key: weight})` (keys weighted 0 or less never come up; null when nothing has weight). Adapted from Slay-The-Robot's `get_player_rng` and `Random.gd`, fixing its shared stream seeds and biased shuffle.
- **`MapNode.gd`:** `id` ("floor_column", or "boss"), `floor_index` (0 at the bottom), `column`, `type` (Enum: BATTLE, ELITE, SHOP, HANGAR, EVENT, BOSS), `next`, `visited`, `enemy`, and `jitter` (its drawn offset from its lattice point), and an elite's `affixes` (rolled with the map from the run's `affix_pool`, `elite_affixes` each). `is_fight()`, `get_tier()`.
- **`MapGraph.gd`:** a sector's map: `act`, `floors` (each floor's nodes, left to right), `boss`, and `current`. `get_nodes()`, `get_reachable()`, `can_travel(node)`, `travel(node)`, `is_at_boss()`, `find_node(id)`.
- **`MapGenerator.gd`:** `generate(act, rng)`. A lattice of the sector's floors × columns, each point linked to the three above it (from Slay-The-Robot's act generator); `paths` random walks up those links from the bottom floor, the first two starting apart, none crossing a link already walked, and only what they walk is kept; the boss linked from every top-floor node and given one of the sector's bosses. Then node kinds as in section 1b, and each node's jitter (up to 0.25 × 0.2 of the spacing).
- **`RewardRoller.gd`:** `draft_parts(rng, catalog, table, count := 3)` and `roll_gold(rng, range)`, with the odds tables (`Table`: STANDARD, ELITE, BOSS, SHOP; `table_for(tier)`) and `rare_pity`, as in section 1b. Adapted from Slay-The-Robot's `generate_rarity_weighted_card_draft`, which stops short when a rarity runs dry and never resets its pity; this one falls back and resets.
- **`FightReward.gd`:** a won fight's `tier`, `gold`, draft `parts` and `taken` (-1 until one is), and `relics` on offer, a boss's `cells` in the same group, and `relic_taken` (`CELLS_TAKEN` for the cells; `take_reward_cells`); `is_draft_open()`, `is_relic_open()`.
- **`RelicPool.gd`:** every relic, shuffled once with the run's "relics" stream. `take(count, rarities, from_back)` (no repeats; shops will pull from the back), `roll(rng, weights)` (a rarity from `CHEST_WEIGHTS` or `ELITE_WEIGHTS`, falling back to the other standard rarities), `remove(relic)`, `has`, `size`. Adapted from Slay-The-Robot's artifact pool.
- **`ShopStock.gd`:** one Scrap Shop visit's `slots` (`SIZE` 4; each a part, its rotation, and whether it's sold), drafted from the catalog with the SHOP odds by a roller of its own (so the loot pity doesn't move), and `relic_offers` (each a relic, its `price` rolled from `RELIC_PRICES`, and whether it's sold). `get_open_slot`, `get_open_relic`, `rotate_slot`, `restock` (parts only), `REROLL_COST`.
- **`Profile.gd`:** `path` (empty never writes), `runs`, `wins`, `fights_won`, `bosses_beaten`, `chassis_records` (id -> runs, wins, best_sector, threat: the highest Threat unlocked), and `unlocked`. `get_threat_unlocked(chassis_id)`. `load_from(path)` (fresh if missing or unreadable), `save()`, `reset()`, `is_unlocked(id)`, `is_available(kind, target_id, unlocks)` and `get_lock(...)`, `sectors_cleared(run)` (all on a win, else the sectors before the one it ended in, plus every sector of an endless run's finished loops), and `record_run(run, unlocks)`, which counts the run, raises its frame's Threat to one above the run's on a win (Slay-The-Robot unlocked only the level beaten), and returns the unlocks it earned. Its shape follows Slay-The-Robot's `ProfileData`.
- **`TechnicianOffer.gd`:** `roll(options, rng)` returns `PAIRS` (2) upside-and-downside `Boon`s ("Upside, but downside"; downside effects first) then `COMPLETE` (1) whole ones, each list shuffled once and nothing used twice; `apply(boon, run)` returns an `EventResult`. Adapted from Slay-The-Robot's `populate_run_start_options`, which shuffled its downsides twice and its complete options never.
- **`EventPool.gd`:** `next(run)` as in section 1b, with the `fallback` kept aside; `get_queue()`. Adapted from Slay-The-Robot's event pools, whose failure strategies never ran (it didn't record failed events).
- **`EventResult.gd`:** a choice's `text`, `lines`, and `fight_tier` (-1 for none).

### Combat (`res://src/combat/`)
Live fight state, built from a finished grid. It reads the grid, chassis, and parts but never writes to them.
- **`ActivePart.gd` (Extends RefCounted):** one placed part in a fight: the `MechPart` it wraps; the `damage`, `energy_gen`, and `energy_cost` it fights with (its own numbers plus the link bonuses it has on its grid, e.g. a cooled gatling's 12 damage); its `heat` and `cooling` (as links and relics change them), `shield` and `upkeep`; `cooldown_max` (the part's, as links change it); `current_cooldown` (starts at `cooldown_max` and counts down; `get_charge()` is how far it has run, 0 to 1); `is_active`; the `hardpoint` a weapon is mounted in (null on the grid); its `shots` and `damage_dealt` this fight; `neighbors` (the ActiveParts touching it, from the grid's contacts); and `counters` with `count(ability, every)` for counted triggers. The same part placed twice gets two ActiveParts with separate state.
- **`BattleMech.gd` (Extends RefCounted):** `BattleMech.new(grid, rules := [], hp_scale := 1.0, start_health := -1, relics := [])`, called `mech_name` in the fight (its chassis's name unless set; an enemy's is its own). Pass the run's rules so link bonuses count, exactly as in the shop's stats panel: `max_hp` is the chassis's base HP plus every part's HP and HP bonuses (the shop's Hull HP), times `hp_scale` (for enemies up the map, which scales their shield too), and each ActivePart gets its linked damage and energy. Holds its `chassis` (for the passive), `current_health` (full, or `start_health` when given: the player's hull as the last fight left it), `current_energy` (starts at 0), `base_energy` (the chassis's, added each turn), `max_shield` and `shield` (its parts' shield, full at the start), `heat` (0 to `MAX_HEAT`, 100; `add_heat` clamps it; `get_fire_rate()` is 1 up to `throttle_heat`, `THROTTLE_HEAT` (50) unless a regulator raised it, falling evenly to `MIN_FIRE_RATE`, 0.5, at full heat), `shutdown_left` (seconds left in a Meltdown shutdown; `is_shut_down()`), `passive_state` (what the chassis passive keeps for the fight, e.g. whether Overclock is spent), `damage_dealt` (weapon hits and meltdowns, after the enemy's plating), and one `ActivePart` per placed part, mounted weapons included. `take_hit(hit)` sends a `HitPipeline.Hit` through the pipeline below (the passive's interceptors, like Thick Plating on a Bastion, then the relics, then any statuses), off the `shield` first and then `current_health`, stopping at 0, and returns the damage taken, shield and hull together (`last_taken`, and `last_absorbed` for the shield's share); `take_damage(amount, kind, attacker)` makes the hit; `get_damage_taken(amount)` answers the same as a preview, without taking the hit. `get_interceptors(side)` is the mech's part of a hit's pipeline. Statuses: `statuses` (one of each at most), `add_status(status, charges, secondary)`, `get_status(id)`, `get_status_charges(id)`, `tick_statuses(delta)` (dropping worn-off ones), and `status_overflowed(status, times)`. `is_starved(active)`: a working weapon that's ready but can't pay (never on a shut-down mech). `get_top_weapon()`: the weapon that has done the most damage, the first placed on a tie, or null. `start_fight()` runs the passive's, the part abilities', and then the relics' fight-start hooks, `end_fight(won)` their fight-end hooks (the engine calls it for both mechs as the fight ends), and `get_shot_damage(weapon)` the relics' shot hooks; a relic that acts emits `relic_triggered(relic)`. `get_abilities()` is the working parts whose abilities act (one of each kind that doesn't stack); `announce(active)` emits `part_triggered(active)` the first time a part's ability acts in a fight. `get_upkeep()`, `collapse_shield()`, `get_storm_lead()`, and `take_storm_strike(damage)` (through the abilities, then `take_damage`).
- **`HitPipeline.gd` and `HitInterceptor.gd`:** every hit (a `Hit`: its `kind`, SHOT, MELTDOWN, STORM, REFLECT, or OTHER; `attacker`, `weapon`, `target`, and `damage`) goes through the attacker's interceptors, then the target's, each side highest `priority` first (ties in the order the mech lists them). Each interceptor sees only its `kinds` (all when empty) and answers CONTINUE, STOPPED (skip the rest of that side), or REJECTED (the hit doesn't land). Then the shield takes what it can, unless the hit pierces it (`pierce_shield`), and the hull the rest; `outgoing` is the damage after the attacker's side, `blocked` what the target's side took off, `absorbed` the shield's share. A `preview` hit only works out the number. The mech's interceptors: relics' `modify_shot_damage` (attacker side, shots only, 10000), Thick Plating (target side, 9000, skipped by `pierce_plating`), relics' `modify_damage_taken` (8000), and statuses that change hits (their own priority). Reflected damage is a REFLECT hit, which armor doesn't answer, so reflections can't bounce back and forth. Adapted from Slay-The-Robot's action interceptors.
- **`MechStatus.gd` (data, `res://src/data/`) and `ActiveStatus.gd` (live):** a status a mech carries for part of a fight, like Burn: `id`, `status_name`, `description`, `type` (BUFF, DEBUFF, NEUTRAL), and a placeholder `glyph` and `color`. Charges stay within `lower_bound`..`upper_bound`; an `overflows` status that reaches its top wraps back by the width of its bounds and runs `on_overflow` once per wrap. Secondary charges (e.g. intensity) combine by `secondary_combine` (ADD, KEEP, MIN, MAX; the first ones are taken as they are). Every `decay_interval` seconds (0 for never) it decays by `decay` (LINEAR by `decay_amount`, ZERO_OUT, HALF_UP, HALF_DOWN); at 0 charges it's gone. Hooks for subclasses: `on_tick`, `on_overflow`, and `intercept` (with `intercepts_hits()`, `side`, `priority`, `kinds`). Statuses tick first each tick, before energy. Adapted from Slay-The-Robot's status effects, re-timed from turn phases to seconds.
- **`CombatEngine.gd` (Extends RefCounted):** `CombatEngine.new(left, right)` runs a fight between two BattleMechs. `state` goes `PRE_GAME` → `RUNNING` (on `start()`, which also starts each mech's relics) → `FINISHED`, and `process_tick(delta)` does nothing unless the fight is `RUNNING`. `elapsed` counts the seconds fought. A turn is `TURN_SECONDS` (1 second): the shop counts energy per turn, and in a fight each chassis's `base_energy` flows in over every turn, a tick's share at a time, so the shop's energy numbers are what a fight does. A mech shut down by a meltdown sits out every phase below until its `shutdown_left` runs out, which is counted down first each tick; it acts again on the tick that happens. Each running tick then has four phases:
  1. **Energy and cooldowns**: each chassis adds `delta`'s share of a turn's energy and its working heatsinks vent their share of a turn's cooling. Energy and heat are whole numbers, so the fractions carry to the next tick: 3 energy a turn arrives as +1 at 0.4, 0.7, and 1.0 seconds. Then each working part, left mech then right: its cooldown drops by `delta` (times its mech's `get_weapon_speed()`, for a weapon: the fire rate from heat, as statuses like Jammed change it), clamped at 0. A time within `TIME_EPSILON` (1e-6) of its mark counts as reached, so float error doesn't delay anything by a tick. When any other part's cooldown runs out (a generator, or armor that makes energy), its ActivePart's `energy_gen` goes to its mech's `current_energy`, its `heat` to its mech, and the cooldown resets to the ActivePart's `cooldown_max` (the part's, as links change it).
  Then each running mech pays its tick's share of its parts' `upkeep` (fractions carried); one that can't pay loses its shield for the fight (`shield_collapsed(mech)`).
  2. **Weapons**, left mech then right: a weapon whose cooldown has run out fires at the other mech if its own mech has at least `energy_cost` energy. The mech pays the cost, the cooldown resets, the shot adds the weapon's heat to its mech (as its ability changes it; the autocannon's grows with `streak`, its shots in a row, which a wait for energy or a shutdown resets), the target calls `take_damage(damage)` with the shot's damage (the ActivePart's linked damage as the attacker's relics change it, kept as `last_shot`), the shot counts toward the weapon's and its mech's tallies, and the engine emits `weapon_fired(attacker, weapon, target, damage taken)`. Then each of the target's abilities may deal damage back (Reactive Armor), through the attacker's `take_damage`, emitting `reflected(source, target, damage)`. A weapon that can't pay stays ready and fires on the first tick its mech can. Weapons can spend energy generated earlier in the same tick. On a Striker, the fight's first shot fires twice (Overclock), the second for free.
  3. **Meltdowns**, left mech then right: a Reactor at full heat deals `meltdown_damage` to the other mech, cools to 0, shuts down for `meltdown_shutdown` seconds, and the engine emits `meltdown(mech, target, damage taken)`.
  4. **The electrical storm**, the sudden death that ends stalemates (`get_storm_countdown()` is the seconds until it starts): from `get_storm_start()` (`storm_start`, default 20, less the larger `get_storm_lead()` of the two mechs, e.g. a Lightning Rod's 6) it strikes both mechs for the same damage on its first tick and every `storm_interval` ticks (2) after. Strike `n` (from 0) deals `round(storm_damage × storm_growth^n)`: by default 1 × 1.25^n, so 1, 1, 2, 2, 2, 3, 4, 5, 6, 7, 9, 12... Each mech takes it through `take_storm_strike` (a Lightning Rod halves it and adds energy). Each strike emits `storm_struck(damage)`, before plating.

  Then each mech's unused AUTO field kits whose condition is met fire (`kit_used(mech, kit)`), so a revive catches a mech that just went down; `use_kit(mech, index)` uses a MANUAL one between ticks (paying its `energy_cost`, never while shut down, and ending the fight at once if it finishes the enemy), and FIGHT_START ones act in `start()`. Then each mech's boss phases that are due come in (`phase_changed(mech, phase)`); a revive brings a boss that just went down back up before the end is checked. Relics tick with the statuses at the start of each tick (`on_tick`), see every hit that lands on their mech (`on_hit_taken`), and every shot of theirs that lands (`on_hit_dealt`).

  Switched-off parts (`is_active` false) don't tick, fire, or vent, and parts with no `cooldown_max` never activate.

  A tick's damage lands together, so a mech that goes down still fires back that tick. After all four phases, if either mech's health is at 0, the fight is `FINISHED` and the engine emits `battle_ended(winner)` once: the mech still standing, or `null` if both went down in the same tick (a draw). Which side a mech is on never decides the winner.

## 3. UI Architecture (The "View")
The UI is strictly visual. It asks `RunState` what an action would do (`preview_buy` / `preview_move`) and calls it to act, but it does NOT calculate fits, costs, or stats itself. Every screen redraws from `RunState.changed`.

### `LoadoutScreen.tscn` (Extends Control)
Where the player works on the mech: the **Loadout** from the map, and the **Scrap Shop** while the run has a shop open. It works on the `run` it's given, or, when it has none (tests, running the scene alone), starts its own run on its chassis, catalog, and rules (loaded from `res://resources/` when not set) with a shop open.
- Header: "Sector 1 · Floor 4" ("Run" for a run without sectors), "Loadout" or "Scrap Shop", the hull and fights won ("Hull: 420 / 500 HP · 3 won"), gold, and **Back to map** or **Leave shop**, either emitting `leave_requested`.
- Side column: the parts shop (only at a shop: the part slots in a row and the relic offers under them, each with its icon, name, effect, and a **Buy · 20g** button; `buy_relic(index)`), and under it the `StashPanel`.
- Chassis column: name, "Wide frame · 5 / 12 slots · 1 / 1 hardpoints", the `MechGridUI`, and the frame's passive under it ("Thick Plating: Reduces all incoming flat damage by 1.").
- Parts shop: 4 `ShopItem` slots in a row (a bought slot shows "Sold · Reroll to restock"), **Reroll**. Each slot has a rotate button when the part can turn (never a weapon). Unaffordable parts can still be dragged; the grid explains why they can't drop.
- Sell zone: at a shop, while a part from the mech or the stash is dragged, the shop panel becomes a drop target showing its sell value and why ("Full refund: bought at this shop", "Full refund: a scrapper drone is installed", or "Half value: bought earlier"), or "Can't be sold".
- `StashPanel` (built in code): "Stash · 2 parts", a hint, and a `StashItem` per part (its shape, name, size, a rotate button when it turns) wrapping into rows. A stash item drags onto the mech to install, and takes a copy of itself dropped on it (from the stash or the mech) to merge, passing any other drop to the stash; an installed part dropped on the panel is stored (`unequip`), and at a shop, a shop part dropped on it is bought into the stash.
- `StatsPanel`: hull HP (noting the chassis's share and any shield, e.g. "450 from chassis · +200 shield"), energy per turn, damage per turn, and heat per turn (net of cooling, red while heat outruns it, "27 made · 15 vented"), each with a delta while a drop is previewed (for heat, a rise shows red); active links (each rule's pair and count; its effect is beside the same color in the legend); the adjacency rules legend. Both lists are `LIST_HEIGHT` (100 px) tall and scroll, so more rules or links never push the Loadout past the window.
- Toasts for results that happen off the grid (sold, rerolled, not enough gold).

### `MechGridUI.tscn` (Extends Control)
- Draws the chassis from its size, disabled cells, and locked cells (dim, with a padlock; while there are cells to open, the frontier glows, a click opens one with `open_at(cell)`, and the tooltip says so), its hardpoint bays around it (their own color, with a weapon-red border), and each placed part as a colored block with a rotate button in its top-right corner. The layout starts at `get_layout_rect()`'s top-left, so bays left of or above the frame fit; `cell_at` and `cell_center` convert between cells and positions. Parts carry no text: hovering one pops up its `PartInfo` (name, type and size, numbers with links applied, link bonuses, blurb) as the grid's tooltip, and an empty bay's tooltip says what it mounts ("Left Arm hardpoint / Mounts a 1×3 weapon").
- A weapon dragged over any cell of a bay snaps into that bay. While a weapon is dragged, the bays it could drop into (`show_open_bays`) get a green border.
- Drag and drop through Godot's `_get_drag_data`, `_can_drop_data`, and `_drop_data`. The payload (`PartDragData`) says where the part came from (a shop slot, a stash entry, or a placed cell: `is_from_shop`, `is_from_stash`, `is_from_grid`), its rotation, and which cell was grabbed.
- While a drag hovers: the footprint in green or red, the reason it can't drop, open edges around it, and link markers for the links it would make. Hovering a placed part shows its open edges; a part that was just placed or moved shows them briefly.
- Dragging a placed part moves it on the grid, stores it when dropped on the stash, or sells it when dropped on the shop. A stashed part dropped on the grid installs, for free ("Install").
- A part dragged over a copy of itself at the same Mk (where it wouldn't otherwise fit) merges into it instead: "Merge → Mk II" (with the price from the shop), the merged part's cells in green, and "Merged into ... Mk II" once dropped. A part's Mk above I shows as a numeral in its top-left cell.

### `CombatScreen.tscn` (Extends Control)
Plays a fight in real time on the arena stage, after the Claude Design combat mockup. With field kits, a `KitBar` along the bottom has a button per kit (a manual one uses itself, if its mech has the energy; auto and fight-start ones show "auto"; a used one greys out), and each kit that acts pops its name over its mech. A looping `TickTimer` (0.1 seconds) calls `CombatEngine.process_tick(TICK)`, refreshes every widget from the engine, and stops once the fight is over (`is_over()`). `setup(left, right, run := null)` sets the two BattleMechs, the player's on the left, and the `RunState` the fight belongs to (for its sector, floor, and fights won); without it, the screen pits a demo build against the dummy on its `chassis`. Each tick still prints `status_line()` ("[ 1.0s] Left HP 47/47 EN 1 HEAT 20 | Right ..."), and `result_line()` at the end, unless `print_ticks` is off.
- **Layout:** the scene's root letterboxes a fixed 1280×820 `Stage` in the window's middle. The stage holds the arena (drawn at 2×), each mech's `FighterView` on its pad, its `WeaponTags` on its outer side, and its `MechGauges` under it. A `Camera2D` with a `PhantomCameraHost` renders the stage; `MainPCam` (a `PhantomCamera2D`, priority 10) frames it, and `KoPCam` waits at priority 0. The HUD is on a `CanvasLayer`, so it never moves with the camera, in a column as wide as the stage: the `RoundBadge` ("SECTOR 1 · FLOOR 5  3W", no floor before the first step, and ELITE or BOSS in red for those fights), an `HpBar` per side (the mech's name, PLAYER or OPPONENT, the bar), and the `StormTimer`. Leaving the tree resets the viewport's canvas transform, so the next screen starts from an unmoved view.
- **Playback:** `PlaybackControls` at the top (pixel-icon buttons that never take focus) and a line under the timer (`get_playback_text()`: PAUSED, FAST FORWARD 2X, or BATTLE OVER). `toggle_pause()`, also on Space, pauses the `TickTimer`. `cycle_speed()` steps through `SPEEDS` (1, 2, 4): ticks come faster and bars glide faster, but each tick still moves the fight `TICK`, so speed never changes a fight. `skip()` plays the rest of the fight at once and brings up the result without the pause. Once the fight is over, all three do nothing and the buttons are off.
- **Motion:** the engine's signals drive the effects, which follow the fight and never change it. Each `weapon_fired` flashes the weapon's tag and sends its `projectile_sprite` (tinted by the shooter's side) from the weapon's muzzle to the target over `FLIGHT_TIME` (0.25 seconds; less at higher speeds), an Overclock double shot staggered. When it lands, the target shakes and flashes (at `LIGHT_HIT` strength unless the weapon hits for `HEAVY_HIT`, 30, or more, which also shakes the camera a little), and its damage pops up in the player's accent over the opponent or pink over the player, with "BLOCK n" under it for what plating stopped and "SHIELD n" (in the shield's cyan) for what the shield soaked up; the number is what reached the hull. Armor dealing damage back pops it over the attacker the same way, and a collapsed shield pops "SHIELD DOWN". A mech gets at most one popup every `POPUP_GAP` (0.15 seconds, real time); hits in between, and hits landing together, add up into it. A relic that acts, or a part's ability the first time it acts, pops its name over its mech in the tag yellow. A meltdown pops "MELTDOWN -100" on its target and shakes the camera hard; each storm strike flashes the stage, hits both mechs, and pops their damage in the storm's blue. On the KO the camera shakes hard and `KoPCam` takes over, zoomed to `KO_ZOOM` (2×, so the view can center on either pad and the pixel art lands on a whole 4×) on the fallen mech (between them on a draw) as close as the view can get while staying inside the stage (`get_ko_focus`), eased over `KO_TIME` (0.5 seconds), while time slows (`Engine.time_scale`) to `KO_SLOW_MO` (30%) for `KO_SLOW_TIME` (1.2 real seconds) and eases back over `KO_RECOVER_TIME` (0.4), so the fall and the punch-in play out; leaving the screen always restores full speed. Camera shakes are two `PhantomCameraNoiseEmitter2D`s on both cameras' noise layer. A skipped fight plays none of this. `Embers` drift up over the arena, and the countdown pulses red in the last 5 seconds.
- **The result:** 2 real seconds after the end, once the KO's slow motion is over (the one-shot `ResultTimer`, which ignores the time scale), the `ResultPanel` comes up on its own layer: `result_title()` (VICTORY, DEFEAT, or DRAW, from the player's side), `record_line()` ("SECTOR 1 · FLOOR 5 · WINS 3", this fight counted if won), and `result_rows()` (battle duration, the player's total damage dealt, and the MVP weapon with its damage, or "—"). Its CONTINUE button emits `finished(winner)`, null for a draw.
- **The dummy** (`DUMMY`, built by `make_dummy(rules)`): a missile pod in the back bay of its own Bastion (`DUMMY_CHASSIS`), cooled by a heatsink touching the bay. It's the demo opponent when the scene runs alone.

### Combat widgets (`res://src/ui/combat/`)
Drawn in code after the mockup, from `CombatColors` (its palette) and `CombatDraw` (the fonts, framed bars, glossy fills, and text with a hard dark outline).
- `FighterView`: a mech's chassis sprite at 2× with each mounted weapon's sprite at its bay's `battle_anchor`, behind the body (shaded) when `battle_behind`. The right side's is mirrored. It bobs smoothly, shakes and flashes on `hit(strength)`, greys out with a blinking "OVERHEAT 2.4s" while shut down, and once destroyed goes dark, topples back 8° away from the fight, and reads DESTROYED; the look goes through the `mech_sprite` shader. `get_muzzle(weapon)` and `get_center()` give where shots leave and land, and `get_rest_center()` its middle standing still.
- `CombatEffects`: the stage's effects layer: `shoot(...)` (a shot in flight that calls back as it lands), `popup(...)` (a `DamagePopup` that swells, rises, and fades), and `flash(color, seconds)` over the whole stage. Everything it makes frees itself.
- `HpBar`: health with a fill that turns red below 30% and a white trail that catches up 0.25 seconds after a hit; `mirrored` for the right side. A shield shows as a cyan band along the top of the bar (`set_shield`) and after the number ("190/220 +80").
- Every bar glides to each new value over its `smoothing` time, which the screen sets to a tick's length, so bars move steadily instead of jumping each tick; a weapon's charge bar drops at once when it fires.
- `MechGauges`: a row of `StatusIcon`s (each status's glyph with its charges; the tooltip names it and what it does) under an EN `GaugeBar` (full at 100; the number shows the real bank) and an HT one with a tick at the mech's throttle line (50, or a regulator's 80) whose fill reddens as heat slows the weapons, and that runs hot, with a pulsing red glow, above 80 heat or while shut down, when it reads OFFLINE.
- `WeaponTags`: a `WeaponTag` per weapon, in placement order: its bay, its name in the side's accent, and a bar filling with its charge, colored by `WeaponTag.state_of(mech, weapon)`: CHARGING (the accent), READY (green), STARVED (blue: ready, but its mech can't pay), or OFFLINE (red).
- `StormTimer`: whole seconds until the storm, pulsing red in the last 5 while the fight runs, then STORM. `RoundBadge`, `PlaybackControls` (with `PixelIconButton`), and `ResultPanel` are above.

### `ChassisSelectScreen.tscn` (Extends Control)
Where a run starts: one card per frame in `options` (every chassis in `res://resources/chassis/` when unset, in section 1's order) with its name, playstyle, a `ChassisPreview` of its slot layout and bays, "HP · EN a turn · slots · hardpoints", and its passive. A card's button calls `choose(chassis)`, which emits `chassis_chosen`. `set_locks(profile, unlocks)` locks frames the profile hasn't earned: "Locked · Clear Sector 1", a dimmed preview, and an off button (`choose` ignores them). With a profile, a footer shows its totals and **Reset progress**, which confirms and then emits `reset_requested`. `set_modifiers(threat_levels, custom_modifiers)` adds a -/+ Threat picker to each open card ("Threat 2", "Win at 2 to unlock 3", and "Threat 2 · <that level's effect> (+1 below)", with every stacked level in its tooltip) and a checkbox per custom mode to the footer. `get_max_threat(chassis)` (the profile's unlocked level, capped at the ladder; every level without a profile), `set_threat(chassis, value)` (clamps the new value, per frame), `get_threat(chassis)` (clamped again on every read, so a changed profile can't leave a level too high), `set_custom(modifier, on)`, `get_custom_modifiers()`, and `get_run_modifiers(chassis)` (the stacked Threat, then the modes). The picker follows Slay-The-Robot's `NewRunMenu`, whose setter clamped the old value.

### `MapScreen.tscn` (Extends Control)
The sector map between stops, for the `run` it's given: the `RunHud` on top, a bar with a hint ("Pick where to start. Each step climbs one floor toward the boss." at a sector's start, then "Pick your next stop.") and the **Loadout** button ("Loadout · 2 in stash"; emits `loadout_requested`), the `MapView` in a vertical scroll, scrolled so the reachable nodes are in the middle, and a legend of node kinds (glyph and name in each kind's color, its blurb as a tooltip). `choose(node)` travels there and emits `node_chosen(node)`; an unreachable node is refused. After a choice the map takes no more clicks.

### `MapView.gd` (Extends Control, `res://src/ui/map/`)
Draws a `MapGraph` in code, bottom floor at the bottom: floors 72 px apart, columns 96, centered, each node nudged by its jitter, and the boss (radius 30) centered on top with its enemy's name above it. Links are dim, the walked path bright, and the links out of the current node lighter. Each node is a dark badge ringed in its kind's color with its glyph (`KINDS`: Battle X, Elite !, Scrap Shop $, Hangar +, Event ?, Sector Boss B); visited nodes are filled lighter, skipped ones below the player dimmed, the current one ringed white, and `reachable` ones pulse. `get_node_position(node)`, `node_at(position)`, and `press(node)` (emits `node_pressed` only for a reachable node; clicks go through it). Hovering a node shows `describe(node)` ("Elite\nA tougher mech with better loot.", the boss by name).

### `RunHud.gd` (Extends HBoxContainer)
The run at a glance, following its `run`: "Threat 3 · Loop 2 · Sector 1 of 3 · Floor 4" (Threat and loop only when there are any; hovering lists the run's modifiers) over the sector's name (a run without sectors shows "Run" and its frame), a `RelicIcon` per relic and status (its glyph on a badge of its color; the tooltip is "Name (Rarity)" and what it does, or "Name (2 fights left)" for a status), "Hull 420 / 500 HP" over a bar that turns red below 30%, and "20 gold".

### `RewardScreen.gd` (Extends Control)
The loot after a won fight, built in code (a dropped field kit gets its own card beside the relics, with **Take** while a slot is free; `take_kit()`): the run's HUD, SALVAGE (ELITE SALVAGE, BOSS SALVAGE), "+11 gold", the relics on offer ("Recovered a relic:" or "Choose a relic:", a card each with its icon, name, rarity, effect, and **Take**; `take_relic(index)`), and a card per drafted part (its name in its rarity's color, "Rare · Weapon · 2×2", its shape, its blurb, and **Take**). `take(index)` stashes it; the others read "Left behind". The button at the bottom reads **Skip the rest** while a part or relic is still on offer, then **Continue**, and emits `finished`.

### `MessageScreen.gd` (Extends Control)
A full-screen message built in code: the run's HUD (when given a run), a title in a color, lines of text, a column of `options` (`add_option(label, hint, action)`), and one button that emits `confirmed`. It serves for SECTOR CLEARED and the run's end, and the two screens below build on it.

### `TechnicianScreen.gd` (Extends MessageScreen)
MECH TECHNICIAN, a line of dialogue, and a button per boon. `choose(index)` applies it once and shows it with its effects' lines; then **Head out** emits `confirmed`.

### `RestScreen.gd` (Extends MessageScreen)
A Hangar stop: HANGAR / REFIT BAY and a button per job in `get_hangar_jobs()` (`job_buttons` by id), its hint built from its effects ("Repair 9 hull (30% of max)."), off when `can_do(job)` says no. `do_job(job)` applies an effects job and shows its lines; an Upgrade job lists "Point-Defense Laser → Mk II" per part, and Back (`show_upgrades()`, `upgrade(part)`). An exclusive job ends the visit (the button reads **Continue**); the others leave the jobs up. **Leave**.

### `HangarJob.gd` (Extends Resource)
One Hangar job: `id`, `order`, `label`, `hint` (empty to build it from the effects' `describe(run)`), `kind` (EFFECTS, or UPGRADE to pick a part), `effects` (the event effects), `requirement`, `cost` in gold, and `cost_type` (EXCLUSIVE ends the visit, INCLUSIVE goes alongside once, REPEATABLE as often as paid for). `describe(run)`, `is_available(run)`. Adapted from Slay-The-Robot's rest actions. New effects and requirements for it: `RepairShareEffect` (`share` of max HP), `ExpandEffect` (`cells`, or `fallback_hp` when the frame is fully open), `DamagedRequirement`, `ExpandableRequirement`.

### `EventScreen.gd` (Extends MessageScreen)
An Event stop: the event's title and text and a button per choice (label over hint; off with "(Needs 30 gold)" when its requirement fails). `choose(index)` shows the outcome and its lines, then the button: **Continue**, or **Fight!** when the `result` starts a fight.

### `Game.tscn` (Extends Node) — the main scene
Plays runs, one screen at a time (`screen`). It loads the parts, rules, sectors (in id order), relics, events, unlocks, `threat_levels` (by level), and `run_modifiers` from `res://resources/`, and the `profile` from `user://profile.json`, unless set (tests set them, and `run_seed`). It opens on the `ChassisSelectScreen`; a chosen frame starts a `RunState` (`start_gold` 20) with the frame select's `get_run_modifiers` and every `is_automatic` modifier, then, once the Technician is unlocked, a `TechnicianScreen` with an offer rolled on the run's "start" stream from `technician_options` (loaded from `res://resources/technician/` unless set), then the `MapScreen`. A chosen node opens what's there:
- **Battle, Elite, Boss:** a `CombatScreen` with the player's mech from the run (`make_player_mech`, at the hull's current HP) on the left and the node's enemy (`make_enemy_mech`) on the right. When it's `finished`, the fight is recorded (`record_fight`). A loss or draw ends the run. A win rolls its loot (`roll_reward`) onto a `RewardScreen`; after it, a boss win shows SECTOR CLEARED ("The Junkyard King is down...", half the hull's damage repaired) and then the next sector's map, or, after the last sector, the run's end; any other win goes back to the map.
- **Scrap Shop:** the run's shop opens (`open_shop`) on a `LoadoutScreen` for the run; Leave shop closes it and goes back to the map.
- **Loadout** (from the map's button): a `LoadoutScreen` for the run with no shop; Back to map returns to the same map.
- **Hangar:** a `RestScreen`; its button goes back to the map.
- **Event:** an `EventScreen` for the node's event. After the choice, the button goes back to the map, or, if the outcome starts a fight, to a fight against one of the sector's enemies of that tier (a stand-in node on the event's floor), with that tier's loot, then back to the map.
- **The run's end:** the run is recorded in the profile (and saved), then MECH DESTROYED or RUN COMPLETE over `end_lines(run)` (the frame, with " · Threat 3" above Threat 0; "Fell in Sector 2 · Floor 7", "Fell in Loop 2 · Sector 1 · Floor 3", or "Cleared all 3 sectors"; "Fights won: 9") and an "Unlocked: ..." line per unlock earned, plus "Unlocked: Threat 4 for The Striker" when the win raised the frame's Threat, and New run, which goes back to a fresh frame select.
Every swap is deferred, so a screen never leaves the tree while it's still emitting.

## 4. Signal Flow & Dependency Direction
- **Rule:** UI nodes can call functions on Data scripts. Data scripts CANNOT call functions on UI nodes.
- **Rule:** Data scripts communicate outward by emitting signals (e.g., `grid_updated`). UI nodes connect to these signals to update visual health, energy, and grid graphics.

## 5. Automated Testing Requirements
Before any UI is built, the following tests MUST be written in GdUnit4 and pass headlessly:
1. `test_part_placement_bounds`: Verify parts fail to place if they hang off the 4x4 edge.
2. `test_disabled_corners`: Verify parts fail to place if any part of their footprint touches the 4 corners.
3. `test_part_overlap`: Verify parts fail to place if they intersect an already placed part.
4. `test_l_shape_placement`: Verify an L-shaped part can be successfully placed in the center of the cross without triggering corner bounds.
