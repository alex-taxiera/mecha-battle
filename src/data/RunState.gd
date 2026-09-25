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
## Boss relics a boss offers to choose from.
const BOSS_RELIC_CHOICES := 3
## Relics a Scrap Shop puts up for sale.
const SHOP_RELICS := 2
## Field kits the run can carry at once.
const KIT_SLOTS := 3
## Kits a Scrap Shop puts up for sale.
const SHOP_KITS := 2
## The chance a won fight drops a field kit, by tier.
const KIT_DROP_CHANCES := {
	EnemyLoadout.Tier.NORMAL: 0.15,
	EnemyLoadout.Tier.ELITE: 0.35,
	EnemyLoadout.Tier.BOSS: 0.0,
}
## What an Unknown node turns into, by weight (Slay the Spire's "?" odds, roughly).
const UNKNOWN_ODDS := {
	MapNode.Type.EVENT: 50,
	MapNode.Type.BATTLE: 25,
	MapNode.Type.CACHE: 15,
	MapNode.Type.SHOP: 10,
}
## Weapon mods a Scrap Shop puts up for sale, and their price range before Threat.
const SHOP_MODS := 1
const MOD_PRICES := Vector2i(12, 18)
## Cells a boss offers to open, in place of a boss relic.
const BOSS_CELLS := 2
## An endless run's enemies get this much more HP each loop.
const ENDLESS_HP_PER_LOOP := 0.5
## A Hangar never repairs less than this share, however Threat cuts it.
const MIN_REPAIR_SHARE := 0.05
## Each affix on an elite adds this share to its gold.
const AFFIX_GOLD_BONUS := 0.2


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
	## Whether the drop merges into the part already there instead of placing.
	var merge := false
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
## Rolls the run's loot, keeping its rare-part pity between fights.
var loot := RewardRoller.new()
## The relics the run has found, in the order it found them. They're the run's own copies.
var relics: Array[Relic] = []
## The relics still to be found.
var relic_pool: RelicPool
## Lasting changes that aren't relics, e.g. max HP from a Hangar's Reinforce. They work like
## relics but don't show as ones.
var upgrades: Array[Relic] = []
## Effects from events that last a few fights (see [TimedStatus]).
var statuses: Array[TimedStatus] = []
## The events the run can still come across.
var event_pool: EventPool
## Cells the player can still open on the frame (see [method open_cell]), from Hangars, events,
## and bosses.
var cells_to_open := 0
## The Hangar's own jobs; relics can add more (see [method get_hangar_jobs]).
var hangar_jobs: Array[HangarJob] = []
## The weapon mods shops, elites, and a Hangar's Refit can offer.
var mod_pool: Array[WeaponMod] = []
## Story flags events set and check (see [SetFlagEffect], [FlagRequirement]), so one event can
## follow up on another.
var flags: Dictionary[String, int] = {}
## The field kits the run carries, up to [constant KIT_SLOTS], and those it can find or buy.
var kits: Array[FieldKit] = []
var kit_pool: Array[FieldKit] = []
## The run's modifiers: its Threat levels (1 up to the chosen one) and any custom modes (see
## [RunModifier]). Their numbers stack: scales multiply, the rest add.
var run_modifiers: Array[RunModifier] = []
## Times an endless run has started the sectors over.
var loops := 0
## The affixes elites can roll, and how many each one gets.
var affix_pool: Array[Relic] = []
var elite_affixes := 1

# News for the next loot screen, e.g. a crate that opened.
var _notes: PackedStringArray = []
# Parts bought at the open shop, which still sell back for their full cost.
var _fresh: Array[MechPart] = []
# The last enemy picked for a fight, so the same one doesn't come twice in a row.
var _last_enemy: EnemyLoadout


