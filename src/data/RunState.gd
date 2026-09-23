class_name RunState
extends RefCounted
## One run: the mech, its stash of spare parts, gold, the hull's damage, and where the player is
## on the current sector's map. Buying, selling, installing, and moving go through here so gold,
## the grid, and the stash can't drift apart.

## How a fight went for the player.
enum FightResult { WIN, LOSS, DRAW }
## How the run stands: going, won (the last sector's boss is down), or lost (the mech went down).
enum Outcome { ONGOING, VICTORY, DEFEAT }

## Emitted after any change to the gold, the grid, the stash, the hull, the shop, or the map.
signal changed

## The share of the hull's damage repaired on reaching the next sector.
const ACT_HEAL := 0.5


## A spare part in the stash, and the way it's turned for installing.
class StashEntry:
	var part: MechPart
	## Quarter-turns clockwise.
	var rotation := 0

	func _init(p_part: MechPart, p_rotation := 0) -> void:
		part = p_part
		rotation = p_rotation


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


var rng: RunRng
var grid: MechGridData
## Parts the player owns but hasn't installed.
var stash: Array[StashEntry] = []
var gold: int
## Hull points the mech is missing. HP carries over between fights, so this is kept as damage:
## parts that add HP raise the mech's current HP along with its max (see [method get_current_hp]).
var hull_damage := 0
## Every part the run can offer: every non-weapon, and the weapons some hardpoint can mount.
var catalog: Array[MechPart] = []
var rules: Array[SynergyRule] = []
## The run's sectors, in order, and the one the player is in.
var acts: Array[ActData] = []
var act_index := 0
## The current sector's map, or [code]null[/code] for a run without sectors.
var map: MapGraph
## The Scrap Shop the player is at, or [code]null[/code] away from one.
var shop: ShopStock
var fights_won := 0
var outcome := Outcome.ONGOING

# Parts bought at the open shop, which still sell back for their full cost.
var _fresh: Array[MechPart] = []
# The last enemy picked for a fight, so the same one doesn't come twice in a row.
var _last_enemy: EnemyLoadout


## Starts a run on [param chassis], with its starter kit installed, [param start_gold], and the
## first of [param p_acts]' maps. [param p_catalog] is filtered to the parts the chassis can use.
## Pass a [RunRng] with a set seed to repeat a run.
func _init(chassis: MechChassis, p_catalog: Array[MechPart], p_rules: Array[SynergyRule], start_gold := 10,
		p_rng: RunRng = null, p_acts: Array[ActData] = []) -> void:
	grid = MechGridData.new(chassis)
	LoadoutPart.place_all(grid, chassis.starter_lineup)
	catalog.assign(p_catalog.filter(func(part: MechPart) -> bool:
		return part.type != MechPart.PartType.WEAPON or chassis.can_mount(part)))
	rules.assign(p_rules)
	gold = start_gold
	rng = p_rng if p_rng else RunRng.new()
	acts.assign(p_acts)
	if not acts.is_empty():
		_start_act(0)


func is_over() -> bool:
	return outcome != Outcome.ONGOING


## Returns the sector the player is in, or [code]null[/code] for a run without sectors.
func get_act() -> ActData:
	return acts[act_index] if act_index < acts.size() else null


## Returns the floor the player is on, counting from 1, or 0 before they've picked a node.
## The boss is on the floor above the sector's last.
func get_floor_number() -> int:
	return map.current.floor_index + 1 if map and map.current else 0


#region Hull

## Returns the mech's stats as it's built now.
func stats() -> MechStats:
	return MechStats.calculate(grid, rules)


func get_max_hp() -> int:
	return stats().hp


## Returns the hull points the mech has now: its max less [member hull_damage], never below 1
## while the run goes on (a stripped-down mech keeps its damage for when parts go back in), and
## 0 once it's been destroyed.
func get_current_hp() -> int:
	if outcome == Outcome.DEFEAT:
		return 0
	var max_hp := get_max_hp()
	return clampi(max_hp - hull_damage, mini(1, max_hp), max_hp)


## Repairs up to [param amount] of the hull's damage and returns how much it repaired.
func heal(amount: int) -> int:
	var healed := clampi(amount, 0, hull_damage)
	hull_damage -= healed
	changed.emit()
	return healed


