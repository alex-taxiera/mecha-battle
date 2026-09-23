class_name ShopStock
extends RefCounted
## One Scrap Shop visit's offers: [constant SIZE] part slots, each shown turned the way it'll be
## bought, that can be rerolled for gold, and a few relics. Parts are drafted with the shop's
## rarity odds (see [RewardRoller]) and sell at their [member MechPart.cost]; relics are priced
## by rarity. [RunState] buys from it while the shop is open.
## The relic price ranges are adapted from Slay-The-Robot (MIT, DesirePathGames): ShopData's
## ARTIFACT_RARITY_TO_PRICE_RANGE, scaled by a quarter to this game's gold (its fights drop 25-50,
## these 8-12), and Random.get_shop_artifact_prices. See THIRD_PARTY_NOTICES.md.

const SIZE := 4
const REROLL_COST := 1
## Each relic rarity's price, from x to y.
const RELIC_PRICES := {
	Relic.Rarity.COMMON: Vector2i(12, 20),
	Relic.Rarity.UNCOMMON: Vector2i(21, 29),
	Relic.Rarity.RARE: Vector2i(30, 35),
	Relic.Rarity.SHOP: Vector2i(37, 50),
}


## One part offer. A bought slot stays [member sold] until the shop restocks.
class Slot:
	var part: MechPart
	## Quarter-turns clockwise the part is shown and bought at.
	var rotation := 0
	var sold := false

	func _init(p_part: MechPart) -> void:
		part = p_part


## One relic offer.
class RelicOffer:
	var relic: Relic
	var price := 0
	var sold := false

	func _init(p_relic: Relic, p_price: int) -> void:
		relic = p_relic
		price = p_price


var slots: Array[Slot] = []
var relic_offers: Array[RelicOffer] = []

var _catalog: Array[MechPart] = []
var _rng: RandomNumberGenerator


## Stocks the shop from [param catalog] with [param rng], and puts [param relics] up for sale at
## their rarity's price.
func _init(catalog: Array[MechPart], rng: RandomNumberGenerator, relics: Array[Relic] = []) -> void:
	_catalog.assign(catalog)
	_rng = rng
	restock()
	for relic in relics:
		var prices: Vector2i = RELIC_PRICES.get(relic.rarity, RELIC_PRICES[Relic.Rarity.RARE])
		relic_offers.append(RelicOffer.new(relic, _rng.randi_range(prices.x, prices.y)))


## Returns the unsold slot at [param index], or [code]null[/code].
func get_open_slot(index: int) -> Slot:
	if index < 0 or index >= slots.size() or slots[index].sold:
		return null
	return slots[index]


## Returns the unsold relic offer at [param index], or [code]null[/code].
func get_open_relic(index: int) -> RelicOffer:
	if index < 0 or index >= relic_offers.size() or relic_offers[index].sold:
		return null
	return relic_offers[index]


## Turns the offer in slot [param index] a quarter-turn clockwise. Parts that can't turn
## (weapons, and shapes a turn doesn't change) stay as they are.
func rotate_slot(index: int) -> bool:
	var slot := get_open_slot(index)
	if slot == null or not slot.part.can_rotate():
		return false
	slot.rotation = posmod(slot.rotation + 1, 4)
	return true


## Fills the part slots with different catalog parts, each slot's rarity rolled with the shop's
## odds. The relics stay.
func restock() -> void:
	slots.clear()
	# A roller of its own: the shop's draws don't move the run's loot pity.
	for part in RewardRoller.new().draft_parts(_rng, _catalog, RewardRoller.Table.SHOP, SIZE):
		slots.append(Slot.new(part))
