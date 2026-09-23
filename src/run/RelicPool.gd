class_name RelicPool
extends RefCounted
## The relics a run can still find: every relic, shuffled once when the run starts, handed out
## without repeats. Rewards pull from the front and shops from the back, so the two don't eat
## into the same end of the order.
## Adapted from Slay-The-Robot (MIT, DesirePathGames): data/prototype/PlayerData.gd
## (initialize_artifact_pool, get_next_artifacts_from_pool) and autoload/Random.gd
## (ARTIFACT_CHEST_RARITY_WEIGHTS, ARTIFACT_MINIBOSS_RARITY_WEIGHTS). See THIRD_PARTY_NOTICES.md.

## Odds of each standard rarity when a relic is rolled, by source.
const CHEST_WEIGHTS := {Relic.Rarity.COMMON: 50, Relic.Rarity.UNCOMMON: 35, Relic.Rarity.RARE: 15}
const ELITE_WEIGHTS := {Relic.Rarity.COMMON: 25, Relic.Rarity.UNCOMMON: 50, Relic.Rarity.RARE: 25}
## The rarities rolled for by weight. The others have their own sources.
const STANDARD: Array[Relic.Rarity] = [Relic.Rarity.COMMON, Relic.Rarity.UNCOMMON, Relic.Rarity.RARE]

var _order: Array[Relic] = []


## Shuffles [param relics] with [param rng] into the run's order.
func _init(relics: Array[Relic], rng: RandomNumberGenerator) -> void:
	_order.assign(relics)
	RunRng.shuffle(rng, _order)


func size() -> int:
	return _order.size()


func has(relic: Relic) -> bool:
	return relic in _order


## Takes up to [param count] relics of [param rarities] out of the pool, in its order (from the
## back with [param from_back]).
func take(count: int, rarities: Array[Relic.Rarity], from_back := false) -> Array[Relic]:
	var taken: Array[Relic] = []
	var order := _order.duplicate()
	if from_back:
		order.reverse()
	for relic: Relic in order:
		if taken.size() >= count:
			break
		if relic.rarity in rarities:
			taken.append(relic)
	for relic in taken:
		_order.erase(relic)
	return taken


## Takes one relic, its rarity rolled with [param rng] from [param weights] (e.g.
## [constant ELITE_WEIGHTS]). If none of that rarity is left, it falls back to the other
## standard rarities, commoner first. Returns [code]null[/code] when none is left at all.
func roll(rng: RandomNumberGenerator, weights: Dictionary) -> Relic:
	var rolled: Variant = RunRng.weighted_pick(rng, weights)
	var tries: Array[Relic.Rarity] = []
	if rolled != null:
		tries.append(rolled)
	for rarity in STANDARD:
		if rarity not in tries:
			tries.append(rarity)
	for rarity in tries:
		var found := take(1, [rarity])
		if not found.is_empty():
			return found[0]
	return null


## Takes [param relic] out of the pool, e.g. when an event gives it.
func remove(relic: Relic) -> void:
	_order.erase(relic)
