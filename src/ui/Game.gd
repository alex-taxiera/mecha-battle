class_name Game
extends Node
## Plays runs. The player picks a frame, then climbs each sector's map to its boss one stop at a
## time: fights play on the combat screen and drop loot, Scrap Shops open the shop, Hangars
## repair or reinforce the hull, and Events tell a story with choices, some leading to a fight.
## From the map, the Loadout rearranges the mech and its stash. The mech's damage carries from
## fight to fight; when it goes down, or the last sector's boss does, the run's end shows, with any
## unlocks it earned, and after it a new run starts. The profile, saved between sessions, decides
## which frames, parts, and relics are unlocked.

const CHASSIS_SELECT_SCENE := preload("res://src/ui/ChassisSelectScreen.tscn")
const MAP_SCENE := preload("res://src/ui/MapScreen.tscn")
const LOADOUT_SCENE := preload("res://src/ui/LoadoutScreen.tscn")
const COMBAT_SCENE := preload("res://src/ui/CombatScreen.tscn")
const ACTS_DIR := "res://resources/acts"
const RELICS_DIR := "res://resources/relics"
const AFFIXES_DIR := "res://resources/affixes"
const HANGAR_JOBS_DIR := "res://resources/hangar_jobs"
const EVENTS_DIR := "res://resources/events"
const UNLOCKS_DIR := "res://resources/unlocks"
const TECHNICIAN_DIR := "res://resources/technician"
## The Mech Technician's id in the unlocks.
const TECHNICIAN := "technician"
# A fight's map node kind for each enemy tier, for fights events start.
const _TIER_NODES := {
	EnemyLoadout.Tier.NORMAL: MapNode.Type.BATTLE,
	EnemyLoadout.Tier.ELITE: MapNode.Type.ELITE,
	EnemyLoadout.Tier.BOSS: MapNode.Type.BOSS,
}
const CLEAR_COLOR := Color("#5fd38a")
const LOSS_COLOR := Color("#ff4d4d")

## Gold a run starts with.
@export var start_gold := 20
## Parts the run can offer, adjacency rules, sectors in order, the relics it can find, and its
## events. Left empty, they're loaded from their folders (sectors in id order).
var catalog: Array[MechPart] = []
var rules: Array[SynergyRule] = []
var acts: Array[ActData] = []
var relics: Array[Relic] = []
var events: Array[GameEvent] = []
## The affixes elites can roll; loaded from [constant AFFIXES_DIR] unless set.
var affixes: Array[Relic] = []
## The Hangar's jobs, in their order; loaded from [constant HANGAR_JOBS_DIR] unless set.
var hangar_jobs: Array[HangarJob] = []
## Everything the profile can unlock. Left empty, it's loaded from its folder.
var unlocks: Array[Unlock] = []
## What the Mech Technician can offer. Left empty, it's loaded from its folder.
var technician_options: Array[RunStartOption] = []
## The player's progress. Left unset, it's loaded from [constant Profile.DEFAULT_PATH] (tests set
## an in-memory one).
var profile: Profile
## The seed for new runs; below 0, each run gets a random one.
var run_seed := -1

## The run being played, once a frame is chosen.
var run: RunState
## The screen showing now.
var screen: Node
## The frame select screen, while it's showing.
var chassis_select: ChassisSelectScreen
## The fight playing now, or null.
var combat: CombatScreen

# The player's mech in the current fight, and the node whose enemy and loot it's for: the map's
# current node, or a stand-in for a fight an event started.
var _player: BattleMech
var _fight_node: MapNode


