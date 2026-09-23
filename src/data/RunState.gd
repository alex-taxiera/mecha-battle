class_name RunState
extends RefCounted
## One run's state: gold, the shop's slots, the mech grid, the round, and the fight record.
## Buying, selling, and moving go through here so gold and the grid can't drift apart.

## How a round's fight went for the player.
enum FightResult { WIN, LOSS, DRAW }

## Emitted after any change to the gold, the shop, the grid, the round, or the record.
signal changed

const SHOP_SIZE := 4
const REROLL_COST := 1


## One shop offer. A bought slot stays [member sold] until the shop restocks.
class ShopSlot:
	var part: MechPart
	## Quarter-turns clockwise the part is shown and bought at.
	var rotation := 0
	var sold := false

	func _init(p_part: MechPart) -> void:
		part = p_part


## What dropping a part at an origin would do, for hover feedback. Nothing is changed.
class Preview:
	var fit: MechGridData.Fit
	var affordable := true
	## The cells the part would cover.
	var cells: Array[Vector2i] = []
	## Empty cells next to those cells, where later parts could link. Empty unless it fits.
	var open_edges: Array[Vector2i] = []
	## The stats with the change made, or [code]null[/code] unless it fits.
	var stats: MechStats


var round_number := 1
## The run's record so far. Nothing ends the run yet when these reach a limit.
var wins := 0
var losses := 0
var draws := 0
var gold: int
## Gold added at the start of each new round.
var round_income: int
var grid: MechGridData
var slots: Array[ShopSlot] = []
## The parts the shop can offer: every non-weapon, and the weapons some hardpoint can mount.
var catalog: Array[MechPart] = []
var rules: Array[SynergyRule] = []

var _rng: RandomNumberGenerator
# Parts bought this round, which still sell back for their full cost.
var _fresh: Array[MechPart] = []


## Starts a run on [param chassis] with [param start_gold], which is also each round's income.
## The first shop shows distinct parts from [param p_catalog], leaving out weapons that no
## hardpoint on the chassis can mount. Pass a seeded [param rng] for repeatable shops.
func _init(chassis: MechChassis, p_catalog: Array[MechPart], p_rules: Array[SynergyRule], start_gold := 10, rng: RandomNumberGenerator = null) -> void:
	grid = MechGridData.new(chassis)
	catalog.assign(p_catalog.filter(func(part: MechPart) -> bool:
		return part.type != MechPart.PartType.WEAPON or chassis.can_mount(part)))
	rules.assign(p_rules)
	gold = start_gold
	round_income = start_gold
	_rng = rng
	if _rng == null:
		_rng = RandomNumberGenerator.new()
		_rng.randomize()
	_restock(true)


func can_afford(part: MechPart) -> bool:
	return part.cost <= gold


## Buys the part in shop slot [param slot_index] and installs it, in the slot's rotation, with
## its top-left at [param origin]. Changes nothing and returns false unless the slot is unsold,
## affordable, and the part fits there.
func buy(slot_index: int, origin: Vector2i) -> bool:
	var slot := _open_slot(slot_index)
	if slot == null or not can_afford(slot.part):
		return false
	# Each purchase is its own instance, so it keeps its own state (e.g. being fresh).
	var part: MechPart = slot.part.duplicate()
	if not grid.place_part(part, origin, slot.rotation):
		return false
	slot.sold = true
	gold -= part.cost
	_fresh.append(part)
	changed.emit()
	return true


## Returns what the part covering [param coords] sells for: its full cost if it was bought
## this round, otherwise half, rounded down. 0 if the cell is empty.
func sell_value(coords: Vector2i) -> int:
	var part := grid.get_part_at(coords)
	if part == null:
		return 0
	return part.cost if part in _fresh else floori(part.cost / 2.0)


## Returns whether the part covering [param coords] was bought this round.
func is_fresh(coords: Vector2i) -> bool:
	var part := grid.get_part_at(coords)
	return part != null and part in _fresh


## Sells the part covering [param coords] and returns the gold it brought in (0 if the cell
## is empty).
func sell(coords: Vector2i) -> int:
	var value := sell_value(coords)
	var part := grid.remove_part(coords)
	if part == null:
		return 0
	gold += value
	_fresh.erase(part)
	changed.emit()
	return value


