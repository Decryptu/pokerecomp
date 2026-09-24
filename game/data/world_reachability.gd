class_name Gen2WorldReachability
extends RefCounted

## Where a player can stand with a set of field moves, from the cartridge's own
## collision, warps, connections and ledges as `DoPlayerMovement` reads them. A
## map is split into the regions its walls leave; a [Gen2WorldStory] gate is a
## node linking its neighbours once open, and a boulder or rock is a wall until
## Strength or Rock Smash.

const GATE_MOVES: Array[int] = [
	Gen2WorldFieldMove.MOVE_SURF,
	Gen2WorldFieldMove.MOVE_CUT,
	Gen2WorldFieldMove.MOVE_WHIRLPOOL,
	Gen2WorldFieldMove.MOVE_WATERFALL,
	Gen2WorldFieldMove.MOVE_STRENGTH,
	Gen2WorldFieldMove.MOVE_ROCK_SMASH,
]
const OBJECT_MOVES: Dictionary = {
	Gen2WorldObject.MOVEMENT_STRENGTH_BOULDER: Gen2WorldFieldMove.MOVE_STRENGTH,
	Gen2WorldObject.MOVEMENT_SMASHABLE_ROCK: Gen2WorldFieldMove.MOVE_ROCK_SMASH,
}
const STEPS: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
const DIRECTIONS: Dictionary = {
	"north": Vector2i.UP, "south": Vector2i.DOWN, "west": Vector2i.LEFT, "east": Vector2i.RIGHT,
}

var _data: GameData = null
var _story: Gen2WorldStory = null
var _graphs: Dictionary = {}
var _worlds: Dictionary = {}
## Map key to the map keys whose warps lead into it.
var _inbound: Dictionary = {}


## Without [param story] the graph is the bare collision.
static func build(data: GameData, story: Gen2WorldStory = null) -> Gen2WorldReachability:
	var out := Gen2WorldReachability.new()
	out._data = data
	out._story = story
	return out


static func map_key(group: int, number: int) -> int:
	return (group & 0xFF) << 8 | (number & 0xFF)


## Every map reachable from [param start] with [param moves] and every gate open,
## as a set of [method map_key]s.
func reachable(start: Vector2i, moves: Dictionary) -> Dictionary:
	var built: Dictionary = graph(moves)
	var open: Dictionary = {}
	for index: int in (built["gates"] as Array).size():
		open[index] = true
	var reached := PackedByteArray()
	reached.resize(int(built["count"]))
	spread(built, reached, Array(place_nodes(built, [start.x, start.y])), open)
	var out: Dictionary = {}
	for node: int in reached.size():
		if reached[node] != 0:
			out[int(built["map_of"][node])] = true
	return out


## Floods [param reached] from [param frontier], into a gate's node once
## [param open] holds it, appending each node newly reached to [param fresh].
static func spread(
	built: Dictionary, reached: PackedByteArray, frontier: Array, open: Dictionary, fresh: Array = []
) -> void:
	var edges: Array = built["edges"]
	var into: Dictionary = built["into_gate"]
	var gates: Array = built["gates"]
	var portals: Dictionary = built["portal_gate"]
	for node: int in frontier:
		if reached[node] == 0:
			fresh.append(node)
		reached[node] = 1
	while not frontier.is_empty():
		var node: int = frontier.pop_back()
		if portals.has(node) and not open.has(portals[node]):
			continue
		for target: int in edges[node]:
			if reached[target] == 0:
				reached[target] = 1
				fresh.append(target)
				frontier.append(target)
		for gate: int in into.get(node, []):
			var portal: int = int((gates[gate] as Dictionary)["portal"])
			if open.has(gate) and reached[portal] == 0:
				reached[portal] = 1
				fresh.append(portal)
				frontier.append(portal)


## Opens gate [param index], flooding on through it from a reached neighbour.
static func open_gate(
	built: Dictionary, reached: PackedByteArray, index: int, open: Dictionary, fresh: Array = []
) -> void:
	open[index] = true
	var gate: Dictionary = (built["gates"] as Array)[index]
	if reached[int(gate["portal"])] != 0:
		spread(built, reached, [int(gate["portal"])], open, fresh)
		return
	for node: int in gate["links"]:
		if reached[node] != 0:
			spread(built, reached, [int(gate["portal"])], open, fresh)
			return