func _ready() -> void:
	if catalog.is_empty():
		catalog.assign(LoadoutScreen.load_dir(LoadoutScreen.PARTS_DIR).filter(func(resource: Resource) -> bool: return resource is MechPart))
	if rules.is_empty():
		rules.assign(LoadoutScreen.load_dir(LoadoutScreen.RULES_DIR).filter(func(resource: Resource) -> bool: return resource is SynergyRule))
	if acts.is_empty():
		var loaded := LoadoutScreen.load_dir(ACTS_DIR).filter(func(resource: Resource) -> bool: return resource is ActData)
		loaded.sort_custom(func(a: ActData, b: ActData) -> bool: return a.id < b.id)
		acts.assign(loaded)
	if relics.is_empty():
		relics.assign(LoadoutScreen.load_dir(RELICS_DIR).filter(func(resource: Resource) -> bool: return resource is Relic))
	if events.is_empty():
		events.assign(LoadoutScreen.load_dir(EVENTS_DIR).filter(func(resource: Resource) -> bool: return resource is GameEvent))
	if affixes.is_empty():
		affixes.assign(LoadoutScreen.load_dir(AFFIXES_DIR).filter(func(resource: Resource) -> bool: return resource is Relic))
	if hangar_jobs.is_empty():
		var jobs := LoadoutScreen.load_dir(HANGAR_JOBS_DIR).filter(func(resource: Resource) -> bool: return resource is HangarJob)
		jobs.sort_custom(func(a: HangarJob, b: HangarJob) -> bool: return a.order < b.order or (a.order == b.order and a.id < b.id))
		hangar_jobs.assign(jobs)
	if unlocks.is_empty():
		unlocks.assign(LoadoutScreen.load_dir(UNLOCKS_DIR).filter(func(resource: Resource) -> bool: return resource is Unlock))
	if technician_options.is_empty():
		technician_options.assign(LoadoutScreen.load_dir(TECHNICIAN_DIR).filter(func(resource: Resource) -> bool: return resource is RunStartOption))
	if profile == null:
		profile = Profile.load_from(Profile.DEFAULT_PATH)
	chassis_select = %ChassisSelectScreen
	screen = chassis_select
	_watch_chassis_select()


## Shows the current sector's map.
func show_map() -> void:
	var map: MapScreen = MAP_SCENE.instantiate()
	map.run = run
	map.node_chosen.connect(_enter, CONNECT_DEFERRED)
	map.loadout_requested.connect(_open_loadout, CONNECT_DEFERRED)
	_show(map)


func _start_run(chassis: MechChassis) -> void:
	chassis_select = null
	# Locked parts and relics stay out of loot and shops (a starter kit still has its parts).
	var run_catalog: Array[MechPart] = []
	run_catalog.assign(catalog.filter(func(part: MechPart) -> bool: return profile.is_available(Unlock.Kind.PART, part.id, unlocks)))
	var run_relics: Array[Relic] = []
	run_relics.assign(relics.filter(func(relic: Relic) -> bool: return profile.is_available(Unlock.Kind.RELIC, relic.id, unlocks)))
	run = RunState.new(chassis, run_catalog, rules, start_gold, RunRng.new(run_seed) if run_seed >= 0 else RunRng.new(), acts,
		run_relics, events, affixes)
	run.hangar_jobs.assign(hangar_jobs)
	if profile.is_available(Unlock.Kind.NPC, TECHNICIAN, unlocks):
		_meet_technician()
	else:
		show_map()


# The Mech Technician offers a boon before the first step.
func _meet_technician() -> void:
	var boons := TechnicianOffer.roll(technician_options, run.rng.stream("start"))
	if boons.is_empty():
		show_map()
		return
	var technician := TechnicianScreen.new(run, boons)
	technician.confirmed.connect(show_map, CONNECT_DEFERRED)
	_show(technician)


# Opens what's at [param node], which the player has just traveled to.
func _enter(node: MapNode) -> void:
	match node.type:
		MapNode.Type.BATTLE, MapNode.Type.ELITE, MapNode.Type.BOSS:
			_start_fight()
		MapNode.Type.SHOP:
			_open_shop()
		MapNode.Type.HANGAR:
			var rest := RestScreen.new(run)
			rest.confirmed.connect(show_map, CONNECT_DEFERRED)
			_show(rest)
		MapNode.Type.EVENT:
			_open_event()


# The player's build, as it stands, at the hull's current HP, against the current node's enemy,
# or, for a fight an event starts, one of the sector's enemies of [param tier].
func _start_fight(tier := -1) -> void:
	_fight_node = run.map.current
	if tier >= 0:
		_fight_node = MapNode.new(run.map.current.floor_index, run.map.current.column, _TIER_NODES[tier])
	_player = run.make_player_mech()
	combat = COMBAT_SCENE.instantiate()
	combat.setup(_player, run.make_enemy_mech(_fight_node), run)
	combat.finished.connect(_end_fight, CONNECT_DEFERRED)
	_show(combat)


func _end_fight(winner: BattleMech) -> void:
	var result := RunState.FightResult.DRAW
	if winner == _player:
		result = RunState.FightResult.WIN
	elif winner != null:
		result = RunState.FightResult.LOSS
	run.record_fight(result, _player)
	_player = null
	combat = null
	if run.is_over():
		_show_end()
		return
	var loot := RewardScreen.new(run, run.roll_reward(_fight_node))
	loot.finished.connect(_after_loot, CONNECT_DEFERRED)
	_show(loot)


