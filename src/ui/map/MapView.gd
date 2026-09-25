class_name MapView
extends Control
## Draws a sector's [MapGraph], bottom floor at the bottom and the boss on top: the links
## between nodes, each node as a colored badge with its kind's glyph, the path walked so far,
## and the nodes the player can travel to next, pulsing. Clicking a reachable node emits
## [signal node_pressed]; hovering any node explains it in a tooltip.

## Emitted when the player clicks a node they can travel to.
signal node_pressed(node: MapNode)

## Space between columns and between floors.
const COLUMN_SPACING := 96.0
const FLOOR_SPACING := 72.0
## Room around the lattice, and above it for the boss and its name.
const MARGIN := Vector2(56, 48)
const BOSS_ROOM := 100.0
const NODE_RADIUS := 17.0
const BOSS_RADIUS := 30.0
## Pulses a second on reachable nodes.
const PULSE_SPEED := 1.6

## Each kind's glyph, color, name, and tooltip text.
const KINDS := {
	MapNode.Type.BATTLE: ["X", Color("#e0607e"), "Battle", "Fight one of the sector's mechs."],
	MapNode.Type.ELITE: ["!", Color("#ff8a3d"), "Elite", "A tougher mech with better loot."],
	MapNode.Type.SHOP: ["$", Color("#f2b134"), "Scrap Shop", "Buy and sell parts."],
	MapNode.Type.HANGAR: ["+", Color("#5fd38a"), "Hangar", "Repair or reinforce your hull."],
	MapNode.Type.EVENT: ["?", Color("#5aa9ff"), "Event", "Something's out there. Risk or reward."],
	MapNode.Type.BOSS: ["B", Color("#b476f0"), "Sector Boss", "The sector's boss. Beat it to move on."],
	MapNode.Type.UNKNOWN: ["~", Color("#aab2c0"), "Unknown", "Could be anything: an event, a fight, a cache, or a shop."],
	MapNode.Type.CACHE: ["C", Color("#7de8f0"), "Salvage Cache", "Free for the taking: gold, a relic, and a field kit."],
}

const LINK_COLOR := Color("#3a4150")
const WALKED_COLOR := Color("#f1f3f7")
const OPEN_COLOR := Color("#aab2c0")
const VISITED_FILL := Color("#2a2f3a")

var map: MapGraph:
	set(value):
		map = value
		update_minimum_size()
		queue_redraw()
## The nodes the player can travel to now. Only these respond to clicks.
var reachable: Array[MapNode] = []:
	set(value):
		reachable = value
		queue_redraw()

var _pulse := 0.0


func _init() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	# A non-empty tooltip turns _get_tooltip on; it replaces the text per node.
	tooltip_text = " "


func _process(delta: float) -> void:
	if not reachable.is_empty():
		_pulse = fmod(_pulse + delta * PULSE_SPEED, 1.0)
		queue_redraw()


func _get_minimum_size() -> Vector2:
	if map == null or map.act == null:
		return Vector2.ZERO
	return Vector2(MARGIN.x * 2 + COLUMN_SPACING * (map.act.columns - 1),
		MARGIN.y * 2 + BOSS_ROOM + FLOOR_SPACING * map.act.floors)


## Returns where [param node] is drawn: its lattice point, nudged by its jitter, centered in the
## view's width. The boss sits centered above the top floor.
func get_node_position(node: MapNode) -> Vector2:
	var width := COLUMN_SPACING * (map.act.columns - 1)
	var left := (size.x - width) / 2.0
	var top_floor_y := MARGIN.y + BOSS_ROOM
	if node == map.boss:
		return Vector2(size.x / 2.0, MARGIN.y + BOSS_RADIUS)
	var floors_below_top := map.act.floors - 1 - node.floor_index
	return Vector2(left + (node.column + node.jitter.x) * COLUMN_SPACING,
		top_floor_y + (floors_below_top + node.jitter.y) * FLOOR_SPACING + NODE_RADIUS)


