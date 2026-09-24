class_name LoadoutScreen
extends Control
## Where the player works on their mech: the run up top, the mech on the left, the stash on the
## right, and the mech's stats below. Drag parts around the mech to move them, from the stash
## onto it to install them, and off it onto the stash to store them. At a Scrap Shop (while the
## run has one open) the shop sits above the stash: drag its parts onto the mech or the stash to
## buy them, buy its relics with their buttons, and drag parts from the mech or the stash onto it
## to sell them. The leave button emits
## [signal leave_requested].

## Emitted when the player is done here.
signal leave_requested

const SHOP_ITEM_SCENE := preload("res://src/ui/ShopItem.tscn")
const PARTS_DIR := "res://resources/parts"
const RULES_DIR := "res://resources/rules"
const TOAST_SECONDS := 1.9
const GOOD_COLOR := Color(0.49, 0.88, 0.63)
const BAD_COLOR := Color(0.94, 0.42, 0.42)


@export var chassis: MechChassis
## Gold for the run this screen starts when it isn't given one.
@export var starting_gold := 10
## Parts for sale. Left empty, the shop sells every MechPart in [constant PARTS_DIR].
@export var catalog: Array[MechPart] = []
## Adjacency rules. Left empty, every SynergyRule in [constant RULES_DIR] applies.
@export var rules: Array[SynergyRule] = []

## The run to work on, set before the screen enters the tree; it shows the shop if the run has
## one open. Left unset, the screen starts its own run on [member chassis], with a shop open.
var run: RunState

# The run's current stats, refreshed on every change.
var _stats: MechStats
var _toast_timer: Timer
# The run's field kits under the chassis, and the shop's kit offers under its relics, built on
# the first refresh.
var _kits_box: VBoxContainer
var _kit_offers: HBoxContainer

@onready var _round_label: Label = %RoundLabel
@onready var _screen_title: Label = %ScreenTitle
@onready var _record_label: Label = %RecordLabel
@onready var _gold_label: Label = %GoldLabel
@onready var _leave_button: Button = %LeaveButton
@onready var _chassis_label: Label = %ChassisLabel
@onready var _chassis_info: Label = %ChassisInfo
@onready var _passive_label: Label = %PassiveLabel
@onready var _grid_ui: MechGridUI = %MechGridUI
@onready var _shop_area: Control = %ShopArea
@onready var _stash_panel: StashPanel = %StashPanel
@onready var _reroll_button: Button = %RerollButton
@onready var _slots: Container = %Slots
@onready var _relic_offers: Container = %RelicOffers
@onready var _sell_zone: Control = %SellZone
@onready var _sell_label: Label = %SellLabel
@onready var _sell_note: Label = %SellNote
@onready var _stats_panel: StatsPanel = %StatsPanel
@onready var _toast: Label = %Toast


func _ready() -> void:
	if run == null:
		if catalog.is_empty():
			catalog.assign(load_dir(PARTS_DIR).filter(func(resource: Resource) -> bool: return resource is MechPart))
		if rules.is_empty():
			rules.assign(load_dir(RULES_DIR).filter(func(resource: Resource) -> bool: return resource is SynergyRule))
		run = RunState.new(chassis, catalog, rules, starting_gold)
		run.open_shop()
	run.changed.connect(_refresh)
	_grid_ui.run = run
	_grid_ui.preview_changed.connect(_on_preview_changed)
	_grid_ui.message.connect(show_toast)
	_stash_panel.run = run
	_stash_panel.message.connect(show_toast)
	_reroll_button.pressed.connect(_on_reroll_pressed)
	_leave_button.pressed.connect(leave_requested.emit)
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
		if drag is PartDragData and not drag.is_from_shop() and run.can_sell():
			show_sell_zone(drag)
	elif what == NOTIFICATION_DRAG_END:
		_sell_zone.hide()


## Shows [param text] briefly at the top of the screen, green when [param good].
func show_toast(text: String, good: bool) -> void:
	_toast.text = text
	_toast.add_theme_color_override("font_color", GOOD_COLOR if good else BAD_COLOR)
	_toast.show()
	_toast_timer.start(TOAST_SECONDS)


