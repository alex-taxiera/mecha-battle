class_name CombatScreen
extends Control
## Plays a fight in real time on the arena stage, after the Claude Design mockup: both mechs on
## their pads with their energy, heat, and weapons, their health across the top, and the
## countdown to the storm. A looping 0.1-second timer drives a [CombatEngine]. Once the fight
## is over, the result panel comes up after a moment, and its button emits [signal finished].
## The fight's ticks also print to the output.

## Emitted when the player leaves the result panel. [param winner] is null for a draw.
signal finished(winner: BattleMech)

## The mech the player fights until there are real opponents, as [part id, origin] pairs on a
## training Bastion: a missile pod in its back bay, cooled by a heatsink touching the bay.
const DUMMY := [["missile_pod", Vector2i(1, -2)], ["heatsink", Vector2i(2, 0)]]
const DUMMY_CHASSIS := preload("res://resources/chassis/bastion.tres")
# Run on its own, the screen pits this stand-in for the player against the dummy, on the
# screen's Bastion: a missile pod overcharged by a reactor touching its bay, and a laser.
const DEMO_PLAYER := [["missile_pod", Vector2i(1, -2)], ["reactor", Vector2i(1, 0)], ["laser", Vector2i(1, 1)]]
## Seconds of fight each tick moves.
const TICK := 0.1

## The chassis the demo mechs are built on.
@export var chassis: MechChassis
## Adjacency rules for the demo mechs. Left empty, every SynergyRule in
## [constant ShopScreen.RULES_DIR] applies.
@export var rules: Array[SynergyRule] = []
## Prints each tick's health and energy, and the result, to the output.
@export var print_ticks := true

var engine: CombatEngine
## The run the fight belongs to, for the round and record. Null outside a run.
var run: RunState

# The winner once the fight is over; null for a draw.
var _winner: BattleMech

@onready var result_panel: ResultPanel = %ResultPanel
@onready var _tick_timer: Timer = %TickTimer
@onready var _result_timer: Timer = %ResultTimer
@onready var _left_fighter: FighterView = %LeftFighter
@onready var _right_fighter: FighterView = %RightFighter
@onready var _left_gauges: MechGauges = %LeftGauges
@onready var _right_gauges: MechGauges = %RightGauges
@onready var _left_weapons: WeaponTags = %LeftWeapons
@onready var _right_weapons: WeaponTags = %RightWeapons
@onready var _left_hp: HpBar = %LeftHp
@onready var _right_hp: HpBar = %RightHp
@onready var _round_badge: RoundBadge = %RoundBadge
@onready var _storm_timer: StormTimer = %StormTimer
@onready var _main_pcam: PhantomCamera2D = %MainPCam


func _ready() -> void:
	if engine == null:
		if rules.is_empty():
			rules.assign(ShopScreen.load_dir(ShopScreen.RULES_DIR).filter(func(resource: Resource) -> bool: return resource is SynergyRule))
		setup(build_mech(chassis, DEMO_PLAYER, rules), make_dummy(rules))
	_tick_timer.timeout.connect(_on_tick_timer_timeout)
	_result_timer.timeout.connect(_show_result)
	result_panel.return_pressed.connect(func() -> void: finished.emit(_winner))
	resized.connect(_center_camera)
	_center_camera()
	_bind()
	engine.start()
	_tick_timer.start()


func _exit_tree() -> void:
	# The camera leaves with the screen: the next screen starts from an unmoved view.
	get_viewport().canvas_transform = Transform2D.IDENTITY


## Sets the two mechs to fight: the player's on the left. Pass the [param p_run] the fight
## belongs to for its round and record. Call it before the screen enters the tree, or it
## fights the demo builds.
func setup(left: BattleMech, right: BattleMech, p_run: RunState = null) -> void:
	engine = CombatEngine.new(left, right)
	engine.battle_ended.connect(func(winner: BattleMech) -> void: _winner = winner)
	run = p_run


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


## Returns the result from the player's side, on the left: "VICTORY", "DEFEAT", or "DRAW", or
## "" while the fight is running.
func result_title() -> String:
	if engine.state != CombatEngine.State.FINISHED:
		return ""
	if _winner == null:
		return "DRAW"
	return "VICTORY" if _winner == engine.left else "DEFEAT"


