class_name FighterView
extends Control
## A mech on the combat stage: its chassis sprite at [constant PIXEL_SCALE]x with each mounted
## weapon's sprite on its bay, facing the other side. The right side's mech is mirrored. It
## bobs while it stands, shakes and flashes when hit, greys out with a blinking OVERHEAT
## countdown while shut down, and once destroyed goes dark and topples back, marked DESTROYED.

## Screen pixels per sprite pixel.
const PIXEL_SCALE := 2
## Chassis sprites are this many pixels square.
const SPRITE_SIZE := 128
## The sprite row a mech's feet stand on, to place it on a pad.
const FEET_ROW := 123
## Weapons behind the body, like a far arm, are shaded this much.
const BEHIND_SHADE := Color(0.62, 0.62, 0.68)
## The idle bob: up this many screen pixels and back down, easing in and out, over BOB_TIME
## seconds.
const BOB_HEIGHT := 4.0
const BOB_TIME := 1.0
## A hit's shake, as the sideways offsets it steps through over SHAKE_TIME seconds, and its flash
## toward white, fading over FLASH_TIME.
const SHAKE_STEPS: Array[float] = [-8.0, 7.0, -4.0, 3.0, 0.0]
const SHAKE_TIME := 0.22
const FLASH := 0.8
const FLASH_TIME := 0.18
## A destroyed mech topples back this many degrees and sinks this many pixels, over FALL_TIME.
const FALL_DEGREES := 8.0
const FALL_DROP := 18.0
const FALL_TIME := 0.3
## The OVERHEAT countdown blinks with this period.
const BLINK_TIME := 0.8
const SHADER := preload("res://assets/shaders/mech_sprite.gdshader")

var mech: BattleMech
var left := true

# Pose holds the sprites unscaled, so it can shake and topple around the feet; the rig inside it
# scales them up, mirrors them, and bobs.
var _pose := Control.new()
var _rig := Control.new()
var _overheat := Label.new()
var _destroyed := Label.new()
var _material := ShaderMaterial.new()
var _weapon_sprites := {}
var _bob: Tween
var _shake: Tween
var _flash: Tween
var _blink: Tween
var _fallen := false
# The bob's height now, snapped to whole pixels as it moves the sprites.
var _bob_offset := 0.0:
	set(p_bob_offset):
		_bob_offset = p_bob_offset
		_rig.position.y = roundf(_bob_offset)
# The shake's sideways offset now, in whole pixels.
var _shake_offset := 0.0:
	set(p_shake_offset):
		_shake_offset = p_shake_offset
		_pose.position.x = roundf(_shake_offset)


func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	_material.shader = SHADER
	_pose.name = "Pose"
	_pose.mouse_filter = MOUSE_FILTER_IGNORE
	_pose.size = Vector2(SPRITE_SIZE, SPRITE_SIZE) * PIXEL_SCALE
	_pose.pivot_offset = Vector2(SPRITE_SIZE / 2.0, FEET_ROW) * PIXEL_SCALE
	add_child(_pose)
	_rig.name = "Rig"
	_rig.mouse_filter = MOUSE_FILTER_IGNORE
	_rig.material = _material
	_pose.add_child(_rig)
	_overheat.name = "Overheat"
	_style_label(_overheat, 16, Rect2(0, 8, SPRITE_SIZE * PIXEL_SCALE, 24))
	_destroyed.name = "Destroyed"
	_destroyed.text = "DESTROYED"
	_style_label(_destroyed, 32, Rect2(0, SPRITE_SIZE * PIXEL_SCALE * 0.3, SPRITE_SIZE * PIXEL_SCALE, 40))


## Shows [param p_mech], facing right on the [param p_left] side and left on the other.
func setup(p_mech: BattleMech, p_left: bool) -> void:
	mech = p_mech
	left = p_left
	for child in _rig.get_children():
		_rig.remove_child(child)
		child.queue_free()
	_weapon_sprites.clear()
	var mounted := mech.active_parts.filter(func(active: ActivePart) -> bool:
		return active.hardpoint != null and active.part.battle_sprite != null)
	for active: ActivePart in mounted.filter(func(active: ActivePart) -> bool: return active.hardpoint.battle_behind):
		_weapon_sprites[active] = _add_sprite(active.part.battle_sprite, active.hardpoint.battle_anchor, BEHIND_SHADE)
	if mech.chassis.battle_sprite:
		_add_sprite(mech.chassis.battle_sprite, Vector2i.ZERO, Color.WHITE)
	for active: ActivePart in mounted.filter(func(active: ActivePart) -> bool: return not active.hardpoint.battle_behind):
		_weapon_sprites[active] = _add_sprite(active.part.battle_sprite, active.hardpoint.battle_anchor, Color.WHITE)
	_rig.scale = Vector2(PIXEL_SCALE if left else -PIXEL_SCALE, PIXEL_SCALE)
	_rig.position = Vector2(0.0 if left else float(SPRITE_SIZE * PIXEL_SCALE), 0.0)
	refresh()
	_start_bob()


## Returns the sprite of [param active], a mounted weapon, or null.
func get_weapon_sprite(active: ActivePart) -> TextureRect:
	return _weapon_sprites.get(active)


## Returns where [param active]'s shots leave from, in the parent's coordinates: the front edge
## of its sprite, halfway down. Without a sprite, the mech's front at chest height.
func get_muzzle(active: ActivePart) -> Vector2:
	var sprite := get_weapon_sprite(active)
	var local := Vector2(SPRITE_SIZE, SPRITE_SIZE * 0.45)
	if sprite:
		local = sprite.position + Vector2(sprite.size.x, sprite.size.y / 2.0)
	return _to_parent(local)


