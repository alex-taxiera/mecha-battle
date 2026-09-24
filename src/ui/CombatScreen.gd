class_name CombatScreen
extends Control
## Plays a fight in real time on the arena stage, after the Claude Design mockup: both mechs on
## their pads with their energy, heat, and weapons, their health across the top, and the
## countdown to the storm. Shots fly between them and land with a shake, a flash, and a damage
## popup; heavy hits, meltdowns, and the KO shake the camera, and the KO slows time and punches
## in on the fallen mech. A looping timer drives a [CombatEngine] 0.1 seconds a tick; the
## player can pause it (also with Space), speed it up, or skip to the end. Once the fight is
## over, the result panel comes up after a moment, and its button emits [signal finished]. The
## fight's ticks also print to the output.

## Emitted when the player leaves the result panel. [param winner] is null for a draw.
signal finished(winner: BattleMech)

## The mech the player fights until there are real opponents, as [part id, origin] pairs on a
## training Bastion: a missile pod in its back bay, cooled by a heatsink touching the bay.
const DUMMY := [["missile_pod", Vector2i(1, -2)], ["heatsink", Vector2i(2, 0)]]
const DUMMY_CHASSIS := preload("res://resources/chassis/bastion.tres")
# Run on its own, the screen pits this stand-in for the player against the dummy, on the
# screen's Bastion: a missile pod overcharged by a reactor touching its bay, and a laser.
const DEMO_PLAYER := [["missile_pod", Vector2i(1, -2)], ["reactor", Vector2i(1, 0)], ["laser", Vector2i(1, 1)]]
## Seconds of fight each tick moves, whatever the playback speed.
const TICK := 0.1
## The playback speeds fast-forward steps through.
const SPEEDS: Array[int] = [1, 2, 4]
# Skipping stops after this many ticks, in case a fight could somehow never end.
const MAX_SKIP_TICKS := 100000
## Seconds a shot takes to cross the stage, and a popup lasts, at normal speed. Faster playback
## shortens both.
const FLIGHT_TIME := 0.25
const POPUP_TIME := 1.0
## Shots one weapon fires in the same tick, like an Overclock double shot, leave this far apart.
const SHOT_STAGGER := 0.08
## A weapon that hits this hard shakes the camera and rocks its target; lighter hits stir it at
## LIGHT_HIT strength.
const HEAVY_HIT := 30
const LIGHT_HIT := 0.4
## A mech gets at most one damage popup this often, in real seconds. Hits in between add up into
## the next one, so rapid fire and fast-forward stay readable.
const POPUP_GAP := 0.15
## The KO punch-in: how far the camera zooms in, over how many seconds. At 2x the zoomed view
## is small enough to center on either pad, and the 2x pixel art lands on a whole 4x.
const KO_ZOOM := 2.0
const KO_TIME := 0.5
## The KO slows time to this share of normal speed for KO_SLOW_TIME real seconds, then eases back
## over KO_RECOVER_TIME, so the fall and the punch-in play out. The result panel waits for it:
## the ResultTimer counts real seconds.
const KO_SLOW_MO := 0.3
const KO_SLOW_TIME := 1.2
const KO_RECOVER_TIME := 0.4

## The chassis the demo mechs are built on.
@export var chassis: MechChassis
## Adjacency rules for the demo mechs. Left empty, every SynergyRule in
## [constant LoadoutScreen.RULES_DIR] applies.
@export var rules: Array[SynergyRule] = []
## Prints each tick's health and energy, and the result, to the output.
@export var print_ticks := true

var engine: CombatEngine
## The run the fight belongs to, for where it is and the fights won. Null outside a run.
var run: RunState
## Whether the fight is paused, and how many times normal speed it plays at.
var paused := false
var speed := 1

