class_name ShopScreen
extends Control
## Root of the shop phase: the round and gold up top, the mech on the left, the parts shop on
## the right, and the mech's stats below. Drag parts from the shop onto the mech to buy them
## (weapons onto the hardpoints around its grid), around the mech to move them, and back onto
## the shop to sell them. Next round asks for the
## round's fight; [method finish_round] records it and opens the next round's shop.

## Emitted when the player is done shopping and wants this round's fight.
signal fight_requested

const SHOP_ITEM_SCENE := preload("res://src/ui/ShopItem.tscn")
const PARTS_DIR := "res://resources/parts"
const RULES_DIR := "res://resources/rules"
const TOAST_SECONDS := 1.9
const GOOD_COLOR := Color(0.49, 0.88, 0.63)
const BAD_COLOR := Color(0.94, 0.42, 0.42)
const _RESULT_WORDS := {
	RunState.FightResult.WIN: "Won",
	RunState.FightResult.LOSS: "Lost",
	RunState.FightResult.DRAW: "Drew",
}

@export var chassis: MechChassis
@export var starting_gold := 10
## Parts for sale. Left empty, the shop sells every MechPart in [constant PARTS_DIR].
@export var catalog: Array[MechPart] = []
## Adjacency rules. Left empty, every SynergyRule in [constant RULES_DIR] applies.
@export var rules: Array[SynergyRule] = []

var run: RunState

# The run's current stats, refreshed on every change.
var _stats: MechStats
var _toast_timer: Timer

@onready var _round_label: Label = %RoundLabel
@onready var _record_label: Label = %RecordLabel
@onready var _gold_label: Label = %GoldLabel
@onready var _next_round_button: Button = %NextRoundButton
@onready var _chassis_label: Label = %ChassisLabel
@onready var _chassis_info: Label = %ChassisInfo
@onready var _passive_label: Label = %PassiveLabel
@onready var _grid_ui: MechGridUI = %MechGridUI
@onready var _reroll_button: Button = %RerollButton
@onready var _slots: Container = %Slots
@onready var _sell_zone: Control = %SellZone
@onready var _sell_label: Label = %SellLabel
@onready var _sell_note: Label = %SellNote
@onready var _stats_panel: StatsPanel = %StatsPanel
@onready var _toast: Label = %Toast


func _ready() -> void:
	if catalog.is_empty():
		catalog.assign(load_dir(PARTS_DIR).filter(func(resource: Resource) -> bool: return resource is MechPart))
	if rules.is_empty():
		rules.assign(load_dir(RULES_DIR).filter(func(resource: Resource) -> bool: return resource is SynergyRule))
	run = RunState.new(chassis, catalog, rules, starting_gold)
	run.changed.connect(_refresh)
	_grid_ui.run = run
	_grid_ui.preview_changed.connect(_on_preview_changed)
	_grid_ui.message.connect(show_toast)
	_reroll_button.pressed.connect(_on_reroll_pressed)
	_next_round_button.pressed.connect(_on_next_round_pressed)
	_sell_zone.set_drag_forwarding(Callable(), can_sell, sell)
	_sell_zone.hide()
	_stats_panel.show_rules(run.rules)
	_toast_timer = Timer.new()
	_toast_timer.one_shot = true
	_toast_timer.timeout.connect(_toast.hide)
	add_child(_toast_timer)
	_toast.hide()
	_refresh()


func _notification(what: int) -> void:
	if not is_node_ready():
		return
	if what == NOTIFICATION_DRAG_BEGIN:
		var drag: Variant = get_viewport().gui_get_drag_data()
		if drag is PartDragData and not drag.is_from_shop():
			show_sell_zone(drag)
	elif what == NOTIFICATION_DRAG_END:
		_sell_zone.hide()


## Shows [param text] briefly at the top of the screen, green when [param good].
func show_toast(text: String, good: bool) -> void:
	_toast.text = text
	_toast.add_theme_color_override("font_color", GOOD_COLOR if good else BAD_COLOR)
	_toast.show()
	_toast_timer.start(TOAST_SECONDS)


## Covers the shop with a drop zone that sells the installed part being dragged.
func show_sell_zone(drag: PartDragData) -> void:
	_sell_label.text = "Sell for +%dg" % run.sell_value(drag.from_cell)
	if run.is_fresh(drag.from_cell):
		_sell_note.text = "Full refund: bought this round"
	else:
		_sell_note.text = "Half value: bought in an earlier round"
	_sell_zone.show()


## Returns whether [param data] is an installed part that can be sold by dropping it here.
func can_sell(_at_position: Vector2, data: Variant) -> bool:
	return data is PartDragData and not data.is_from_shop()


## Sells the installed part being dropped on the shop.
func sell(_at_position: Vector2, data: Variant) -> void:
	var drag: PartDragData = data
	var gained := run.sell(drag.from_cell)
	_sell_zone.hide()
	show_toast("Sold %s · +%dg" % [drag.part.part_name, gained], true)


func _refresh() -> void:
	_stats = run.stats()
	_round_label.text = "Hangar · Round %d" % run.round_number
	_record_label.text = "Record: %d W · %d L" % [run.wins, run.losses]
	if run.draws:
		_record_label.text += " · %d D" % run.draws
	_gold_label.text = "Gold: %d" % run.gold
	var frame := run.grid.chassis
	_chassis_label.text = "Chassis · %s" % frame.chassis_name
	_chassis_info.text = "%s · %d / %d slots · %d / %d hardpoints" % [frame.frame_name, run.grid.get_used_cell_count(),
		frame.get_usable_cell_count(), run.grid.get_mounted_count(), frame.hardpoints.size()]
	_passive_label.visible = frame.passive != MechChassis.Passive.NONE
	_passive_label.text = "%s: %s" % [frame.passive_name, frame.passive_text]
	_reroll_button.text = "Reroll · %dg" % RunState.REROLL_COST
	for item in _slots.get_children():
		_slots.remove_child(item)
		item.queue_free()
	for i in run.slots.size():
		var slot := run.slots[i]
		var item: ShopItem = SHOP_ITEM_SCENE.instantiate()
		item.slot_index = i
		item.part = slot.part
		item.turns = slot.rotation
		item.sold = slot.sold
		item.affordable = run.can_afford(slot.part)
		item.rotate_requested.connect(run.rotate_slot.bind(i))
		_slots.add_child(item)
	_stats_panel.show_stats(_stats, null, frame)


func _on_preview_changed(preview: MechStats) -> void:
	_stats_panel.show_stats(_stats, preview, run.grid.chassis)


func _on_reroll_pressed() -> void:
	if not run.reroll():
		show_toast("Not enough gold to reroll", false)


## Records how the round's fight went, then starts the next round: income, a restock, and a
## toast saying so.
func finish_round(result: RunState.FightResult) -> void:
	var fought := run.round_number
	run.record_fight(result)
	run.end_round()
	show_toast("%s round %d · +%dg income, shop restocked" % [_RESULT_WORDS[result], fought, run.round_income],
		result != RunState.FightResult.LOSS)


func _on_next_round_pressed() -> void:
	fight_requested.emit()


## Loads every resource in [param dir], e.g. [constant PARTS_DIR]. Other screens use it to
## load the same content the shop does.
static func load_dir(dir: String) -> Array[Resource]:
	var loaded: Array[Resource] = []
	for file in ResourceLoader.list_directory(dir):
		if not file.ends_with("/"):
			loaded.append(load(dir.path_join(file)))
	return loaded
