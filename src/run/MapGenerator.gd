class_name MapGenerator
extends RefCounted
## Builds a sector's map the way Slay the Spire does:
## 1. A lattice: [member ActData.floors] floors of [member ActData.columns] points, each linked to
##    the three points above it (up-left, up, up-right).
## 2. [member ActData.paths] random walks up the lattice's links, from the bottom floor to the
##    top, none crossing a link another walk took. What they walk is the map; the rest is dropped.
## 3. One boss, linked from every node on the top floor.
## Then each node gets a kind: fights on the bottom floor, hangars on the top one, and weighted
## picks in between, spread out so the same special node doesn't come twice in a row.
## A sector can name a subclass in [member ActData.generator] to lay its map out differently.
## Steps 1 and 3 are adapted from Slay-The-Robot (MIT, DesirePathGames):
## scripts/actions/world_generation_actions/ActionGenerateAct.gd. See THIRD_PARTY_NOTICES.md.

## Special nodes that never follow one of their own kind on a path.
const NO_REPEAT: Array[MapNode.Type] = [MapNode.Type.ELITE, MapNode.Type.HANGAR, MapNode.Type.SHOP]
## How far a node is drawn off its lattice point, at most, in lattice spacings.
const JITTER := Vector2(0.25, 0.2)


## Returns a new map for [param act], rolled with [param rng].
func generate(act: ActData, rng: RandomNumberGenerator) -> MapGraph:
	var lattice := _build_lattice(act)
	var walked := _walk_paths(act, lattice, rng)
	var graph := MapGraph.new()
	graph.act = act
	for floor_nodes: Array in lattice:
		graph.floors.append(floor_nodes.filter(func(node: MapNode) -> bool: return walked.has(node)))
	graph.boss = MapNode.new(act.floors, floori(act.columns / 2.0), MapNode.Type.BOSS)
	graph.boss.id = "boss"
	for node: MapNode in graph.floors[-1]:
		node.next.append(graph.boss)
	_assign_types(act, graph, rng)
	var bosses := act.get_enemies(EnemyLoadout.Tier.BOSS)
	if not bosses.is_empty():
		graph.boss.enemy = bosses[rng.randi_range(0, bosses.size() - 1)]
	for node in graph.get_nodes():
		if node != graph.boss:
			node.jitter = Vector2(rng.randf_range(-JITTER.x, JITTER.x), rng.randf_range(-JITTER.y, JITTER.y))
	return graph


# Every lattice point, floor by floor. Links come later, from the walks.
func _build_lattice(act: ActData) -> Array[Array]:
	var lattice: Array[Array] = []
	for floor_index in act.floors:
		var floor_nodes: Array[MapNode] = []
		for column in act.columns:
			floor_nodes.append(MapNode.new(floor_index, column))
		lattice.append(floor_nodes)
	return lattice


# Walks the paths up the lattice, linking each step, and returns the nodes walked (as a set).
func _walk_paths(act: ActData, lattice: Array[Array], rng: RandomNumberGenerator) -> Dictionary:
	var walked := {}
	var first_start := -1
	for path in act.paths:
		var column := rng.randi_range(0, act.columns - 1)
		# The first two paths start apart, so the map always opens with a choice.
		while path == 1 and column == first_start and act.columns > 1:
			column = rng.randi_range(0, act.columns - 1)
		if path == 0:
			first_start = column
		var node: MapNode = lattice[0][column]
		walked[node] = true
		for floor_index in act.floors - 1:
			var options: Array[MapNode] = []
			# The lattice's links: up-left, up, and up-right.
			for step in [-1, 0, 1]:
				var to_column: int = node.column + step
				if to_column >= 0 and to_column < act.columns and not _crosses(lattice[floor_index], lattice[floor_index + 1], node, to_column):
					options.append(lattice[floor_index + 1][to_column])
			# Straight up never crosses anything, so there's always an option.
			var chosen := options[rng.randi_range(0, options.size() - 1)]
			if chosen not in node.next:
				node.next.append(chosen)
			node = chosen
			walked[node] = true
	for floor_nodes: Array in lattice:
		for node: MapNode in floor_nodes:
			node.next.sort_custom(func(a: MapNode, b: MapNode) -> bool: return a.column < b.column)
	return walked


# Whether a link from [param node] up to [param to_column] would cross a link already taken: a
# diagonal crosses the opposite diagonal between the same two columns.
func _crosses(below: Array, above: Array, node: MapNode, to_column: int) -> bool:
	if to_column == node.column:
		return false
	var neighbor: MapNode = below[to_column]
	return above[node.column] in neighbor.next


func _assign_types(act: ActData, graph: MapGraph, rng: RandomNumberGenerator) -> void:
	var parents := {}
	for node in graph.get_nodes():
		for child in node.next:
			if not parents.has(child):
				parents[child] = []
			parents[child].append(node)
	var assigned := {}
	for floor_index in graph.floors.size():
		for node: MapNode in graph.floors[floor_index]:
			node.type = _roll_type(act, node, parents.get(node, []), assigned, rng)
			assigned[node] = true


func _roll_type(act: ActData, node: MapNode, parents: Array, assigned: Dictionary, rng: RandomNumberGenerator) -> MapNode.Type:
	if node.floor_index == 0:
		return MapNode.Type.BATTLE
	if node.floor_index == act.floors - 1:
		return MapNode.Type.HANGAR
	var weights := act.get_node_weights()
	if node.floor_index < act.min_special_floor:
		weights.erase(MapNode.Type.ELITE)
		weights.erase(MapNode.Type.HANGAR)
	# The top floor is all hangars, so the floor under it can't be one.
	if node.floor_index == act.floors - 2:
		weights.erase(MapNode.Type.HANGAR)
	for parent: MapNode in parents:
		if parent.type in NO_REPEAT:
			weights.erase(parent.type)
	# Where it can, a node differs from the other nodes its parents lead to, so each fork is a
	# real choice.
	var spread := weights.duplicate()
	for parent: MapNode in parents:
		for sibling in parent.next:
			if sibling != node and assigned.has(sibling):
				spread.erase(sibling.type)
	var picked: Variant = RunRng.weighted_pick(rng, spread)
	if picked == null:
		picked = RunRng.weighted_pick(rng, weights)
	return MapNode.Type.BATTLE if picked == null else picked
