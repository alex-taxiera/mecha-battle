class_name MechGauges
extends VBoxContainer
## A mech's energy and heat gauges, stacked under it on the stage. Energy fills toward
## [constant ENERGY_SCALE] and shows the real bank past it. Heat runs 0 to
## [constant BattleMech.MAX_HEAT], with a tick where it starts to slow the weapons; past it the
## fill reddens as they slow. Above [constant HOT_HEAT], or while the mech is shut down, the
## gauge runs hot.

## A full energy bar. The engine has no cap, so a bigger bank just shows a full bar.
const ENERGY_SCALE := 100.0
## Heat above this turns the gauge red.
const HOT_HEAT := 80

var energy := GaugeBar.new()
var heat := GaugeBar.new()
## Seconds both gauges take to glide to a new value.
var smoothing := 0.1:
	set(p_smoothing):
		smoothing = p_smoothing
		energy.smoothing = smoothing
		heat.smoothing = smoothing


func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 12)
	energy.label = "EN"
	energy.tag_color = CombatColors.ENERGY
	energy.fill_color = CombatColors.ENERGY
	energy.max_value = ENERGY_SCALE
	heat.label = "HT"
	heat.max_value = BattleMech.MAX_HEAT
	heat.mark = float(BattleMech.THROTTLE_HEAT) / BattleMech.MAX_HEAT
	add_child(energy)
	add_child(heat)
	_show_heat(0, false)


## Shows [param mech]'s energy and heat as they are now.
func refresh(mech: BattleMech) -> void:
	energy.set_value(mech.current_energy)
	_show_heat(mech.heat, mech.is_shut_down(), mech.get_fire_rate())


# [param fire_rate] reddens the fill as heat slows the weapons.
func _show_heat(amount: int, shut_down: bool, fire_rate := 1.0) -> void:
	heat.hot = amount > HOT_HEAT or shut_down
	heat.tag_color = CombatColors.DANGER if heat.hot else CombatColors.HEAT
	var throttle := (1.0 - fire_rate) / (1.0 - BattleMech.MIN_FIRE_RATE)
	heat.fill_color = CombatColors.HEAT.lerp(CombatColors.DANGER, throttle)
	heat.set_value(amount, "OFFLINE" if shut_down else "")