# The winner once the fight is over; null for a draw.
var _winner: BattleMech
# Off while skipping, so a skipped fight plays no effects.
var _animate := true
# How many shots each weapon has fired this tick, to stagger an Overclock double shot.
var _shots_this_tick := {}
var _rng := RandomNumberGenerator.new()
# Damage and blocks landed on each mech since its last popup: mech -> [damage, blocked, color].
var _pending_popups := {}
# When each mech's last popup went up, in milliseconds.
var _last_popup := {}
# Camera shakes: a small one for heavy hits and storm strikes, a big one for meltdowns and KOs.
var _small_shake: PhantomCameraNoiseEmitter2D
var _big_shake: PhantomCameraNoiseEmitter2D

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
@onready var _ko_pcam: PhantomCamera2D = %KoPCam
@onready var _stage: Control = %Stage
@onready var _effects: CombatEffects = %Effects
@onready var _playback: PlaybackControls = %Playback
@onready var _playback_label: Label = %PlaybackLabel


func _ready() -> void:
	if engine == null:
		if rules.is_empty():
			rules.assign(LoadoutScreen.load_dir(LoadoutScreen.RULES_DIR).filter(func(resource: Resource) -> bool: return resource is SynergyRule))
		setup(build_mech(chassis, DEMO_PLAYER, rules), make_dummy(rules))
	_tick_timer.timeout.connect(_on_tick_timer_timeout)
	_result_timer.timeout.connect(_show_result)
	result_panel.return_pressed.connect(func() -> void: finished.emit(_winner))
	_playback.pause_pressed.connect(toggle_pause)
	_playback.speed_pressed.connect(cycle_speed)
	_playback.skip_pressed.connect(skip)
	engine.weapon_fired.connect(_on_weapon_fired)
	engine.meltdown.connect(_on_meltdown)
	engine.storm_struck.connect(_on_storm_struck)
	engine.reflected.connect(_on_reflected)
	engine.shield_collapsed.connect(_on_shield_collapsed)
	engine.battle_ended.connect(_on_battle_ended)
	for mech: BattleMech in [engine.left, engine.right]:
		mech.relic_triggered.connect(_on_relic_triggered.bind(mech))
		mech.part_triggered.connect(_on_part_triggered.bind(mech))
		mech.status_added.connect(_on_status_added.bind(mech))
		mech.status_overflowed.connect(_on_status_overflowed.bind(mech))
	_rng.randomize()
	_set_up_camera()
	resized.connect(_center_camera)
	_center_camera()
	_bind()
	engine.start()
	_tick_timer.start()


func _exit_tree() -> void:
	# The camera leaves with the screen: the next screen starts from an unmoved view, at full
	# speed.
	get_viewport().canvas_transform = Transform2D.IDENTITY
	Engine.time_scale = 1.0


## Sets the two mechs to fight: the player's on the left. Pass the [param p_run] the fight
## belongs to for where it is and the fights won. Call it before the screen enters the tree, or it
## fights the demo builds.
func setup(left: BattleMech, right: BattleMech, p_run: RunState = null) -> void:
	engine = CombatEngine.new(left, right)
	engine.battle_ended.connect(func(winner: BattleMech) -> void: _winner = winner)
	run = p_run


## Pauses a running fight, or resumes a paused one. Does nothing once the fight is over.
func toggle_pause() -> void:
	if is_over():
		return
	paused = not paused
	_tick_timer.paused = paused
	_show_playback()


## Steps to the next speed in [constant SPEEDS], after the fastest back to 1x. Ticks come faster,
## but each still moves the fight [constant TICK] seconds, so speed never changes a fight.
func cycle_speed() -> void:
	if is_over():
		return
	speed = SPEEDS[(SPEEDS.find(speed) + 1) % SPEEDS.size()]
	_tick_timer.wait_time = TICK / speed
	_set_smoothing(TICK / speed)
	_show_playback()


## Plays the rest of the fight at once and brings up the result.
func skip() -> void:
	if is_over():
		return
	var ticks := 0
	_animate = false
	while engine.state == CombatEngine.State.RUNNING and ticks < MAX_SKIP_TICKS:
		engine.process_tick(TICK)
		ticks += 1
	_animate = true
	_refresh()
	if is_over():
		_end_fight()
		_show_result()


