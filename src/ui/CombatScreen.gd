class_name CombatScreen
extends Control
## Plays a fight in real time: a looping 0.1-second timer drives a [CombatEngine]. For now the
## screen only shows both mechs' health and energy as text, and prints each tick to the output.
## Once the fight is over it shows the result for a moment, then emits [signal finished].

## Emitted once the fight is over and its result has been on screen for a moment. [param winner]
## is null for a draw.
signal finished(winner: BattleMech)

## The mech the player fights until there are real opponents, as [part id, origin] pairs on a
## training Bastion: a missile pod in its back bay, cooled by a heatsink touching the bay.
const DUMMY := [["missile_pod", Vector2i(1, -2)], ["heatsink", Vector2i(2, 0)]]
const DUMMY_CHASSIS := preload("res://resources/chassis/bastion.tres")
# Run on its own, the screen pits this stand-in for the player against the dummy, on the
# screen's Bastion: a missile pod overcharged by a reactor touching its bay, and a laser.
const DEMO_PLAYER := [["missile_pod", Vector2i(1, -2)], ["reactor", Vector2i(1, 0)], ["laser", Vector2i(1, 1)]]

## The chassis the demo mechs are built on.
@export var chassis: MechChassis
## Adjacency rules for the demo mechs. Left empty, every SynergyRule in
## [constant ShopScreen.RULES_DIR] applies.
@export var rules: Array[SynergyRule] = []
## Prints each tick's health and energy, and the result, to the output.
@export var print_ticks := true

var engine: CombatEngine

# The winner once the fight is over; null for a draw.
var _winner: BattleMech

@onready var _tick_timer: Timer = %TickTimer
@onready var _result_timer: Timer = %ResultTimer
@onready var _status_label: Label = %StatusLabel


func _ready() -> void:
	if engine == null:
		if rules.is_empty():
			rules.assign(ShopScreen.load_dir(ShopScreen.RULES_DIR).filter(func(resource: Resource) -> bool: return resource is SynergyRule))
		setup(build_mech(chassis, DEMO_PLAYER, rules), make_dummy(rules))
	_tick_timer.timeout.connect(_on_tick_timer_timeout)
	_result_timer.timeout.connect(func() -> void: finished.emit(_winner))
	_status_label.text = status_line()
	engine.start()
	_tick_timer.start()


## Sets the two mechs to fight: the player's on the left. Call it before the screen enters the
## tree, or it fights the demo builds.
func setup(left: BattleMech, right: BattleMech) -> void:
	engine = CombatEngine.new(left, right)
	engine.battle_ended.connect(func(winner: BattleMech) -> void: _winner = winner)


## Returns a tick's printout, e.g.
## "[ 1.0s] Left HP 47/47 EN 1 HEAT 20 | Right HP 18/30 EN 0 HEAT 0 OFF", where OFF marks a
## mech shut down by a meltdown.
func status_line() -> String:
	return "[%4.1fs] %s | %s" % [engine.elapsed, _mech_status("Left", engine.left), _mech_status("Right", engine.right)]


## Returns the fight's result, e.g. "Left wins with 11/47 HP left", or "" while it's running.
func result_line() -> String:
	if engine.state != CombatEngine.State.FINISHED:
		return ""
	if _winner == null:
		return "Draw: both mechs went down together"
	return "%s wins with %d/%d HP left" % [_side_name(_winner), _winner.current_health, _winner.max_hp]


## Returns what the screen shows.
func get_status_text() -> String:
	return _status_label.text


## Returns a mech built on [param p_chassis] from [param lineup], [part id, origin] pairs of
## part files in [constant ShopScreen.PARTS_DIR], fighting with [param p_rules]' link bonuses
## and its chassis HP for round [param round_number].
static func build_mech(p_chassis: MechChassis, lineup: Array, p_rules: Array[SynergyRule], round_number := 1) -> BattleMech:
	var grid := MechGridData.new(p_chassis)
	for entry in lineup:
		var part: MechPart = load(ShopScreen.PARTS_DIR.path_join("%s.tres" % entry[0]))
		if not grid.place_part(part, entry[1]):
			push_error("CombatScreen: can't place %s at %s" % [entry[0], entry[1]])
	return BattleMech.new(grid, p_rules, round_number)


## Returns the [constant DUMMY] build on [constant DUMMY_CHASSIS], its HP grown for round
## [param round_number] like the player's.
static func make_dummy(p_rules: Array[SynergyRule], round_number := 1) -> BattleMech:
	return build_mech(DUMMY_CHASSIS, DUMMY, p_rules, round_number)


func _on_tick_timer_timeout() -> void:
	engine.process_tick(_tick_timer.wait_time)
	var status := status_line()
	_status_label.text = status
	if print_ticks:
		print(status)
	if engine.state == CombatEngine.State.FINISHED:
		_tick_timer.stop()
		_status_label.text = "%s\n%s" % [status, result_line()]
		if print_ticks:
			print(result_line())
		_result_timer.start()


func _mech_status(side: String, mech: BattleMech) -> String:
	var status := "%s HP %d/%d EN %d HEAT %d" % [side, mech.current_health, mech.max_hp, mech.current_energy, mech.heat]
	return status + " OFF" if mech.is_shut_down() else status


func _side_name(mech: BattleMech) -> String:
	return "Left" if mech == engine.left else "Right"
