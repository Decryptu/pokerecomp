class_name Gen3World
extends RefCounted

const HEADER_SIZE: int = 28
const WILD_HEADER_SIZE: int = 20
const WILD_METHODS: Array[String] = ["land", "water", "rock_smash", "fishing"]
## pret's ChooseWildMonIndex_*; fishing weights sum to 100 within each rod.
const SLOT_CHANCES: Array = [
	[20, 20, 10, 10, 10, 10, 5, 5, 4, 4, 1, 1],
	[60, 30, 5, 4, 1], [60, 30, 5, 4, 1],
	[70, 30, 60, 20, 20, 40, 40, 15, 4, 1],
]
const RODS: Dictionary = {"old_rod": [0, 2], "good_rod": [2, 5], "super_rod": [5, 10]}


static func verify(rom: RomFile, layout: Dictionary) -> Dictionary:
	if read(rom, layout).is_empty():
		return {"ok": false, "message": "Map layouts, tilesets, events, script bytecode, script data or wild encounters did not decode."}
	return {"ok": true, "message": ""}


static func read(rom: RomFile, layout: Dictionary) -> Dictionary:
	var headers: Dictionary = _headers(rom, layout)
	if headers.is_empty():
		return {}
	var encounters: Dictionary = _encounters(rom, layout, headers)
	if encounters.is_empty():
		return {}
	var graphics: Dictionary = _graphics(rom, headers)
	if graphics.is_empty():
		return {}
	var scripts: Dictionary = Gen3Script.read(rom, layout, headers)
	if scripts.is_empty():
		return {}
	return {"headers": headers, "encounters": encounters, "graphics": graphics, "scripts": scripts}


static func _headers(rom: RomFile, layout: Dictionary) -> Dictionary:
	var sizes: Array = layout["map_group_sizes"]
	var table: int = int(layout["map_groups"])
	if not rom.in_bounds(table, sizes.size() * 4):
		return {}
	var out: Dictionary = {}
	for group: int in sizes.size():
		var pointers: int = Gen3Layout.read_pointer(rom, table + group * 4, int(sizes[group]) * 4)
		if pointers < 0:
			return {}
		for number: int in int(sizes[group]):
			var at: int = Gen3Layout.read_pointer(rom, pointers + number * 4, HEADER_SIZE)
			var row: Dictionary = _header(rom, layout, at)
			if row.is_empty():
				return {}
			row.merge({"group": group, "number": number})
			out["%d:%d" % [group, number]] = row
	return out


static func _header(rom: RomFile, layout: Dictionary, at: int) -> Dictionary:
	if at < 0:
		return {}
	var frlg: bool = rom.id in [RomRegistry.FIRERED, RomRegistry.LEAFGREEN]
	var map_layout: int = Gen3Layout.read_pointer(rom, at, 28 if frlg else 24)
	var events: int = Gen3Layout.read_pointer(rom, at + 4, 20)
	var scripts: int = 0 if rom.u32le(at + 8) == 0 else Gen3Layout.read_pointer(rom, at + 8, 1, 1)
	if map_layout < 0 or events < 0 or scripts < 0:
		return {}
	var dimensions: Dictionary = _layout(rom, map_layout, frlg)
	var connections: Array = _connections(rom, layout, at + 12)
	var event_rows: Dictionary = Gen3Events.read(rom, layout, events)
	var script_rows: Array = Gen3Events.map_scripts(rom, scripts)
	if dimensions.is_empty() or connections == [{}] or event_rows.is_empty() or script_rows == [{}]:
		return {}
	var out: Dictionary = {
		"header_offset": at, "layout_offset": map_layout,
		"events_offset": events, "scripts_offset": scripts,
		"music": rom.u16le(at + 16), "layout_id": rom.u16le(at + 18),
		"region_map_section": rom.u8(at + 20), "requires_flash": rom.u8(at + 21) != 0,
		"weather": rom.u8(at + 22), "map_type": rom.u8(at + 23),
		"battle_scene": rom.u8(at + 27), "connections": connections,
		"events": event_rows, "map_scripts": script_rows,
	}
	out.merge(dimensions)
	out.merge(_flags(rom, at, frlg))
	return out