## Returns the mech's middle, where shots land, in the parent's coordinates.
func get_center() -> Vector2:
	return _to_parent(Vector2(SPRITE_SIZE / 2.0, SPRITE_SIZE * 0.55))


## Returns the mech's middle as it stands at rest, whatever its bob, shake, or fall, in the
## parent's coordinates.
func get_rest_center() -> Vector2:
	return get_transform() * (Vector2(SPRITE_SIZE / 2.0, SPRITE_SIZE * 0.55) * PIXEL_SCALE)


## Updates the look for the mech's state: greyed with a blinking OVERHEAT countdown while shut
## down; dark, toppled, and marked DESTROYED once destroyed.
func refresh() -> void:
	if mech == null:
		return
	if is_destroyed():
		_material.set_shader_parameter("desaturate", 1.0)
		_material.set_shader_parameter("brightness", 0.45)
		_show_overheat(false)
		_fall()
	elif mech.is_shut_down():
		_material.set_shader_parameter("desaturate", 0.7)
		_material.set_shader_parameter("brightness", 0.7)
		_overheat.text = "OVERHEAT %.1fs" % mech.shutdown_left
		_show_overheat(true)
	else:
		_material.set_shader_parameter("desaturate", 0.0)
		_material.set_shader_parameter("brightness", 1.0)
		_show_overheat(false)


## Shakes the mech and flashes it white, as a shot lands. [param strength] scales both, so a
## light hit barely stirs it and a heavy one rocks it.
func hit(strength := 1.0) -> void:
	if not is_inside_tree():
		return
	if _shake:
		_shake.kill()
	_shake = create_tween()
	for step in SHAKE_STEPS:
		_shake.tween_property(self, "_shake_offset", step * strength, SHAKE_TIME / SHAKE_STEPS.size())
	if _flash:
		_flash.kill()
	var flash := FLASH * strength
	_material.set_shader_parameter("flash", flash)
	_flash = create_tween()
	_flash.tween_method(func(amount: float) -> void: _material.set_shader_parameter("flash", amount), flash, 0.0, FLASH_TIME) \
		.set_ease(Tween.EASE_OUT)


func is_destroyed() -> bool:
	return mech != null and mech.current_health <= 0


func get_shader_parameter(parameter: String) -> Variant:
	return _material.get_shader_parameter(parameter)


## Returns the OVERHEAT countdown's text while it shows, or "".
func get_overheat_text() -> String:
	return _overheat.text if _overheat.visible else ""


## Returns whether the DESTROYED mark shows.
func is_marked_destroyed() -> bool:
	return _destroyed.visible


func _get_minimum_size() -> Vector2:
	return Vector2(SPRITE_SIZE, SPRITE_SIZE) * PIXEL_SCALE


func _add_sprite(texture: Texture2D, at: Vector2i, shade: Color) -> TextureRect:
	var sprite := TextureRect.new()
	sprite.texture = texture
	sprite.position = Vector2(at)
	sprite.size = texture.get_size()
	sprite.modulate = shade
	sprite.use_parent_material = true
	sprite.mouse_filter = MOUSE_FILTER_IGNORE
	_rig.add_child(sprite)
	return sprite


func _style_label(label: Label, font_size: int, rect: Rect2) -> void:
	label.visible = false
	label.mouse_filter = MOUSE_FILTER_IGNORE
	label.position = rect.position
	label.size = rect.size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", CombatDraw.PIXEL_FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", CombatColors.DANGER)
	label.add_theme_color_override("font_outline_color", CombatColors.NIGHT)
	label.add_theme_constant_override("outline_size", 4 if font_size <= 16 else 8)
	add_child(label)


func _show_overheat(on: bool) -> void:
	if on == _overheat.visible:
		return
	_overheat.visible = on
	if _blink:
		_blink.kill()
		_blink = null
	_overheat.modulate.a = 1.0
	if on and is_inside_tree():
		_blink = create_tween().set_loops()
		_blink.tween_property(_overheat, "modulate:a", 0.3, 0.0).set_delay(BLINK_TIME / 2.0)
		_blink.tween_property(_overheat, "modulate:a", 1.0, 0.0).set_delay(BLINK_TIME / 2.0)


# Topples the mech back, away from the fight, once.
func _fall() -> void:
	if _fallen:
		return
	_fallen = true
	_stop_bob()
	_destroyed.visible = true
	var angle := deg_to_rad(-FALL_DEGREES if left else FALL_DEGREES)
	if not is_inside_tree():
		_pose.rotation = angle
		_pose.position.y = FALL_DROP
		return
	var fall := create_tween().set_parallel().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	fall.tween_property(_pose, "rotation", angle, FALL_TIME)
	fall.tween_property(_pose, "position:y", FALL_DROP, FALL_TIME)


# A smooth bob, up and back down. The right side starts at the top, so the two mechs bob half a
# beat apart.
func _start_bob() -> void:
	_stop_bob()
	if not is_inside_tree() or is_destroyed():
		return
	var start := 0.0 if left else -BOB_HEIGHT
	_bob_offset = start
	_bob = create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_bob.tween_property(self, "_bob_offset", -BOB_HEIGHT - start, BOB_TIME / 2.0)
	_bob.tween_property(self, "_bob_offset", start, BOB_TIME / 2.0)


func _to_parent(local: Vector2) -> Vector2:
	return get_transform() * (_pose.get_transform() * (_rig.get_transform() * local))


func _stop_bob() -> void:
	if _bob:
		_bob.kill()
		_bob = null
	_bob_offset = 0.0


func _enter_tree() -> void:
	if mech != null and _bob == null and not _fallen:
		_start_bob()
