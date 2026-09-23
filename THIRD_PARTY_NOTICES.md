# Third-party notices

Vendored addons under `addons/` carry their own licenses in their folders.

## Slay-The-Robot

Parts of the run code are adapted from [Slay-The-Robot](https://github.com/DesirePathGames/Slay-The-Robot) by DesirePathGames. Each adapted file names its source in a header comment:

- `src/run/RunRng.gd`: `data/prototype/PlayerData.gd` (`get_player_rng`) and `autoload/Random.gd` (`shuffle_array`, `shuffle_slice_array`, `get_weighted_selection`)
- `src/run/MapGenerator.gd`: `scripts/actions/world_generation_actions/ActionGenerateAct.gd` (the floor lattice and boss hookup)

```
MIT License

Copyright (c) 2025 DesirePathGames

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```
