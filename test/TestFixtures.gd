extends RefCounted
## Builders shared by the test suites. Values are pinned to design_doc.md and the Shop Phase
## mockup rather than read from res://resources, so tuning the game's content doesn't break
## the tests. Preload it: [code]const Fixtures := preload("res://test/TestFixtures.gd")[/code].

const CORNERS: Array[Vector2i] = [Vector2i(0, 0), Vector2i(3, 0), Vector2i(0, 3), Vector2i(3, 3)]
const ARM_SHAPE: Array[Vector2i] = [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2)]
const BACK_SHAPE: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]


## The design doc's chassis: 4x4 with the corners disabled, with the Skirmisher's base stats.
## It has no hardpoints, so section 5's bounds tests see only the frame.
static func cross_chassis() -> MechChassis:
	var chassis := _chassis(Vector2i(4, 4), CORNERS)
	chassis.chassis_name = "The Skirmisher"
	chassis.frame_name = "Cross frame"
	return chassis


## The cross with a bay of each kind for weapons: a left arm at (-1, 1) touching (0, 1) and
## (0, 2), a right arm at (4, 1) touching (3, 1) and (3, 2), and a back at (1, -2) touching
## (1, 0) and (2, 0).
static func armed_cross() -> MechChassis:
	var chassis := cross_chassis()
	chassis.hardpoints = [left_arm(Vector2i(-1, 1)), right_arm(Vector2i(4, 1)), back(Vector2i(1, -2))]
	return chassis


## A frame with no disabled cells and the Skirmisher's base stats, for roomy layouts.
static func open_chassis(size: Vector2i) -> MechChassis:
	return _chassis(size, [])


# The design doc's three frames, at the hundreds-of-HP scale.

## Tank: 4 wide by 3 tall, 450 HP, 20 energy a turn, every hit taken 2 smaller. One back bay,
## over (1, 0) and (2, 0).
static func bastion() -> MechChassis:
	var chassis := _frame("The Bastion", "Wide frame", Vector2i(4, 3), [], 450, 20)
	chassis.hardpoints = [back(Vector2i(1, -2))]
	chassis.playstyle = "Tank / Attrition"
	chassis.passive = MechChassis.Passive.THICK_PLATING
	chassis.passive_name = "Thick Plating"
	chassis.passive_text = "Reduces all incoming flat damage by 2."
	chassis.plating = 2
	return chassis


## Glass cannon: 2 wide by 5 tall, 220 HP, 40 energy a turn, its first shot fires twice. Arms
## beside rows 1-3 and a back over row 0.
static func striker() -> MechChassis:
	var chassis := _frame("The Striker", "Tall frame", Vector2i(2, 5), [], 220, 40)
	chassis.hardpoints = [left_arm(Vector2i(-1, 1)), right_arm(Vector2i(2, 1)), back(Vector2i(0, -2))]
	chassis.playstyle = "Glass Cannon / Burst"
	chassis.passive = MechChassis.Passive.OVERCLOCK
	chassis.passive_name = "Overclock"
	chassis.passive_text = "The first weapon to fire each battle fires twice."
	return chassis


## Combo: a 13-cell diamond on 5x5, 300 HP, 30 energy a turn. At full heat it deals 100 and
## shuts down for 3 seconds. Arms beside rows 1-3, each touching only a tip, (0, 2) or (4, 2).
static func reactor_frame() -> MechChassis:
	var disabled: Array[Vector2i] = []
	for y in 5:
		for x in 5:
			if absi(x - 2) + absi(y - 2) > 2:
				disabled.append(Vector2i(x, y))
	var chassis := _frame("The Reactor", "Diamond frame", Vector2i(5, 5), disabled, 300, 30)
	chassis.hardpoints = [left_arm(Vector2i(-1, 1)), right_arm(Vector2i(5, 1))]
	chassis.playstyle = "Synergy / Combo"
	chassis.passive = MechChassis.Passive.MELTDOWN
	chassis.passive_name = "Meltdown"
	chassis.passive_text = "When heat reaches 100%, deal massive damage and shut down for 3 seconds."
	chassis.meltdown_damage = 100
	chassis.meltdown_shutdown = 3.0
	return chassis


# The design's hardpoints: arms are 1x3 vertical, backs 2x2.

static func left_arm(origin: Vector2i) -> Hardpoint:
	return hardpoint("left_arm", "Left Arm", origin, ARM_SHAPE)


static func right_arm(origin: Vector2i) -> Hardpoint:
	return hardpoint("right_arm", "Right Arm", origin, ARM_SHAPE)


static func back(origin: Vector2i) -> Hardpoint:
	return hardpoint("back", "Back", origin, BACK_SHAPE)


static func hardpoint(id: String, hardpoint_name: String, origin: Vector2i, shape: Array[Vector2i]) -> Hardpoint:
	var result := Hardpoint.new()
	result.id = id
	result.hardpoint_name = hardpoint_name
	result.origin = origin
	# A copy, so fixtures never share the read-only constant shapes.
	result.shape = shape.duplicate()
	return result