## Covers the shop with a drop zone that sells the part being dragged, from the mech or the stash.
func show_sell_zone(drag: PartDragData) -> void:
	var value := run.stash_sell_value(drag.stash_index) if drag.is_from_stash() else run.sell_value(drag.from_cell)
	var fresh := run.is_stash_fresh(drag.stash_index) if drag.is_from_stash() else run.is_fresh(drag.from_cell)
	_sell_label.text = "Sell for +%dg" % value
	if not drag.part.sellable:
		_sell_label.text = "Can't be sold"
		_sell_note.text = "No shop will take it"
	elif fresh:
		_sell_note.text = "Full refund: bought at this shop"
	elif run.refunds_in_full():
		_sell_note.text = "Full refund: a scrapper drone is installed"
	else:
		_sell_note.text = "Half value: bought earlier"
	_sell_zone.show()


## Returns whether [param data] is a part from the mech or the stash that can be sold by dropping
## it here: only at a shop.
func can_sell(_at_position: Vector2, data: Variant) -> bool:
	return data is PartDragData and not data.is_from_shop() and run.can_sell_part(data.part)


## Sells the part being dropped on the shop.
func sell(_at_position: Vector2, data: Variant) -> void:
	var drag: PartDragData = data
	var gained := run.sell_stashed(drag.stash_index) if drag.is_from_stash() else run.sell(drag.from_cell)
	_sell_zone.hide()
	show_toast("Sold %s · +%dg" % [drag.part.get_display_name(), gained], true)


func _refresh() -> void:
	_stats = run.stats()
	_round_label.text = "Sector %d · Floor %d" % [run.act_index + 1, run.get_floor_number()] if run.get_act() else "Run"
	var shopping := run.shop != null
	_screen_title.text = "Scrap Shop" if shopping else "Loadout"
	_leave_button.text = "Leave shop" if shopping else "Back to map"
	_shop_area.visible = shopping
	_record_label.text = "Hull: %d / %d HP · %d won" % [run.get_current_hp(), run.get_max_hp(), run.fights_won]
	_gold_label.text = "Gold: %d" % run.gold
	var frame := run.grid.chassis
	_chassis_label.text = "Chassis · %s" % frame.chassis_name
	_chassis_info.text = "%s · %d / %d slots · %d / %d hardpoints" % [frame.frame_name, run.grid.get_used_cell_count(),
		frame.get_usable_cell_count(), run.grid.get_mounted_count(), frame.hardpoints.size()]
	var locked := frame.get_locked_cells().size()
	# Cells the player can open glow on the grid, and their tooltips say to click them.
	if run.cells_to_open > 0:
		_chassis_info.text += " · %d to open" % run.cells_to_open
	elif locked > 0:
		_chassis_info.text += " · %d locked" % locked
	_passive_label.visible = frame.passive != null
	_passive_label.text = "%s: %s" % [frame.passive_name, frame.passive_text]
	_reroll_button.text = "Reroll · %dg" % run.get_reroll_cost()
	for item in _slots.get_children():
		_slots.remove_child(item)
		item.queue_free()
	# The shop closes as the player leaves, just before the screen goes.
	var slots: Array[ShopStock.Slot] = []
	if run.shop:
		slots = run.shop.slots
	for i in slots.size():
		var slot := slots[i]
		var item: ShopItem = SHOP_ITEM_SCENE.instantiate()
		item.slot_index = i
		item.part = slot.part
		item.turns = slot.rotation
		item.sold = slot.sold
		item.affordable = run.can_afford(slot.part)
		item.price = run.price_of(slot.part)
		item.rotate_requested.connect(run.rotate_slot.bind(i))
		_slots.add_child(item)
	for offer in _relic_offers.get_children():
		_relic_offers.remove_child(offer)
		offer.queue_free()
	if run.shop:
		for i in run.shop.relic_offers.size():
			_relic_offers.add_child(_make_relic_offer(i))
		for i in run.shop.mod_offers.size():
			_relic_offers.add_child(_make_mod_offer(i))
	_show_kit_offers()
	_show_kits()
	_stats_panel.show_stats(_stats, null)


## Returns the shop's relic offers, left to right.
func get_relic_offers() -> Array[Node]:
	return _relic_offers.get_children()


