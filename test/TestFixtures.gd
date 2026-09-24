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
	var plating := ThickPlatingPassive.new()
	plating.plating = 2
	chassis.passive = plating
	chassis.passive_name = "Thick Plating"
	chassis.passive_text = "Reduces all incoming flat damage by 2."
	return chassis


## Glass cannon: 2 wide by 5 tall, 220 HP, 40 energy a turn, its first shot fires twice. Arms
## beside rows 1-3 and a back over row 0.
static func striker() -> MechChassis:
	var chassis := _frame("The Striker", "Tall frame", Vector2i(2, 5), [], 220, 40)
	chassis.hardpoints = [left_arm(Vector2i(-1, 1)), right_arm(Vector2i(2, 1)), back(Vector2i(0, -2))]
	chassis.playstyle = "Glass Cannon / Burst"
	chassis.passive = OverclockPassive.new()
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
	var meltdown := MeltdownPassive.new()
	meltdown.damage = 100
	meltdown.shutdown = 3.0
	chassis.passive = meltdown
	chassis.passive_name = "Meltdown"
	chassis.passive_text = "When heat reaches 100%, deal massive damage and shut down for 3 seconds."
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
	return part("L-Shaped Heatsink", MechPart.PartType.UTILITY, [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1)], 4, {"tags": ["heatsink"] as Array[String]})


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
	var rule := _rule(MechPart.PartType.WEAPON, MechPart.PartType.UTILITY, SynergyRule.Target.FIRST, [_bonus(RuleBonus.Stat.DAMAGE, RuleBonus.Op.MULTIPLY, 1.5)], false)
	rule.second_tag = "heatsink"
	return _named(rule, "cooled", "Heatsink + Weapon", "weapon dmg ×1.5", Color(0.31, 0.77, 0.74))


static func overcharge() -> SynergyRule:
	var rule := _rule(MechPart.PartType.WEAPON, MechPart.PartType.GENERATOR, SynergyRule.Target.FIRST, [_bonus(RuleBonus.Stat.DAMAGE, RuleBonus.Op.ADD, 3.0)], true)
	return _named(rule, "overcharge", "Reactor + Weapon", "+3 weapon dmg", Color(0.65, 0.55, 0.94))


static func stable() -> SynergyRule:
	var rule := _rule(MechPart.PartType.GENERATOR, MechPart.PartType.UTILITY, SynergyRule.Target.FIRST, [_bonus(RuleBonus.Stat.ENERGY, RuleBonus.Op.ADD, 2.0)], true)
	rule.second_tag = "heatsink"
	return _named(rule, "stable", "Heatsink + Reactor", "+2 energy", Color(0.94, 0.71, 0.24))


static func plated() -> SynergyRule:
	var rule := _rule(MechPart.PartType.DEFENSE, MechPart.PartType.DEFENSE, SynergyRule.Target.BOTH, [_bonus(RuleBonus.Stat.HP, RuleBonus.Op.ADD, 4.0)], true)
	return _named(rule, "plated", "Laser + Laser", "+4 HP each", Color(0.5, 0.65, 0.86))


## All four mockup rules, in the mockup's legend order.
static func rules() -> Array[SynergyRule]:
	return [cooled(), overcharge(), stable(), plated()]


# The design doc's newer rules.

## A chip touching a weapon: the weapon's cooldown ×0.9 and energy cost ×1.2, per chip.
static func overclocked() -> SynergyRule:
	var rule := _rule(MechPart.PartType.WEAPON, MechPart.PartType.UTILITY, SynergyRule.Target.FIRST, [
		_bonus(RuleBonus.Stat.COOLDOWN, RuleBonus.Op.MULTIPLY, 0.9),
		_bonus(RuleBonus.Stat.ENERGY_COST, RuleBonus.Op.MULTIPLY, 1.2),
	], true)
	rule.second_tag = "chip"
	return _named(rule, "overclocked", "Chip + Weapon", "CD ×0.9, EN cost ×1.2", Color(0.9, 0.4, 0.7))