func is_over() -> bool:
	return engine.state == CombatEngine.State.FINISHED


## Returns what the line under the timer says: "BATTLE OVER", "PAUSED", "FAST FORWARD 2X", or
## nothing while the fight plays at normal speed.
func get_playback_text() -> String:
	if is_over():
		return "BATTLE OVER"
	if paused:
		return "PAUSED"
	return "FAST FORWARD %dX" % speed if speed > 1 else ""


## Returns the camera shake for heavy hits and storm strikes, and the one for meltdowns and KOs.
func get_small_shake() -> PhantomCameraNoiseEmitter2D:
	return _small_shake


func get_big_shake() -> PhantomCameraNoiseEmitter2D:
	return _big_shake


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


## Returns where the fight is in the run and the fights won with this one counted, e.g.
## "SECTOR 1 · FLOOR 5 · WINS 3". Outside a run, it's sector 1 with only this fight.
func record_line() -> String:
	var wins := run.fights_won if run else 0
	if result_title() == "VICTORY":
		wins += 1
	var parts := ["SECTOR %d" % _sector()]
	var floor_number := run.get_floor_number() if run else 0
	if floor_number > 0:
		parts.append("FLOOR %d" % floor_number)
	parts.append("WINS %d" % wins)
	return " · ".join(parts)


## Returns the player's numbers from the fight, as [label, value] rows for the result panel.
func result_rows() -> Array:
	var player := engine.left
	var top := player.get_top_weapon()
	return [
		["Battle duration", "%.1fs" % engine.elapsed],
		["Total damage dealt", "%d DMG" % player.damage_dealt],
		["MVP weapon", "%s · %d DMG" % [top.part.get_display_name(), top.damage_dealt] if top else "—"],
	]


## Returns a mech built on [param p_chassis] from [param lineup], [part id, origin] pairs of
## part files in [constant LoadoutScreen.PARTS_DIR], fighting with [param p_rules]' link bonuses.
static func build_mech(p_chassis: MechChassis, lineup: Array, p_rules: Array[SynergyRule]) -> BattleMech:
	var grid := MechGridData.new(p_chassis)
	for entry in lineup:
		var part: MechPart = load(LoadoutScreen.PARTS_DIR.path_join("%s.tres" % entry[0]))
		if not grid.place_part(part, entry[1]):
			push_error("CombatScreen: can't place %s at %s" % [entry[0], entry[1]])
	return BattleMech.new(grid, p_rules)


## Returns the [constant DUMMY] build on [constant DUMMY_CHASSIS].
static func make_dummy(p_rules: Array[SynergyRule]) -> BattleMech:
	return build_mech(DUMMY_CHASSIS, DUMMY, p_rules)


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.keycode == KEY_SPACE and not is_over():
		toggle_pause()
		get_viewport().set_input_as_handled()


func _on_tick_timer_timeout() -> void:
	_shots_this_tick.clear()
	engine.process_tick(TICK)
	_refresh()
	if print_ticks:
		print(status_line())
	if is_over():
		_end_fight()
		_result_timer.start()


# Stops the ticks once the fight is over and turns the playback controls off.
func _end_fight() -> void:
	_tick_timer.stop()
	_storm_timer.running = false
	paused = false
	_tick_timer.paused = false
	_show_playback()
	if print_ticks:
		print(result_line())


func _show_playback() -> void:
	_playback.show_state(paused, speed, is_over())
	_playback_label.text = get_playback_text()


