class_name KitBar
extends HBoxContainer
## The player's field kits in a fight, one button each: a MANUAL kit uses itself when pressed (if
## its mech has the energy); AUTO and FIGHT_START kits show when they act. A used kit greys out.

var engine: CombatEngine
var mech: BattleMech


func _init(p_engine: CombatEngine = null, p_mech: BattleMech = null) -> void:
	engine = p_engine
	mech = p_mech
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 8)
	if mech:
		for i in mech.kits.size():
			var button := Button.new()
			button.custom_minimum_size = Vector2(150, 38)
			button.focus_mode = Control.FOCUS_NONE
			button.pressed.connect(use.bind(i))
			add_child(button)
	refresh()


## Uses kit [param index] if it can be used now. Returns whether it was.
func use(index: int) -> bool:
	var used := engine.use_kit(mech, index)
	refresh()
	return used


## Updates each button: its label, and whether it can be pressed.
func refresh() -> void:
	if mech == null:
		return
	for i in get_child_count():
		var button := get_child(i) as Button
		var kit := mech.kits[i]
		var used := not mech.can_use_kit(i)
		button.tooltip_text = KitIcon.describe(kit)
		button.add_theme_color_override("font_color", kit.color)
		if used:
			button.text = "%s · used" % kit.kit_name
		elif kit.trigger == FieldKit.Trigger.MANUAL:
			button.text = kit.kit_name + (" · %d EN" % kit.energy_cost if kit.energy_cost > 0 else "")
		else:
			button.text = "%s · auto" % kit.kit_name
		button.disabled = used or kit.trigger != FieldKit.Trigger.MANUAL or mech.current_energy < kit.energy_cost \
			or engine.state != CombatEngine.State.RUNNING
