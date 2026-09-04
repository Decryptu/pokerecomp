class_name Gen2WorldMap
extends RefCounted

## Node-free map data decoded from either generation's map header and event
## block. Coordinates are row-major, y increasing from the top as on the
## cartridge, and Generation 1's one flat map id is [member number] under
## [member group] 0. Collision values are the raw byte the cartridge tests: a
## permission byte in Generation 2, and the tile the cell draws in Generation 1,
## which [method Gen2WorldTileset.tile_passable] answers for.

var group: int = 0
var number: int = 0
var tileset: int = 0
var environment: int = 0
var location: int = 0
var music: int = 0
var phone_flag: int = 0
var palette: int = 0
var fish_group: int = 0
var border_block: int = 0
var width_blocks: int = 0
var height_blocks: int = 0
## Both grids are cartridge bytes, so they are packed rather than kept as Arrays
## of Variants. Every map in the cache is resident at once and each lookup is on
## the draw path, so the twenty-odd bytes a Variant costs are paid 388 times over
## and unboxed once per tile.
var blocks: PackedByteArray = PackedByteArray()
var collision: PackedByteArray = PackedByteArray()
var collision_width: int = 0
var collision_height: int = 0
var connection_flags: int = 0
var connections: Array = []
var scripts: Dictionary = {}
var events: Dictionary = {}
## `<Map>_TextPointers` decoded, one row a text id from 1 up. Generation 1 only:
## a Generation 2 map's text is inside the script its event names.
var texts: Array = []


static func from_cache(value: Dictionary) -> Gen2WorldMap:
	var out := Gen2WorldMap.new()
	out.group = int(value.get("group", 0))
	out.number = int(value.get("number", 0))
	out.tileset = int(value.get("tileset", 0))
	out.environment = int(value.get("environment", 0))
	out.location = int(value.get("location", 0))
	out.music = int(value.get("music", 0))
	out.phone_flag = int(value.get("phone_flag", 0))
	out.palette = int(value.get("palette", 0))
	out.fish_group = int(value.get("fish_group", 0))
	out.border_block = int(value.get("border_block", 0))
	out.width_blocks = int(value.get("width_blocks", 0))
	out.height_blocks = int(value.get("height_blocks", 0))
	out.blocks = RomCache.packed_bytes(value.get("blocks", []))
	out.collision = RomCache.packed_bytes(value.get("collision", []))
	out.collision_width = int(value.get("collision_width", out.width_blocks * 2))
	out.collision_height = int(value.get("collision_height", out.height_blocks * 2))
	var cached_connections: Variant = value.get("connections", [])
	if cached_connections is Array:
		out.connections = _connection_rows(cached_connections)
		out.connection_flags = int(value.get("connection_flags", 0))
	else:
		# Caches before format 12 stored only the raw direction flags.
		out.connection_flags = int(cached_connections)
		out.connections = []
	out.scripts = _scripts_from_cache(value.get("scripts", {}))
	out.events = _events_from_cache(value.get("events", {}))
	out.texts = _text_rows(value.get("texts", []))
	return out


## The text one id names. Ids count from one, as `DisplayTextID`'s `dec a` says.
func text_at(id: int) -> Dictionary:
	if id < 1 or id > texts.size():
		return {}
	return texts[id - 1]


func block_at(block_x: int, block_y: int) -> int:
	if block_x < 0 or block_x >= width_blocks or block_y < 0 or block_y >= height_blocks:
		return 0
	var at: int = block_y * width_blocks + block_x
	return blocks[at] if at < blocks.size() else 0


func collision_at(cell_x: int, cell_y: int) -> int:
	if cell_x < 0 or cell_x >= collision_width or cell_y < 0 or cell_y >= collision_height:
		return -1
	var at: int = cell_y * collision_width + cell_x
	return collision[at] if at < collision.size() else -1


static func _scripts_from_cache(value: Variant) -> Dictionary:
	if not value is Dictionary:
		return {}
	var script_values: Dictionary = value
	return {
		"bank": int(script_values.get("bank", 0)),
		"address": int(script_values.get("address", 0)),
		"scenes": _script_pointer_rows(script_values.get("scenes", [])),
		"callbacks": _script_pointer_rows(script_values.get("callbacks", [])),
	}


static func _text_rows(value: Variant) -> Array:
	if not value is Array:
		return []
	var out: Array = []
	for raw: Dictionary in value as Array:
		var row: Dictionary = raw.duplicate(true)
		row["command"] = int(raw.get("command", 0))
		out.append(row)
	return out


static func _script_pointer_rows(value: Variant) -> Array:
	if not value is Array:
		return []
	var out: Array = []
	for raw: Dictionary in value as Array:
		var row: Dictionary = raw.duplicate(true)
		for field: String in ["id", "type", "script"]:
			if raw.has(field):
				row[field] = int(raw[field])
		out.append(row)
	return out


static func _connection_rows(value: Array) -> Array:
	var out: Array = []
	for raw: Dictionary in value:
		var connection: Dictionary = raw.duplicate(true)
		# Generation 2 records two offsets where Generation 1 records two
		# alignments, so a connection carries four of these six.
		for field: String in [
			"map_group", "map_number", "length", "target_width_blocks",
			"x_offset", "y_offset", "x_alignment", "y_alignment",
			"target_block_pointer", "map_pointer", "window_pointer",
		]:
			if raw.has(field):
				connection[field] = int(raw[field])
		out.append(connection)
	return out


static func _events_from_cache(value: Variant) -> Dictionary:
	if not value is Dictionary:
		return {}
	var event_values: Dictionary = value
	return {
		"bank": int(event_values.get("bank", 0)),
		"address": int(event_values.get("address", 0)),
		"warps": _event_rows(event_values.get("warps", []), ["x", "y", "destination", "map_group", "map_number"]),
		"coord_events": _event_rows(event_values.get("coord_events", []), ["scene", "x", "y", "script"]),
		"bg_events": _event_rows(
			event_values.get("bg_events", []), ["x", "y", "type", "script", "text"]
		),
		# The last seven are Generation 1's, whose events carry a text id where
		# Generation 2's carry a script pointer.
		"objects": _event_rows(event_values.get("objects", []), [
			"sprite", "x", "y", "movement", "x_radius", "y_radius", "hour_1", "hour_2",
			"palette", "object_type", "sight_range", "script", "event_flag",
			"range", "text", "trainer_class", "trainer_number", "species", "level", "item",
		]),
	}


static func _event_rows(value: Variant, integer_fields: Array[String]) -> Array:
	if not value is Array:
		return []
	var out: Array = []
	for raw: Dictionary in value as Array:
		var event: Dictionary = raw.duplicate(true)
		# An absent field stays absent: an object names a trainer or an item.
		for field: String in integer_fields:
			if raw.has(field):
				event[field] = int(raw[field])
		out.append(event)
	return out
