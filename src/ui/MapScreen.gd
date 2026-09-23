class_name MapScreen
extends Control
## The sector map between stops: the run's HUD on top, the map below it, scrolled to where the
## player is, and a legend of node kinds. Clicking a reachable node travels there and emits
## [signal node_chosen]; the Loadout button asks to work on the mech.

## Emitted after the player travels to [param node]; the game opens what's there.
signal node_chosen(node: MapNode)
## Emitted when the player wants to rearrange their mech and stash.
signal loadout_requested

## Set before the screen enters the tree.
var run: RunState

@onready var _hud: RunHud = %RunHud
@onready var _hint: Label = %Hint
@onready var _loadout_button: Button = %LoadoutButton
@onready var _scroll: ScrollContainer = %MapScroll
@onready var _view: MapView = %MapView
@onready var _legend: Container = %Legend


func _ready() -> void:
	_hud.run = run
	_view.map = run.map
	_view.reachable = run.get_reachable()
	_view.node_pressed.connect(choose)
	_hint.text = _hint_text()
	_loadout_button.text = loadout_text(run)
	_loadout_button.pressed.connect(loadout_requested.emit)
	for type: MapNode.Type in MapView.KINDS:
		_legend.add_child(_legend_entry(type))
	_scroll_to_player.call_deferred()


## Travels to [param node] and emits [signal node_chosen]. Does nothing, returning false, if
## the node can't be reached from where the player is.
func choose(node: MapNode) -> bool:
	if not run.travel(node):
		return false
	_view.reachable = []
	node_chosen.emit(node)
	return true


## Returns the map view, for tests and scrolling.
func get_view() -> MapView:
	return _view


## Returns the Loadout button's text, e.g. "Loadout · 2 in stash".
static func loadout_text(p_run: RunState) -> String:
	return "Loadout" if p_run.stash.is_empty() else "Loadout · %d in stash" % p_run.stash.size()


func _hint_text() -> String:
	if run.map.current == null:
		return "Pick where to start. Each step climbs one floor toward the boss."
	return "Pick your next stop."


func _legend_entry(type: MapNode.Type) -> Control:
	var kind: Array = MapView.KINDS[type]
	var label := Label.new()
	label.text = "%s  %s" % [kind[0], kind[2]]
	label.add_theme_color_override("font_color", kind[1])
	label.add_theme_font_size_override("font_size", 13)
	label.tooltip_text = kind[3]
	label.mouse_filter = MOUSE_FILTER_PASS
	return label


# Scrolls so the nodes the player can reach sit in the middle of the view: the bottom at the
# start of a sector.
func _scroll_to_player() -> void:
	await get_tree().process_frame
	var reachable := run.get_reachable()
	if reachable.is_empty():
		return
	var y := 0.0
	for node in reachable:
		y += _view.get_node_position(node).y
	y /= reachable.size()
	_scroll.scroll_vertical = int(y - _scroll.size.y / 2.0)
