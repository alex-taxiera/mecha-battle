# Mecha Battle

A roguelike mech auto-battler made in Godot 4. Pick a frame, bolt parts onto its grid, and climb three sectors of a branching map in the style of Slay the Spire. Fights play out on their own; winning or losing comes down to how you built the mech.

## How a run works

- **Pick a frame.** The Bastion is a tank with Thick Plating, the Striker a glass cannon with Overclock, and the Reactor a combo engine that melts down at full heat. Each one has its own grid shape, weapon hardpoints, and starter kit.
- **Build on a grid.** Weapons mount on hardpoints around the frame. Inside the frame go generators, heatsinks, and defenses. Parts that touch each other link up for bonuses: a heatsink next to a weapon cools it for ×1.5 damage, and a reactor next to one overcharges it.
- **Climb the map.** Each sector is 12 floors of branching paths, with the sector boss at the top:
  - **Battles and elites:** real-time fights. The electrical storm ends any stalemate.
  - **Scrap Shops:** buy parts and relics, and sell what you don't need.
  - **Hangars:** repair your hull, or reinforce it for good.
  - **Events:** risk-or-reward choices, some of which end in a fight.
- **Keep your damage.** Hull damage carries over from fight to fight. If you're destroyed, the run is over.
- **Loot every fight.** Every win drops gold and a pick of parts for your stash. Elites also drop relics, and bosses offer a choice of boss relics.
- **Collect relics.** Relics bend the rules for the rest of the run, like double damage on each fight's first shot or +20 energy a turn.

## Running it

You need [Godot 4.7.2](https://godotengine.org/download) (the standard build, not .NET). Open `project.godot` in the editor and press Play. The main scene is `src/ui/Game.tscn`.

## Tests

Tests use [GdUnit4](https://github.com/MikeSchulze/gdUnit4). Run them headless from the project root:

```sh
godot --headless --path . --import
godot --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://test -c --ignoreHeadlessMode -rd user://reports
```

The first command only needs to run after adding or moving a `class_name` script. CI runs both on every push to `main` and on pull requests.

## Releasing

Pushing a tag like `v0.1.0` runs `.github/workflows/release.yml`, which:

1. runs the tests
2. exports Web, Windows, and Linux builds
3. uploads them to itch.io with [butler](https://itch.io/docs/butler/)

You can also start it by hand from the Actions tab. For upload, the repository needs:

| Setting | Kind | Value |
|---|---|---|
| `BUTLER_API_KEY` | Secret | An itch.io API key |
| `ITCH_USER` | Variable | Your itch.io username |
| `ITCH_GAME` | Variable | The game's itch.io URL name, e.g. `mecha-battle` |

Until they're set, the workflow still tests and exports (the builds are attached to the run as an artifact), and it skips the upload.

## Project layout

| Path | What's there |
|---|---|
| `src/data/` | Game data classes: parts, chassis, the grid, stats, the run, relics, and events |
| `src/combat/` | The fight engine, independent of the UI |
| `src/run/` | Run logic: map generation, seeded RNG, loot, shops, and the relic and event pools |
| `src/ui/` | Screens and widgets |
| `resources/` | Content as `.tres` files: parts, chassis, adjacency rules, enemies, sectors, relics, and events. Tune it in the inspector. |
| `assets/` | Pixel art, fonts, and shaders |
| `test/` | GdUnit4 suites. They build their own data with `TestFixtures.gd`, so tuning content doesn't break them. |
| `design_doc.md` | The rules and architecture in detail |

## Credits

- Parts of the run code (the seeded RNG streams, map lattice, loot drafts with pity, relic and event pools, and shop relic prices) are adapted from [Slay-The-Robot](https://github.com/DesirePathGames/Slay-The-Robot) by DesirePathGames, under the MIT License. See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
- Addons, each under the MIT License in its own folder:
  - [GdUnit4](https://github.com/MikeSchulze/gdUnit4) by Mike Schulze
  - [Phantom Camera](https://github.com/ramokz/phantom-camera) by Marcus Skov
  - [Godot Git Plugin](https://github.com/godotengine/godot-git-plugin) by the Godot Engine community
- Fonts, each under the SIL Open Font License beside its files in `assets/fonts/`: Silkscreen, Chakra Petch, and JetBrains Mono.
