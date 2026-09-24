# Third-party notices

Vendored addons under `addons/` carry their own licenses in their folders.

## Slay-The-Robot

Parts of the run code are adapted from [Slay-The-Robot](https://github.com/DesirePathGames/Slay-The-Robot) by DesirePathGames. Each adapted file names its source in a header comment:

- `src/run/RunRng.gd`: `data/prototype/PlayerData.gd` (`get_player_rng`) and `autoload/Random.gd` (`shuffle_array`, `shuffle_slice_array`, `get_weighted_selection`)
- `src/run/MapGenerator.gd`: `scripts/actions/world_generation_actions/ActionGenerateAct.gd` (the floor lattice and boss hookup)
- `src/run/Profile.gd`: the shape of `data/mutable/ProfileData.gd` (run totals and per-character records, saved as JSON)
- `src/run/RelicPool.gd`: `data/prototype/PlayerData.gd` (`initialize_artifact_pool`, `get_next_artifacts_from_pool`) and `autoload/Random.gd` (`ARTIFACT_CHEST_RARITY_WEIGHTS`, `ARTIFACT_MINIBOSS_RARITY_WEIGHTS`)
- `src/run/EventPool.gd`: `data/prototype/PlayerData.gd` (`get_next_event_object_id_from_pool`) and `EventPoolData`
- `src/run/ShopStock.gd`: the relic price ranges from `data/mutable/ShopData.gd` (`ARTIFACT_RARITY_TO_PRICE_RANGE`) and `autoload/Random.gd` (`get_shop_artifact_prices`)
- `src/run/RewardRoller.gd`: `autoload/Random.gd` (`generate_rarity_weighted_card_draft`, `CARD_DRAFT_RARITY_WEIGHTS`) and the rare-card modifier in `data/prototype/PlayerData.gd`

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