static func _layout(rom: RomFile, at: int, frlg: bool) -> Dictionary:
	var width: int = rom.u32le(at)
	var height: int = rom.u32le(at + 4)
	var border_width: int = rom.u8(at + 24) if frlg else 2
	var border_height: int = rom.u8(at + 25) if frlg else 2
	if width < 1 or height < 1 or width > 0x7FFF or height > 0x7FFF \
		or border_width < 1 or border_height < 1:
		return {}
	var border: int = Gen3Layout.read_pointer(rom, at + 8, border_width * border_height * 2, 2)
	var blocks: int = Gen3Layout.read_pointer(rom, at + 12, width * height * 2, 2)
	var primary: int = Gen3Layout.read_pointer(rom, at + 16, 24)
	var secondary: int = Gen3Layout.read_pointer(rom, at + 20, 24)
	if border < 0 or blocks < 0 or primary < 0 or secondary < 0:
		return {}
	return {"width": width, "height": height, "border_width": border_width,
		"border_height": border_height, "border_offset": border, "blocks_offset": blocks,
		"primary_tileset_offset": primary, "secondary_tileset_offset": secondary}


## Ruby's flags only carry show_map_name; running/cycling are code rules there.
static func _flags(rom: RomFile, at: int, frlg: bool) -> Dictionary:
	if rom.id in [RomRegistry.RUBY, RomRegistry.SAPPHIRE]:
		return {"flags": rom.u8(at + 26), "escape_rope": rom.u8(at + 25),
			"show_map_name": rom.u8(at + 26) != 0}
	var flags: int = rom.u8(at + (25 if frlg else 26))
	var out: Dictionary = {
		"allow_cycling": rom.u8(at + 24) != 0 if frlg else (flags & 1) != 0,
		"allow_escaping": (flags & (1 if frlg else 2)) != 0,
		"allow_running": (flags & (2 if frlg else 4)) != 0,
		"show_map_name": (flags & (4 if frlg else 8)) != 0,
	}
	if frlg:
		out["floor_number"] = rom.s8(at + 26)
	return out


static func _connections(rom: RomFile, layout: Dictionary, pointer_at: int) -> Array:
	if rom.u32le(pointer_at) == 0:
		return []
	var at: int = Gen3Layout.read_pointer(rom, pointer_at, 8)
	if at < 0:
		return [{}]
	var count: int = rom.u32le(at)
	if count < 1 or count > 255:
		return [{}]
	var list: int = Gen3Layout.read_pointer(rom, at + 4, count * 12)
	if list < 0:
		return [{}]
	var out: Array = []
	for slot: int in count:
		var row: int = list + slot * 12
		var direction: int = rom.u8(row)
		var group: int = rom.u8(row + 8)
		var number: int = rom.u8(row + 9)
		if direction < 1 or direction > 6 or not Gen3Layout.valid_map(layout, group, number):
			return [{}]
		var offset: int = rom.u32le(row + 4)
		out.append({"direction": direction, "offset": offset if offset < 0x80000000 else offset - 0x100000000,
			"group": group, "number": number})
	return out


static func _encounters(rom: RomFile, layout: Dictionary, headers: Dictionary) -> Dictionary:
	var at: int = int(layout["wild_headers"])
	var count: int = int(layout["wild_header_count"])
	if not rom.in_bounds(at, (count + 1) * WILD_HEADER_SIZE):
		return {}
	var end: int = at + count * WILD_HEADER_SIZE
	if rom.u8(end) != 0xFF or rom.u8(end + 1) != 0xFF:
		return {}
	var out: Dictionary = {"land": {}, "water": {}, "rock_smash": {},
		"old_rod": {}, "good_rod": {}, "super_rod": {}}
	var seen: Dictionary = {}
	for index: int in count:
		var row: int = at + index * WILD_HEADER_SIZE
		var key: String = "%d:%d" % [rom.u8(row), rom.u8(row + 1)]
		if not headers.has(key):
			return {}
		var variant: int = int(seen.get(key, 0))
		seen[key] = variant + 1
		if not _encounter_methods(rom, layout, row, key, variant, out):
			return {}
	return out


## GetCurrentMapWildMonHeaderId adds the Altering Cave set to its first row.
## Every occurrence keeps its ordinal even when a method is absent in that set.
static func _encounter_methods(rom: RomFile, layout: Dictionary, at: int, key: String, variant: int, out: Dictionary) -> bool:
	var records: Dictionary = {}
	for method: int in WILD_METHODS.size():
		var pointer_at: int = at + 4 + method * 4
		if rom.u32le(pointer_at) == 0:
			continue
		var record: Dictionary = _wild_info(rom, layout, pointer_at, method)
		if record.is_empty():
			return false
		if method < 3:
			records[WILD_METHODS[method]] = record
			continue
		for rod: String in RODS:
			var rod_record: Dictionary = record.duplicate(true)
			rod_record["slots"] = record["slots"].slice(int(RODS[rod][0]), int(RODS[rod][1]))
			records[rod] = rod_record
	for method: String in out:
		var table: Dictionary = out[method]
		if not records.has(method) and not table.has(key):
			continue
		var variants: Array = table.get(key, [])
		while variants.size() < variant:
			variants.append({})
		variants.append(records.get(method, {}))
		table[key] = variants
	return true