# Points every widget at the fight's mechs.
func _bind() -> void:
	for side in [[engine.left, true, _left_fighter, _left_weapons, _left_hp, "PLAYER"],
			[engine.right, false, _right_fighter, _right_weapons, _right_hp, "OPPONENT"]]:
		var mech: BattleMech = side[0]
		var left: bool = side[1]
		(side[2] as FighterView).setup(mech, left)
		(side[3] as WeaponTags).bind(mech, CombatColors.accent(left), not left)
		var hp: HpBar = side[4]
		hp.mech_name = mech.mech_name.to_upper()
		hp.owner_text = side[5]
		hp.accent = CombatColors.accent(left)
		hp.mirrored = not left
	if run:
		_round_badge.set_progress(_sector(), run.get_floor_number(), run.fights_won, _tier_tag())
	_set_smoothing(TICK)
	_show_playback()
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
		(side[4] as HpBar).set_shield(mech.shield, mech.max_shield)
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


# Both cameras take the shakes, and the camera eases over to the KO camera when it takes over.
func _set_up_camera() -> void:
	_main_pcam.noise_emitter_layer = 1
	_ko_pcam.noise_emitter_layer = 1
	var punch_in := PhantomCameraTween.new()
	punch_in.duration = KO_TIME
	punch_in.transition = PhantomCameraTween.TransitionType.SINE
	punch_in.ease = PhantomCameraTween.EaseType.EASE_IN_OUT
	_ko_pcam.tween_resource = punch_in
	_small_shake = _shaker(4.0, 0.1, 0.15)
	_big_shake = _shaker(10.0, 0.2, 0.35)


func _shaker(amplitude: float, duration: float, decay: float) -> PhantomCameraNoiseEmitter2D:
	var noise := PhantomCameraNoise2D.new()
	noise.amplitude = amplitude
	noise.frequency = 12.0
	var emitter := PhantomCameraNoiseEmitter2D.new()
	emitter.noise = noise
	emitter.duration = duration
	emitter.decay_time = decay
	emitter.noise_emitter_layer = 1
	add_child(emitter)
	return emitter


# A shot flies from the weapon's muzzle to the target, tinted by the shooter's side, and lands a
# moment later. The engine has already counted its damage; the effects follow it.
func _on_weapon_fired(attacker: BattleMech, weapon: ActivePart, target: BattleMech, damage: int) -> void:
	if not _animate:
		return
	var left := attacker == engine.left
	var tag := _weapons_of(attacker).get_tag(weapon)
	if tag:
		tag.fire()
	var nth: int = _shots_this_tick.get(weapon, 0)
	_shots_this_tick[weapon] = nth + 1
	var to := _fighter_of(target).get_center() + Vector2(0, _rng.randf_range(-24.0, 24.0))
	var tint := CombatColors.accent(left).lerp(Color.WHITE, 0.25)
	# The engine emits right after the hit, so the target's shield share is this shot's.
	var landed := _land_shot.bind(target, damage - target.last_absorbed, weapon.last_shot - damage, weapon.last_shot >= HEAVY_HIT,
		target.last_absorbed)
	_effects.shoot(weapon.part.projectile_sprite, _fighter_of(attacker).get_muzzle(weapon), to, tint, not left,
		FLIGHT_TIME / speed, landed, nth * SHOT_STAGGER / speed)


func _land_shot(target: BattleMech, damage: int, blocked: int, heavy: bool, shielded: int) -> void:
	_fighter_of(target).hit(1.0 if heavy else LIGHT_HIT)
	_pop_damage(target, damage, blocked, _hit_color(target), shielded)
	if heavy:
		_small_shake.emit()


# Adds a hit to [param target]'s next popup: [param damage] to the hull, [param blocked] by plating,
# and [param shielded] by its shield. Popups go up once a frame, so hits landing together share one.
func _pop_damage(target: BattleMech, damage: int, blocked: int, color: Color, shielded := 0) -> void:
	var pending: Array = _pending_popups.get(target, [0, 0, color, 0])
	pending[0] += damage
	pending[1] += blocked
	pending[3] += shielded
	pending[2] = color
	_pending_popups[target] = pending


