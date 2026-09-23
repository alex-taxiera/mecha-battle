class_name MechStats
extends RefCounted
## A mech's totals for a grid: HP, energy, and damage after adjacency bonuses. Energy and
## damage are per turn, counting each part as often as it acts in one (see
## [method activations_per_turn]); a part's own numbers are per activation. Build one with
## [method calculate]; it's a snapshot and doesn't follow later grid changes.

## One placed part's numbers after its bonuses, each time it acts.
class PartStats:
	var hp := 0
	var energy := 0
	var energy_draw := 0
	var damage := 0
	## Heat added per shot and vented per turn. No rule changes these.
	var heat := 0
	var cooling := 0
	## How many touching parts it links with.
	var links := 0
	## Each rule that changed this part -> its total: the summed amount for ADD rules, the
	## combined factor for MULTIPLY rules.
	var bonuses: Dictionary[SynergyRule, float] = {}


## A touching pair that matched a rule.
class Link:
	var rule: SynergyRule
	var contact: MechGridData.Contact

	func _init(p_rule: SynergyRule, p_contact: MechGridData.Contact) -> void:
		rule = p_rule
		contact = p_contact


var hp := 0
## The chassis's share of [member hp].
var base_hp := 0
## Energy a turn: the chassis's, plus its generators' and its weapons' at their cadence.
var energy_generated := 0
var energy_drawn := 0
## Damage a turn: each weapon's damage times how often it fires, scaled by [member power].
var damage := 0
## Heat a turn: made by each weapon at its cadence, scaled by [member power] like damage, and
## vented by the heatsinks.
var heat_made := 0
var heat_vented := 0
## Share of the weapons' energy draw that's covered, 0-1.
var power := 1.0
var links: Array[Link] = []
## Each placement -> its numbers.
var part_stats: Dictionary[MechGridData.Placement, PartStats] = {}


func get_net_energy() -> int:
	return energy_generated - energy_drawn


## Returns the heat a turn the heatsinks can't keep up with; above 0, the mech runs hot and its
## weapons slow down in a long fight.
func get_net_heat() -> int:
	return heat_made - heat_vented


## Returns how many times [param part] acts in a turn of combat: a turn's length over its
## cooldown, e.g. 2 for a weapon that fires every half second. A part with no cooldown counts
## once.
static func activations_per_turn(part: MechPart) -> float:
	return CombatEngine.TURN_SECONDS / part.cooldown_max if part.cooldown_max > 0.0 else 1.0


## Returns how many links each rule has made.
func get_rule_counts() -> Dictionary[SynergyRule, int]:
	var counts: Dictionary[SynergyRule, int] = {}
	for link in links:
		counts[link.rule] = counts.get(link.rule, 0) + 1
	return counts


## Returns the stats of the parts on [param grid], with [param rules] applied to every touching
## pair. A pair links once, however many edges it shares.
static func calculate(grid: MechGridData, rules: Array[SynergyRule]) -> MechStats:
	var stats := MechStats.new()
	for placement in grid.get_placements():
		stats.part_stats[placement] = PartStats.new()
	for contact in grid.get_contacts():
		var linked := false
		for rule in rules:
			if not rule.matches(contact.a.part.type, contact.b.part.type):
				continue
			linked = true
			stats.links.append(Link.new(rule, contact))
			for target in _targets(rule, contact):
				_add_bonus(stats.part_stats[target], rule)
		if linked:
			stats.part_stats[contact.a].links += 1
			stats.part_stats[contact.b].links += 1

	stats.base_hp = grid.chassis.base_hp
	stats.hp = stats.base_hp
	var generated := 0.0
	var drawn := 0.0
	var raw_damage := 0.0
	var raw_heat := 0.0
	for placement: MechGridData.Placement in stats.part_stats:
		var part := placement.part
		var numbers: PartStats = stats.part_stats[placement]
		numbers.hp = _with_bonuses(part.hp, numbers, SynergyRule.Stat.HP)
		numbers.energy = _with_bonuses(part.energy_gen, numbers, SynergyRule.Stat.ENERGY)
		numbers.energy_draw = part.energy_cost
		numbers.damage = _with_bonuses(part.damage, numbers, SynergyRule.Stat.DAMAGE)
		numbers.heat = part.heat
		numbers.cooling = part.cooling
		stats.hp += numbers.hp
		var rate := activations_per_turn(part)
		generated += numbers.energy * rate
		drawn += numbers.energy_draw * rate
		raw_damage += numbers.damage * rate
		raw_heat += numbers.heat * rate
		stats.heat_vented += numbers.cooling
	stats.energy_generated = grid.chassis.base_energy + roundi(generated)
	stats.energy_drawn = roundi(drawn)
	if stats.energy_drawn > 0:
		stats.power = minf(1.0, float(stats.energy_generated) / stats.energy_drawn)
	stats.damage = roundi(raw_damage * stats.power)
	stats.heat_made = roundi(raw_heat * stats.power)
	return stats


# The placements of [param contact] that [param rule] gives its bonus to.
static func _targets(rule: SynergyRule, contact: MechGridData.Contact) -> Array[MechGridData.Placement]:
	var first_is_a := contact.a.part.type == rule.first_type
	match rule.target:
		SynergyRule.Target.FIRST:
			return [contact.a if first_is_a else contact.b]
		SynergyRule.Target.SECOND:
			return [contact.b if first_is_a else contact.a]
	return [contact.a, contact.b]


static func _add_bonus(numbers: PartStats, rule: SynergyRule) -> void:
	if not numbers.bonuses.has(rule):
		numbers.bonuses[rule] = rule.amount
	elif rule.stacks:
		if rule.op == SynergyRule.Op.ADD:
			numbers.bonuses[rule] += rule.amount
		else:
			numbers.bonuses[rule] *= rule.amount


# [param base] plus the ADD bonuses for [param stat], times its MULTIPLY bonuses, rounded.
static func _with_bonuses(base: int, numbers: PartStats, stat: SynergyRule.Stat) -> int:
	var total := float(base)
	var factor := 1.0
	for rule: SynergyRule in numbers.bonuses:
		if rule.stat != stat:
			continue
		if rule.op == SynergyRule.Op.ADD:
			total += numbers.bonuses[rule]
		else:
			factor *= numbers.bonuses[rule]
	return roundi(total * factor)
