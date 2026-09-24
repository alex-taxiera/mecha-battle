class_name MeltdownPassive
extends ChassisPassive
## At full heat the mech deals [member damage] to its enemy, cools to 0, then shuts down for
## [member shutdown] seconds. The [CombatEngine] runs it (see its [signal CombatEngine.meltdown]).

## Damage dealt to the enemy when the mech melts down.
@export var damage := 25
## Seconds the mech's parts and chassis stop after a meltdown.
@export var shutdown := 3.0