## Two touching generators: +20 energy and +10 heat each activation, each.
static func volatile() -> SynergyRule:
	var rule := _rule(MechPart.PartType.GENERATOR, MechPart.PartType.GENERATOR, SynergyRule.Target.BOTH, [
		_bonus(RuleBonus.Stat.ENERGY, RuleBonus.Op.ADD, 20.0),
		_bonus(RuleBonus.Stat.HEAT, RuleBonus.Op.ADD, 10.0),
	], true)
	return _named(rule, "volatile", "Generator + Generator", "+20 EN, +10 heat", Color(0.95, 0.45, 0.3))


## A utility part touching a defense part: the defense part's HP ×1.1, per utility part.
static func insulated() -> SynergyRule:
	var rule := _rule(MechPart.PartType.DEFENSE, MechPart.PartType.UTILITY, SynergyRule.Target.FIRST,
		[_bonus(RuleBonus.Stat.HP, RuleBonus.Op.MULTIPLY, 1.1)], true)
	return _named(rule, "insulated", "Utility + Defense", "defense HP ×1.1", Color(0.6, 0.8, 0.95))


# The design doc's newer parts, at its numbers.

## An arm weapon: every 4 s, 150 damage for 160 energy and 90 heat.
static func plasma_lance() -> MechPart:
	return part("Plasma Lance", MechPart.PartType.WEAPON, ARM_SHAPE, 7,
		{"damage": 150, "energy_cost": 160, "heat": 90, "cooldown_max": 4.0})


## A 2x2 generator: 80 energy and 10 heat every second.
static func combustion_core() -> MechPart:
	return part("Combustion Core", MechPart.PartType.GENERATOR, BACK_SHAPE, 5,
		{"energy_gen": 80, "heat": 10, "cooldown_max": 1.0})


## A 1x2 defense part that also makes energy: +100 HP, 15 energy every second.
static func solar_plating() -> MechPart:
	return part("Solar Plating", MechPart.PartType.DEFENSE, [Vector2i(0, 0), Vector2i(1, 0)], 3,
		{"hp": 100, "energy_gen": 15, "cooldown_max": 1.0})


## A 1x1 utility part that vents 5 heat a turn and has no tag, so it's no heatsink.
static func flush_tank() -> MechPart:
	return part("Coolant Flush Tank", MechPart.PartType.UTILITY, [Vector2i(0, 0)], 2, {"cooling": 5})


## A back weapon: every 0.25 s, 4 damage for 8 energy and 2 heat, plus 1 heat for each shot in a
## row before it, up to 10 more.
static func autocannon() -> MechPart:
	var ramp := HeatRamp.new()
	ramp.ramp = 1
	ramp.max_extra = 10
	return part("Rotary Autocannon", MechPart.PartType.WEAPON, BACK_SHAPE, 5,
		{"damage": 4, "energy_cost": 8, "heat": 2, "cooldown_max": 0.25, "abilities": [ramp] as Array[PartAbility]})


## A 1x2 defense part: a 200-point shield for 10 energy a turn.
static func shield_emitter() -> MechPart:
	return part("Energy Shield Emitter", MechPart.PartType.DEFENSE, [Vector2i(0, 0), Vector2i(0, 1)], 4,
		{"shield": 200, "upkeep": 10})


## A 1x1 defense part: +40 HP, and a hit of 30 or more deals 15 back.
static func reactive_armor() -> MechPart:
	var reflect := ReactiveReflect.new()
	reflect.threshold = 30
	reflect.damage = 15
	return part("Reactive Armor", MechPart.PartType.DEFENSE, [Vector2i(0, 0)], 2, {"hp": 40, "abilities": [reflect] as Array[PartAbility]})


## A 2x1 utility part: the mech's weapons only slow above 80 heat.
static func thermal_regulator() -> MechPart:
	var raise := ThrottleRaise.new()
	raise.throttle_heat = 80
	return part("Thermal Regulator", MechPart.PartType.UTILITY, [Vector2i(0, 0), Vector2i(1, 0)], 4, {"abilities": [raise] as Array[PartAbility]})