## Starts a run on [param chassis], with its starter kit installed, [param start_gold], and the
## first of [param p_acts]' maps. [param p_catalog] is filtered to the parts the chassis can use;
## [param p_relics] are the relics it can find and [param p_events] the events it can come
## across. [param p_affixes] are the affixes elites can roll, and [param p_modifiers] the run's
## Threat levels and custom modes. Pass a [RunRng] with a set seed to repeat a run.
func _init(chassis: MechChassis, p_catalog: Array[MechPart], p_rules: Array[SynergyRule], start_gold := 10,
		p_rng: RunRng = null, p_acts: Array[ActData] = [], p_relics: Array[Relic] = [],
		p_events: Array[GameEvent] = [], p_affixes: Array[Relic] = [], p_modifiers: Array[RunModifier] = []) -> void:
	# The run grows its own copy of the frame; the shared chassis never changes.
	var frame: MechChassis = chassis.duplicate()
	frame.opened_cells = chassis.opened_cells.duplicate()
	grid = MechGridData.new(frame)
	LoadoutPart.place_all(grid, chassis.starter_lineup)
	catalog.assign(p_catalog.filter(func(part: MechPart) -> bool:
		return part.type != MechPart.PartType.WEAPON or chassis.can_mount(part)))
	rules.assign(p_rules)
	gold = start_gold
	rng = p_rng if p_rng else RunRng.new()
	# Relics made for one chassis only turn up in its runs.
	var relics_here: Array[Relic] = []
	relics_here.assign(p_relics.filter(func(relic: Relic) -> bool:
		return relic.chassis_id.is_empty() or relic.chassis_id == chassis.id))
	relic_pool = RelicPool.new(relics_here, rng.stream("relics"))
	event_pool = EventPool.new(p_events, rng.stream("events"))
	affix_pool.assign(p_affixes)
	run_modifiers.assign(p_modifiers)
	acts.assign(p_acts)
	if not acts.is_empty():
		_start_act(0)
	_start_modifiers()


## Returns the run's Threat: its highest Threat level, or 0.
func get_threat() -> int:
	var threat := 0
	for modifier in run_modifiers:
		threat = maxi(threat, modifier.threat_level)
	return threat


## Returns the run's modifiers' [param field] multiplied together (1 without any).
func get_mod_product(field: StringName) -> float:
	var product := 1.0
	for modifier in run_modifiers:
		product *= modifier.get(field)
	return product


## Returns the run's modifiers' [param field] added up (0 without any).
func get_mod_sum(field: StringName) -> float:
	var total := 0.0
	for modifier in run_modifiers:
		total += modifier.get(field)
	return total


## Returns whether a modifier makes the run endless: the sectors loop after the last boss.
func is_endless() -> bool:
	return run_modifiers.any(func(modifier: RunModifier) -> bool: return modifier.endless)


## Returns what [param part] costs at a shop in this run: its cost, as the modifiers scale it and
## relics change it (never below 0).
func price_of(part: MechPart) -> int:
	var price := scale_price(part.cost)
	for modifier in get_modifiers():
		price = modifier.modify_part_price(part, price)
	return maxi(0, price)


## Returns [param price] as the modifiers scale shop prices, rounded up so that on parts costing
## a few gold any markup still costs at least one more.
func scale_price(price: int) -> int:
	var scale := get_mod_product(&"shop_price_scale")
	if scale == 1.0:
		return price
	# The small allowance keeps float error (20 * 1.15 = 23.000001) from rounding up a whole gold.
	return ceili(price * scale - 0.001)


## Returns the share of max HP a Hangar's Repair mends: [param share], as the modifiers change it.
func get_repair_share(share: float) -> float:
	return maxf(MIN_REPAIR_SHARE, share + get_mod_sum(&"repair_share_add"))


# The modifiers' start: the player's mech scaled, starting hull damage and parts, and each one's
# own start.
func _start_modifiers() -> void:
	var damage_scale := get_mod_product(&"player_damage_scale")
	var hp_scale := get_mod_product(&"player_hp_scale")
	if damage_scale != 1.0 or hp_scale != 1.0:
		var scale := PlayerScale.new()
		scale.damage_scale = damage_scale
		scale.hp_scale = hp_scale
		upgrades.append(scale)
	var damage_share := get_mod_sum(&"start_hull_damage_share")
	if damage_share > 0.0:
		hull_damage = mini(roundi(get_max_hp() * damage_share), get_max_hp() - 1)
	for modifier in run_modifiers:
		for part in modifier.start_parts:
			stash.append(StashEntry.new(part.duplicate()))
		modifier.on_run_start(self)


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

## Returns everything that changes the mech's rules: its relics, upgrades, and statuses.
func get_modifiers() -> Array[Relic]:
	var modifiers: Array[Relic] = []
	modifiers.append_array(relics)
	modifiers.append_array(upgrades)
	modifiers.append_array(statuses)
	return modifiers


## Returns the mech's stats as it's built now, relics and upgrades included.
func stats() -> MechStats:
	return MechStats.calculate(grid, rules, get_modifiers())


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

