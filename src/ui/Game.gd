class_name Game
extends Node
## Plays a run: the shop, then each round a fight between the player's build and an opponent,
## then back to the shop for the next round. The one ShopScreen lives for the whole run and
## holds its [RunState]; it steps out of the tree while a fight plays.

const COMBAT_SCENE := preload("res://src/ui/CombatScreen.tscn")

## Builds the mech the player fights each round. Left unset, it's the combat screen's dummy.
var make_opponent: Callable
## The fight playing now, or null while the player is shopping.
var combat: CombatScreen

# The player's mech in the current fight.
var _player: BattleMech

@onready var shop: ShopScreen = %ShopScreen


func _ready() -> void:
	if not make_opponent.is_valid():
		make_opponent = func() -> BattleMech: return CombatScreen.make_dummy(shop.run.grid.chassis, shop.run.rules)
	# Deferred, so a screen isn't taken out of the tree while it's still emitting.
	shop.fight_requested.connect(_start_fight, CONNECT_DEFERRED)


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