# One relic for sale: its icon, name, and effect, and a button to buy it.
func _make_relic_offer(index: int) -> Control:
	var offer: ShopStock.RelicOffer = run.shop.relic_offers[index]
	var card := PanelContainer.new()
	card.size_flags_horizontal = SIZE_EXPAND_FILL
	card.tooltip_text = RelicIcon.describe(offer.relic)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	card.add_child(row)
	row.add_child(RelicIcon.new(offer.relic, 32.0))
	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 0)
	text.size_flags_horizontal = SIZE_EXPAND_FILL
	row.add_child(text)
	var name_label := Label.new()
	name_label.text = offer.relic.relic_name
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", offer.relic.color)
	text.add_child(name_label)
	var effect := Label.new()
	effect.text = offer.relic.description
	effect.add_theme_font_size_override("font_size", 11)
	effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_child(effect)
	var buy := Button.new()
	buy.custom_minimum_size = Vector2(96, 32)
	buy.size_flags_vertical = SIZE_SHRINK_CENTER
	if offer.sold:
		buy.text = "Sold"
		buy.disabled = true
	else:
		buy.text = "Buy · %dg" % offer.price
		buy.disabled = offer.price > run.gold
		buy.pressed.connect(buy_relic.bind(index), CONNECT_DEFERRED)
	row.add_child(buy)
	return card


# The run's field kits under the chassis, each with a button to throw it away and free its slot.
func _show_kits() -> void:
	if _kits_box == null:
		_kits_box = VBoxContainer.new()
		_kits_box.add_theme_constant_override("separation", 4)
		_passive_label.get_parent().add_child(_kits_box)
	for child in _kits_box.get_children():
		_kits_box.remove_child(child)
		child.queue_free()
	var title := Label.new()
	title.text = "Field kits · %d / %d" % [run.kits.size(), RunState.KIT_SLOTS]
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", Color(0.72, 0.74, 0.78))
	_kits_box.add_child(title)
	for i in run.kits.size():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.add_child(KitIcon.new(run.kits[i], 24.0))
		var label := Label.new()
		label.text = run.kits[i].kit_name
		label.size_flags_horizontal = SIZE_EXPAND_FILL
		label.add_theme_font_size_override("font_size", 13)
		row.add_child(label)
		var discard := Button.new()
		discard.text = "Discard"
		discard.pressed.connect(discard_kit.bind(i), CONNECT_DEFERRED)
		row.add_child(discard)
		_kits_box.add_child(row)


## Throws away kit [param index], with a toast saying so.
func discard_kit(index: int) -> bool:
	var kit: FieldKit = run.kits[index] if index >= 0 and index < run.kits.size() else null
	if kit == null or not run.discard_kit(index):
		return false
	show_toast("Discarded %s" % kit.kit_name, true)
	return true


# The shop's kits, in a slim row of their own under the relics.
func _show_kit_offers() -> void:
	if _kit_offers == null:
		_kit_offers = HBoxContainer.new()
		_kit_offers.add_theme_constant_override("separation", 10)
		_relic_offers.get_parent().add_child(_kit_offers)
		_relic_offers.get_parent().move_child(_kit_offers, _relic_offers.get_index() + 1)
	for offer in _kit_offers.get_children():
		_kit_offers.remove_child(offer)
		offer.queue_free()
	var count := run.shop.kit_offers.size() if run.shop else 0
	_kit_offers.visible = count > 0
	for i in count:
		_kit_offers.add_child(_make_kit_offer(i))


## Returns the shop's kit offers, left to right.
func get_kit_offers() -> Array[Node]:
	return _kit_offers.get_children() if _kit_offers else []


# One field kit for sale on a single line: its icon, name, and when it acts, and a button. What it
# does is in the tooltip.
func _make_kit_offer(index: int) -> Control:
	var offer: ShopStock.KitOffer = run.shop.kit_offers[index]
	var card := PanelContainer.new()
	card.size_flags_horizontal = SIZE_EXPAND_FILL
	card.tooltip_text = KitIcon.describe(offer.kit)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	card.add_child(row)
	var icon := KitIcon.new(offer.kit, 22.0)
	icon.size_flags_vertical = SIZE_SHRINK_CENTER
	row.add_child(icon)
	var name_label := Label.new()
	name_label.text = offer.kit.kit_name
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.add_theme_color_override("font_color", offer.kit.color)
	row.add_child(name_label)
	var when := Label.new()
	when.text = offer.kit.describe_trigger()
	when.add_theme_font_size_override("font_size", 11)
	when.add_theme_color_override("font_color", Color(0.72, 0.74, 0.78))
	when.size_flags_horizontal = SIZE_EXPAND_FILL
	when.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(when)
	var buy := Button.new()
	buy.custom_minimum_size = Vector2(90, 28)
	buy.size_flags_vertical = SIZE_SHRINK_CENTER
	if offer.sold:
		buy.text = "Sold"
		buy.disabled = true
	else:
		buy.text = "Buy · %dg" % offer.price
		buy.disabled = offer.price > run.gold or not run.has_kit_room()
		if not run.has_kit_room():
			buy.tooltip_text = "Every kit slot is full: discard one first."
		buy.pressed.connect(buy_kit.bind(index), CONNECT_DEFERRED)
	row.add_child(buy)
	return card


