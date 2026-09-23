class_name Game
extends Node
## Plays runs. The player picks a frame, then climbs each sector's map to its boss one stop at a
## time: fights play on the combat screen and drop loot, Scrap Shops open the shop, and stops
## that aren't built yet show a placeholder. From the map, the Loadout rearranges the mech and its
## stash. The mech's damage carries from fight to fight; when it goes down, or the last sector's
## boss does, the run's end shows, and after it a new run starts.

const CHASSIS_SELECT_SCENE := preload("res://src/ui/ChassisSelectScreen.tscn")
const MAP_SCENE := preload("res://src/ui/MapScreen.tscn")
const LOADOUT_SCENE := preload("res://src/ui/LoadoutScreen.tscn")
const COMBAT_SCENE := preload("res://src/ui/CombatScreen.tscn")
const ACTS_DIR := "res://resources/acts"
const CLEAR_COLOR := Color("#5fd38a")
const LOSS_COLOR := Color("#ff4d4d")

## Gold a run starts with.
@export var start_gold := 20
## Parts the run can offer, adjacency rules, and sectors in order. Left empty, they're loaded
## from their folders (sectors in id order).
var catalog: Array[MechPart] = []
var rules: Array[SynergyRule] = []
var acts: Array[ActData] = []
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

# The player's mech in the current fight.
var _player: BattleMech


func _ready() -> void:
	if catalog.is_empty():
		catalog.assign(LoadoutScreen.load_dir(LoadoutScreen.PARTS_DIR).filter(func(resource: Resource) -> bool: return resource is MechPart))
	if rules.is_empty():
		rules.assign(LoadoutScreen.load_dir(LoadoutScreen.RULES_DIR).filter(func(resource: Resource) -> bool: return resource is SynergyRule))
	if acts.is_empty():
		var loaded := LoadoutScreen.load_dir(ACTS_DIR).filter(func(resource: Resource) -> bool: return resource is ActData)
		loaded.sort_custom(func(a: ActData, b: ActData) -> bool: return a.id < b.id)
		acts.assign(loaded)
	chassis_select = %ChassisSelectScreen
	screen = chassis_select
	# Every swap is deferred, so a screen isn't taken out of the tree while it's still emitting.
	chassis_select.chassis_chosen.connect(_start_run, CONNECT_DEFERRED)


## Shows the current sector's map.
func show_map() -> void:
	var map: MapScreen = MAP_SCENE.instantiate()
	map.run = run
	map.node_chosen.connect(_enter, CONNECT_DEFERRED)
	map.loadout_requested.connect(_open_loadout, CONNECT_DEFERRED)
	_show(map)


func _start_run(chassis: MechChassis) -> void:
	chassis_select = null
	run = RunState.new(chassis, catalog, rules, start_gold, RunRng.new(run_seed) if run_seed >= 0 else RunRng.new(), acts)
	show_map()


# Opens what's at [param node], which the player has just traveled to.
func _enter(node: MapNode) -> void:
	match node.type:
		MapNode.Type.BATTLE, MapNode.Type.ELITE, MapNode.Type.BOSS:
			_start_fight()
		MapNode.Type.SHOP:
			_open_shop()
		MapNode.Type.HANGAR:
			_placeholder("Hangar / Refit Bay", "The refit crew isn't here yet. Repairs and upgrades are coming soon.")
		MapNode.Type.EVENT:
			_placeholder("Unknown Signal", "Nothing answers. Events are coming soon.")


# The player's build, as it stands, at the hull's current HP, against the node's enemy.
func _start_fight() -> void:
	_player = run.make_player_mech()
	combat = COMBAT_SCENE.instantiate()
	combat.setup(_player, run.make_enemy_mech(), run)
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
	var loot := RewardScreen.new(run, run.roll_reward())
	loot.finished.connect(_after_loot, CONNECT_DEFERRED)
	_show(loot)


func _after_loot() -> void:
	if run.map.is_at_boss():
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


func _placeholder(title: String, text: String) -> void:
	var message := MessageScreen.new(title, MessageScreen.TEXT_COLOR, PackedStringArray([text]), "Continue", run)
	message.confirmed.connect(show_map, CONNECT_DEFERRED)
	_show(message)


func _show_end() -> void:
	var won := run.outcome == RunState.Outcome.VICTORY
	var message := MessageScreen.new("RUN COMPLETE" if won else "MECH DESTROYED", CLEAR_COLOR if won else LOSS_COLOR,
		end_lines(run), "New run")
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
	chassis_select.chassis_chosen.connect(_start_run, CONNECT_DEFERRED)
	_show(chassis_select)


# Replaces the screen showing with [param next].
func _show(next: Node) -> void:
	if screen:
		remove_child(screen)
		screen.queue_free()
	screen = next
	add_child(next)