# The mockup's parts. Shapes are (x, y): the gatling is 1x3 vertical, the reactor 2x1.

## An arm weapon.
static func gatling() -> MechPart:
	return part("Twin Gatling", MechPart.PartType.WEAPON, ARM_SHAPE, 4, {"damage": 8, "energy_cost": 3})


## A back weapon: 2x2, 6 gold, 14 damage for 5 energy.
static func missile_pod() -> MechPart:
	return part("Missile Pod", MechPart.PartType.WEAPON, BACK_SHAPE, 6, {"damage": 14, "energy_cost": 5})


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
	result.id = part_name.to_snake_case()
	result.part_name = part_name
	result.type = type
	result.grid_shape = shape.duplicate()
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


# Sectors and enemies for run tests.

## A sector with the default map and two normal enemies, an elite, and a boss, each a bare cross
## (30 HP, no parts), with enemy HP ×[param hp_scale] and +[param hp_per_floor] a floor.
static func act(hp_scale := 1.0, hp_per_floor := 0.0) -> ActData:
	var sector := ActData.new()
	sector.sector_name = "Test Sector"
	sector.enemy_hp_scale = hp_scale
	sector.enemy_hp_per_floor = hp_per_floor
	sector.enemies = [enemy("Grunt A", EnemyLoadout.Tier.NORMAL), enemy("Grunt B", EnemyLoadout.Tier.NORMAL),
		enemy("Elite", EnemyLoadout.Tier.ELITE), enemy("Boss", EnemyLoadout.Tier.BOSS)]
	return sector


## An enemy on the bare cross, carrying [param lineup].
static func enemy(enemy_name: String, tier: EnemyLoadout.Tier, lineup: Array[LoadoutPart] = []) -> EnemyLoadout:
	var result := EnemyLoadout.new()
	result.id = enemy_name.to_snake_case()
	result.enemy_name = enemy_name
	result.tier = tier
	result.chassis = cross_chassis()
	result.lineup = lineup
	return result


# Relics for run tests: plain ones that do nothing, so tests only see the rarities.

## Two common relics, an uncommon, a rare, and two boss relics, none with any effect.
static func relics() -> Array[Relic]:
	return [relic("Common A", Relic.Rarity.COMMON), relic("Common B", Relic.Rarity.COMMON),
		relic("Uncommon", Relic.Rarity.UNCOMMON), relic("Rare", Relic.Rarity.RARE),
		relic("Boss A", Relic.Rarity.BOSS), relic("Boss B", Relic.Rarity.BOSS)]


static func relic(relic_name: String, rarity: Relic.Rarity) -> Relic:
	var result := Relic.new()
	result.id = relic_name.to_snake_case()
	result.relic_name = relic_name
	result.rarity = rarity
	result.description = "Does nothing."
	return result


# Events for run tests.

## An event with [param choices], which comes up when [param requirement] passes (always, if null).
static func event(title: String, choices: Array[EventChoice], requirement: EventRequirement = null,
		strategy := GameEvent.FailedStrategy.KEEP, is_fallback := false) -> GameEvent:
	var result := GameEvent.new()
	result.id = title.to_snake_case()
	result.title = title
	result.text = "Something happens."
	result.choices = choices
	result.requirement = requirement
	result.failed_strategy = strategy
	result.fallback = is_fallback
	return result


static func choice(label: String, outcomes: Array[EventOutcome], requirement: EventRequirement = null) -> EventChoice:
	var result := EventChoice.new()
	result.label = label
	result.hint = "It does something."
	result.outcomes = outcomes
	result.requirement = requirement
	return result


static func outcome(text: String, effects: Array[EventEffect], weight := 1) -> EventOutcome:
	var result := EventOutcome.new()
	result.text = text
	result.effects = effects
	result.weight = weight
	return result


static func gold_effect(amount: int) -> GoldEffect:
	var effect := GoldEffect.new()
	effect.amount = amount
	return effect


static func gold_requirement(gold: int) -> GoldRequirement:
	var requirement := GoldRequirement.new()
	requirement.gold = gold
	return requirement


## An event with one choice that gains [param gold] gold.
static func gold_event(title: String, gold := 10) -> GameEvent:
	return event(title, [choice("Take it", [outcome("You take it.", [gold_effect(gold)])])])


static func _chassis(size: Vector2i, disabled: Array[Vector2i]) -> MechChassis:
	var chassis := MechChassis.new()
	chassis.size = size
	chassis.disabled_cells = disabled
	chassis.base_hp = 30
	chassis.base_energy = 3
	return chassis


static func _frame(chassis_name: String, frame_name: String, size: Vector2i, disabled: Array[Vector2i], hp: int, energy: int) -> MechChassis:
	var chassis := _chassis(size, disabled)
	chassis.chassis_name = chassis_name
	chassis.frame_name = frame_name
	chassis.base_hp = hp
	chassis.base_energy = energy
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
