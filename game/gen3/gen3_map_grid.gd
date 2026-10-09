class_name Gen3MapGrid
extends RefCounted

## The field's backup map (`fieldmap.c`): the layout's blocks inside a ring of
## [constant MAP_OFFSET] cells that the connected maps' edges fill, and the
## border pattern past it. Coordinates are the cartridge's backup-map ones, so
## the layout's own (0, 0) is ([constant MAP_OFFSET], [constant MAP_OFFSET]).

const MAP_OFFSET: int = 7
const OFFSET_W: int = MAP_OFFSET * 2 + 1
const OFFSET_H: int = MAP_OFFSET * 2
const UNDEFINED: int = 0x3FF
const METATILE_MASK: int = 0x3FF
const COLLISION_MASK: int = 0xC00
const ELEVATION_SHIFT: int = 12
const NUM_METATILES_TOTAL: int = 1024

enum Connection { INVALID = -1, NONE, SOUTH, NORTH, WEST, EAST, DIVE, EMERGE }

var width: int = 0
var height: int = 0
var layout_width: int = 0
var layout_height: int = 0
var blocks := PackedInt32Array()
var primary: Dictionary = {}
var secondary: Dictionary = {}
## FireRed and LeafGreen tile the layout's own border size from the layout's
## origin; Ruby, Sapphire and Emerald read a 2x2 by coordinate parity.
var _sized_border: bool = false
var _border := PackedByteArray()
var _border_width: int = 2
var _border_height: int = 2
var _split: int = 512
var _flags: Dictionary = {}
## Behavior and layer type by metatile id, read once from both tilesets.
var _behaviors := PackedInt32Array()
var _layer_types := PackedInt32Array()


## `InitMapLayoutData` for one map, or null when the cache lacks it. No map
## reaches `MAX_MAP_DATA_SIZE`. Emerald returns before clearing the connection
## flags for a map with no connections, so they stay [param previous]'s, which
## only [method border_id_at] past the buffer reads.
static func open(data: GameData, group: int, number: int, previous: Gen3MapGrid = null) -> Gen3MapGrid:
	var header: Dictionary = data.world_map_header(group, number)
	var layout: Dictionary = data.world_map_layout(group, number)
	if header.is_empty() or layout.is_empty():
		return null
	var grid := Gen3MapGrid.new()
	grid._sized_border = data.id in [RomRegistry.FIRERED, RomRegistry.LEAFGREEN]
	grid._split = Gen3World.primary_tile_count(data.id)
	grid.primary = data.world_map_tileset(group, number)
	grid.secondary = data.world_map_tileset(group, number, true)
	grid.layout_width = int(header["width"])
	grid.layout_height = int(header["height"])
	grid._border = layout["border"]["bytes"]
	grid._border_width = int(header["border_width"])
	grid._border_height = int(header["border_height"])
	var connections: Array = header.get("connections", [])
	grid._read_attributes()
	grid.width = grid.layout_width + OFFSET_W
	grid.height = grid.layout_height + OFFSET_H
	grid.blocks.resize(grid.width * grid.height)
	grid.blocks.fill(UNDEFINED)
	if previous != null and connections.is_empty() and data.id == RomRegistry.EMERALD:
		grid._flags = previous._flags.duplicate()
	grid._fill(layout["blocks"]["bytes"], grid.layout_width, 0, 0, MAP_OFFSET, MAP_OFFSET,
		grid.layout_width, grid.layout_height)
	for connection: Dictionary in connections:
		grid._connect(data, connection)
	return grid