## Returns the round and the run's record with this fight counted, e.g.
## "ROUND 3 · WINS 3 · LOSSES 1". Draws show once there are any.
func record_line() -> String:
	var round_number := run.round_number if run else 1
	var wins := run.wins if run else 0
	var losses := run.losses if run else 0
	var draws := run.draws if run else 0
	match result_title():
		"VICTORY":
			wins += 1
		"DEFEAT":
			losses += 1
		"DRAW":
			draws += 1
	var parts := ["ROUND %d" % round_number, "WINS %d" % wins, "LOSSES %d" % losses]
	if draws > 0:
		parts.append("DRAWS %d" % draws)
	return " · ".join(parts)


## Returns the player's numbers from the fight, as [label, value] rows for the result panel.
func result_rows() -> Array:
	var player := engine.left
	var top := player.get_top_weapon()
	return [
		["Battle duration", "%.1fs" % engine.elapsed],
		["Total damage dealt", "%d DMG" % player.damage_dealt],
		["MVP weapon", "%s · %d DMG" % [top.part.part_name, top.damage_dealt] if top else "—"],
	]


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
	engine.process_tick(TICK)
	_refresh()
	if print_ticks:
		print(status_line())
	if engine.state == CombatEngine.State.FINISHED:
		_tick_timer.stop()
		if print_ticks:
			print(result_line())
		_result_timer.start()


# Points every widget at the fight's mechs.
func _bind() -> void:
	for side in [[engine.left, true, _left_fighter, _left_weapons, _left_hp, "PLAYER"],
			[engine.right, false, _right_fighter, _right_weapons, _right_hp, "OPPONENT"]]:
		var mech: BattleMech = side[0]
		var left: bool = side[1]
		(side[2] as FighterView).setup(mech, left)
		(side[3] as WeaponTags).bind(mech, CombatColors.accent(left), not left)
		var hp: HpBar = side[4]
		hp.mech_name = mech.chassis.chassis_name.to_upper()
		hp.owner_text = side[5]
		hp.accent = CombatColors.accent(left)
		hp.mirrored = not left
	if run:
		_round_badge.set_record(run.round_number, run.wins, run.losses, run.draws)
	_set_smoothing(TICK)
	_refresh()


# Shows the fight as it is now.
func _refresh() -> void:
	for side in [[engine.left, _left_fighter, _left_gauges, _left_weapons, _left_hp],
			[engine.right, _right_fighter, _right_gauges, _right_weapons, _right_hp]]:
		var mech: BattleMech = side[0]
		(side[1] as FighterView).refresh()
		(side[2] as MechGauges).refresh(mech)
		(side[3] as WeaponTags).refresh()
		(side[4] as HpBar).set_health(mech.current_health, mech.max_hp)
	_storm_timer.set_countdown(engine.get_storm_countdown())


# Bars glide to each tick's values over [param seconds], the time until the next tick, so they
# move steadily instead of jumping.
func _set_smoothing(seconds: float) -> void:
	for bar: HpBar in [_left_hp, _right_hp]:
		bar.smoothing = seconds
	for gauges: MechGauges in [_left_gauges, _right_gauges]:
		gauges.smoothing = seconds
	for tags: WeaponTags in [_left_weapons, _right_weapons]:
		tags.smoothing = seconds


func _show_result() -> void:
	var colors := {"VICTORY": CombatColors.HP, "DEFEAT": CombatColors.DANGER, "DRAW": CombatColors.DIM}
	var title := result_title()
	result_panel.present(title, colors[title], record_line(), result_rows())


# The main camera frames the whole screen, whatever the window's shape.
func _center_camera() -> void:
	_main_pcam.position = size / 2.0


func _mech_status(side: String, mech: BattleMech) -> String:
	var status := "%s HP %d/%d EN %d HEAT %d" % [side, mech.current_health, mech.max_hp, mech.current_energy, mech.heat]
	return status + " OFF" if mech.is_shut_down() else status


func _side_name(mech: BattleMech) -> String:
	return "Left" if mech == engine.left else "Right"
