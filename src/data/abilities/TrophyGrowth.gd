class_name TrophyGrowth
extends PartAbility
## A trophy rack: each fight its mech wins, the part earns [member damage] more damage for the
## rest of the run (see [member MechPart.bonus_damage]), up to [member max_bonus].

@export var damage := 2
@export var max_bonus := 40


func on_fight_end(_mech: BattleMech, active: ActivePart, won: bool) -> void:
	if won:
		active.part.bonus_damage = mini(max_bonus, active.part.bonus_damage + damage)
