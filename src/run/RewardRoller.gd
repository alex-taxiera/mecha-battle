class_name RewardRoller
extends RefCounted
## Rolls loot: which parts a draft offers, by rarity, with a pity counter that makes a rare part
## likelier each time a common one comes up instead. The run keeps one, so the pity carries over.
## Adapted from Slay-The-Robot (MIT, DesirePathGames): autoload/Random.gd
## (generate_rarity_weighted_card_draft, CARD_DRAFT_RARITY_WEIGHTS) and the rare-card modifier
## in data/prototype/PlayerData.gd. See THIRD_PARTY_NOTICES.md.

## Which odds a draft uses.
enum Table { STANDARD, ELITE, BOSS, SHOP }

## Each table's weights for common, uncommon, and rare, from Slay-The-Robot's draft tables.
const RARITY_WEIGHTS := {
	Table.STANDARD: {MechPart.Rarity.COMMON: 55, MechPart.Rarity.UNCOMMON: 43, MechPart.Rarity.RARE: 2},
	Table.ELITE: {MechPart.Rarity.COMMON: 50, MechPart.Rarity.UNCOMMON: 40, MechPart.Rarity.RARE: 10},
	Table.BOSS: {MechPart.Rarity.COMMON: 0, MechPart.Rarity.UNCOMMON: 0, MechPart.Rarity.RARE: 100},
	Table.SHOP: {MechPart.Rarity.COMMON: 55, MechPart.Rarity.UNCOMMON: 40, MechPart.Rarity.RARE: 5},
}
## How much the pity grows each time a common part is offered. Its whole part moves that much
## weight from common to rare.
const PITY_STEP := 1.5
## Parts in a fight's draft.
const DRAFT_SIZE := 3

## Weight moved from common to rare in every draft until a rare part comes up.
var rare_pity := 0.0


## Returns the draft table for a fight against an enemy of [param tier].
static func table_for(tier: EnemyLoadout.Tier) -> Table:
	match tier:
		EnemyLoadout.Tier.ELITE:
			return Table.ELITE
		EnemyLoadout.Tier.BOSS:
			return Table.BOSS
	return Table.STANDARD


## Returns up to [param count] different parts from [param catalog], each slot's rarity rolled
## from [param table]'s odds with the pity applied. When no part of the rolled rarity is left,
## the slot falls back to the nearest rarity that has one (lower first), so a small catalog still
## fills the draft. A common part raises the pity; a rare one resets it.
func draft_parts(rng: RandomNumberGenerator, catalog: Array[MechPart], table: Table, count := DRAFT_SIZE) -> Array[MechPart]:
	var weights: Dictionary = RARITY_WEIGHTS[table].duplicate()
	var bonus := mini(floori(rare_pity), weights[MechPart.Rarity.COMMON])
	weights[MechPart.Rarity.RARE] += bonus
	weights[MechPart.Rarity.COMMON] -= bonus
	# One shuffled bucket per rarity, each part once, so a draft never repeats a part.
	var buckets := {}
	for rarity: int in MechPart.Rarity.values():
		buckets[rarity] = []
	for part in catalog:
		if part not in buckets[part.rarity]:
			buckets[part.rarity].append(part)
	for rarity: int in buckets:
		RunRng.shuffle(rng, buckets[rarity])
	var drafted: Array[MechPart] = []
	for i in count:
		var rolled: int = RunRng.weighted_pick(rng, weights)
		var rarity := _nearest_stocked(buckets, rolled)
		if rarity < 0:
			break
		drafted.append(buckets[rarity].pop_back())
		if rarity == MechPart.Rarity.RARE:
			# Slay-The-Robot never lowers its modifier again; like Slay the Spire, it resets here.
			rare_pity = 0.0
		elif rarity == MechPart.Rarity.COMMON:
			rare_pity += PITY_STEP
	return drafted


## Returns a gold amount from [param gold_range] (x to y, inclusive).
static func roll_gold(rng: RandomNumberGenerator, gold_range: Vector2i) -> int:
	return rng.randi_range(gold_range.x, maxi(gold_range.x, gold_range.y))


# The rarity nearest [param rolled] that still has parts, trying lower rarities first; -1 when
# every bucket is empty.
static func _nearest_stocked(buckets: Dictionary, rolled: int) -> int:
	for distance in MechPart.Rarity.size():
		for rarity in [rolled - distance, rolled + distance]:
			if buckets.has(rarity) and not buckets[rarity].is_empty():
				return rarity
	return -1