# Shows [param target]'s summed damage, with what plating blocked and its shield soaked up just
# under it, once its last
# popup is POPUP_GAP old.
func _flush_popup(target: BattleMech) -> void:
	var now := Time.get_ticks_msec()
	if not _pending_popups.has(target) or now - _last_popup.get(target, -100000) < POPUP_GAP * 1000.0:
		return
	var pending: Array = _pending_popups[target]
	_pending_popups.erase(target)
	_last_popup[target] = now
	var spot := _popup_spot(_fighter_of(target))
	if pending[0] > 0:
		_effects.popup("-%d" % pending[0], spot, pending[2], _popup_time())
	if pending[1] > 0:
		_effects.popup("BLOCK %d" % pending[1], spot + Vector2(0, 24), CombatColors.FRAME, _popup_time(), 16)
	if pending[3] > 0:
		var below := 48 if pending[1] > 0 else 24
		_effects.popup("SHIELD %d" % pending[3], spot + Vector2(0, below), CombatColors.SHIELD, _popup_time(), 16)


# Each mech's hits since its last popup go up together, once the gap has passed.
func _process(_delta: float) -> void:
	for target: BattleMech in _pending_popups.keys():
		_flush_popup(target)


func _on_meltdown(_mech: BattleMech, target: BattleMech, damage: int) -> void:
	if not _animate:
		return
	var view := _fighter_of(target)
	view.hit()
	_effects.popup("MELTDOWN -%d" % damage, _popup_spot(view), CombatColors.DANGER, _popup_time())
	_big_shake.emit()


# Each strike flashes the stage and hits both mechs, through any plating.
func _on_storm_struck(_damage: int) -> void:
	if not _animate:
		return
	_effects.flash(Color(CombatColors.STORM, 0.35), 0.25)
	for mech: BattleMech in [engine.left, engine.right]:
		_fighter_of(mech).hit(LIGHT_HIT)
		_pop_damage(mech, mech.last_taken - mech.last_absorbed, 0, CombatColors.STORM, mech.last_absorbed)
	_small_shake.emit()


# Armor dealing damage back: the attacker flinches and takes it like any hit.
func _on_reflected(_source: BattleMech, target: BattleMech, damage: int) -> void:
	if not _animate:
		return
	_fighter_of(target).hit(LIGHT_HIT)
	_pop_damage(target, damage - target.last_absorbed, 0, _hit_color(target), target.last_absorbed)


# A mech that can't pay its shield's upkeep loses it for the fight.
func _on_shield_collapsed(mech: BattleMech) -> void:
	if not _animate:
		return
	var view := _fighter_of(mech)
	_effects.popup("SHIELD DOWN", view.position + Vector2(view.size.x / 2.0, 24), CombatColors.DANGER, _popup_time(), 16)


# A part's ability acting for the first time in the fight pops its name up, like a relic's.
func _on_part_triggered(active: ActivePart, mech: BattleMech) -> void:
	if not _animate:
		return
	var view := _fighter_of(mech)
	_effects.popup(active.part.part_name.to_upper(), view.position + Vector2(view.size.x / 2.0, 0), CombatColors.TAG, _popup_time(), 16)


# A status a mech didn't have pops its name up in its color; after that its icon under the
# gauges keeps count, so a fast weapon stacking it doesn't fill the stage with popups.
func _on_status_added(status: ActiveStatus, amount: int, mech: BattleMech) -> void:
	if not _animate or status.charges != amount:
		return
	var view := _fighter_of(mech)
	_effects.popup(status.data.status_name.to_upper(), view.position + Vector2(view.size.x / 2.0, 48), status.data.color,
		_popup_time(), 16)


# A status wrapping past its top pops its own line, e.g. SHIELD STRIPPED.
func _on_status_overflowed(status: ActiveStatus, _times: int, mech: BattleMech) -> void:
	if not _animate or status.data.overflow_text.is_empty():
		return
	var view := _fighter_of(mech)
	_effects.popup(status.data.overflow_text, view.position + Vector2(view.size.x / 2.0, 24), status.data.color,
		_popup_time(), 16)
	_small_shake.emit()