## A 1x3 utility part: the storm starts 6 s sooner, and this mech takes half of each strike
## (rounded down) and gains 30 energy from it.
static func lightning_rod() -> MechPart:
	var ground := StormGround.new()
	ground.storm_lead = 6.0
	ground.share_taken = 0.5
	ground.energy = 30
	return part("Lightning Rod", MechPart.PartType.UTILITY, ARM_SHAPE, 4, {"abilities": [ground] as Array[PartAbility]})


## A 1x1 utility part: while installed, shops buy every part back in full.
static func scrapper_drone() -> MechPart:
	return part("Scrapper Drone", MechPart.PartType.UTILITY, [Vector2i(0, 0)], 3, {"abilities": [FullRefund.new()] as Array[PartAbility]})


## A 1x1 utility part with no numbers of its own, tagged "chip" for Overclocked.
static func logic_chip() -> MechPart:
	return part("Overdrive Logic Chip", MechPart.PartType.UTILITY, [Vector2i(0, 0)], 3, {"tags": ["chip"] as Array[String]})


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


# Unlocks for profile tests.

## An unlock of [param kind] for [param target_id], earned by the [param milestone] fields (e.g.
## {"sectors_cleared": 1}).
static func unlock(id: String, kind: Unlock.Kind, target_id: String, milestone := {}) -> Unlock:
	var result := Unlock.new()
	result.id = id
	result.kind = kind
	result.target_id = target_id
	result.title = id.capitalize()
	result.hint = "Do the thing"
	for field in milestone:
		assert(field in result, "Unlock has no field '%s'" % field)
		result.set(field, milestone[field])
	return result


# Mech Technician options for run tests.

static func start_option(id: String, kind: RunStartOption.Kind, effects: Array[EventEffect] = []) -> RunStartOption:
	var result := RunStartOption.new()
	result.id = id
	result.text = id.replace("_", " ")
	result.kind = kind
	result.effects = effects
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
		bonuses: Array[RuleBonus], stacks: bool) -> SynergyRule:
	var rule := SynergyRule.new()
	rule.first_type = first_type
	rule.second_type = second_type
	rule.target = target
	rule.bonuses = bonuses
	rule.stacks = stacks
	return rule


static func _bonus(stat: RuleBonus.Stat, op: RuleBonus.Op, amount: float) -> RuleBonus:
	return RuleBonus.new(stat, op, amount)


## A weapon mod with [param prefix] and [param values] (e.g. [code]{"damage_scale": 1.3}[/code]).
static func weapon_mod(id: String, prefix: String, values := {}) -> WeaponMod:
	var mod := WeaponMod.new()
	mod.id = id
	mod.prefix = prefix
	for key in values:
		assert(key in mod, "WeaponMod has no '%s'" % key)
		mod.set(key, values[key])
	return mod


# The design doc's statuses.

## +2 heat a second per charge, up to 10, losing one a second.
static func burn() -> Burn:
	var status := _status_data(Burn.new(), "burn", "Burn", 10)
	status.heat_per_charge = 2.0
	return status


## Weapons 8% slower per charge, down to half speed; up to 6, losing one a second.
static func jammed() -> Jammed:
	var status := _status_data(Jammed.new(), "jammed", "Jammed", 6)
	status.slow_per_charge = 0.08
	status.min_speed = 0.5
	return status


## -6 energy a second per charge, up to 10, losing one a second.
static func drained() -> Drained:
	var status := _status_data(Drained.new(), "drained", "Drained", 10)
	status.energy_per_charge = 6.0
	return status


## Every hit taken 3 bigger per charge, before plating; wraps at 5, stripping the shield; loses
## one every 3 seconds.
static func corroded() -> Corroded:
	var status := _status_data(Corroded.new(), "corroded", "Corroded", 5)
	status.damage_per_charge = 3
	status.overflows = true
	status.decay_interval = 3.0
	status.priority = 9500
	return status


