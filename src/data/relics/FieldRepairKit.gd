class_name FieldRepairKit
extends Relic
## Repairs the hull a little after every won fight.

@export var repair := 20


func on_fight_won(run: RunState) -> void:
	run.heal(repair)