# A relic that acts pops its name up over its mech, in the tag yellow.
func _on_relic_triggered(relic: Relic, mech: BattleMech) -> void:
	if not _animate:
		return
	var view := _fighter_of(mech)
	_effects.popup(relic.relic_name.to_upper(), view.position + Vector2(view.size.x / 2.0, 0), CombatColors.TAG, _popup_time(), 16)


# The camera shakes hard and punches in on the fallen mech, or between them on a draw.
func _on_battle_ended(winner: BattleMech) -> void:
	if not _animate:
		return
	_big_shake.emit()
	var focus := (_left_fighter.get_rest_center() + _right_fighter.get_rest_center()) / 2.0
	if winner != null:
		focus = _fighter_of(engine.right if winner == engine.left else engine.left).get_rest_center()
	_ko_pcam.position = get_ko_focus(_stage.position + focus)
	_ko_pcam.zoom = Vector2.ONE * KO_ZOOM
	_ko_pcam.priority = _main_pcam.priority + 10
	_slow_time()


# Slows everything to KO_SLOW_MO, then eases back to full speed, on real time so the slowdown
# doesn't stretch itself.
func _slow_time() -> void:
	Engine.time_scale = KO_SLOW_MO
	var recover := create_tween().set_ignore_time_scale(true)
	recover.tween_interval(KO_SLOW_TIME)
	recover.tween_method(func(rate: float) -> void: Engine.time_scale = rate, KO_SLOW_MO, 1.0, KO_RECOVER_TIME) \
		.set_ease(Tween.EASE_IN)


## Returns where the KO camera centers to punch in on [param point]: as close to it as the zoomed
## view can get while staying inside the stage, so the stage's edges never show. Along an axis
## where the view is bigger than the stage, it centers on the stage.
func get_ko_focus(point: Vector2) -> Vector2:
	var half := size / (2.0 * KO_ZOOM)
	var stage := Rect2(_stage.position, _stage.size)
	var focus := point
	for axis in 2:
		var low := stage.position[axis] + half[axis]
		var high := stage.end[axis] - half[axis]
		focus[axis] = clampf(point[axis], low, high) if low <= high else stage.get_center()[axis]
	return focus


# A random spot over the top of a mech's body.
func _popup_spot(view: FighterView) -> Vector2:
	var box := Rect2(view.position, view.size)
	return box.position + box.size * Vector2(_rng.randf_range(0.28, 0.72), _rng.randf_range(0.08, 0.38))


# Hits on the opponent pop up in the player's accent, hits on the player in pink.
func _hit_color(target: BattleMech) -> Color:
	return CombatColors.HIT_ON_OPPONENT if target == engine.right else CombatColors.HIT_ON_PLAYER


func _popup_time() -> float:
	return maxf(0.5, POPUP_TIME / speed)


func _fighter_of(mech: BattleMech) -> FighterView:
	return _left_fighter if mech == engine.left else _right_fighter


func _weapons_of(mech: BattleMech) -> WeaponTags:
	return _left_weapons if mech == engine.left else _right_weapons


func _mech_status(side: String, mech: BattleMech) -> String:
	var status := "%s HP %d/%d EN %d HEAT %d" % [side, mech.current_health, mech.max_hp, mech.current_energy, mech.heat]
	return status + " OFF" if mech.is_shut_down() else status


# "ELITE" or "BOSS" for those fights on the map, otherwise "".
func _tier_tag() -> String:
	var node := run.map.current if run and run.map else null
	if node == null or node.type not in [MapNode.Type.ELITE, MapNode.Type.BOSS]:
		return ""
	return MapNode.Type.keys()[node.type]


# The run's sector, counting from 1; 1 outside a run.
func _sector() -> int:
	return run.act_index + 1 if run else 1


func _side_name(mech: BattleMech) -> String:
	return "Left" if mech == engine.left else "Right"