## Returns the player's mech for a fight: the build as it is, with the run's relics, starting at
## its current HP.
## Returns the player's mech for a fight at [param node] (if given): the build at the hull's
## current HP, with the run's relics and kits, and the node's hazard.
func make_player_mech(node: MapNode = null) -> BattleMech:
	var modifiers := get_modifiers()
	if node and node.hazard:
		modifiers.append(node.hazard.duplicate())
	var mech := BattleMech.new(grid, rules, 1.0, get_current_hp(), modifiers)
	mech.kits.assign(kits)
	return mech


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
## for the enemy, its HP scaled for the sector and how far up the map the node is, with the node's
## affixes and a boss's phases.
func make_enemy_mech(node: MapNode = null) -> BattleMech:
	node = node if node else map.current
	var enemy := get_enemy(node)
	# The fight gets its own copies of the node's affixes, so any state they keep starts fresh.
	var affixes: Array[Relic] = []
	for affix in node.affixes:
		affixes.append(affix.duplicate())
	if node.hazard:
		affixes.append(node.hazard.duplicate())
	enemy = enemy.with_threat(get_threat())
	var hp_scale := get_act().get_enemy_hp_scale(node.floor_index) * enemy.hp_scale * get_mod_product(&"enemy_hp_scale") \
		* (1.0 + ENDLESS_HP_PER_LOOP * loops)
	var mech := BattleMech.new(enemy.build_grid(), rules, hp_scale, -1, affixes)
	mech.mech_name = enemy.enemy_name
	mech.phases.assign(enemy.phases)
	mech.phase_threshold_bonus = get_mod_sum(&"phase_threshold_add")
	return mech


## Records how a fight went, given the player's [param mech] as the fight left it: its damage
## carries over to the hull, then relics act on a win. Anything but a win destroys the mech and
## ends the run.
func record_fight(result: FightResult, mech: BattleMech) -> void:
	hull_damage = maxi(0, mech.max_hp - mech.current_health)
	# The kits it used are spent.
	var used := mech.kits_used.duplicate()
	used.sort()
	used.reverse()
	for index: int in used:
		if index < kits.size():
			kits.remove_at(index)
	if result == FightResult.WIN:
		fights_won += 1
		for modifier in get_modifiers():
			modifier.on_fight_won(self)
		_crack_crates()
	else:
		outcome = Outcome.DEFEAT
	changed.emit()


# Counts a won fight for each installed crate; one that's sat through enough opens into a random
# catalog part of its rarity, in the stash, and says so on the next loot screen.
func _crack_crates() -> void:
	for placement in grid.get_placements():
		var crate := placement.part
		if crate.opens_after_wins <= 0:
			continue
		crate.crate_wins += 1
		if crate.crate_wins < crate.opens_after_wins:
			continue
		var pool := catalog.filter(func(part: MechPart) -> bool: return part.rarity == crate.opens_into)
		if pool.is_empty():
			continue
		var found: MechPart = pool[rng.stream("loot").randi_range(0, pool.size() - 1)]
		grid.remove_part(placement.origin)
		stash_part(found)
		_notes.append("The %s cracked open: a %s is in your stash." % [crate.part_name, found.part_name])

## Rolls the loot for winning the fight at [param node] (by default the current node): gold from
## the sector's range for the enemy's tier (as relics change it), added at once, and a draft of
## parts from the catalog with that tier's odds. An elite also drops a relic, rolled with
## [constant RelicPool.ELITE_WEIGHTS]; a boss offers three boss relics to choose from. A
## [param relic_rarity] of 0 or more adds a relic of that rarity to the choice (an event's prize
## fight). Take a part with [method take_reward_part] and a relic with [method take_reward_relic].
func roll_reward(node: MapNode = null, relic_rarity := -1) -> FightReward:
	node = node if node else map.current
	var reward := FightReward.new()
	reward.tier = node.get_tier()
	reward.notes = _notes
	_notes = []
	var loot_rng := rng.stream("loot")
	reward.gold = RewardRoller.roll_gold(loot_rng, get_act().get_gold_range(reward.tier))
	if reward.tier == EnemyLoadout.Tier.NORMAL:
		reward.gold = roundi(reward.gold * get_mod_product(&"battle_gold_scale"))
	# Each affix makes an elite worth a little more.
	reward.gold = roundi(reward.gold * (1.0 + AFFIX_GOLD_BONUS * node.affixes.size()))
	for modifier in get_modifiers():
		reward.gold = modifier.modify_gold(reward.gold)
	_tick_statuses()
	reward.parts = loot.draft_parts(loot_rng, catalog, RewardRoller.table_for(reward.tier))
	match reward.tier:
		EnemyLoadout.Tier.ELITE:
			var relic := relic_pool.roll(rng.stream("relics"), RelicPool.ELITE_WEIGHTS)
			if relic:
				reward.relics.append(relic)
			# Or a mod for the strongest weapon instead.
			reward.mod = roll_mod()
		EnemyLoadout.Tier.BOSS:
			reward.relics = relic_pool.take(BOSS_RELIC_CHOICES, [Relic.Rarity.BOSS])
			# Or grow the frame instead, while it has room.
			reward.cells = mini(BOSS_CELLS, get_expandable_cells())
	if rng.stream("kits").randf() < KIT_DROP_CHANCES.get(reward.tier, 0.0):
		reward.kit = roll_kit()
	if relic_rarity >= 0:
		var rarities: Array[Relic.Rarity] = [relic_rarity as Relic.Rarity]
		reward.relics.append_array(relic_pool.take(1, rarities))
	gold += reward.gold
	changed.emit()
	return reward


