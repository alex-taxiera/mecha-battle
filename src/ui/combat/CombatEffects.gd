class_name CombatEffects
extends Control
## The combat stage's effects layer, over the mechs: shots in flight, damage popups, and the
## storm's flash. Everything it makes frees itself when it's done.

## A missile's glow around its sprite, in pixels.
const GLOW := 3.0

# The storm's flash over the whole stage.
var _flash := ColorRect.new()


func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	_flash.mouse_filter = MOUSE_FILTER_IGNORE
	_flash.set_anchors_preset(PRESET_FULL_RECT)
	_flash.color = Color(CombatColors.STORM, 0.0)
	add_child(_flash)


## Sends a shot, drawn with [param texture] at 2x and tinted [param tint], from [param from] to
## [param to] over [param seconds], after [param delay]. [param flip] draws it facing left. Calls
## [param on_arrive] as it lands, then frees it. Returns the shot.
func shoot(texture: Texture2D, from: Vector2, to: Vector2, tint: Color, flip: bool, seconds: float,
		on_arrive: Callable, delay := 0.0) -> Control:
	var shot := TextureRect.new()
	shot.mouse_filter = MOUSE_FILTER_IGNORE
	shot.texture = texture
	shot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shot.stretch_mode = TextureRect.STRETCH_SCALE
	shot.flip_h = flip
	shot.size = (texture.get_size() if texture else Vector2(6, 2)) * FighterView.PIXEL_SCALE
	shot.modulate = tint
	var glow := ColorRect.new()
	glow.mouse_filter = MOUSE_FILTER_IGNORE
	glow.show_behind_parent = true
	glow.color = Color(1, 1, 1, 0.3)
	glow.position = -Vector2(GLOW, GLOW)
	glow.size = shot.size + Vector2(GLOW, GLOW) * 2.0
	shot.add_child(glow)
	shot.position = (from - shot.size / 2.0).round()
	shot.visible = delay <= 0.0
	add_child(shot)
	var flight := create_tween()
	if delay > 0.0:
		flight.tween_interval(delay)
		flight.tween_callback(func() -> void: shot.visible = true)
	flight.tween_property(shot, "position", (to - shot.size / 2.0).round(), seconds)
	flight.tween_callback(on_arrive)
	flight.tween_callback(shot.queue_free)
	return shot


## Pops [param text] up over [param at] in [param color], for [param seconds]. Returns the popup.
func popup(text: String, at: Vector2, color: Color, seconds: float, font_size := 24) -> DamagePopup:
	var pop := DamagePopup.new(text, color, font_size)
	add_child(pop)
	pop.play(at, seconds)
	return pop


## Flashes the whole stage [param color], fading over [param seconds].
func flash(color: Color, seconds: float) -> void:
	_flash.color = color
	create_tween().tween_property(_flash, "color:a", 0.0, seconds).set_ease(Tween.EASE_OUT)


## Returns the flash's strength now, 0 when there's none.
func get_flash_alpha() -> float:
	return _flash.color.a


## Returns the shots in flight and the popups showing.
func get_effects() -> Array[Node]:
	return get_children().filter(func(child: Node) -> bool: return child != _flash)
