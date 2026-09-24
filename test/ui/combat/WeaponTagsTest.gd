class_name WeaponTagsTest
extends GdUnitTestSuite

const __source: String = "res://src/ui/combat/WeaponTags.gd"
const Fixtures := preload("res://test/TestFixtures.gd")

var _gatling: MechPart
var _pod: MechPart
var _mech: BattleMech


func before_test() -> void:
	_gatling = Fixtures.gatling() # 3 energy a shot
	_gatling.cooldown_max = 2.0
	_pod = Fixtures.missile_pod()
	_pod.cooldown_max = 1.0
	var grid := MechGridData.new(Fixtures.armed_cross())
	assert_bool(grid.place_part(_gatling, Vector2i(-1, 1))).is_true()
	assert_bool(grid.place_part(Fixtures.laser(), Vector2i(1, 1))).is_true()
	assert_bool(grid.place_part(_pod, Vector2i(1, -2))).is_true()
	_mech = BattleMech.new(grid)


func test_one_tag_per_weapon_in_placement_order() -> void:
	var tags: WeaponTags = auto_free(WeaponTags.new())
	tags.bind(_mech, CombatColors.OPPONENT, true)
	var shown := tags.get_tags()
	assert_array(shown).has_size(2) # the laser isn't a weapon
	assert_str(shown[0].weapon_name).is_equal("Twin Gatling")
	assert_str(shown[0].slot_name).is_equal("Left Arm")
	assert_str(shown[1].weapon_name).is_equal("Missile Pod")
	assert_str(shown[1].slot_name).is_equal("Back")
	for tag in shown:
		assert_bool(tag.align_right).is_true()
		assert_that(tag.accent).is_equal(CombatColors.OPPONENT)
	assert_object(tags.get_tag(_active(_gatling))).is_same(shown[0])
	# Binding again replaces them.
	tags.bind(_mech, CombatColors.PLAYER, false)
	assert_array(tags.get_tags()).has_size(2)


func test_tags_show_charge_and_state() -> void:
	var tags: WeaponTags = auto_free(WeaponTags.new())
	tags.bind(_mech, CombatColors.PLAYER, false)
	var gun := _active(_gatling)
	var tag := tags.get_tag(gun)
	# A fight starts with every cooldown full.
	assert_float(tag.charge).is_equal(0.0)
	assert_int(tag.state).is_equal(WeaponTag.State.CHARGING)
	assert_that(tag.get_bar_color()).is_equal(CombatColors.PLAYER)
	gun.current_cooldown = 0.5
	tags.refresh()
	assert_float(tag.charge).is_equal(0.75)
	# Ready with no energy to pay: starved. With enough: ready.
	gun.current_cooldown = 0.0
	tags.refresh()
	assert_int(tag.state).is_equal(WeaponTag.State.STARVED)
	assert_that(tag.get_bar_color()).is_equal(CombatColors.ENERGY)
	_mech.current_energy = 3
	tags.refresh()
	assert_int(tag.state).is_equal(WeaponTag.State.READY)
	assert_that(tag.get_bar_color()).is_equal(CombatColors.HP)
	# A shut-down mech's weapons are offline, whatever else is true.
	_mech.shutdown_left = 1.0
	tags.refresh()
	assert_int(tag.state).is_equal(WeaponTag.State.OFFLINE)
	assert_that(tag.get_bar_color()).is_equal(CombatColors.DANGER)


func test_firing_flashes_the_tag() -> void:
	var tags: WeaponTags = auto_free(WeaponTags.new())
	add_child(tags)
	tags.bind(_mech, CombatColors.PLAYER, false)
	var tag := tags.get_tag(_active(_pod))
	assert_float(tag.flash).is_equal(0.0)
	tag.fire()
	assert_float(tag.flash).is_equal(1.0)
	await await_millis(int(WeaponTag.FLASH_TIME * 1000) + 150)
	assert_float(tag.flash).is_equal(0.0)


func test_bars_fill_smoothly_and_empty_at_once() -> void:
	var tags: WeaponTags = auto_free(WeaponTags.new())
	add_child(tags)
	tags.smoothing = 0.2
	tags.bind(_mech, CombatColors.PLAYER, false)
	var gun := _active(_gatling)
	var tag := tags.get_tag(gun)
	gun.current_cooldown = 1.0 # halfway
	tags.refresh()
	assert_float(tag.charge).is_equal(0.5)
	assert_float(tag.shown_charge).is_less(0.5)
	await await_millis(300)
	assert_float(tag.shown_charge).is_equal_approx(0.5, 1e-3)
	# Firing restarts the cooldown: the bar drops straight away.
	gun.current_cooldown = 2.0
	tags.refresh()
	assert_float(tag.shown_charge).is_equal(0.0)


func _active(part: MechPart) -> ActivePart:
	for active in _mech.active_parts:
		if active.part == part:
			return active
	return null



func test_a_long_weapon_name_shrinks_to_fit() -> void:
	var tag: WeaponTag = auto_free(WeaponTag.new())
	tag.weapon_name = "Gatling"
	assert_int(tag.get_name_size(180.0)).is_equal(WeaponTag.NAME_SIZE)
	tag.weapon_name = "Concussive Ion Cannon Mk III"
	var shrunk := tag.get_name_size(180.0)
	assert_int(shrunk).is_less(WeaponTag.NAME_SIZE)
	assert_int(shrunk).is_greater_equal(WeaponTag.MIN_NAME_SIZE)