## Puts part [param index] of [param reward]'s draft in the stash, closing the draft. Returns
## false, taking nothing, if the draft is closed or there's no such part.
func take_reward_part(reward: FightReward, index: int) -> bool:
	if not reward.is_draft_open() or index < 0 or index >= reward.parts.size():
		return false
	reward.taken = index
	stash_part(reward.parts[index])
	return true

## Gives the run relic [param index] of [param reward]'s offer, closing it. Returns false,
## taking nothing, if the offer is closed or there's no such relic.
## Takes a boss reward's cells to open instead of a relic. Returns false if the group is closed or
## offers none.
func take_reward_cells(reward: FightReward) -> bool:
	if not reward.is_relic_open() or reward.cells <= 0:
		return false
	reward.relic_taken = FightReward.CELLS_TAKEN
	grant_cells(reward.cells)
	return true


## Takes the reward's field kit into a free slot. Returns false if there's none, it's taken, or
## every slot is full.
func take_reward_kit(reward: FightReward) -> bool:
	if reward.kit == null or reward.kit_taken or not add_kit(reward.kit):
		return false
	reward.kit_taken = true
	return true


## Puts [param kit] in a free kit slot. Returns false if they're all full.
func add_kit(kit: FieldKit) -> bool:
	if kit == null or not has_kit_room():
		return false
	kits.append(kit)
	changed.emit()
	return true


## Whether a kit slot is free.
func has_kit_room() -> bool:
	return kits.size() < KIT_SLOTS


## Throws away kit [param index] to free its slot.
func discard_kit(index: int) -> bool:
	if index < 0 or index >= kits.size():
		return false
	kits.remove_at(index)
	changed.emit()
	return true


## Returns a kit from [member kit_pool], rolled on the run's "kits" stream, or null.
func roll_kit() -> FieldKit:
	if kit_pool.is_empty():
		return null
	return kit_pool[rng.stream("kits").randi_range(0, kit_pool.size() - 1)]


## Fits the reward's weapon mod, instead of a relic. Returns false if the group is closed, there's
## no mod, or no weapon to fit it to.
func take_reward_mod(reward: FightReward) -> bool:
	if not reward.is_relic_open() or reward.mod == null or fit_mod(reward.mod) == null:
		return false
	reward.relic_taken = FightReward.MOD_TAKEN
	return true


## Returns a weapon mod from [member mod_pool] for the strongest mounted weapon, one it doesn't
## already have, rolled on the run's "mods" stream; null with no weapon or nothing to offer.
func roll_mod() -> WeaponMod:
	var weapon := WeaponModEffect.strongest_weapon(self)
	if weapon == null:
		return null
	var choices := mod_pool.filter(func(mod: WeaponMod) -> bool: return mod.fits(weapon) and mod != weapon.mod)
	if choices.is_empty():
		return null
	return choices[rng.stream("mods").randi_range(0, choices.size() - 1)]


## Fits [param mod] to the strongest mounted weapon, replacing any mod it had. Returns the weapon,
## or null (fitting nothing) if there's none it fits.
func fit_mod(mod: WeaponMod) -> MechPart:
	var weapon := WeaponModEffect.strongest_weapon(self)
	if weapon == null or mod == null or not mod.fits(weapon):
		return null
	weapon.mod = mod
	changed.emit()
	return weapon


func take_reward_relic(reward: FightReward, index: int) -> bool:
	if not reward.is_relic_open() or index < 0 or index >= reward.relics.size():
		return false
	reward.relic_taken = index
	add_relic(reward.relics[index])
	return true


## Adds a lasting change that isn't a relic, e.g. a [HullUpgrade].
func add_upgrade(upgrade: Relic) -> void:
	upgrades.append(upgrade)
	upgrade.on_obtain(self)
	changed.emit()