## A weapon ability leaving [param charges] of [param status] on each hit.
static func apply_status(status: MechStatus, charges: int) -> ApplyStatus:
	var ability := ApplyStatus.new()
	ability.status = status
	ability.charges = charges
	return ability


# The design doc's status weapons.

## An arm weapon: every 0.5 s, 4 damage for 12 energy and 6 heat, and 2 Burn.
static func flamer() -> MechPart:
	return part("Flamer", MechPart.PartType.WEAPON, ARM_SHAPE, 5, {"damage": 4, "energy_cost": 12, "heat": 6,
		"cooldown_max": 0.5, "abilities": [apply_status(burn(), 2)] as Array[PartAbility]})


## An arm weapon: every 3 s, 90 damage for 120 energy and 60 heat, through plating and shields.
static func railgun() -> MechPart:
	return part("Railgun", MechPart.PartType.WEAPON, ARM_SHAPE, 7, {"damage": 90, "energy_cost": 120, "heat": 60,
		"cooldown_max": 3.0, "abilities": [Piercing.new()] as Array[PartAbility]})


# The design doc's buffs.

## Shots deal 10% more per charge, up to 5 charges.
static func overcharged() -> Overcharged:
	var status := _status_data(Overcharged.new(), "overcharged", "Overcharged", 5)
	status.type = MechStatus.Type.BUFF
	status.damage_per_charge = 0.1
	status.side = HitInterceptor.Side.ATTACKER
	status.priority = 9000
	status.kinds = [HitPipeline.Kind.SHOT] as Array[HitPipeline.Kind]
	return status


## Hits taken are 2 smaller per charge, after plating, up to 10 charges.
static func fortified() -> Fortified:
	var status := _status_data(Fortified.new(), "fortified", "Fortified", 10)
	status.type = MechStatus.Type.BUFF
	status.block_per_charge = 2
	status.priority = 8500
	return status


## Weapons count down 10% faster per charge, up to half again as fast, up to 5 charges.
static func haste() -> Haste:
	var status := _status_data(Haste.new(), "haste", "Haste", 5)
	status.type = MechStatus.Type.BUFF
	status.speed_per_charge = 0.1
	status.max_speed = 1.5
	return status


static func _status_data(status: MechStatus, id: String, status_name: String, upper: int) -> MechStatus:
	status.id = id
	status.status_name = status_name
	status.upper_bound = upper
	return status


# The design doc's trigger parts.

## A 1x1 utility part: +5 energy each time a weapon it touches fires.
static func capacitor_coupler() -> MechPart:
	var ability := EnergyOnNeighborFire.new()
	ability.energy = 5
	ability.every = 1
	return part("Capacitor Coupler", MechPart.PartType.UTILITY, [Vector2i(0, 0)], 3,
		{"abilities": [ability] as Array[PartAbility]})


## A 2x1 utility part: every 3rd shot from a weapon it touches takes 0.5 s off the others'.
static func ammo_feeder() -> MechPart:
	var ability := FeedOnNeighborFire.new()
	ability.every = 3
	ability.seconds = 0.5
	return part("Ammo Feeder", MechPart.PartType.UTILITY, [Vector2i(0, 0), Vector2i(1, 0)], 4,
		{"abilities": [ability] as Array[PartAbility]})


## A 1x2 utility part: vents 40 heat when the shield breaks.
static func emergency_vent() -> MechPart:
	var ability := VentOnShieldBreak.new()
	ability.heat = 40
	return part("Emergency Vent", MechPart.PartType.UTILITY, [Vector2i(0, 0), Vector2i(0, 1)], 4,
		{"abilities": [ability] as Array[PartAbility]})


## A 1x1 generator: on a meltdown, the weapons it touches charge fully.
static func meltdown_capacitor() -> MechPart:
	return part("Meltdown Capacitor", MechPart.PartType.GENERATOR, [Vector2i(0, 0)], 3,
		{"abilities": [ChargeOnMeltdown.new()] as Array[PartAbility]})