## `InitBackupMapLayoutConnections`' four `Fill*Connection`s.
func _connect(data: GameData, connection: Dictionary) -> void:
	var direction: int = int(connection["direction"])
	var other: Dictionary = data.world_map_header(int(connection["group"]), int(connection["number"]))
	var other_layout: Dictionary = data.world_map_layout(int(connection["group"]), int(connection["number"]))
	if direction < Connection.SOUTH or direction > Connection.EAST or other.is_empty():
		return
	_flags[direction] = true
	var other_width: int = int(other["width"])
	var other_height: int = int(other["height"])
	var bytes: PackedByteArray = other_layout["blocks"]["bytes"]
	var at: int = int(connection["offset"]) + MAP_OFFSET
	if direction == Connection.SOUTH or direction == Connection.NORTH:
		var from_x: int = 0
		var span: int = 0
		if at < 0:
			from_x = -at
			span = mini(at + other_width, width)
			at = 0
		else:
			span = other_width if at + other_width < width else width - at
		var to_y: int = layout_height + MAP_OFFSET if direction == Connection.SOUTH else 0
		var source_y: int = 0 if direction == Connection.SOUTH else other_height - MAP_OFFSET
		_fill(bytes, other_width, from_x, source_y, at, to_y, span, MAP_OFFSET)
		return
	var from_y: int = 0
	var rows: int = 0
	if at < 0:
		from_y = -at
		rows = at + other_height if at + other_height < height else height
		at = 0
	else:
		rows = other_height if at + other_height < height else height - at
	if direction == Connection.WEST:
		_fill(bytes, other_width, other_width - MAP_OFFSET, from_y, 0, at, MAP_OFFSET, rows)
	else:
		_fill(bytes, other_width, 0, from_y, layout_width + MAP_OFFSET, at, MAP_OFFSET + 1, rows)


## `FillConnection`'s row copies.
func _fill(source: PackedByteArray, source_width: int, from_x: int, from_y: int,
		to_x: int, to_y: int, span: int, rows: int) -> void:
	for row: int in rows:
		var from: int = (source_width * (from_y + row) + from_x) * 2
		var to: int = width * (to_y + row) + to_x
		for column: int in span:
			if from + column * 2 + 1 < source.size() and to + column < blocks.size():
				blocks[to + column] = source.decode_u16(from + column * 2)


## `GetMapGridBlockAt`: the buffer's word, or the border's with collision set.
func block_at(x: int, y: int) -> int:
	if x >= 0 and x < width and y >= 0 and y < height:
		return blocks[x + width * y]
	return border_block_at(x, y)


func border_block_at(x: int, y: int) -> int:
	var index: int = ((x + 1) & 1) + (((y + 1) & 1) << 1)
	if _sized_border:
		index = (x - MAP_OFFSET + 8 * _border_width) % _border_width \
			+ (y - MAP_OFFSET + 8 * _border_height) % _border_height * _border_width
	return _border.decode_u16(index * 2) | COLLISION_MASK


func metatile_id_at(x: int, y: int) -> int:
	var block: int = block_at(x, y)
	if block == UNDEFINED:
		block = border_block_at(x, y)
	return block & METATILE_MASK


func collision_at(x: int, y: int) -> int:
	var block: int = block_at(x, y)
	return 1 if block == UNDEFINED else (block & COLLISION_MASK) >> 10


func elevation_at(x: int, y: int) -> int:
	var block: int = block_at(x, y)
	return 0 if block == UNDEFINED else block >> ELEVATION_SHIFT


## The tileset row a metatile id draws and reads its attributes from, empty
## past the tileset's own rows.
func metatile(id: int) -> Dictionary:
	return Gen3World.metatile(secondary if id >= _split else primary, id)


func behavior_at(x: int, y: int) -> int:
	return _behaviors[metatile_id_at(x, y)]


func layer_type_at(x: int, y: int) -> int:
	return _layer_types[metatile_id_at(x, y)]


func _read_attributes() -> void:
	_behaviors.resize(NUM_METATILES_TOTAL)
	_layer_types.resize(NUM_METATILES_TOTAL)
	for id: int in NUM_METATILES_TOTAL:
		var row: Dictionary = metatile(id)
		_behaviors[id] = int(row.get("behavior", 0))
		_layer_types[id] = int(row.get("layer_type", 0))


## `GetMapBorderIdAt`: which connection a backup-map cell belongs to.
func border_id_at(x: int, y: int) -> int:
	if block_at(x, y) == UNDEFINED:
		return Connection.INVALID
	var side: int = Connection.NONE
	if x >= width - (MAP_OFFSET + 1):
		side = Connection.EAST
	elif x < MAP_OFFSET:
		side = Connection.WEST
	elif y >= height - MAP_OFFSET:
		side = Connection.SOUTH
	elif y < MAP_OFFSET:
		side = Connection.NORTH
	if side != Connection.NONE and not _flags.get(side, false):
		return Connection.INVALID
	return side
