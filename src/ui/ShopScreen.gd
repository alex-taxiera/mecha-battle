class_name ShopScreen
extends Control
## Root of the shop phase: the player's mech on the left, parts for sale on the right.
## Dragging a part from the shop onto the mech buys it.

const SHOP_ITEM_SCENE := preload("res://src/ui/ShopItem.tscn")
const PARTS_DIR := "res://resources/parts"

@export var starting_gold := 10
## Parts for sale. Left empty, the shop sells every MechPart in [constant PARTS_DIR].
@export var catalog: Array[MechPart] = []

var grid := MechGridData.new()
var shop: ShopData

@onready var _grid_ui: MechGridUI = %MechGridUI
@onready var _gold_label: Label = %GoldLabel
@onready var _items: Container = %Items


func _ready() -> void:
	if catalog.is_empty():
		catalog = _load_parts(PARTS_DIR)
	shop = ShopData.new(starting_gold, catalog)
	shop.changed.connect(_refresh)
	_grid_ui.grid_data = grid
	_grid_ui.part_dropped.connect(_on_part_dropped)
	_refresh()


func _refresh() -> void:
	_gold_label.text = "Gold: %d" % shop.gold
	for item in _items.get_children():
		_items.remove_child(item)
		item.queue_free()
	for part in shop.offers:
		var item: ShopItem = SHOP_ITEM_SCENE.instantiate()
		item.part = part
		item.affordable = shop.can_afford(part)
		_items.add_child(item)


func _on_part_dropped(part: MechPart, _origin: Vector2i) -> void:
	shop.buy(part)


static func _load_parts(dir: String) -> Array[MechPart]:
	var parts: Array[MechPart] = []
	for file in ResourceLoader.list_directory(dir):
		if file.ends_with("/"):
			continue
		var part := load(dir.path_join(file)) as MechPart
		if part:
			parts.append(part)
	return parts
