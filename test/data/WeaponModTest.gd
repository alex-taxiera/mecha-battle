class_name WeaponModTest
extends GdUnitTestSuite

const __source: String = "res://src/data/WeaponMod.gd"
const Fixtures := preload("res://test/TestFixtures.gd")

const LEFT_ARM := Vector2i(-1, 1)


func test_mods_fit_weapons_only() -> void:
	var mod := Fixtures.weapon_mod("m", "Mod")
	assert_bool(mod.fits(Fixtures.gatling())).is_true()
	assert_bool(mod.fits(Fixtures.laser())).is_false()
	assert_bool(mod.fits(null)).is_false()


func test_a_mod_scales_the_weapons_numbers_and_comes_off_exactly() -> void:
	var gun := Fixtures.part("Gun", MechPart.PartType.WEAPON, Fixtures.ARM_SHAPE, 4,
		{"damage": 10, "energy_cost": 20, "heat": 5, "cooldown_max": 1.0})
	var grid := MechGridData.new(Fixtures.armed_cross())
	assert_bool(grid.place_part(gun, LEFT_ARM)).is_true()
	var before := _numbers(grid)
	gun.mod = Fixtures.weapon_mod("m", "Hot", {"damage_scale": 1.3, "energy_scale": 0.8, "heat_add": 15, "cooldown_scale": 1.1})
	var modded := _numbers(grid)
	assert_int(modded.damage).is_equal(13)
	assert_int(modded.energy_draw).is_equal(16)
	assert_int(modded.heat).is_equal(20)
	assert_float(modded.cooldown).is_equal_approx(1.1, 1e-6)
	# The part's own numbers never changed, so taking the mod off puts everything back.
	assert_int(gun.damage).is_equal(10)
	gun.mod = null
	var after := _numbers(grid)
	assert_int(after.damage).is_equal(before.damage)
	assert_int(after.energy_draw).is_equal(before.energy_draw)
	assert_int(after.heat).is_equal(before.heat)
	assert_float(after.cooldown).is_equal(before.cooldown)


func test_a_mods_abilities_act_in_a_fight() -> void:
	# An Incendiary-style mod on a plain free gun: its hits leave 1 Burn.
	var gun := Fixtures.part("Gun", MechPart.PartType.WEAPON, Fixtures.ARM_SHAPE, 0, {"damage": 1, "cooldown_max": 0.5})
	gun.mod = Fixtures.weapon_mod("incendiary", "Incendiary")
	gun.mod.abilities.assign([Fixtures.apply_status(Fixtures.burn(), 1)])
	assert_array(gun.get_abilities()).has_size(1)
	var grid := MechGridData.new(Fixtures.armed_cross())
	assert_bool(grid.place_part(gun, LEFT_ARM)).is_true()
	var target := BattleMech.new(MechGridData.new(Fixtures.cross_chassis()))
	var engine := CombatEngine.new(BattleMech.new(grid), target)
	engine.start()
	for i in 5:
		engine.process_tick(0.1)
	assert_int(target.get_status_charges("burn")).is_equal(1)


func test_a_modded_weapon_is_named_for_its_mod_and_merges_only_with_its_own_kind() -> void:
	var incendiary := Fixtures.weapon_mod("incendiary", "Incendiary")
	var a := Fixtures.gatling()
	a.mod = incendiary
	a.level = 2
	assert_str(a.get_display_name()).is_equal("Incendiary Twin Gatling Mk II")
	var same := Fixtures.gatling()
	same.mod = incendiary
	same.level = 2
	assert_bool(a.can_merge_with(same)).is_true()
	var plain := Fixtures.gatling()
	plain.level = 2
	assert_bool(a.can_merge_with(plain)).is_false()
	var other := Fixtures.gatling()
	other.mod = Fixtures.weapon_mod("concussive", "Concussive")
	other.level = 2
	assert_bool(a.can_merge_with(other)).is_false()


func test_a_mod_is_kept_when_the_part_is_copied() -> void:
	var gun := Fixtures.gatling()
	gun.mod = Fixtures.weapon_mod("incendiary", "Incendiary")
	var copy: MechPart = gun.duplicate()
	assert_object(copy.mod).is_same(gun.mod)


func _numbers(grid: MechGridData) -> MechStats.PartStats:
	return MechStats.calculate(grid, []).part_stats[grid.get_placement_at(LEFT_ARM)]