## The nodes at a [Gen2WorldStory] place: the cell's region, else its
## neighbours', else the whole map. [param name] is its cache key.
func place_nodes(built: Dictionary, place: Array, name: String = "") -> PackedInt32Array:
	var cache: Dictionary = built["places"]
	if name.is_empty():
		name = str(place)
	if cache.has(name):
		return cache[name]
	var key: int = map_key(int(place[0]), int(place[1]))
	var label: Dictionary = (built["labels"] as Dictionary).get(key, {})
	var out := PackedInt32Array()
	if not label.is_empty() and place.size() >= 4:
		out = _nodes_at(label, Vector2i(int(place[2]), int(place[3])), true)
	if out.is_empty() and not label.is_empty():
		for comp: int in int(label["count"]):
			out.append(int(label["base"]) + comp)
	cache[name] = out
	return out


## One move set's `labels` (map key to its regions), `edges` by node, `gates`
## (`portal` and neighbour `links`, story links after), `into_gate`, `map_of`.
func graph(moves: Dictionary) -> Dictionary:
	var key: int = _moves_key(moves)
	if _graphs.has(key):
		return _graphs[key]
	var built: Dictionary = {
		"labels": {}, "edges": [], "gates": [], "into_gate": {}, "map_of": [],
		"count": 0, "places": {}, "portal_gate": {},
	}
	var closed: Dictionary = _gate_cells()
	for map: Gen2WorldMap in _data.world_maps():
		_label(built, map, moves, closed.get(map_key(map.group, map.number), {}))
	_add_portals(built)
	_add_links(built)
	for map: Gen2WorldMap in _data.world_maps():
		_link(built, map)
	_graphs[key] = built
	return built


func _gate_cells() -> Dictionary:
	var out: Dictionary = {}
	if _story == null:
		return out
	for index: int in _story.gates.size():
		var gate: Dictionary = _story.gates[index]
		var key: int = map_key(int(gate["map"][0]), int(gate["map"][1]))
		var cells: Dictionary = out.get(key, {})
		for cell: Array in gate["cells"]:
			cells[_cell_key(int(cell[0]), int(cell[1]))] = index
		out[key] = cells
	return out


func _walls_of(map: Gen2WorldMap) -> Dictionary:
	var out: Dictionary = {}
	if _story == null:
		return out
	for cell: Array in _story.walls.get("%d:%d" % [map.group, map.number], []):
		out[_cell_key(int(cell[0]), int(cell[1]))] = true
	return out


func _world(map: Gen2WorldMap) -> Gen2WorldAPI:
	var key: int = map_key(map.group, map.number)
	if not _worlds.has(key):
		var tileset: Gen2WorldTileset = _data.world_tileset(map.tileset)
		_worlds[key] = null if tileset == null else Gen2WorldAPI.new(
			_data, map, tileset, Vector2i.ZERO, Gen2WorldState.new()
		)
	return _worlds[key]


## Numbers one map's regions from the next free node, walls and gates left out.
func _label(built: Dictionary, map: Gen2WorldMap, moves: Dictionary, gates: Dictionary) -> void:
	var world: Gen2WorldAPI = _world(map)
	if world == null:
		return
	var walls: Dictionary = _walls_of(map)
	for object: Dictionary in map.events.get("objects", []) as Array:
		var move: int = int(OBJECT_MOVES.get(int(object.get("movement", 0)), 0))
		if move > 0 and not moves.has(move):
			walls[_cell_key(int(object.get("x", 0)), int(object.get("y", 0)))] = true
	gates = _closing_cells(world, map, moves, gates)
	var of: Dictionary = {}
	var count: int = 0
	var base: int = int(built["count"])
	for y: int in map.collision_height:
		for x: int in map.collision_width:
			var cell_key: int = _cell_key(x, y)
			if of.has(cell_key) or walls.has(cell_key) or gates.has(cell_key):
				continue
			if not _standable(world, map, world.collision_code_at(Vector2i(x, y)), moves):
				continue
			_fill(world, map, moves, walls, gates, of, Vector2i(x, y), count)
			count += 1
	var key: int = map_key(map.group, map.number)
	(built["labels"] as Dictionary)[key] = {
		"of": of, "count": count, "base": base, "gates": gates, "map": map,
	}
	for _comp: int in count:
		(built["edges"] as Array).append(PackedInt32Array())
		(built["map_of"] as Array).append(key)
	built["count"] = base + count


