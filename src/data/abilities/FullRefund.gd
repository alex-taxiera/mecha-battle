class_name FullRefund
extends PartAbility
## A scrapper drone: while it's installed, a shop buys every part back at its full value, not
## just the ones bought at that shop.


func _init() -> void:
	stacks = false


func refunds_in_full() -> bool:
	return true
