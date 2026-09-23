class_name FighterView
extends Control
## A mech on the combat stage: its chassis sprite at [constant PIXEL_SCALE]x with each mounted
## weapon's sprite on its bay, facing the other side. The right side's mech is mirrored. It
## bobs while it stands, greys out while shut down, and goes dark once destroyed.

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
const SHADER := preload("res://assets/shaders/mech_sprite.gdshader")

var mech: BattleMech
var left := true

# Holds the sprites, scaled up and mirrored; the bob moves it.
var _rig: Control
var _material := ShaderMaterial.new()
var _weapon_sprites := {}
var _bob: Tween
# The bob's height now, snapped to whole pixels as it moves the sprites.
var _bob_offset := 0.0:
	set(p_bob_offset):
		_bob_offset = p_bob_offset
		_rig.position.y = roundf(_bob_offset)


func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	_material.shader = SHADER
	_rig = Control.new()
	_rig.mouse_filter = MOUSE_FILTER_IGNORE
	_rig.material = _material
	add_child(_rig)


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


## Updates the sprite's look for the mech's state: greyed while shut down, dark once destroyed.
func refresh() -> void:
	if mech == null:
		return
	if is_destroyed():
		_material.set_shader_parameter("desaturate", 1.0)
		_material.set_shader_parameter("brightness", 0.45)
		_stop_bob()
	elif mech.is_shut_down():
		_material.set_shader_parameter("desaturate", 0.7)
		_material.set_shader_parameter("brightness", 0.7)
	else:
		_material.set_shader_parameter("desaturate", 0.0)
		_material.set_shader_parameter("brightness", 1.0)


func is_destroyed() -> bool:
	return mech != null and mech.current_health <= 0


func get_shader_parameter(parameter: String) -> Variant:
	return _material.get_shader_parameter(parameter)


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
	return get_transform() * (_rig.get_transform() * local)


func _stop_bob() -> void:
	if _bob:
		_bob.kill()
		_bob = null
	_bob_offset = 0.0


func _enter_tree() -> void:
	if mech != null and _bob == null:
		_start_bob()
