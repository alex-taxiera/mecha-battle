class_name MapGraph
extends RefCounted
## A sector's map, built by a [MapGenerator]: its floors of [MapNode]s, the boss on top, and
## where the player is.

## The sector the map belongs to.
var act: ActData
## Each floor's nodes, bottom floor first, left to right. The boss isn't on any floor.
var floors: Array[Array] = []
var boss: MapNode
## The node the player is on, or [code]null[/code] before they pick one on the bottom floor.
var current: MapNode


## Returns every node, floor by floor, then the boss.
func get_nodes() -> Array[MapNode]:
	var nodes: Array[MapNode] = []
	for floor_nodes in floors:
		nodes.append_array(floor_nodes)
	if boss:
		nodes.append(boss)
	return nodes


## Returns the nodes the player can travel to next: any node on the bottom floor at first, then
## the ones linked above the current node.
func get_reachable() -> Array[MapNode]:
	var reachable: Array[MapNode] = []
	if current == null:
		if not floors.is_empty():
			reachable.assign(floors[0])
	else:
		reachable.assign(current.next)
	return reachable


func can_travel(node: MapNode) -> bool:
	return node in get_reachable()


## Moves the player to [param node] and marks it visited. Returns false, moving nowhere, if it
## isn't reachable from where they are.
func travel(node: MapNode) -> bool:
	if not can_travel(node):
		return false
	current = node
	node.visited = true
	return true


## Returns whether the player is on the boss's node.
func is_at_boss() -> bool:
	return current != null and current == boss


## Returns the node with [param id], or [code]null[/code].
func find_node(id: String) -> MapNode:
	for node in get_nodes():
		if node.id == id:
			return node
	return null