func _after_loot() -> void:
	if _fight_node == run.map.boss:
		_clear_sector()
	else:
		show_map()


# The boss is down: on to the next sector, or the run is won.
func _clear_sector() -> void:
	var boss := run.map.boss.enemy.enemy_name if run.map.boss.enemy else "The boss"
	var cleared := run.get_act().sector_name
	run.next_act()
	if run.is_over():
		_show_end()
		return
	var message := MessageScreen.new("SECTOR CLEARED", CLEAR_COLOR, PackedStringArray([
		"%s is down. %s is behind you." % [boss, cleared],
		"Half your hull damage is repaired on the way to %s." % run.get_act().sector_name,
	]), "Onward", run)
	message.confirmed.connect(show_map, CONNECT_DEFERRED)
	_show(message)


func _open_shop() -> void:
	run.open_shop()
	var shop: LoadoutScreen = LOADOUT_SCENE.instantiate()
	shop.run = run
	shop.leave_requested.connect(_leave_shop, CONNECT_DEFERRED)
	_show(shop)


# The Loadout between stops: the mech and stash, no shop.
func _open_loadout() -> void:
	var loadout: LoadoutScreen = LOADOUT_SCENE.instantiate()
	loadout.run = run
	loadout.leave_requested.connect(show_map, CONNECT_DEFERRED)
	_show(loadout)


func _leave_shop() -> void:
	run.close_shop()
	show_map()


# The event at the current node; one that starts a fight goes on to it.
func _open_event() -> void:
	var event := run.get_event()
	if event == null:
		var quiet := MessageScreen.new("Quiet Sector", MessageScreen.TEXT_COLOR, PackedStringArray(["Nothing out here but static."]),
			"Continue", run)
		quiet.confirmed.connect(show_map, CONNECT_DEFERRED)
		_show(quiet)
		return
	var event_screen := EventScreen.new(run, event)
	event_screen.confirmed.connect(_after_event.bind(event_screen), CONNECT_DEFERRED)
	_show(event_screen)


func _after_event(event_screen: EventScreen) -> void:
	if event_screen.result and event_screen.result.fight_tier >= 0:
		_start_fight(event_screen.result.fight_tier)
	else:
		show_map()


func _show_end() -> void:
	var won := run.outcome == RunState.Outcome.VICTORY
	var lines := end_lines(run)
	for unlock in profile.record_run(run, unlocks):
		lines.append("Unlocked: %s" % unlock.title)
	profile.save()
	var message := MessageScreen.new("RUN COMPLETE" if won else "MECH DESTROYED", CLEAR_COLOR if won else LOSS_COLOR,
		lines, "New run")
	message.confirmed.connect(_new_run, CONNECT_DEFERRED)
	_show(message)


## Returns the run's summary for its end screen, e.g. "The Bastion", "Fell in Sector 2 ·
## Floor 7", "Fights won: 9".
static func end_lines(p_run: RunState) -> PackedStringArray:
	var lines := PackedStringArray([p_run.grid.chassis.chassis_name])
	if p_run.outcome == RunState.Outcome.VICTORY:
		lines.append("Cleared all %d sectors" % p_run.acts.size())
	else:
		lines.append("Fell in Sector %d · Floor %d" % [p_run.act_index + 1, p_run.get_floor_number()])
	lines.append("Fights won: %d" % p_run.fights_won)
	return lines


func _new_run() -> void:
	run = null
	chassis_select = CHASSIS_SELECT_SCENE.instantiate()
	_show(chassis_select)
	_watch_chassis_select()


# Hooks up the frame select showing now: its locks, and what it asks for. Every swap is deferred,
# so a screen isn't taken out of the tree while it's still emitting.
func _watch_chassis_select() -> void:
	chassis_select.set_locks(profile, unlocks)
	chassis_select.chassis_chosen.connect(_start_run, CONNECT_DEFERRED)
	chassis_select.reset_requested.connect(_reset_progress)


func _reset_progress() -> void:
	profile.reset()
	profile.save()
	chassis_select.set_locks(profile, unlocks)


# Replaces the screen showing with [param next].
func _show(next: Node) -> void:
	if screen:
		remove_child(screen)
		screen.queue_free()
	screen = next
	add_child(next)
