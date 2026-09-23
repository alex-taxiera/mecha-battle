class_name ShopStock
extends RefCounted
## One Scrap Shop visit's offers: [constant SIZE] part slots, each shown turned the way it'll be
## bought, that can be rerolled for gold. [RunState] buys from it while the shop is open.

const SIZE := 4
const REROLL_COST := 1


## One offer. A bought slot stays [member sold] until the shop restocks.
class Slot:
	var part: MechPart
	## Quarter-turns clockwise the part is shown and bought at.
	var rotation := 0
	var sold := false

	func _init(p_part: MechPart) -> void:
		part = p_part


var slots: Array[Slot] = []

var _catalog: Array[MechPart] = []
var _rng: RandomNumberGenerator


## Stocks the shop from [param catalog] with [param rng]. The first stock shows distinct parts
## until the catalog runs out.
func _init(catalog: Array[MechPart], rng: RandomNumberGenerator) -> void:
	_catalog.assign(catalog)
	_rng = rng
	restock(true)


## Returns the unsold slot at [param index], or [code]null[/code].
func get_open_slot(index: int) -> Slot:
	if index < 0 or index >= slots.size() or slots[index].sold:
		return null
	return slots[index]


## Turns the offer in slot [param index] a quarter-turn clockwise. Parts that can't turn
## (weapons, and shapes a turn doesn't change) stay as they are.
func rotate_slot(index: int) -> bool:
	var slot := get_open_slot(index)
	if slot == null or not slot.part.can_rotate():
		return false
	slot.rotation = posmod(slot.rotation + 1, 4)
	return true


## Fills every slot with a random catalog part. With [param distinct], no part repeats until
## the catalog runs out.
func restock(distinct := false) -> void:
	slots.clear()
	if _catalog.is_empty():
		return
	var pool: Array[MechPart] = []
	for i in SIZE:
		if pool.is_empty():
			pool.assign(_catalog)
		var pick := _rng.randi_range(0, pool.size() - 1)
		slots.append(Slot.new(pool[pick]))
		if distinct:
			pool.remove_at(pick)
