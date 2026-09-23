class_name ShopStockTest
extends GdUnitTestSuite

const __source: String = "res://src/run/ShopStock.gd"
const Fixtures := preload("res://test/TestFixtures.gd")

var _catalog: Array[MechPart] = []


func before_test() -> void:
	_catalog = [Fixtures.gatling(), Fixtures.laser(), Fixtures.reactor(), Fixtures.heatsink()]


func test_the_first_stock_shows_each_part_once() -> void:
	var shop := ShopStock.new(_catalog, _seeded(1))
	assert_array(_parts(shop)).has_size(4).contains_same_exactly_in_any_order(_catalog)
	for slot in shop.slots:
		assert_bool(slot.sold).is_false()
		assert_int(slot.rotation).is_equal(0)


func test_restocking_refills_every_slot() -> void:
	var shop := ShopStock.new(_catalog, _seeded(1))
	shop.slots[0].sold = true
	shop.restock()
	assert_array(shop.slots).has_size(ShopStock.SIZE)
	for slot in shop.slots:
		assert_bool(slot.sold).is_false()
		assert_bool(slot.part in _catalog).is_true()
	# An empty catalog stocks nothing.
	assert_array(ShopStock.new([], _seeded(1)).slots).is_empty()


func test_the_same_seed_stocks_the_same_shop() -> void:
	var a := ShopStock.new(_catalog, _seeded(8))
	var b := ShopStock.new(_catalog, _seeded(8))
	a.restock()
	b.restock()
	assert_array(_parts(a)).contains_same_exactly(_parts(b))


func test_open_slots_and_turning_offers() -> void:
	var shop := ShopStock.new(_catalog, _seeded(1))
	var gatling := _slot_of(shop, _catalog[0])
	var reactor := _slot_of(shop, _catalog[2])
	assert_object(shop.get_open_slot(gatling)).is_same(shop.slots[gatling])
	assert_object(shop.get_open_slot(-1)).is_null()
	assert_object(shop.get_open_slot(ShopStock.SIZE)).is_null()
	# Weapons never turn; a 2x1 does, round to where it started.
	assert_bool(shop.rotate_slot(gatling)).is_false()
	for turn in 4:
		assert_bool(shop.rotate_slot(reactor)).is_true()
	assert_int(shop.slots[reactor].rotation).is_equal(0)
	# A sold slot is closed.
	shop.slots[reactor].sold = true
	assert_object(shop.get_open_slot(reactor)).is_null()
	assert_bool(shop.rotate_slot(reactor)).is_false()


func _parts(shop: ShopStock) -> Array[MechPart]:
	var parts: Array[MechPart] = []
	for slot in shop.slots:
		parts.append(slot.part)
	return parts


func _slot_of(shop: ShopStock, part: MechPart) -> int:
	for i in shop.slots.size():
		if shop.slots[i].part == part:
			return i
	return -1


func _seeded(rng_seed: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	return rng
