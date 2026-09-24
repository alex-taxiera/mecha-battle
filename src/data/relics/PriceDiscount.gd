class_name PriceDiscount
extends Relic
## Every part at a shop costs [member amount] less.

@export var amount := 1


func modify_part_price(_part: MechPart, price: int) -> int:
	return price - amount