## A 1x2 defense part: +40 HP, and +3 energy for every hit the mech takes.
static func kinetic_dynamo() -> MechPart:
	var ability := EnergyOnDamage.new()
	ability.energy = 3
	return part("Kinetic Dynamo", MechPart.PartType.DEFENSE, [Vector2i(0, 0), Vector2i(0, 1)], 3,
		{"hp": 40, "abilities": [ability] as Array[PartAbility]})


# The design doc's elite affixes.

## Every hit taken 3 smaller.
static func armored() -> Armored:
	var affix := _affix(Armored.new(), "armored", "Armored")
	affix.plating = 3
	return affix


## Starts each fight with a quarter of its max HP as shield.
static func shielded() -> Shielded:
	var affix := _affix(Shielded.new(), "shielded", "Shielded")
	affix.shield_share = 0.25
	return affix


## Weapons cool down 85% as long.
static func rapid_fire() -> RapidFire:
	var affix := _affix(RapidFire.new(), "rapid_fire", "Rapid-Fire")
	affix.cooldown_scale = 0.85
	return affix


## A shot of 30 or more deals 15 back.
static func reflective() -> Reflective:
	var affix := _affix(Reflective.new(), "reflective", "Reflective")
	affix.threshold = 30
	affix.damage = 15
	return affix


## Repairs 1% of max HP a second.
static func regenerating() -> Regenerating:
	var affix := _affix(Regenerating.new(), "regenerating", "Regenerating")
	affix.heal_share = 0.01
	return affix


## Weapons hit 1.2 times as hard and make 10 more heat a shot.
static func unstable() -> Unstable:
	var affix := _affix(Unstable.new(), "unstable", "Unstable")
	affix.damage_scale = 1.2
	affix.heat_add = 10
	return affix


## The first shot each fight deals nothing.
static func ablative_affix() -> AblativeCore:
	var affix := _affix(AblativeCore.new(), "ablative", "Ablative")
	affix.hits = 1
	return affix


## The first debuff each fight doesn't land.
static func hardened_firmware() -> HardenedFirmware:
	var affix := _affix(HardenedFirmware.new(), "hardened_firmware", "Hardened Firmware")
	affix.blocks = 1
	return affix


## Each landed shot repairs a fifth of its damage.
static func vampiric() -> Vampiric:
	var affix := _affix(Vampiric.new(), "vampiric", "Vampiric")
	affix.share = 0.2
	return affix


## Shots leave 1 Jammed.
static func jamming() -> Burning:
	var affix := _affix(Burning.new(), "jamming", "Jamming")
	affix.status = jammed()
	affix.charges = 1
	return affix


## Shots leave 1 Burn.
static func burning() -> Burning:
	var affix := _affix(Burning.new(), "burning", "Burning")
	affix.status = burn()
	affix.charges = 1
	return affix


## A boss phase at [param threshold] of max HP with [param values] (e.g. [code]{"shield_share": 0.3}[/code]).
static func boss_phase(title: String, threshold := 0.5, values := {}) -> BossPhase:
	var phase := BossPhase.new()
	phase.title = title
	phase.threshold = threshold
	for key in values:
		assert(key in phase, "BossPhase has no '%s'" % key)
		phase.set(key, values[key])
	return phase


static func _affix(affix: Relic, id: String, relic_name: String) -> Relic:
	affix.id = id
	affix.relic_name = relic_name
	affix.rarity = Relic.Rarity.AFFIX
	return affix


# The design doc's Hangar jobs.

## Repair (30% of max, needs damage), Reinforce (+25 max HP), Upgrade (a part a Mk), and Expand
## (one more cell to open): all exclusive and free.
static func hangar_jobs() -> Array[HangarJob]:
	var repair := RepairShareEffect.new()
	repair.share = 0.3
	var reinforce := MaxHpEffect.new()
	reinforce.hp = 25
	var expand := ExpandEffect.new()
	expand.cells = 1
	return [
		hangar_job("repair", "Repair", [repair], DamagedRequirement.new()),
		hangar_job("reinforce", "Reinforce", [reinforce]),
		hangar_job("upgrade", "Upgrade", [], UpgradableRequirement.new(), HangarJob.Kind.UPGRADE, "Raise one part a Mk."),
		hangar_job("expand", "Expand", [expand], ExpandableRequirement.new()),
	]


