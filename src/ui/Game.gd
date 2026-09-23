class_name Game
extends Node
## Plays a run: the player picks a chassis, then shops, and each round fights with their
## build and returns to the shop for the next round. One ShopScreen lives for the whole run
## and holds its [RunState]; it steps out of the tree while a fight plays.

const SHOP_SCENE := preload("res://src/ui/ShopScreen.tscn")
const COMBAT_SCENE := preload("res://src/ui/CombatScreen.tscn")

## Parts and adjacency rules for the run's shop. Left empty, the shop loads its folders.
var catalog: Array[MechPart] = []
var rules: Array[SynergyRule] = []
## Builds the mech the player fights each round. Left unset, it's the combat screen's dummy.
var make_opponent: Callable
## The run's shop, once a chassis is chosen.
var shop: ShopScreen
## The fight playing now, or null while the player is shopping.
var combat: CombatScreen

# The player's mech in the current fight.
var _player: BattleMech

@onready var chassis_select: ChassisSelectScreen = %ChassisSelectScreen


func _ready() -> void:
	# Deferred, so a screen isn't taken out of the tree while it's still emitting.
	chassis_select.chassis_chosen.connect(_start_run, CONNECT_DEFERRED)


func _start_run(chassis: MechChassis) -> void:
	shop = SHOP_SCENE.instantiate()
	shop.chassis = chassis
	shop.catalog.assign(catalog)
	shop.rules.assign(rules)
	shop.fight_requested.connect(_start_fight, CONNECT_DEFERRED)
	remove_child(chassis_select)
	chassis_select.queue_free()
	chassis_select = null
	add_child(shop)
	if not make_opponent.is_valid():
		make_opponent = func() -> BattleMech: return CombatScreen.make_dummy(shop.run.rules)


# The player's build, as it is when they press Next round, fights on the left.
func _start_fight() -> void:
	_player = BattleMech.new(shop.run.grid, shop.run.rules)
	combat = COMBAT_SCENE.instantiate()
	combat.setup(_player, make_opponent.call())
	combat.finished.connect(_end_fight, CONNECT_DEFERRED)
	remove_child(shop)
	add_child(combat)


func _end_fight(winner: BattleMech) -> void:
	var result := RunState.FightResult.DRAW
	if winner == _player:
		result = RunState.FightResult.WIN
	elif winner != null:
		result = RunState.FightResult.LOSS
	remove_child(combat)
	combat.queue_free()
	combat = null
	_player = null
	add_child(shop)
	shop.finish_round(result)
