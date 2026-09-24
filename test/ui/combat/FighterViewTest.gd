class_name FighterViewTest
extends GdUnitTestSuite

const __source: String = "res://src/ui/combat/FighterView.gd"
const Fixtures := preload("res://test/TestFixtures.gd")

var _body: Texture2D
var _left_gun: MechPart
var _right_gun: MechPart
var _pod: MechPart


func before_test() -> void:
	_body = _texture(128, 128)
	_left_gun = _gun()
	_right_gun = _gun()
	_pod = Fixtures.missile_pod() # no sprite


func test_draws_each_mounted_weapon_behind_or_in_front_of_the_body() -> void:
	var view: FighterView = auto_free(FighterView.new())
	var mech := _mech()
	view.setup(mech, true)
	var behind := view.get_weapon_sprite(_active(mech, _left_gun))
	var front := view.get_weapon_sprite(_active(mech, _right_gun))
	# Each weapon sits at its bay's anchor, in sprite pixels.
	assert_that(behind.position).is_equal(Vector2(86, 50))
	assert_that(front.position).is_equal(Vector2(98, 63))
	assert_that(behind.modulate).is_equal(FighterView.BEHIND_SHADE)
	assert_that(front.modulate).is_equal(Color.WHITE)
	# The far arm's gun, the body, then the near arm's gun; the pod has no sprite.
	var sprites := _sprites(view)
	assert_array(sprites).has_size(3)
	assert_object(sprites[0]).is_same(behind)
	assert_object(sprites[1].texture).is_same(_body)
	assert_object(sprites[2]).is_same(front)
	assert_object(view.get_weapon_sprite(_active(mech, _pod))).is_null()


func test_each_side_faces_the_other() -> void:
	var left: FighterView = auto_free(FighterView.new())
	var right: FighterView = auto_free(FighterView.new())
	var mech := _mech()
	left.setup(mech, true)
	right.setup(mech, false)
	var gun := _active(mech, _right_gun)
	# Shots leave from the gun's front edge, at 2x: (98 + 40) × 2 on the left.
	assert_that(left.get_muzzle(gun)).is_equal(Vector2(276, 144))
	assert_float(left.get_muzzle(gun).x).is_greater(left.get_center().x)
	# The right side is mirrored inside the same 256-pixel box.
	assert_that(right.get_muzzle(gun)).is_equal(Vector2(256 - 276, 144))
	assert_float(right.get_muzzle(gun).x).is_less(right.get_center().x)
	# At rest, before any bob or shake, the middle is the same on both sides.
	assert_vector(left.get_rest_center()).is_equal_approx(Vector2(128, 140.8), Vector2(0.01, 0.01))
	assert_vector(right.get_rest_center()).is_equal_approx(left.get_rest_center(), Vector2(0.01, 0.01))


func test_greys_out_while_shut_down_and_darkens_once_destroyed() -> void:
	var view: FighterView = auto_free(FighterView.new())
	var mech := _mech()
	view.setup(mech, true)
	assert_float(view.get_shader_parameter("desaturate")).is_equal(0.0)
	assert_float(view.get_shader_parameter("brightness")).is_equal(1.0)
	assert_str(view.get_overheat_text()).is_empty()
	mech.shutdown_left = 2.4
	view.refresh()
	assert_float(view.get_shader_parameter("desaturate")).is_equal(0.7)
	assert_float(view.get_shader_parameter("brightness")).is_equal(0.7)
	assert_str(view.get_overheat_text()).is_equal("OVERHEAT 2.4s")
	mech.current_health = 0
	view.refresh()
	assert_bool(view.is_destroyed()).is_true()
	assert_float(view.get_shader_parameter("desaturate")).is_equal(1.0)
	assert_float(view.get_shader_parameter("brightness")).is_equal(0.45)
	assert_str(view.get_overheat_text()).is_empty()
	assert_bool(view.is_marked_destroyed()).is_true()
	# Out of the tree it's already toppled back, away from the fight.
	var pose: Control = view.get_node("Pose")
	assert_float(pose.rotation_degrees).is_equal_approx(-FighterView.FALL_DEGREES, 1e-3)
	assert_float(pose.position.y).is_equal(FighterView.FALL_DROP)


func test_a_mech_without_sprites_draws_nothing() -> void:
	var view: FighterView = auto_free(FighterView.new())
	var mech := BattleMech.new(MechGridData.new(Fixtures.cross_chassis()))
	view.setup(mech, false)
	assert_array(_sprites(view)).is_empty()
	# Shots still have somewhere to leave from.
	assert_vector(view.get_muzzle(null)).is_equal_approx(Vector2(0, 115.2), Vector2(0.01, 0.01))


