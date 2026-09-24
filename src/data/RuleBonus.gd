class_name RuleBonus
extends Resource
## One change an adjacency rule makes to a linked part: a stat, added to or multiplied.
## A [SynergyRule] can make several, e.g. more energy and more heat.

enum Stat { HP, ENERGY, DAMAGE, HEAT, COOLDOWN, ENERGY_COST }
enum Op { ADD, MULTIPLY }

## Short names for the stats, for bonus lines like "+20 EN / +10 HEAT".
const STAT_LABELS := {
	Stat.HP: "HP",
	Stat.ENERGY: "EN",
	Stat.DAMAGE: "DMG",
	Stat.HEAT: "HEAT",
	Stat.COOLDOWN: "CD",
	Stat.ENERGY_COST: "EN cost",
}

@export var stat: Stat
@export var op: Op
@export var amount: float


func _init(p_stat := Stat.HP, p_op := Op.ADD, p_amount := 0.0) -> void:
	stat = p_stat
	op = p_op
	amount = p_amount


## Returns what [param count] applications add up to: the summed amount for ADD, the combined
## factor for MULTIPLY.
func total(count: int) -> float:
	return amount * count if op == Op.ADD else pow(amount, count)


## Returns [param count] applications as text, e.g. "+3" or "×1.5".
func describe(count: int) -> String:
	var value := total(count)
	var shown := str(roundi(value)) if is_equal_approx(value, roundf(value)) else str(snappedf(value, 0.01))
	return ("×" if op == Op.MULTIPLY else "+") + shown
