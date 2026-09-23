extends RefCounted
## Builders shared by the test suites. Values are pinned to design_doc.md and the Shop Phase
## mockup rather than read from res://resources, so tuning the game's content doesn't break
## the tests. Preload it: [code]const Fixtures := preload("res://test/TestFixtures.gd")[/code].

const CORNERS: Array[Vector2i] = [Vector2i(0, 0), Vector2i(3, 0), Vector2i(0, 3), Vector2i(3, 3)]


## The design doc's chassis: 4x4 with the corners disabled, with the Skirmisher's base stats.
static func cross_chassis() -> MechChassis:
	var chassis := _chassis(Vector2i(4, 4), CORNERS)
	chassis.chassis_name = "The Skirmisher"
	chassis.frame_name = "Cross frame"
	return chassis


## A frame with no disabled cells and the Skirmisher's base stats, for roomy layouts.
static func open_chassis(size: Vector2i) -> MechChassis:
	return _chassis(size, [])


# The mockup's parts. Shapes are (x, y): the gatling is 1x3 vertical, the reactor 2x1.

static func gatling() -> MechPart:
	return part("Twin Gatling", MechPart.PartType.WEAPON, [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2)], 4, {"damage": 8, "energy_cost": 3})


static func laser() -> MechPart:
	return part("Point-Defense Laser", MechPart.PartType.DEFENSE, [Vector2i(0, 0)], 2, {"hp": 12})


static func reactor() -> MechPart:
	return part("Micro-Reactor", MechPart.PartType.GENERATOR, [Vector2i(0, 0), Vector2i(1, 0)], 3, {"energy_gen": 4, "hp": 5})


## X.
## XX
static func heatsink() -> MechPart:
	return part("L-Shaped Heatsink", MechPart.PartType.UTILITY, [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1)], 4)


static func part(part_name: String, type: MechPart.PartType, shape: Array[Vector2i], cost := 0, stats := {}) -> MechPart:
	var result := MechPart.new()
	result.part_name = part_name
	result.type = type
	result.grid_shape = shape
	result.cost = cost
	for stat in stats:
		# set() ignores names MechPart doesn't have, which would quietly zero a stat.
		assert(stat in result, "MechPart has no stat '%s'" % stat)
		result.set(stat, stats[stat])
	return result


# The mockup's adjacency rules.

static func cooled() -> SynergyRule:
	var rule := _rule(MechPart.PartType.WEAPON, MechPart.PartType.UTILITY, SynergyRule.Target.FIRST, SynergyRule.Stat.DAMAGE, SynergyRule.Op.MULTIPLY, 1.5, false)
	return _named(rule, "cooled", "Heatsink + Weapon", "weapon dmg ×1.5", Color(0.31, 0.77, 0.74))


static func overcharge() -> SynergyRule:
	var rule := _rule(MechPart.PartType.WEAPON, MechPart.PartType.GENERATOR, SynergyRule.Target.FIRST, SynergyRule.Stat.DAMAGE, SynergyRule.Op.ADD, 3.0, true)
	return _named(rule, "overcharge", "Reactor + Weapon", "+3 weapon dmg", Color(0.65, 0.55, 0.94))


static func stable() -> SynergyRule:
	var rule := _rule(MechPart.PartType.GENERATOR, MechPart.PartType.UTILITY, SynergyRule.Target.FIRST, SynergyRule.Stat.ENERGY, SynergyRule.Op.ADD, 2.0, true)
	return _named(rule, "stable", "Heatsink + Reactor", "+2 energy", Color(0.94, 0.71, 0.24))


static func plated() -> SynergyRule:
	var rule := _rule(MechPart.PartType.DEFENSE, MechPart.PartType.DEFENSE, SynergyRule.Target.BOTH, SynergyRule.Stat.HP, SynergyRule.Op.ADD, 4.0, true)
	return _named(rule, "plated", "Laser + Laser", "+4 HP each", Color(0.5, 0.65, 0.86))


## All four mockup rules, in the mockup's legend order.
static func rules() -> Array[SynergyRule]:
	return [cooled(), overcharge(), stable(), plated()]


static func _chassis(size: Vector2i, disabled: Array[Vector2i]) -> MechChassis:
	var chassis := MechChassis.new()
	chassis.size = size
	chassis.disabled_cells = disabled
	chassis.base_hp = 30
	chassis.base_energy = 3
	return chassis


static func _named(rule: SynergyRule, id: String, label: String, effect_text: String, color: Color) -> SynergyRule:
	rule.id = id
	rule.label = label
	rule.effect_text = effect_text
	rule.color = color
	return rule


static func _rule(first_type: MechPart.PartType, second_type: MechPart.PartType, target: SynergyRule.Target,
		stat: SynergyRule.Stat, op: SynergyRule.Op, amount: float, stacks: bool) -> SynergyRule:
	var rule := SynergyRule.new()
	rule.first_type = first_type
	rule.second_type = second_type
	rule.target = target
	rule.stat = stat
	rule.op = op
	rule.amount = amount
	rule.stacks = stacks
	return rule