static func hangar_job(id: String, label: String, effects: Array[EventEffect], requirement: EventRequirement = null,
		kind := HangarJob.Kind.EFFECTS, hint := "") -> HangarJob:
	var job := HangarJob.new()
	job.id = id
	job.label = label
	job.effects = effects
	job.requirement = requirement
	job.kind = kind
	job.hint = hint
	return job


# The design doc's Threat ladder and custom modes.

## A run modifier with [param values] (e.g. [code]{"enemy_hp_scale": 1.1}[/code]); a Threat level
## when [param threat] is above 0.
static func run_modifier(id: String, values := {}, threat := 0) -> RunModifier:
	var modifier := RunModifier.new()
	modifier.id = id
	modifier.modifier_name = id.capitalize()
	modifier.description = id.capitalize()
	modifier.threat_level = threat
	for key in values:
		assert(key in modifier, "RunModifier has no '%s'" % key)
		modifier.set(key, values[key])
	return modifier


## Threat 1 to 8: enemies +10% HP, shop prices +15%, normal battles -25% gold, elites +1 affix,
## repairs -10% of max HP, boss phases +16%, normal battles a 25% affix chance, and a start with
## 10% hull damage and a Glitch.
static func threat_levels() -> Array[RunModifier]:
	return [
		run_modifier("threat_1", {"enemy_hp_scale": 1.1}, 1),
		run_modifier("threat_2", {"shop_price_scale": 1.15}, 2),
		run_modifier("threat_3", {"battle_gold_scale": 0.75}, 3),
		run_modifier("threat_4", {"elite_affixes_add": 1}, 4),
		run_modifier("threat_5", {"repair_share_add": -0.1}, 5),
		run_modifier("threat_6", {"phase_threshold_add": 0.16}, 6),
		run_modifier("threat_7", {"normal_affix_chance": 0.25}, 7),
		run_modifier("threat_8", {"start_hull_damage_share": 0.1, "start_parts": [glitch()] as Array[MechPart]}, 8),
	]


## Weapons deal 1.5 times the damage; the mech has half the HP.
static func glass_cannon() -> RunModifier:
	return run_modifier("glass_cannon", {"is_custom": true, "player_damage_scale": 1.5, "player_hp_scale": 0.5})


## The sectors loop after the last boss.
static func endless() -> RunModifier:
	return run_modifier("endless", {"is_custom": true, "endless": true})


## A 1x1 junk part that does nothing and can't be sold.
static func glitch() -> MechPart:
	return part("Glitch", MechPart.PartType.JUNK, [Vector2i(0, 0)], 0, {"sellable": false})


# The design doc's second round of parts.

## The first common arm weapon: 14 damage a second for 25 EN, 12 heat.
static func scrap_repeater() -> MechPart:
	return part("Scrap Repeater", MechPart.PartType.WEAPON, ARM_SHAPE, 3, {"damage": 14, "energy_cost": 25, "heat": 12,
		"cooldown_max": 1.0})


## The first common back weapon: 35 damage every 2.5 s for 40 EN, 20 heat.
static func rivet_mortar() -> MechPart:
	return part("Rivet Mortar", MechPart.PartType.WEAPON, BACK_SHAPE, 4, {"damage": 35, "energy_cost": 40, "heat": 20,
		"cooldown_max": 2.5})


## An arm weapon: 12 damage a second for 20 EN, 10 heat, and 2 Jammed a hit.
static func shock_lance() -> MechPart:
	return part("Shock Lance", MechPart.PartType.WEAPON, ARM_SHAPE, 5, {"damage": 12, "energy_cost": 20, "heat": 10,
		"cooldown_max": 1.0, "abilities": [apply_status(jammed(), 2)] as Array[PartAbility]})


