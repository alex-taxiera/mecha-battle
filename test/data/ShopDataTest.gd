class_name ShopDataTest
extends GdUnitTestSuite

const __source: String = "res://src/data/ShopData.gd"

var _changes := 0


func before_test() -> void:
	_changes = 0


func test_can_afford() -> void:
	var shop := ShopData.new(3, [])
	assert_bool(shop.can_afford(_make_part(3))).is_true() # exactly enough
	assert_bool(shop.can_afford(_make_part(4))).is_false()


func test_buy_pays_and_removes_the_offer() -> void:
	var cannon := _make_part(4)
	var laser := _make_part(2)
	var shop := ShopData.new(10, [cannon, laser])
	shop.changed.connect(func() -> void: _changes += 1)

	assert_bool(shop.buy(cannon)).is_true()
	assert_int(shop.gold).is_equal(6)
	assert_array(shop.offers).contains_same_exactly(laser)
	assert_int(_changes).is_equal(1)


func test_buy_rejects_unaffordable_and_unoffered_parts() -> void:
	var cheap := _make_part(2)
	var pricey := _make_part(5)
	var shop := ShopData.new(4, [cheap, pricey])
	shop.changed.connect(func() -> void: _changes += 1)

	assert_bool(shop.buy(pricey)).is_false()        # costs more than the gold
	assert_bool(shop.buy(_make_part(1))).is_false() # not on offer
	assert_int(shop.gold).is_equal(4)
	assert_array(shop.offers).contains_same_exactly(cheap, pricey)
	assert_int(_changes).is_equal(0)
	# The affordable offer still sells.
	assert_bool(shop.buy(cheap)).is_true()
	assert_int(shop.gold).is_equal(2)


func test_buying_leaves_the_catalog_untouched() -> void:
	var part := _make_part(1)
	var catalog: Array[MechPart] = [part]
	var shop := ShopData.new(5, catalog)
	assert_bool(shop.buy(part)).is_true()
	assert_array(catalog).contains_same_exactly(part)


func _make_part(cost: int) -> MechPart:
	var part := MechPart.new()
	part.cost = cost
	part.grid_shape = [Vector2i.ZERO]
	return part