## Moves the part covering [param coords] so its top-left is at [param new_origin], for free.
func move(coords: Vector2i, new_origin: Vector2i) -> bool:
	if not grid.move_part(coords, new_origin):
		return false
	changed.emit()
	return true


## Turns the part covering [param coords] a quarter-turn clockwise in place, for free.
func rotate_placed(coords: Vector2i) -> bool:
	if not grid.rotate_part(coords):
		return false
	changed.emit()
	return true


## Turns the offer in shop slot [param slot_index] a quarter-turn clockwise. Parts that can't
## turn (weapons, and shapes a turn doesn't change) stay as they are.
func rotate_slot(slot_index: int) -> bool:
	var slot := _open_slot(slot_index)
	if slot == null or not slot.part.can_rotate():
		return false
	slot.rotation = posmod(slot.rotation + 1, 4)
	changed.emit()
	return true


## Pays [constant REROLL_COST] to replace every shop slot with random parts. Returns false
## without gold to pay.
func reroll() -> bool:
	if gold < REROLL_COST:
		return false
	gold -= REROLL_COST
	_restock(false)
	changed.emit()
	return true


## Counts a fight's [param result] in the run's record.
func record_fight(result: FightResult) -> void:
	match result:
		FightResult.WIN:
			wins += 1
		FightResult.LOSS:
			losses += 1
		FightResult.DRAW:
			draws += 1
	changed.emit()


## Starts the next round: adds the round's income, restocks the shop for free, and ends the
## full refund on parts bought this round. Unspent gold carries over.
func end_round() -> void:
	round_number += 1
	gold += round_income
	_fresh.clear()
	_restock(false)
	changed.emit()


## Returns the mech's stats this round: its chassis HP grows each round.
func stats() -> MechStats:
	return MechStats.calculate(grid, rules, round_number)


## Returns what buying shop slot [param slot_index] with its top-left at [param origin] would
## do, without doing it, or [code]null[/code] if the slot is sold or doesn't exist.
func preview_buy(slot_index: int, origin: Vector2i) -> Preview:
	var slot := _open_slot(slot_index)
	if slot == null:
		return null
	var preview := Preview.new()
	preview.affordable = can_afford(slot.part)
	preview.cells = MechGridData.get_footprint(slot.part, origin, slot.rotation)
	preview.fit = grid.check_placement(slot.part, origin, slot.rotation)
	if preview.fit == MechGridData.Fit.OK:
		var hypothetical := grid.copy()
		hypothetical.place_part(slot.part, origin, slot.rotation)
		_fill_preview(preview, hypothetical)
	return preview


## Returns what moving the part covering [param coords] to [param new_origin] would do,
## without doing it, or [code]null[/code] if the cell is empty.
func preview_move(coords: Vector2i, new_origin: Vector2i) -> Preview:
	var placement := grid.get_placement_at(coords)
	if placement == null:
		return null
	var preview := Preview.new()
	preview.cells = MechGridData.get_footprint(placement.part, new_origin, placement.rotation)
	preview.fit = grid.check_move(coords, new_origin)
	if preview.fit == MechGridData.Fit.OK:
		var hypothetical := grid.copy()
		hypothetical.move_part(coords, new_origin)
		_fill_preview(preview, hypothetical)
	return preview


func _fill_preview(preview: Preview, hypothetical: MechGridData) -> void:
	preview.open_edges = hypothetical.get_open_edges(preview.cells)
	preview.stats = MechStats.calculate(hypothetical, rules, round_number)


func _open_slot(slot_index: int) -> ShopSlot:
	if slot_index < 0 or slot_index >= slots.size() or slots[slot_index].sold:
		return null
	return slots[slot_index]


# Fills every slot with a random catalog part. With [param distinct], no part repeats until
# the catalog runs out (the first shop shows one of each).
func _restock(distinct: bool) -> void:
	slots.clear()
	if catalog.is_empty():
		return
	var pool: Array[MechPart] = []
	for i in SHOP_SIZE:
		if pool.is_empty():
			pool.assign(catalog)
		var pick := _rng.randi_range(0, pool.size() - 1)
		slots.append(ShopSlot.new(pool[pick]))
		if distinct:
			pool.remove_at(pick)
