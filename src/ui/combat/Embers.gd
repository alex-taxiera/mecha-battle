class_name Embers
extends CPUParticles2D
## Embers drifting up over the arena, after the mockup: small amber and orange squares that rise
## from the floor, drift sideways, and fade in and out over several seconds. Place it at the
## middle of the floor's bottom edge. It configures itself on entering the scene, so the scene
## never holds copies of its settings.

## How wide a strip of floor they rise from, in pixels.
const WIDTH := 1200.0


func _ready() -> void:
	amount = 16
	lifetime = 9.0
	lifetime_randomness = 0.35
	preprocess = 9.0
	emission_shape = EMISSION_SHAPE_RECTANGLE
	emission_rect_extents = Vector2(WIDTH / 2.0, 12.0)
	direction = Vector2(0, -1)
	spread = 10.0
	gravity = Vector2.ZERO
	initial_velocity_min = 40.0
	initial_velocity_max = 70.0
	scale_amount_min = 3.0
	scale_amount_max = 4.0
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0))
	fade.set_color(1, Color(1, 1, 1, 0))
	fade.add_point(0.1, Color(1, 1, 1, 0.9))
	fade.add_point(0.7, Color(1, 1, 1, 0.6))
	color_ramp = fade
	var hues := Gradient.new()
	hues.set_color(0, CombatColors.PLAYER)
	hues.set_color(1, Color("#ff7a59"))
	hues.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	color_initial_ramp = hues
	restart()