## An arm weapon: 10 damage every half second for 15 EN, 8 heat, repairing a quarter of each hit.
static func leech_drill() -> MechPart:
	var leech := Leech.new()
	leech.share = 0.25
	return part("Leech Drill", MechPart.PartType.WEAPON, ARM_SHAPE, 5, {"damage": 10, "energy_cost": 15, "heat": 8,
		"cooldown_max": 0.5, "abilities": [leech] as Array[PartAbility]})


## A back weapon: 50 damage every 2.5 s for 90 EN, 50 heat; double against a target at 30% HP or less.
static func guillotine_cannon() -> MechPart:
	var execute := Execute.new()
	execute.threshold = 0.3
	execute.multiplier = 2.0
	return part("Guillotine Cannon", MechPart.PartType.WEAPON, BACK_SHAPE, 7, {"damage": 50, "energy_cost": 90,
		"heat": 50, "cooldown_max": 2.5, "abilities": [execute] as Array[PartAbility]})


## A back weapon: 30 damage every 2 s for 60 EN, 30 heat; +2 damage for each fight won, up to +40.
static func trophy_rack() -> MechPart:
	var growth := TrophyGrowth.new()
	growth.damage = 2
	growth.max_bonus = 40
	return part("Trophy Rack", MechPart.PartType.WEAPON, BACK_SHAPE, 6, {"damage": 30, "energy_cost": 60, "heat": 30,
		"cooldown_max": 2.0, "abilities": [growth] as Array[PartAbility]})


## A heavy back weapon: 120 damage every 4 s for 150 EN, 80 heat.
static func siege_cannon() -> MechPart:
	return part("Siege Cannon", MechPart.PartType.WEAPON, BACK_SHAPE, 8, {"damage": 120, "energy_cost": 150, "heat": 80,
		"cooldown_max": 4.0})


## A 2x1 generator: +0.8 EN a second for each point of heat.
static func thermoelectric() -> MechPart:
	var ability := HeatToEnergy.new()
	ability.energy_per_heat = 0.8
	return part("Thermoelectric Generator", MechPart.PartType.GENERATOR, [Vector2i(0, 0), Vector2i(1, 0)], 4,
		{"abilities": [ability] as Array[PartAbility]})


## A 1x1 generator: every 4th shot from a weapon it touches releases 40 EN.
static func capacitor_battery() -> MechPart:
	var ability := EnergyOnNeighborFire.new()
	ability.energy = 40
	ability.every = 4
	return part("Capacitor Battery", MechPart.PartType.GENERATOR, [Vector2i(0, 0)], 3,
		{"abilities": [ability] as Array[PartAbility]})


## A 2x2 generator: +150 EN and +25 heat every second.
static func fusion_cell() -> MechPart:
	return part("Fusion Cell", MechPart.PartType.GENERATOR, BACK_SHAPE, 7, {"energy_gen": 150, "heat": 25,
		"cooldown_max": 1.0})


## A 1x2 defense part: +20 HP, and repairs 1% of max HP a second.
static func nanite_bay() -> MechPart:
	var ability := RepairOverTime.new()
	ability.share = 0.01
	return part("Nanite Repair Bay", MechPart.PartType.DEFENSE, [Vector2i(0, 0), Vector2i(0, 1)], 5,
		{"hp": 20, "abilities": [ability] as Array[PartAbility]})


## A 1x1 defense part: +20 HP, and the first 2 shots each fight deal nothing.
static func ablative_plating() -> MechPart:
	var ability := Ablative.new()
	ability.hits = 2
	return part("Ablative Plating", MechPart.PartType.DEFENSE, [Vector2i(0, 0)], 2,
		{"hp": 20, "abilities": [ability] as Array[PartAbility]})


## A 1x1 defense part: no single hit takes more than 60.
static func damage_limiter() -> MechPart:
	var ability := DamageCap.new()
	ability.cap = 60
	ability.stacks = false
	return part("Damage Limiter", MechPart.PartType.DEFENSE, [Vector2i(0, 0)], 5,
		{"abilities": [ability] as Array[PartAbility]})


