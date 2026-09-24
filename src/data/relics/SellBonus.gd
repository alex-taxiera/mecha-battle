class_name SellBonus
extends Relic
## Every part a shop buys brings [member amount] more gold.

@export var amount := 3


func modify_sell_value(part: MechPart, value: int) -> int:
	return value + amount if part.sellable else value