## Puts a copy of [param status] on the run for its [member TimedStatus.fights]. Returns the copy.
func add_status(status: TimedStatus) -> TimedStatus:
	var owned: TimedStatus = status.duplicate()
	statuses.append(owned)
	changed.emit()
	return owned


# A won fight's loot uses up a fight of each status; spent ones leave.
func _tick_statuses() -> void:
	for status in statuses:
		status.fights -= 1
	statuses.assign(statuses.filter(func(status: TimedStatus) -> bool: return status.fights > 0))


## Gives the run its own copy of [param relic], out of the pool, and runs its
## [method Relic.on_obtain]. Returns the copy.
func add_relic(relic: Relic) -> Relic:
	var owned: Relic = relic.duplicate()
	relic_pool.remove(relic)
	relics.append(owned)
	owned.on_obtain(self)
	changed.emit()
	return owned

#endregion
#region Stops

## Returns the jobs a Hangar offers: its own, then the ones the run's relics add.
func get_hangar_jobs() -> Array[HangarJob]:
	var jobs: Array[HangarJob] = hangar_jobs.duplicate()
	for relic in relics:
		jobs.append_array(relic.hangar_jobs)
	return jobs


## Returns how many more cells the frame can still grow: its locked cells not already owed.
func get_expandable_cells() -> int:
	return maxi(0, grid.chassis.get_locked_cells().size() - cells_to_open)


## Lets the player open up to [param count] more cells, as many as the frame has room for.
## Returns how many it granted.
func grant_cells(count: int) -> int:
	var granted := clampi(count, 0, get_expandable_cells())
	cells_to_open += granted
	if granted > 0:
		changed.emit()
	return granted


## Opens [param cell] on the frame, if the player has a cell to open and it's on the frontier
## (touching the frame). Returns whether it did.
func open_cell(cell: Vector2i) -> bool:
	if cells_to_open <= 0 or not grid.chassis.open_cell(cell):
		return false
	cells_to_open -= 1
	grid.grid_updated.emit()
	changed.emit()
	return true


## Returns the event at [param node] (by default the current node), drawing it from the pool the
## first time it's needed.
func get_event(node: MapNode = null) -> GameEvent:
	node = node if node else map.current
	if node.event == null:
		node.event = event_pool.next(self)
	return node.event


## Picks choice [param index] of [param event]: rolls one of its outcomes by weight, applies it,
## and returns what happened. Returns [code]null[/code], doing nothing, if the choice doesn't
## exist or its requirement isn't met.
func choose_event_option(event: GameEvent, index: int) -> EventResult:
	if index < 0 or index >= event.choices.size() or not event.choices[index].is_available(self):
		return null
	var choice := event.choices[index]
	var result := EventResult.new()
	if choice.outcomes.is_empty():
		return result
	var weights := {}
	for option_outcome in choice.outcomes:
		weights[option_outcome] = option_outcome.weight
	var picked: EventOutcome = RunRng.weighted_pick(rng.stream("events"), weights)
	if picked == null:
		picked = choice.outcomes[0]
	result.text = picked.text
	result.next_event = picked.next_event
	for effect in picked.effects:
		effect.apply(self, result)
	changed.emit()
	return result

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
	for modifier in get_modifiers():
		modifier.on_node_entered(self, node)
	changed.emit()
	return true


## Moves on once the sector's boss is down: to the next sector's map, repairing
## [constant ACT_HEAL] of the hull's damage, or, after the last sector, to victory.
func next_act() -> void:
	if act_index + 1 >= acts.size() and not is_endless():
		outcome = Outcome.VICTORY
	else:
		if act_index + 1 >= acts.size():
			# Endless: the sectors start over, tougher.
			act_index = 0
			loops += 1
		else:
			act_index += 1
		hull_damage -= ceili(hull_damage * ACT_HEAL)
		_start_act(act_index)
	changed.emit()


func _start_act(index: int) -> void:
	var act := acts[index]
	var generator: MapGenerator = act.generator.new() if act.generator else MapGenerator.new()
	map = generator.generate(act, rng.stream("map"))
	_roll_affixes()
	_roll_hazards()