## A 1x1 utility part: every 5 s, clears the debuff with the most charges.
static func status_scrubber() -> MechPart:
	var ability := StatusScrubber.new()
	ability.interval = 5.0
	return part("Status Scrubber", MechPart.PartType.UTILITY, [Vector2i(0, 0)], 4,
		{"abilities": [ability] as Array[PartAbility]})


## A 1x1 utility part tagged targeting: see [method targeted].
static func targeting_computer() -> MechPart:
	return part("Targeting Computer", MechPart.PartType.UTILITY, [Vector2i(0, 0)], 4,
		{"tags": ["targeting"] as Array[String]})


## Targeting + Weapon: each targeting part touching a weapon makes it hit 1.1 times as hard.
static func targeted() -> SynergyRule:
	var rule := _rule(MechPart.PartType.WEAPON, MechPart.PartType.UTILITY, SynergyRule.Target.FIRST, [
		_bonus(RuleBonus.Stat.DAMAGE, RuleBonus.Op.MULTIPLY, 1.1),
	], true)
	rule.second_tag = "targeting"
	return _named(rule, "targeted", "Targeting + Weapon", "weapon dmg ×1.1", Color(0.45, 0.85, 0.95))


# The design doc's second round of weapon mods.

## A quarter again as fast, for 15% less damage.
static func rapid_mod() -> WeaponMod:
	return weapon_mod("rapid", "Rapid", {"cooldown_scale": 0.8, "damage_scale": 0.85})


## 10 less heat a shot, for 10% less damage.
static func stabilized_mod() -> WeaponMod:
	return weapon_mod("stabilized", "Stabilized", {"heat_add": -10, "damage_scale": 0.9})


## Each hit repairs a tenth of its damage.
static func siphon_mod() -> WeaponMod:
	var leech := Leech.new()
	leech.share = 0.1
	return weapon_mod("siphon", "Siphon", {"abilities": [leech] as Array[PartAbility]})


## +1 Corroded a hit, for 10% less damage.
static func corrosive_mod() -> WeaponMod:
	return weapon_mod("corrosive", "Corrosive", {"damage_scale": 0.9,
		"abilities": [apply_status(corroded(), 1)] as Array[PartAbility]})


# The design doc's second-round frames.

## Evasion: 3 wide by 4 tall with the top corners cut, 250 HP, 45 energy a turn; every 4th shot
## at it misses. Arms beside rows 1-3.
static func phantom_frame() -> MechChassis:
	var chassis := _frame("The Phantom", "Slim frame", Vector2i(3, 4), [Vector2i(0, 0), Vector2i(2, 0)], 250, 45)
	chassis.hardpoints = [left_arm(Vector2i(-1, 1)), right_arm(Vector2i(3, 1))]
	chassis.playstyle = "Evasion / Tempo"
	var evasion := EvasionPassive.new()
	evasion.every = 4
	chassis.passive = evasion
	chassis.passive_name = "Evasion"
	chassis.passive_text = "Every 4th shot aimed at it misses."
	return chassis


## Siege: 5 wide by 3 tall, 450 HP, 15 energy a turn; weapons fire 2% faster a second of the
## fight, up to 30%. Two backs over columns 0-1 and 3-4, and arms beside rows 1-2.
static func juggernaut_frame() -> MechChassis:
	var chassis := _frame("The Juggernaut", "Heavy frame", Vector2i(5, 3), [], 450, 15)
	chassis.hardpoints = [back(Vector2i(0, -2)), hardpoint("back_right", "Back Right", Vector2i(3, -2), BACK_SHAPE),
		left_arm(Vector2i(-1, 1)), right_arm(Vector2i(5, 1))]
	chassis.playstyle = "Siege / Momentum"
	var momentum := MomentumPassive.new()
	momentum.per_second = 0.02
	momentum.max_bonus = 0.3
	chassis.passive = momentum
	chassis.passive_name = "Momentum"
	chassis.passive_text = "Weapons fire 2% faster for every second of the fight, up to 30%."
	return chassis