## A rewritten block closes only the cells a player cannot stand on already.
func _closing_cells(world: Gen2WorldAPI, map: Gen2WorldMap, moves: Dictionary, gates: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for key: int in gates:
		var closing: Array = _story.gates[int(gates[key])]["closing"]
		if closing.all(func(list: Array) -> bool: return String(list[0]).begins_with("!c:")) \
			and _standable(world, map, world.collision_code_at(Vector2i(key >> 8, key & 0xFF)), moves):
			continue
		out[key] = gates[key]
	return out


func _fill(
	world: Gen2WorldAPI, map: Gen2WorldMap, moves: Dictionary, walls: Dictionary,
	gates: Dictionary, of: Dictionary, first: Vector2i, comp: int
) -> void:
	var frontier: Array = [first]
	of[_cell_key(first.x, first.y)] = comp
	while not frontier.is_empty():
		var cell: Vector2i = frontier.pop_back()
		for step: Vector2i in STEPS:
			var next: Vector2i = cell + step
			if next.x < 0 or next.y < 0 or next.x >= map.collision_width \
				or next.y >= map.collision_height:
				continue
			var key: int = _cell_key(next.x, next.y)
			if of.has(key) or walls.has(key) or gates.has(key):
				continue
			if _side_blocked(world, cell, step) or _side_blocked(world, next, -step):
				continue
			if _standable(world, map, world.collision_code_at(next), moves):
				of[key] = comp
				frontier.append(next)


func _add_portals(built: Dictionary) -> void:
	if _story == null:
		return
	for index: int in _story.gates.size():
		var gate: Dictionary = _story.gates[index]
		var key: int = map_key(int(gate["map"][0]), int(gate["map"][1]))
		var label: Dictionary = (built["labels"] as Dictionary).get(key, {})
		var portal: int = int(built["count"])
		var links := PackedInt32Array()
		for cell: Array in gate["cells"]:
			if not label.is_empty():
				links.append_array(_nodes_at(label, Vector2i(int(cell[0]), int(cell[1])), false))
		(built["gates"] as Array).append({"portal": portal, "links": links})
		built["portal_gate"][portal] = index
		(built["edges"] as Array).append(links)
		(built["map_of"] as Array).append(key)
		built["count"] = portal + 1
		for node: int in links:
			var into: Array = (built["into_gate"] as Dictionary).get(node, [])
			into.append(index)
			built["into_gate"][node] = into
	for index: int in _story.gates.size():
		_link_gate_row(built, index)


## A story link is a one-way gate from its places to its landing.
func _add_links(built: Dictionary) -> void:
	if _story == null:
		return
	for link: Dictionary in _story.links:
		var index: int = (built["gates"] as Array).size()
		var portal: int = int(built["count"])
		var from := PackedInt32Array()
		for place: Array in link["at"]:
			from.append_array(place_nodes(built, place))
		var to: Array = link["to"]
		(built["gates"] as Array).append({"portal": portal, "links": from})
		built["portal_gate"][portal] = index
		(built["edges"] as Array).append(_land(built, to, false))
		(built["map_of"] as Array).append(map_key(int(to[0]), int(to[1])))
		built["count"] = portal + 1
		for node: int in from:
			var into: Array = (built["into_gate"] as Dictionary).get(node, [])
			into.append(index)
			built["into_gate"][node] = into


## Gates side by side, a corridor two people fill, pass into each other.
func _link_gate_row(built: Dictionary, index: int) -> void:
	var gate: Dictionary = _story.gates[index]
	var label: Dictionary = (built["labels"] as Dictionary).get(
		map_key(int(gate["map"][0]), int(gate["map"][1])), {}
	)
	if label.is_empty():
		return
	var gates: Array = built["gates"]
	for cell: Array in gate["cells"]:
		for step: Vector2i in STEPS:
			var other: int = int((label["gates"] as Dictionary).get(
				_cell_key(int(cell[0]) + step.x, int(cell[1]) + step.y), index
			))
			if other != index:
				_join(built, PackedInt32Array([int(gates[index]["portal"])]),
					PackedInt32Array([int(gates[other]["portal"])]))


## Every edge out of one map's regions: warps, connections, ledges, side walls.
func _link(built: Dictionary, map: Gen2WorldMap) -> void:
	var key: int = map_key(map.group, map.number)
	var label: Dictionary = (built["labels"] as Dictionary).get(key, {})
	if label.is_empty():
		return
	var of: Dictionary = label["of"]
	var warps: Array = map.events.get("warps", [])
	for index: int in warps.size():
		var warp: Dictionary = warps[index]
		var from: PackedInt32Array = _exit_nodes(built, label, Vector2i(int(warp.get("x", 0)), int(warp.get("y", 0))))
		for landing: Array in _warp_landings(map, warp):
			_join(built, from, _land(built, landing, false))
	for connection: Dictionary in map.connections:
		_link_connection(built, map, label, connection)
	var world: Gen2WorldAPI = _world(map)
	for cell_key: int in of:
		var cell := Vector2i(cell_key >> 8, cell_key & 0xFF)
		for step: Vector2i in STEPS:
			var landing: Vector2i = cell + step * 2
			if of.has(_cell_key(landing.x, landing.y)) and world.allows_hop_at(cell, step):
				_join_cells(built, label, cell, landing)
			var next: Vector2i = cell + step
			if of.has(_cell_key(next.x, next.y)) and not _side_blocked(world, cell, step):
				_join_cells(built, label, cell, next)


static func _join_cells(built: Dictionary, label: Dictionary, from: Vector2i, to: Vector2i) -> void:
	var of: Dictionary = label["of"]
	var base: int = int(label["base"])
	_join(built, PackedInt32Array([base + int(of[_cell_key(from.x, from.y)])]),
		PackedInt32Array([base + int(of[_cell_key(to.x, to.y)])]))


## `GetMovementPermissions`' side walls, which can pass a step one way only.
func _side_blocked(world: Gen2WorldAPI, cell: Vector2i, step: Vector2i) -> bool:
	if _data.generation == RomRegistry.GEN1:
		return false
	if not _sided(world.collision_code_at(cell)) and not _sided(world.collision_code_at(cell + step)):
		return false
	return world.step_blocked_from(cell, step)


static func _sided(code: int) -> bool:
	return (code & 0xF0) == Gen2WorldCollision.HI_NYBBLE_SIDE_WALLS \
		or (code & 0xF0) == Gen2WorldCollision.HI_NYBBLE_SIDE_BUOYS


## The nodes leaving by an exit at [param cell]: its region, or its gate.
func _exit_nodes(built: Dictionary, label: Dictionary, cell: Vector2i) -> PackedInt32Array:
	var key: int = _cell_key(cell.x, cell.y)
	if (label["of"] as Dictionary).has(key):
		return PackedInt32Array([int(label["base"]) + int(label["of"][key])])
	if (label["gates"] as Dictionary).has(key):
		return PackedInt32Array([int(((built["gates"] as Array)[int(label["gates"][key])] as Dictionary)["portal"])])
	return PackedInt32Array()


func _link_connection(built: Dictionary, map: Gen2WorldMap, label: Dictionary, connection: Dictionary) -> void:
	var target: Gen2WorldMap = _data.world_map(
		int(connection.get("map_group", -1)), int(connection.get("map_number", -1))
	)
	var step: Vector2i = DIRECTIONS.get(String(connection.get("direction", "")), Vector2i.ZERO)
	if target == null or step == Vector2i.ZERO:
		return
	for cell: Vector2i in _edge_cells(map, step):
		var from: PackedInt32Array = _exit_nodes(built, label, cell)
		if from.is_empty():
			continue
		var landing: Vector2i = Gen2WorldAPI.connection_landing(target, connection, cell)
		_join(built, from, _land(built, [target.group, target.number, landing.x, landing.y], true))


static func _edge_cells(map: Gen2WorldMap, step: Vector2i) -> Array:
	var out: Array = []
	if step.y != 0:
		var y: int = 0 if step.y < 0 else map.collision_height - 1
		for x: int in map.collision_width:
			out.append(Vector2i(x, y))
	else:
		var x: int = 0 if step.x < 0 else map.collision_width - 1
		for y: int in map.collision_height:
			out.append(Vector2i(x, y))
	return out


## Where a warp lands. Generation 1's `LAST_MAP` is any map leading in;
## Generation 2's -1 goes back out the door taken in, so it is no edge.
func _warp_landings(map: Gen2WorldMap, warp: Dictionary) -> Array:
	var gen1: bool = _data.generation == RomRegistry.GEN1
	var destination: int = int(warp.get("destination", 0))
	if not gen1 and destination == Gen2WorldAPI.BACKUP_WARP_DESTINATION:
		return []
	var sources: Array = [Vector2i(int(warp.get("map_group", 0)), int(warp.get("map_number", 0)))]
	if gen1 and sources[0].y == Gen1Layout.WARP_TO_LAST_MAP:
		sources = _inbound_maps(map)
	var out: Array = []
	var index: int = destination if gen1 else destination - 1
	for source: Vector2i in sources:
		var target: Gen2WorldMap = _data.world_map(source.x, source.y)
		var warps: Array = target.events.get("warps", []) if target != null else []
		if index >= 0 and index < warps.size():
			var at: Dictionary = warps[index]
			out.append([target.group, target.number, int(at.get("x", 0)), int(at.get("y", 0))])
	return out


func _inbound_maps(map: Gen2WorldMap) -> Array:
	if _inbound.is_empty():
		for source: Gen2WorldMap in _data.world_maps():
			for warp: Dictionary in source.events.get("warps", []) as Array:
				var key: int = map_key(int(warp.get("map_group", 0)), int(warp.get("map_number", 0)))
				var list: Array = _inbound.get(key, [])
				if not list.has(Vector2i(source.group, source.number)):
					list.append(Vector2i(source.group, source.number))
				_inbound[key] = list
	return _inbound.get(map_key(map.group, map.number), [])


## Where an arrival stands: across a [param strict] connection its cell or the
## gate there; off a warp, past a gate on its cell, as a gate triggers on a step.
func _land(built: Dictionary, place: Array, strict: bool) -> PackedInt32Array:
	var label: Dictionary = (built["labels"] as Dictionary).get(map_key(int(place[0]), int(place[1])), {})
	if label.is_empty():
		return PackedInt32Array()
	if not strict:
		return place_nodes(built, place)
	var key: int = _cell_key(int(place[2]), int(place[3]))
	if (label["gates"] as Dictionary).has(key):
		var gate: Dictionary = (built["gates"] as Array)[int(label["gates"][key])]
		return PackedInt32Array([int(gate["portal"])])
	var of: Dictionary = label["of"]
	return PackedInt32Array([int(label["base"]) + int(of[key])]) if of.has(key) \
		else PackedInt32Array()


static func _join(built: Dictionary, from: PackedInt32Array, to: PackedInt32Array) -> void:
	var edges: Array = built["edges"]
	for node: int in from:
		var out: PackedInt32Array = edges[node]
		for target: int in to:
			if target != node and not out.has(target):
				out.append(target)
		edges[node] = out


## The regions at [param cell], else its neighbours' (a gate cell's only with
## [param gate_cells]).
static func _nodes_at(label: Dictionary, cell: Vector2i, gate_cells: bool) -> PackedInt32Array:
	var of: Dictionary = label["of"]
	var base: int = int(label["base"])
	var out := PackedInt32Array()
	var key: int = _cell_key(cell.x, cell.y)
	if of.has(key):
		out.append(base + int(of[key]))
		return out
	if not gate_cells and not (label["gates"] as Dictionary).has(key):
		return out
	for step: Vector2i in STEPS:
		var next: int = _cell_key(cell.x + step.x, cell.y + step.y)
		if of.has(next) and not out.has(base + int(of[next])):
			out.append(base + int(of[next]))
	return out


## Whether a player with [param moves] can be on a cell of this code: the water
## gates are the cartridge's own tile tests, the rest is the permission byte.
func _standable(
	world: Gen2WorldAPI, map: Gen2WorldMap, code: int, moves: Dictionary
) -> bool:
	var gen1: bool = _data.generation == RomRegistry.GEN1
	match world.permission_for_code(code):
		Gen2WorldCollision.LAND_TILE:
			return true
		Gen2WorldCollision.WATER_TILE:
			if not gen1 and Gen2WorldFieldMove.waterfall_tile(code):
				return moves.has(Gen2WorldFieldMove.MOVE_WATERFALL)
			if not gen1 and Gen2WorldFieldMove.whirlpool_tile(code):
				return moves.has(Gen2WorldFieldMove.MOVE_WHIRLPOOL)
			return moves.has(Gen2WorldFieldMove.MOVE_SURF)
	## A cut tree is not walkable until it is cut, and then it is ordinary ground.
	if not moves.has(Gen2WorldFieldMove.MOVE_CUT):
		return false
	return Gen1Layout.cut_tile(map.tileset, code) >= 0 if gen1 \
		else Gen2WorldFieldMove.cuttable(code)


static func _cell_key(x: int, y: int) -> int:
	return (x & 0xFF) << 8 | (y & 0xFF)


static func _moves_key(moves: Dictionary) -> int:
	var key: int = 0
	for index: int in GATE_MOVES.size():
		if moves.has(GATE_MOVES[index]):
			key |= 1 << index
	return key
