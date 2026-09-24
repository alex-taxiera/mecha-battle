class_name ThrottleRaise
extends PartAbility
## A thermal regulator: the mech's weapons only start to slow above [member throttle_heat]
## heat instead of [constant BattleMech.THROTTLE_HEAT]. More regulators don't do more.

@export var throttle_heat := 80


func _init() -> void:
	stacks = false


func on_fight_start(mech: BattleMech, _active: ActivePart) -> void:
	mech.throttle_heat = maxi(mech.throttle_heat, throttle_heat)
