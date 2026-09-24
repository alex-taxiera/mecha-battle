class_name FreeReroll
extends Relic
## The first [member free] rerolls at each shop cost nothing.

@export var free := 1

var _left := 0


func on_shop_opened(_run: RunState, _shop: ShopStock) -> void:
	_left = free


func modify_reroll_cost(_run: RunState, cost: int) -> int:
	return 0 if _left > 0 else cost


func on_reroll(_run: RunState) -> void:
	_left = maxi(0, _left - 1)
