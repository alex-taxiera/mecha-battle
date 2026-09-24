class_name MechStats
extends RefCounted
## A mech's totals for a grid: HP, energy, and damage after adjacency bonuses. Energy and
## damage are per turn, counting each part as often as it acts in one (see
## [method activations_per_turn]); a part's own numbers are per activation. Build one with
## [method calculate]; it's a snapshot and doesn't follow later grid changes.

# Stands in for a part without a mod: changes nothing.
static var NO_MOD := WeaponMod.new()


## One placed part's numbers after its bonuses, each time it acts.
class PartStats:
	var hp := 0
	var energy := 0
	var energy_draw := 0
	var damage := 0
	## Heat added each activation (each shot, for a weapon) and vented per turn. Rules can
	## change the heat a part makes but not its cooling.
	var heat := 0
	var cooling := 0
	## Shield points it adds, and energy it drains each turn to keep working.
	var shield := 0
	var upkeep := 0
	## Seconds between its activations, after links (0 for a part that never activates).
	var cooldown := 0.0
	## How many touching parts it links with.
	var links := 0
	## Each rule that changed this part -> how many times it applies: once per touching partner
	## for a stacking rule, else once. [method get_bonus_total] turns that into a number.
	var bonuses: Dictionary[SynergyRule, int] = {}

	## Returns the ADD bonuses for [param stat] summed and its MULTIPLY bonuses combined, as
	## [code][sum, factor][/code].
	func get_bonus_total(stat: RuleBonus.Stat) -> Array[float]:
		var total := 0.0
		var factor := 1.0
		for rule: SynergyRule in bonuses:
			for bonus in rule.bonuses:
				if bonus.stat != stat:
					continue
				if bonus.op == RuleBonus.Op.ADD:
					total += bonus.total(bonuses[rule])
				else:
					factor *= bonus.total(bonuses[rule])
		return [total, factor]

	## Returns [param base] plus the ADD bonuses for [param stat], times its MULTIPLY bonuses.
	func apply(base: float, stat: RuleBonus.Stat) -> float:
		var bonus := get_bonus_total(stat)
		return (base + bonus[0]) * bonus[1]


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
## Energy the chassis adds each turn, with any relic bonus.
var base_energy := 0
## Energy a turn: the chassis's, plus its generators' and its weapons' at their cadence.
var energy_generated := 0
## Energy used a turn: the weapons' shots at their cadence plus every part's upkeep.
var energy_drawn := 0
## Shield points: a pool that takes hits before the hull, full again every fight.
var shield := 0
## Damage a turn: each weapon's damage times how often it fires, scaled by [member power].
var damage := 0
## Heat a turn: made by each weapon at its cadence, scaled by [member power] like damage, and
## by other parts that run hot at theirs; and vented by the heatsinks.
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


## Returns how many times a part with [param cooldown] seconds between activations acts in a
## turn of combat: a turn's length over it, e.g. 2 for a weapon that fires every half second. A
## part with no cooldown counts once.
static func activations_per_turn(cooldown: float) -> float:
	return CombatEngine.TURN_SECONDS / cooldown if cooldown > 0.0 else 1.0


## Returns how many links each rule has made.
func get_rule_counts() -> Dictionary[SynergyRule, int]:
	var counts: Dictionary[SynergyRule, int] = {}
	for link in links:
		counts[link.rule] = counts.get(link.rule, 0) + 1
	return counts


## Returns the stats of the parts on [param grid], with [param rules] applied to every touching
## pair, then [param relics]' changes. A pair links once, however many edges it shares.
static func calculate(grid: MechGridData, rules: Array[SynergyRule], relics: Array[Relic] = []) -> MechStats:
	var stats := MechStats.new()
	for placement in grid.get_placements():
		stats.part_stats[placement] = PartStats.new()
	for contact in grid.get_contacts():
		var linked := false
		for rule in rules:
			if not rule.matches(contact.a.part, contact.b.part):
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
	# Weapons' heat is scaled by power like their damage; other parts' isn't.
	var weapon_heat := 0.0
	var other_heat := 0.0
	for placement: MechGridData.Placement in stats.part_stats:
		var part := placement.part
		var numbers: PartStats = stats.part_stats[placement]
		# A part's Mk scales its own numbers before links and relics add to them.
		var scale := part.get_level_scale()
		# A mod scales them too, from the part's own numbers, so taking it off is exact.
		var mod := part.mod if part.mod else NO_MOD
		numbers.hp = roundi(numbers.apply(roundi(part.hp * scale), RuleBonus.Stat.HP))
		numbers.energy = roundi(numbers.apply(roundi(part.energy_gen * scale), RuleBonus.Stat.ENERGY))
		numbers.energy_draw = roundi(numbers.apply(roundi(part.energy_cost * mod.energy_scale), RuleBonus.Stat.ENERGY_COST))
		numbers.damage = roundi(numbers.apply(roundi(part.damage * scale * mod.damage_scale), RuleBonus.Stat.DAMAGE))
		numbers.heat = roundi(numbers.apply(part.heat + mod.heat_add, RuleBonus.Stat.HEAT))
		numbers.cooling = roundi(numbers.apply(roundi(part.cooling * scale), RuleBonus.Stat.COOLING))
		numbers.shield = roundi(numbers.apply(roundi(part.shield * scale), RuleBonus.Stat.SHIELD))
		numbers.upkeep = part.upkeep
		if part.cooldown_max > 0.0:
			numbers.cooldown = maxf(0.0, numbers.apply(part.cooldown_max * mod.cooldown_scale, RuleBonus.Stat.COOLDOWN))
		for relic in relics:
			relic.modify_part_stats(part, numbers)
		stats.hp += numbers.hp
		stats.shield += numbers.shield
		var rate := activations_per_turn(numbers.cooldown)
		generated += numbers.energy * rate
		drawn += numbers.energy_draw * rate + numbers.upkeep
		raw_damage += numbers.damage * rate
		if part.type == MechPart.PartType.WEAPON:
			weapon_heat += numbers.heat * rate
		else:
			other_heat += numbers.heat * rate
		stats.heat_vented += numbers.cooling
	stats.base_energy = grid.chassis.base_energy
	stats.energy_generated = stats.base_energy + roundi(generated)
	stats.energy_drawn = roundi(drawn)
	if stats.energy_drawn > 0:
		stats.power = minf(1.0, float(stats.energy_generated) / stats.energy_drawn)
	stats.damage = roundi(raw_damage * stats.power)
	stats.heat_made = roundi(weapon_heat * stats.power + other_heat)
	for relic in relics:
		relic.modify_stats(stats)
	if stats.energy_drawn > 0:
		stats.power = minf(1.0, float(stats.energy_generated) / stats.energy_drawn)
	return stats


# The placements of [param contact] that [param rule] gives its bonus to.
static func _targets(rule: SynergyRule, contact: MechGridData.Contact) -> Array[MechGridData.Placement]:
	var first_is_a := rule.fits_first(contact.a.part) and rule.fits_second(contact.b.part)
	match rule.target:
		SynergyRule.Target.FIRST:
			return [contact.a if first_is_a else contact.b]
		SynergyRule.Target.SECOND:
			return [contact.b if first_is_a else contact.a]
	return [contact.a, contact.b]


static func _add_bonus(numbers: PartStats, rule: SynergyRule) -> void:
	if not numbers.bonuses.has(rule):
		numbers.bonuses[rule] = 1
	elif rule.stacks:
		numbers.bonuses[rule] += 1