# Rolls affixes on the run's "affixes" stream, from [member affix_pool]: [member elite_affixes]
# different ones for each elite (more with Threat), and one for a normal battle by Threat's chance.
func _roll_affixes() -> void:
	if affix_pool.is_empty():
		return
	var stream := rng.stream("affixes")
	var per_elite := elite_affixes + roundi(get_mod_sum(&"elite_affixes_add"))
	var normal_chance := get_mod_sum(&"normal_affix_chance")
	for node in map.get_nodes():
		var count := 0
		if node.type == MapNode.Type.ELITE:
			count = per_elite
		elif node.type == MapNode.Type.BATTLE and normal_chance > 0.0 and stream.randf() < normal_chance:
			count = 1
		if count > 0:
			var picks := RunRng.shuffle(stream, affix_pool.duplicate())
			node.affixes.assign(picks.slice(0, mini(count, picks.size())))

# Rolls a hazard onto each battle and elite at the sector's chance, on the run's "hazards" stream.
func _roll_hazards() -> void:
	var act := get_act()
	if act.hazards.is_empty() or act.hazard_chance <= 0.0:
		return
	var stream := rng.stream("hazards")
	for node in map.get_nodes():
		if node.type in [MapNode.Type.BATTLE, MapNode.Type.ELITE] and stream.randf() < act.hazard_chance:
			node.hazard = act.hazards[stream.randi_range(0, act.hazards.size() - 1)]


## Turns an Unknown [param node] into what it really is, by [constant UNKNOWN_ODDS] on the run's
## "unknown" stream, and returns its new type. Any other node stays as it is.
func resolve_unknown(node: MapNode) -> MapNode.Type:
	if node.type == MapNode.Type.UNKNOWN:
		var picked: Variant = RunRng.weighted_pick(rng.stream("unknown"), UNKNOWN_ODDS)
		node.type = picked if picked != null else MapNode.Type.EVENT
	return node.type


## Opens a Salvage Cache: gold from the sector's battle range, a relic rolled like an elite's, and
## a field kit, all to take like a fight's loot (the gold at once).
func roll_cache() -> FightReward:
	var reward := FightReward.new()
	reward.title = "SALVAGE CACHE"
	reward.gold = RewardRoller.roll_gold(rng.stream("loot"), get_act().get_gold_range(EnemyLoadout.Tier.NORMAL))
	var relic := relic_pool.roll(rng.stream("relics"), RelicPool.ELITE_WEIGHTS)
	if relic:
		reward.relics.append(relic)
	reward.kit = roll_kit()
	gold += reward.gold
	changed.emit()
	return reward

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
#region Upgrades

## Merges stashed part [param index] into the installed part covering [param coords], which goes
## up a Mk. Returns false, changing nothing, unless they can merge (see
## [method MechPart.can_merge_with]).
func merge_from_stash(index: int, coords: Vector2i) -> bool:
	var target := grid.get_part_at(coords)
	if index < 0 or index >= stash.size() or not stash[index].part.can_merge_with(target):
		return false
	var source := stash[index].part
	stash.remove_at(index)
	_level_up(target, source)
	return true


## Merges stashed part [param from] into stashed part [param into].
func merge_stash(from: int, into: int) -> bool:
	if from < 0 or into < 0 or from >= stash.size() or into >= stash.size():
		return false
	var source := stash[from].part
	var target := stash[into].part
	if not source.can_merge_with(target):
		return false
	stash.remove_at(from)
	_level_up(target, source)
	return true


## Merges the installed part covering [param from_coords] into the one covering
## [param into_coords], freeing the first one's cells.
func merge_on_grid(from_coords: Vector2i, into_coords: Vector2i) -> bool:
	var source := grid.get_part_at(from_coords)
	var target := grid.get_part_at(into_coords)
	if source == null or not source.can_merge_with(target):
		return false
	grid.remove_part(from_coords)
	_level_up(target, source)
	return true


## Merges the installed part covering [param coords] into the stash's part [param into].
func merge_into_stash(coords: Vector2i, into: int) -> bool:
	var source := grid.get_part_at(coords)
	if source == null or into < 0 or into >= stash.size() or not source.can_merge_with(stash[into].part):
		return false
	grid.remove_part(coords)
	_level_up(stash[into].part, source)
	return true


## Buys shop slot [param slot_index] and merges it straight into the installed part covering
## [param coords]. Changes nothing unless it's affordable and they can merge.
func buy_and_merge(slot_index: int, coords: Vector2i) -> bool:
	var slot := shop.get_open_slot(slot_index) if shop else null
	if slot == null or not slot.part.can_merge_with(grid.get_part_at(coords)) or not can_afford(slot.part):
		return false
	return buy_to_stash(slot_index) and merge_from_stash(stash.size() - 1, coords)


