class_name WeaponTag
extends Control
## One weapon's tag beside its mech, after the mockup: the bay it's in, its name in the side's
## accent, and a bar filling as its cooldown runs, colored by what it's doing. Right-aligned
## for the right side.

## What a weapon is doing, which colors its bar.
enum State {
	## Cooling down: the side's accent.
	CHARGING,
	## Ready to fire.
	READY,
	## Ready, but its mech can't pay for the shot.
	STARVED,
	## Its mech is shut down, or the weapon is switched off.
	OFFLINE,
}

const SLOT_SIZE := 8
const NAME_SIZE := 18
const BAR_HEIGHT := 5
## Seconds the muzzle flash takes to fade.
const FLASH_TIME := 0.35

@export var align_right := false:
	set(p_align_right):
		align_right = p_align_right
		queue_redraw()
@export var accent := CombatColors.PLAYER
## The bay's name, e.g. "LEFT ARM", and the weapon's, e.g. "Twin Gatling".
var slot_name := ""
var weapon_name := ""
## How far the cooldown has run, 0 to 1.
var charge := 0.0
var state := State.CHARGING
## Seconds the bar takes to fill up to a new charge. It drops at once when the weapon fires.
var smoothing := 0.1
## The charge as drawn, filling toward [member charge].
var shown_charge := 0.0:
	set(p_shown_charge):
		shown_charge = p_shown_charge
		queue_redraw()
## The muzzle flash's strength, 0 to 1.
var flash := 0.0:
	set(p_flash):
		flash = p_flash
		queue_redraw()

var _fill: Tween


func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE


## Returns what [param active], one of [param mech]'s weapons, is doing now.
static func state_of(mech: BattleMech, active: ActivePart) -> State:
	if mech.is_shut_down() or not active.is_active:
		return State.OFFLINE
	if mech.is_starved(active):
		return State.STARVED
	if active.current_cooldown == 0.0:
		return State.READY
	return State.CHARGING


func show_state(p_charge: float, p_state: State) -> void:
	var rising := p_charge > shown_charge
	charge = p_charge
	state = p_state
	if _fill:
		_fill.kill()
	if rising and is_inside_tree() and smoothing > 0.0:
		_fill = create_tween()
		_fill.tween_property(self, "shown_charge", charge, smoothing)
	else:
		shown_charge = charge
	queue_redraw()


## Flashes the tag, as the weapon fires.
func fire() -> void:
	flash = 1.0
	if is_inside_tree():
		create_tween().tween_property(self, "flash", 0.0, FLASH_TIME).set_ease(Tween.EASE_OUT)


func get_bar_color() -> Color:
	match state:
		State.OFFLINE:
			return CombatColors.DANGER
		State.STARVED:
			return CombatColors.ENERGY
		State.READY:
			return CombatColors.HP
	return accent


func _get_minimum_size() -> Vector2:
	return Vector2(200, 58)


func _draw() -> void:
	var back := Color(0.04, 0.047, 0.07, 0.55).lerp(Color(1.0, 0.82, 0.47, 0.45), flash)
	draw_rect(Rect2(Vector2.ZERO, size), back)
	var align := HORIZONTAL_ALIGNMENT_RIGHT if align_right else HORIZONTAL_ALIGNMENT_LEFT
	var inner := Rect2(10, 6, size.x - 20, size.y - 12)
	CombatDraw.text(self, CombatDraw.PIXEL_FONT, Rect2(inner.position, Vector2(inner.size.x, 12)), slot_name.to_upper(),
		SLOT_SIZE, CombatColors.DIM, 0, align)
	CombatDraw.text(self, CombatDraw.BODY_FONT, Rect2(inner.position + Vector2(0, 13), Vector2(inner.size.x, 22)), weapon_name,
		NAME_SIZE, accent, 1, align)
	var track := Rect2(inner.position.x, inner.end.y - BAR_HEIGHT, inner.size.x, BAR_HEIGHT)
	draw_rect(track, Color(0, 0, 0, 0.5))
	var bar := get_bar_color()
	if state == State.OFFLINE:
		bar.a = 0.6
	draw_rect(CombatDraw.fill_rect(track, shown_charge, align_right), bar)