static func _wild_info(rom: RomFile, layout: Dictionary, pointer_at: int, method: int) -> Dictionary:
	var at: int = Gen3Layout.read_pointer(rom, pointer_at, 8)
	if at < 0:
		return {}
	var rate: int = rom.u8(at)
	var chances: Array = SLOT_CHANCES[method]
	var mons: int = Gen3Layout.read_pointer(rom, at + 4, chances.size() * 4)
	if rate > 100 or mons < 0:
		return {}
	var slots: Array = []
	for slot: int in chances.size():
		var row: int = mons + slot * 4
		var low: int = rom.u8(row)
		var high: int = rom.u8(row + 1)
		var species: int = Gen3Layout.national_number(rom, layout, rom.u16le(row + 2))
		if low < 1 or low > 100 or high < 1 or high > 100 or species < 1 or species > Gen3Layout.NATIONAL_DEX_COUNT:
			return {}
		slots.append({"slot": slot, "min_level": low, "max_level": high,
			"species": species, "chance": int(chances[slot])})
	return {"rate": rate, "slots": slots}


## pret's metatiles.h/metatiles.inc places each attribute array immediately
## after its eight-word metatile array. FRLG swaps callback/attributes in Tileset.
static func _graphics(rom: RomFile, headers: Dictionary) -> Dictionary:
	var layouts: Dictionary = {}
	var tilesets: Dictionary = {}
	for header: Dictionary in headers.values():
		var key: String = str(header["layout_offset"])
		if not layouts.has(key):
			layouts[key] = {
				"blocks": {"bytes": Array(rom.slice(header["blocks_offset"], header["width"] * header["height"] * 2))},
				"border": {"bytes": Array(rom.slice(header["border_offset"], header["border_width"] * header["border_height"] * 2))},
			}
		for field: String in ["primary_tileset_offset", "secondary_tileset_offset"]:
			key = str(header[field])
			if not tilesets.has(key):
				tilesets[key] = _tileset(rom, int(header[field]))
			var record: Dictionary = tilesets[key]
			if record.is_empty() or bool(record["secondary"]) != (field == "secondary_tileset_offset"):
				return {}
	return {"layouts": layouts, "tilesets": tilesets}


static func _tileset(rom: RomFile, at: int) -> Dictionary:
	var frlg: bool = rom.id in [RomRegistry.FIRERED, RomRegistry.LEAFGREEN]
	var attribute_size: int = 4 if frlg else 2
	var secondary: int = rom.u8(at + 1)
	if rom.u8(at) > 1 or secondary > 1:
		return {}
	var split: int = primary_tile_count(rom.id)
	var capacity: int = 1024 - split if secondary == 1 else split
	var tiles: int = Gen3Layout.read_pointer(rom, at + 4, 4)
	var metatiles: int = Gen3Layout.read_pointer(rom, at + 12, 16, 2)
	var attributes: int = Gen3Layout.read_pointer(rom, at + (20 if frlg else 16), attribute_size, attribute_size)
	var count: int = (attributes - metatiles) / 16
	if tiles < 0 or metatiles < 0 or attributes < 0 or count < 1 or count > capacity \
		or (attributes - metatiles) % 16 != 0 \
		or not rom.in_bounds(attributes, count * attribute_size):
		return {}
	var tile_bytes: PackedByteArray = _tile_bytes(rom, tiles, capacity, rom.u8(at) == 1)
	if tile_bytes.is_empty():
		return {}
	var palette: Dictionary = _tileset_palette(rom, at, frlg, secondary)
	var callback: int = int(palette.get("callback_offset", 0))
	var animation: Dictionary = Gen3TilesetAnims.read(rom, callback) if callback != 0 else {}
	if palette.is_empty() or (callback != 0 and animation.is_empty()):
		return {}
	var out: Dictionary = {"compressed": rom.u8(at) == 1, "secondary": secondary == 1,
		"tile_offset": split if secondary == 1 else 0, "tile_count": tile_bytes.size() / 32,
		"metatile_offset": split if secondary == 1 else 0, "metatile_count": count,
		"attribute_size": attribute_size,
		"tiles": {"bytes": Array(tile_bytes)},
		"metatiles": {"bytes": Array(rom.slice(metatiles, count * 16))},
		"attributes": {"bytes": Array(rom.slice(attributes, count * attribute_size))},
		"metatile_tail": {"bytes": Array(_tail(rom, metatiles + count * 16, (capacity - count) * 16))},
		"attribute_tail": {"bytes": Array(_tail(rom, attributes + count * attribute_size,
			(capacity - count) * attribute_size))},
		"animation": animation}
	out.merge(palette)
	return out