## Returns what merging [param part] into the installed part covering [param into_coords] would
## do, or [code]null[/code] if they can't merge. Pass [param from_coords] when [param part] is
## installed too, so its cells are freed in the stats.
func preview_merge(part: MechPart, into_coords: Vector2i, from_coords: Variant = null) -> Preview:
	var placement := grid.get_placement_at(into_coords)
	if placement == null or not part.can_merge_with(placement.part):
		return null
	var preview := Preview.new()
	preview.fit = MechGridData.Fit.OK
	preview.merge = true
	preview.cells = placement.cells.duplicate()
	var hypothetical := grid.copy()
	if from_coords != null:
		hypothetical.remove_part(from_coords)
	# The copy shares part instances: raise the Mk just for the numbers.
	placement.part.level += 1
	preview.stats = MechStats.calculate(hypothetical, rules, get_modifiers())
	placement.part.level -= 1
	preview.open_edges = hypothetical.get_open_edges(preview.cells)
	return preview


## Raises [param part] a Mk, e.g. at a Hangar. Returns false if it's at the top already.
func upgrade_part(part: MechPart) -> bool:
	if part == null or part.level >= MechPart.MAX_LEVEL:
		return false
	part.level += 1
	changed.emit()
	return true


## Returns every part the player owns that can still go up a Mk, installed ones first. Junk
## isn't worth upgrading and isn't listed.
func get_upgradable_parts() -> Array[MechPart]:
	var parts: Array[MechPart] = []
	for placement in grid.get_placements():
		parts.append(placement.part)
	for entry in stash:
		parts.append(entry.part)
	return parts.filter(func(part: MechPart) -> bool:
		return part.level < MechPart.MAX_LEVEL and part.type != MechPart.PartType.JUNK)


# [param target] absorbs [param source] and goes up a Mk. The merged part sells back in full
# only if both halves were bought at this shop.
func _level_up(target: MechPart, source: MechPart) -> void:
	target.level += 1
	if not (source in _fresh and target in _fresh):
		_fresh.erase(target)
	_fresh.erase(source)
	changed.emit()

#endregion
#region Shop

## Opens a Scrap Shop, stocked from the catalog, with [constant SHOP_RELICS] relics from the
## back of the pool.
func open_shop() -> void:
	var for_sale := relic_pool.take(SHOP_RELICS, [Relic.Rarity.COMMON, Relic.Rarity.UNCOMMON, Relic.Rarity.RARE,
		Relic.Rarity.SHOP], true)
	shop = ShopStock.new(catalog, rng.stream("shop"), for_sale)
	for offer in shop.relic_offers:
		offer.price = scale_price(offer.price)
	var kits_for_sale := RunRng.shuffle(rng.stream("shop"), kit_pool.duplicate())
	for kit: FieldKit in kits_for_sale.slice(0, SHOP_KITS):
		shop.kit_offers.append(ShopStock.KitOffer.new(kit, scale_price(kit.price)))
	for i in SHOP_MODS:
		var mod := roll_mod()
		if mod and shop.mod_offers.all(func(offer: ShopStock.ModOffer) -> bool: return offer.mod != mod):
			var price := rng.stream("shop").randi_range(MOD_PRICES.x, MOD_PRICES.y)
			shop.mod_offers.append(ShopStock.ModOffer.new(mod, scale_price(price)))
	for modifier in get_modifiers():
		modifier.on_shop_opened(self, shop)
	_fresh.clear()
	changed.emit()


## Leaves the shop. Parts bought there no longer sell back in full.
func close_shop() -> void:
	shop = null
	_fresh.clear()
	changed.emit()


## Returns whether the run can pay [param part]'s shop price.
func can_afford(part: MechPart) -> bool:
	return price_of(part) <= gold


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
	gold -= price_of(part)
	_fresh.append(part)
	changed.emit()
	return true


## Buys the part in shop slot [param slot_index] into the stash, in the slot's rotation. Changes
## nothing and returns false unless a shop is open, the slot is unsold, and it's affordable.
func buy_to_stash(slot_index: int) -> bool:
	var slot := shop.get_open_slot(slot_index) if shop else null
	if slot == null or not can_afford(slot.part):
		return false
	var part: MechPart = slot.part.duplicate()
	slot.sold = true
	gold -= price_of(part)
	_fresh.append(part)
	stash.append(StashEntry.new(part, slot.rotation))
	changed.emit()
	return true


## Buys the shop's relic offer [param index]. Returns false unless a shop is open, the offer is
## unsold, and it's affordable.
func buy_relic(index: int) -> bool:
	var offer := shop.get_open_relic(index) if shop else null
	if offer == null or offer.price > gold:
		return false
	offer.sold = true
	gold -= offer.price
	add_relic(offer.relic)
	return true


