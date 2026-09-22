class_name ShopData
extends RefCounted
## The shop phase's economy: the player's gold and the parts on offer.

## Emitted whenever the gold or the offers change.
signal changed

var gold: int
var offers: Array[MechPart] = []


func _init(starting_gold: int, catalog: Array[MechPart]) -> void:
	gold = starting_gold
	offers.assign(catalog)


func can_afford(part: MechPart) -> bool:
	return part.cost <= gold


## Pays for an offered part and takes it off the shelf. Returns whether it was bought.
func buy(part: MechPart) -> bool:
	if part not in offers or not can_afford(part):
		return false
	offers.erase(part)
	gold -= part.cost
	changed.emit()
	return true