func test_bobs_in_the_tree_until_destroyed() -> void:
	var view: FighterView = auto_free(FighterView.new())
	var mech := _mech()
	add_child(view)
	view.setup(mech, true)
	var rig: Control = view.get_node("Pose/Rig")
	assert_float(rig.position.y).is_equal(0.0)
	# A quarter of the way in it's on its way up, on a whole pixel.
	await await_millis(int(FighterView.BOB_TIME * 250))
	assert_float(rig.position.y).is_less(0.0).is_greater_equal(-FighterView.BOB_HEIGHT)
	assert_float(rig.position.y).is_equal(roundf(rig.position.y))
	mech.current_health = 0
	view.refresh()
	assert_float(rig.position.y).is_equal(0.0)


func test_a_hit_shakes_and_flashes_the_mech() -> void:
	var view: FighterView = auto_free(FighterView.new())
	add_child(view)
	view.setup(_mech(), true)
	var pose: Control = view.get_node("Pose")
	view.hit()
	assert_float(view.get_shader_parameter("flash")).is_equal(FighterView.FLASH)
	# The shake swings through 0 between its steps, so a single sample can catch it centered;
	# watch every frame of it instead.
	var widest := 0.0
	var until := Time.get_ticks_msec() + int(FighterView.SHAKE_TIME * 1000)
	while Time.get_ticks_msec() < until:
		await get_tree().process_frame
		widest = maxf(widest, absf(pose.position.x))
	assert_float(widest).append_failure_message("the pose never moved during the shake").is_greater(0.0)
	assert_float(widest).is_less_equal(absf(FighterView.SHAKE_STEPS[0]))
	# Both settle once the hit is over (with room for the tween starting a frame late).
	await await_millis(200)
	assert_float(pose.position.x).is_equal(0.0)
	assert_float(view.get_shader_parameter("flash")).is_equal_approx(0.0, 1e-3)
	# A lighter hit flashes less.
	view.hit(0.4)
	assert_float(view.get_shader_parameter("flash")).is_equal_approx(FighterView.FLASH * 0.4, 1e-6)
	await await_millis(int(FighterView.SHAKE_TIME * 1000) + 100)


func test_a_destroyed_mech_topples_away_from_the_fight() -> void:
	var left: FighterView = auto_free(FighterView.new())
	var right: FighterView = auto_free(FighterView.new())
	add_child(left)
	add_child(right)
	var left_mech := _mech()
	var right_mech := _mech()
	left.setup(left_mech, true)
	right.setup(right_mech, false)
	left_mech.current_health = 0
	right_mech.current_health = 0
	left.refresh()
	right.refresh()
	await await_millis(int(FighterView.FALL_TIME * 1000) + 150)
	# Each falls back toward its own edge of the stage, and sinks.
	assert_float((left.get_node("Pose") as Control).rotation_degrees).is_equal_approx(-FighterView.FALL_DEGREES, 1e-3)
	assert_float((right.get_node("Pose") as Control).rotation_degrees).is_equal_approx(FighterView.FALL_DEGREES, 1e-3)
	assert_float((right.get_node("Pose") as Control).position.y).is_equal_approx(FighterView.FALL_DROP, 1e-3)
	assert_bool(right.is_marked_destroyed()).is_true()


# The armed cross with sprites: a gatling in each arm, the left one behind the body, and a pod
# with no sprite on its back.
func _mech() -> BattleMech:
	var chassis := Fixtures.armed_cross()
	chassis.battle_sprite = _body
	chassis.hardpoints[0].battle_anchor = Vector2i(86, 50)
	chassis.hardpoints[0].battle_behind = true
	chassis.hardpoints[1].battle_anchor = Vector2i(98, 63)
	var grid := MechGridData.new(chassis)
	assert_bool(grid.place_part(_left_gun, Vector2i(-1, 1))).is_true()
	assert_bool(grid.place_part(_right_gun, Vector2i(4, 1))).is_true()
	assert_bool(grid.place_part(_pod, Vector2i(1, -2))).is_true()
	return BattleMech.new(grid)


func _gun() -> MechPart:
	var gatling := Fixtures.gatling()
	gatling.battle_sprite = _texture(40, 18)
	return gatling


func _texture(width: int, height: int) -> Texture2D:
	return ImageTexture.create_from_image(Image.create(width, height, false, Image.FORMAT_RGBA8))


func _sprites(view: FighterView) -> Array:
	return view.get_node("Pose/Rig").get_children()


func _active(mech: BattleMech, part: MechPart) -> ActivePart:
	for active in mech.active_parts:
		if active.part == part:
			return active
	return null