## Buys the shop's kit offer [param index] into a free kit slot. Returns false unless a shop is
## open, the offer is unsold and affordable, and a slot is free.
func buy_kit(index: int) -> bool:
	var offer := shop.get_open_kit(index) if shop else null
	if offer == null or offer.price > gold or not add_kit(offer.kit):
		return false
	offer.sold = true
	gold -= offer.price
	changed.emit()
	return true


## Buys the shop's mod offer [param index] and fits it to the strongest weapon. Returns false
## unless a shop is open, the offer is unsold and affordable, and there's a weapon it fits.
func buy_mod(index: int) -> bool:
	var offer := shop.get_open_mod(index) if shop else null
	if offer == null or offer.price > gold or fit_mod(offer.mod) == null:
		return false
	offer.sold = true
	gold -= offer.price
	changed.emit()
	return true


## Turns the offer in shop slot [param slot_index] a quarter-turn clockwise.
func rotate_slot(slot_index: int) -> bool:
	if shop == null or not shop.rotate_slot(slot_index):
		return false
	changed.emit()
	return true


## Returns what restocking the open shop costs: [constant ShopStock.REROLL_COST], as relics change
## it (never below 0).
func get_reroll_cost() -> int:
	var cost := ShopStock.REROLL_COST
	for modifier in get_modifiers():
		cost = modifier.modify_reroll_cost(self, cost)
	return maxi(0, cost)


## Pays [method get_reroll_cost] to restock the open shop. Returns false without a shop
## or the gold to pay.
func reroll() -> bool:
	var cost := get_reroll_cost()
	if shop == null or gold < cost:
		return false
	gold -= cost
	shop.restock()
	for modifier in get_modifiers():
		modifier.on_reroll(self)
	changed.emit()
	return true


## Returns whether parts can be sold: only at a shop.
func can_sell() -> bool:
	return shop != null


## Returns whether [param part] can be sold here: at a shop, and a part shops buy.
func can_sell_part(part: MechPart) -> bool:
	return can_sell() and part != null and part.sellable


## Returns what the part covering [param coords] sells for: its cost times its Mk, in full if it
## was bought at this shop or an installed part refunds in full (see [method refunds_in_full]),
## otherwise half, rounded down. 0 if the cell is empty.
func sell_value(coords: Vector2i) -> int:
	return _value_of(grid.get_part_at(coords))


## Returns what stashed part [param index] sells for, as [method sell_value] does.
func stash_sell_value(index: int) -> int:
	return _value_of(stash[index].part) if index >= 0 and index < stash.size() else 0


## Returns whether a part installed on the mech (a scrapper drone) makes shops buy every part
## back at its full value.
func refunds_in_full() -> bool:
	for placement in grid.get_placements():
		for ability in placement.part.get_abilities():
			if ability.refunds_in_full():
				return true
	return false


## Returns whether stashed part [param index] was bought at this shop.
func is_stash_fresh(index: int) -> bool:
	return index >= 0 and index < stash.size() and stash[index].part in _fresh


## Returns whether the part covering [param coords] was bought at this shop.
func is_fresh(coords: Vector2i) -> bool:
	var part := grid.get_part_at(coords)
	return part != null and part in _fresh


## Sells the part covering [param coords] and returns the gold it brought in: 0, selling
## nothing, if the cell is empty or there's no shop.
func sell(coords: Vector2i) -> int:
	if not can_sell_part(grid.get_part_at(coords)):
		return 0
	var value := sell_value(coords)
	var part := grid.remove_part(coords)
	if part == null:
		return 0
	gold += value
	_fresh.erase(part)
	changed.emit()
	return value


## Sells stashed part [param index] and returns the gold it brought in: 0, selling nothing,
## without a shop or such a part.
func sell_stashed(index: int) -> int:
	if index < 0 or index >= stash.size() or not can_sell_part(stash[index].part):
		return 0
	var value := stash_sell_value(index)
	var part := stash[index].part
	stash.remove_at(index)
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


func _value_of(part: MechPart) -> int:
	if part == null:
		return 0
	var value := part.cost * part.level
	# A part bought at this shop refunds what was paid for it, Threat's markup and all.
	if part in _fresh:
		value = price_of(part) * part.level
	elif not refunds_in_full():
		value = floori(value / 2.0)
	for modifier in get_modifiers():
		value = modifier.modify_sell_value(part, value)
	return maxi(0, value)


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
	preview.stats = MechStats.calculate(hypothetical, rules, get_modifiers())

#endregion