## Damages the hull by [param amount] outside a fight, leaving it at least 1 HP.
func damage_hull(amount: int) -> void:
	hull_damage = clampi(hull_damage + maxi(amount, 0), 0, maxi(get_max_hp() - 1, 0))
	changed.emit()

#endregion
#region Fights

## Returns the player's mech for a fight: the build as it is, starting at its current HP.
func make_player_mech() -> BattleMech:
	return BattleMech.new(grid, rules, 1.0, get_current_hp())


## Returns the enemy fought at [param node] (by default the current node): the node's own if it
## has one, otherwise one of the sector's enemies of its tier, picked now and kept on the node.
## Returns [code]null[/code] if the sector has none of that tier.
func get_enemy(node: MapNode = null) -> EnemyLoadout:
	node = node if node else map.current
	if node.enemy == null:
		var pool := get_act().get_enemies(node.get_tier())
		if pool.size() > 1:
			pool.erase(_last_enemy)
		if not pool.is_empty():
			node.enemy = pool[rng.stream("enemies").randi_range(0, pool.size() - 1)]
	_last_enemy = node.enemy
	return node.enemy


## Returns the enemy's mech for the fight at [param node] (by default the current node), named
## for the enemy, its HP scaled for the sector and how far up the map the node is.
func make_enemy_mech(node: MapNode = null) -> BattleMech:
	node = node if node else map.current
	var enemy := get_enemy(node)
	var mech := BattleMech.new(enemy.build_grid(), rules, get_act().get_enemy_hp_scale(node.floor_index) * enemy.hp_scale)
	mech.mech_name = enemy.enemy_name
	return mech


## Records how a fight went, given the player's [param mech] as the fight left it: its damage
## carries over to the hull. Anything but a win destroys the mech and ends the run.
func record_fight(result: FightResult, mech: BattleMech) -> void:
	hull_damage = maxi(0, mech.max_hp - mech.current_health)
	if result == FightResult.WIN:
		fights_won += 1
	else:
		outcome = Outcome.DEFEAT
	changed.emit()

#endregion
#region Map

## Returns the nodes the player can travel to next.
func get_reachable() -> Array[MapNode]:
	var none: Array[MapNode] = []
	return map.get_reachable() if map else none


## Moves the player to [param node]. Returns false, moving nowhere, if it isn't reachable.
func travel(node: MapNode) -> bool:
	if is_over() or map == null or not map.travel(node):
		return false
	changed.emit()
	return true


## Moves on once the sector's boss is down: to the next sector's map, repairing
## [constant ACT_HEAL] of the hull's damage, or, after the last sector, to victory.
func next_act() -> void:
	if act_index + 1 >= acts.size():
		outcome = Outcome.VICTORY
	else:
		act_index += 1
		hull_damage -= ceili(hull_damage * ACT_HEAL)
		_start_act(act_index)
	changed.emit()


func _start_act(index: int) -> void:
	var act := acts[index]
	var generator: MapGenerator = act.generator.new() if act.generator else MapGenerator.new()
	map = generator.generate(act, rng.stream("map"))

#endregion
#region Stash

## Puts a copy of [param part] in the stash, turned [param rotation] quarter-turns.
func stash_part(part: MechPart, rotation := 0) -> void:
	stash.append(StashEntry.new(part.duplicate(), rotation if part.can_rotate() else 0))
	changed.emit()


## Installs stashed part [param index], at its rotation, with its top-left at [param origin].
## Changes nothing and returns false unless it fits there.
func install(index: int, origin: Vector2i) -> bool:
	if index < 0 or index >= stash.size():
		return false
	var entry := stash[index]
	if not grid.place_part(entry.part, origin, entry.rotation):
		return false
	stash.remove_at(index)
	changed.emit()
	return true


## Takes the part covering [param coords] off the mech and into the stash, keeping its turn.
func unequip(coords: Vector2i) -> bool:
	var placement := grid.get_placement_at(coords)
	if placement == null:
		return false
	grid.remove_part(coords)
	stash.append(StashEntry.new(placement.part, placement.rotation))
	changed.emit()
	return true