## Buys the shop's kit offer [param index], with a toast saying so.
func buy_kit(index: int) -> bool:
	var offer: ShopStock.KitOffer = run.shop.kit_offers[index] if run.shop and index < run.shop.kit_offers.size() else null
	if offer == null or not run.buy_kit(index):
		show_toast("Can't buy that kit", false)
		return false
	show_toast("Bought %s · -%dg" % [offer.kit.kit_name, offer.price], true)
	return true


# One weapon mod for sale: its name, what it does and which weapon it goes on, and a button.
func _make_mod_offer(index: int) -> Control:
	var offer: ShopStock.ModOffer = run.shop.mod_offers[index]
	var weapon := WeaponModEffect.strongest_weapon(run)
	var card := PanelContainer.new()
	card.size_flags_horizontal = SIZE_EXPAND_FILL
	card.tooltip_text = "Fitted to your strongest weapon, replacing any mod it has."
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	card.add_child(row)
	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 0)
	text.size_flags_horizontal = SIZE_EXPAND_FILL
	row.add_child(text)
	var name_label := Label.new()
	name_label.text = "%s mod" % offer.mod.prefix
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", RewardScreen.MOD_COLOR)
	text.add_child(name_label)
	var effect := Label.new()
	effect.text = "%s For your %s." % [offer.mod.description, weapon.get_display_name()] if weapon else offer.mod.description
	effect.add_theme_font_size_override("font_size", 11)
	effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_child(effect)
	var buy := Button.new()
	buy.custom_minimum_size = Vector2(96, 32)
	buy.size_flags_vertical = SIZE_SHRINK_CENTER
	if offer.sold:
		buy.text = "Fitted"
		buy.disabled = true
	else:
		buy.text = "Fit · %dg" % offer.price
		buy.disabled = offer.price > run.gold or weapon == null
		buy.pressed.connect(buy_mod.bind(index), CONNECT_DEFERRED)
	row.add_child(buy)
	return card


## Buys the shop's mod offer [param index], with a toast saying so.
func buy_mod(index: int) -> bool:
	var offer: ShopStock.ModOffer = run.shop.mod_offers[index] if run.shop and index < run.shop.mod_offers.size() else null
	if offer == null or not run.buy_mod(index):
		show_toast("Can't fit that mod", false)
		return false
	show_toast("Fitted %s · -%dg" % [offer.mod.prefix, offer.price], true)
	return true


## Buys the shop's relic offer [param index], with a toast saying so.
func buy_relic(index: int) -> bool:
	var offer: ShopStock.RelicOffer = run.shop.relic_offers[index] if run.shop and index < run.shop.relic_offers.size() else null
	if offer == null or not run.buy_relic(index):
		show_toast("Not enough gold", false)
		return false
	show_toast("Bought %s · -%dg" % [offer.relic.relic_name, offer.price], true)
	return true


func _on_preview_changed(preview: MechStats) -> void:
	_stats_panel.show_stats(_stats, preview)


func _on_reroll_pressed() -> void:
	if not run.reroll():
		show_toast("Not enough gold to reroll", false)


## Loads every resource in [param dir], e.g. [constant PARTS_DIR]. Other screens use it to
## load the same content the shop does.
static func load_dir(dir: String) -> Array[Resource]:
	var loaded: Array[Resource] = []
	for file in ResourceLoader.list_directory(dir):
		if not file.ends_with("/"):
			loaded.append(load(dir.path_join(file)))
	return loaded