## Returns the node drawn under [param at_position], or [code]null[/code].
func node_at(at_position: Vector2) -> MapNode:
	if map == null:
		return null
	for node in map.get_nodes():
		if get_node_position(node).distance_to(at_position) <= _radius(node) + 4.0:
			return node
	return null


## Travels to [param node] if it's reachable, by emitting [signal node_pressed]. Returns whether
## it was.
func press(node: MapNode) -> bool:
	if node == null or node not in reachable:
		return false
	node_pressed.emit(node)
	return true


## Returns what the tooltip over [param node] says, e.g. "Elite\nA tougher mech with better
## loot." The boss's names its enemy.
static func describe(node: MapNode) -> String:
	var kind: Array = KINDS[node.type]
	var title: String = kind[2]
	if node.type == MapNode.Type.BOSS and node.enemy:
		title = "Sector Boss: %s" % node.enemy.enemy_name
	var text := "%s\n%s" % [title, kind[3]]
	if not node.affixes.is_empty():
		text += "\nAffixes: %s" % ", ".join(node.affixes.map(func(affix: Relic) -> String: return affix.relic_name))
	if node.hazard:
		text += "\nHazard: %s (both mechs): %s" % [node.hazard.relic_name, node.hazard.description]
	return text


func _get_tooltip(at_position: Vector2) -> String:
	var node := node_at(at_position)
	return describe(node) if node else ""


func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		if press(node_at(click.position)):
			accept_event()


func _draw() -> void:
	if map == null or map.act == null:
		return
	for node in map.get_nodes():
		for child in node.next:
			var walked := node.visited and child.visited
			var open := node == map.current and child in reachable
			var color := WALKED_COLOR if walked else (OPEN_COLOR if open else LINK_COLOR)
			draw_line(get_node_position(node), get_node_position(child), color, 3.0 if walked else 2.0, true)
	for node in map.get_nodes():
		_draw_node(node)
	if map.boss.enemy:
		var name_y := get_node_position(map.boss).y - BOSS_RADIUS - 18.0
		CombatDraw.text(self, CombatDraw.PIXEL_FONT, Rect2(0, name_y - 10, size.x, 20),
			map.boss.enemy.enemy_name.to_upper(), 14, KINDS[MapNode.Type.BOSS][1], 2, HORIZONTAL_ALIGNMENT_CENTER)


func _draw_node(node: MapNode) -> void:
	var center := get_node_position(node)
	var radius := _radius(node)
	var kind: Array = KINDS[node.type]
	var color: Color = kind[1]
	var is_open := node in reachable
	if is_open:
		# A ring swelling out and fading, once per pulse.
		var ring := color
		ring.a = 1.0 - _pulse
		draw_arc(center, radius + 4.0 + _pulse * 10.0, 0, TAU, 32, ring, 2.0, true)
	var faded := node.floor_index < _current_floor() and not node.visited
	var fill := VISITED_FILL if node.visited else CombatColors.NIGHT
	draw_circle(center, radius, fill)
	var edge := color.darkened(0.5) if faded else color
	draw_arc(center, radius, 0, TAU, 32, edge, 3.0, true)
	if node == map.current:
		draw_arc(center, radius + 5.0, 0, TAU, 32, WALKED_COLOR, 2.0, true)
	if node.hazard:
		# A hazard is a small badge of its color on the node's upper right.
		var spot := center + Vector2(radius, -radius) * 0.75
		draw_circle(spot, 6.0, CombatColors.NIGHT)
		draw_circle(spot, 4.0, node.hazard.color)
	var font_size := 30 if node.type == MapNode.Type.BOSS else 20
	CombatDraw.text(self, CombatDraw.BODY_FONT, Rect2(center - Vector2(radius, radius), Vector2(radius, radius) * 2),
		kind[0], font_size, edge, 0, HORIZONTAL_ALIGNMENT_CENTER)


func _radius(node: MapNode) -> float:
	return BOSS_RADIUS if node.type == MapNode.Type.BOSS else NODE_RADIUS


# The floor the player is on, or -1 before their first step.
func _current_floor() -> int:
	return map.current.floor_index if map.current else -1