## Turns stashed part [param index] a quarter-turn clockwise, if it can turn.
func rotate_stashed(index: int) -> bool:
	if index < 0 or index >= stash.size() or not stash[index].part.can_rotate():
		return false
	stash[index].rotation = posmod(stash[index].rotation + 1, 4)
	changed.emit()
	return true


## Returns what installing stashed part [param index] with its top-left at [param origin] would
## do, without doing it, or [code]null[/code] if there's no such part.
func preview_install(index: int, origin: Vector2i) -> Preview:
	if index < 0 or index >= stash.size():
		return null
	var entry := stash[index]
	return _preview_place(entry.part, origin, entry.rotation)

#endregion
#region Shop

## Opens a Scrap Shop, stocked from the catalog.
func open_shop() -> void:
	shop = ShopStock.new(catalog, rng.stream("shop"))
	_fresh.clear()
	changed.emit()


## Leaves the shop. Parts bought there no longer sell back in full.
func close_shop() -> void:
	shop = null
	_fresh.clear()
	changed.emit()


func can_afford(part: MechPart) -> bool:
	return part.cost <= gold


## Buys the part in shop slot [param slot_index] and installs it, in the slot's rotation, with
## its top-left at [param origin]. Changes nothing and returns false unless a shop is open, the
## slot is unsold, the part is affordable, and it fits there.
func buy(slot_index: int, origin: Vector2i) -> bool:
	var slot := shop.get_open_slot(slot_index) if shop else null
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


## Turns the offer in shop slot [param slot_index] a quarter-turn clockwise.
func rotate_slot(slot_index: int) -> bool:
	if shop == null or not shop.rotate_slot(slot_index):
		return false
	changed.emit()
	return true


## Pays [constant ShopStock.REROLL_COST] to restock the open shop. Returns false without a shop
## or the gold to pay.
func reroll() -> bool:
	if shop == null or gold < ShopStock.REROLL_COST:
		return false
	gold -= ShopStock.REROLL_COST
	shop.restock()
	changed.emit()
	return true


## Returns whether parts can be sold: only at a shop.
func can_sell() -> bool:
	return shop != null


## Returns what the part covering [param coords] sells for: its full cost if it was bought at
## this shop, otherwise half, rounded down. 0 if the cell is empty.
func sell_value(coords: Vector2i) -> int:
	var part := grid.get_part_at(coords)
	if part == null:
		return 0
	return part.cost if part in _fresh else floori(part.cost / 2.0)


## Returns whether the part covering [param coords] was bought at this shop.
func is_fresh(coords: Vector2i) -> bool:
	var part := grid.get_part_at(coords)
	return part != null and part in _fresh


## Sells the part covering [param coords] and returns the gold it brought in: 0, selling
## nothing, if the cell is empty or there's no shop.
func sell(coords: Vector2i) -> int:
	if not can_sell():
		return 0
	var value := sell_value(coords)
	var part := grid.remove_part(coords)
	if part == null:
		return 0
	gold += value
	_fresh.erase(part)
	changed.emit()
	return value


## Returns what buying shop slot [param slot_index] with its top-left at [param origin] would
## do, without doing it, or [code]null[/code] if there's no shop or the slot is sold.
func preview_buy(slot_index: int, origin: Vector2i) -> Preview:
	var slot := shop.get_open_slot(slot_index) if shop else null
	if slot == null:
		return null
	var preview := _preview_place(slot.part, origin, slot.rotation)
	preview.affordable = can_afford(slot.part)
	return preview

#endregion
#region Grid

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


func _preview_place(part: MechPart, origin: Vector2i, rotation: int) -> Preview:
	var preview := Preview.new()
	preview.cells = MechGridData.get_footprint(part, origin, rotation)
	preview.fit = grid.check_placement(part, origin, rotation)
	if preview.fit == MechGridData.Fit.OK:
		var hypothetical := grid.copy()
		hypothetical.place_part(part, origin, rotation)
		_fill_preview(preview, hypothetical)
	return preview


func _fill_preview(preview: Preview, hypothetical: MechGridData) -> void:
	preview.open_edges = hypothetical.get_open_edges(preview.cells)
	preview.stats = MechStats.calculate(hypothetical, rules)

#endregion
