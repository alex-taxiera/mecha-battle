class_name SalvageDrone
extends Relic
## Fights drop more gold.

## The share added: 0.25 is +25%, rounded up.
@export var bonus := 0.25


func modify_gold(amount: int) -> int:
	return ceili(amount * (1.0 + bonus))