## The ROM after a metatile or attribute array, up to the bank's id space:
## `DrawMetatileAt` and `GetMetatileAttributesById` index past the array for an
## id the tileset lacks, which a connection strip from a map on another
## secondary tileset brings into the backup map.
static func _tail(rom: RomFile, at: int, length: int) -> PackedByteArray:
	return rom.slice(at, clampi(rom.size() - at, 0, length))


static func _tile_bytes(rom: RomFile, at: int, capacity: int, compressed: bool) -> PackedByteArray:
	if compressed and (rom.u32le(at) >> 8) % GbaTiles.TILE_BYTES != 0:
		return PackedByteArray()
	var bytes: PackedByteArray = GbaLz.decompress(rom.bytes(), at) if compressed \
		else rom.slice(at, capacity * GbaTiles.TILE_BYTES)
	if bytes.size() < GbaTiles.TILE_BYTES or bytes.size() > capacity * GbaTiles.TILE_BYTES:
		return PackedByteArray()
	return bytes


static func _tileset_palette(rom: RomFile, at: int, frlg: bool, secondary: int) -> Dictionary:
	var primary_pals: int = 7 if frlg else 6
	var total_pals: int = 12 if rom.id in [RomRegistry.RUBY, RomRegistry.SAPPHIRE] else 13
	var first_pal: int = primary_pals if secondary == 1 else 0
	var pal_count: int = total_pals - primary_pals if secondary == 1 else primary_pals
	var palettes: int = Gen3Layout.read_pointer(rom, at + 8, total_pals * 32 if secondary == 1 else primary_pals * 32)
	var callback: int = rom.u32le(at + (16 if frlg else 20))
	var callback_offset: int = Gen3Layout.rom_offset(callback & ~1)
	if palettes < 0 or (callback != 0 and ((callback & 1) == 0 or not rom.in_bounds(callback_offset, 2))):
		return {}
	return {"palette_offset": first_pal, "palette_count": pal_count,
		"callback_offset": callback_offset if callback != 0 else 0,
		"palettes": {"bytes": Array(rom.slice(palettes + first_pal * 32, pal_count * 32))}}


static func primary_tile_count(id: StringName) -> int:
	return 640 if id in [RomRegistry.FIRERED, RomRegistry.LEAFGREEN] else 512


## One metatile id's tiles and attributes. An id past the tileset's rows reads
## the ROM after the arrays, as the cartridge does; one past that is empty.
static func metatile(tileset: Dictionary, number: int) -> Dictionary:
	var index: int = number - int(tileset.get("metatile_offset", 0))
	var count: int = int(tileset.get("metatile_count", 0))
	if index < 0:
		return {}
	var tiles: PackedByteArray = tileset["metatiles"]["bytes"]
	var attributes: PackedByteArray = tileset["attributes"]["bytes"]
	var wide: bool = int(tileset["attribute_size"]) == 4
	if index >= count:
		index -= count
		tiles = tileset["metatile_tail"]["bytes"]
		attributes = tileset["attribute_tail"]["bytes"]
		if (index + 1) * 16 > tiles.size() or (index + 1) * (4 if wide else 2) > attributes.size():
			return {}
	var raw: int = attributes.decode_u32(index * 4) if wide else attributes.decode_u16(index * 2)
	var entries: Array = []
	for slot: int in 8:
		var word: int = tiles.decode_u16(index * 16 + slot * 2)
		entries.append({"tile": word & 0x3FF, "flip_x": (word & 0x400) != 0,
			"flip_y": (word & 0x800) != 0, "palette": word >> 12})
	return {"tiles": entries, "attributes": raw, "behavior": raw & (0x1FF if wide else 0xFF),
		"layer_type": (raw >> (29 if wide else 12)) & (3 if wide else 15)}
