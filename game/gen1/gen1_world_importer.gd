class_name Gen1WorldImporter
extends RefCounted

## Decodes every Generation 1 map, tileset, SGB palette, overworld sprite and
## wild encounter table into the shared world sections of the cache, the
## counterpart of [Gen2WorldImporter]. A map is named by one flat id, so a
## record's group is zero and its number is that id. A script is machine code
## here, so the header's script and text pointers are kept as addresses.

const LIST_END: int = Gen1Layout.TILESET_LIST_END


static func verify_layout(rom: RomFile) -> Dictionary:
	var result: Dictionary = read_world(rom, Gen1Layout.for_id(rom.id))
	if not bool(result.get("ok", false)):
		return {"ok": false, "message": String(result.get("message", "World data failed validation."))}
	return {"ok": true, "message": ""}


static func import_to_cache(
	rom: RomFile, layout: Dictionary, directory: String, on_progress: Callable = Callable()
) -> Dictionary:
	var result: Dictionary = read_world(rom, layout, on_progress)
	if not bool(result.get("ok", false)):
		return result

	var tilesets: Array = result["tilesets"]
	var sprites: Array = result["sprites"]
	var sections: Dictionary = {
		RomCache.world_maps_path(directory): result["maps"],
		RomCache.world_tilesets_path(directory): tilesets,
		RomCache.world_palettes_path(directory): result["palettes"],
		RomCache.overworld_sprites_path(directory): sprites,
		RomCache.world_encounters_path(directory): result["encounters"],
	}
	for path: String in sections:
		if not RomCache.write_json(path, sections[path]):
			return _error("Could not write %s." % path.get_file())
	var graphics: Dictionary = result["graphics"]
	for number: int in graphics:
		if not RomCache.write_indices(RomCache.world_tile_path(directory, number), graphics[number]):
			return _error("Could not write overworld tileset %d." % number)
	var sheets: Dictionary = result["sprite_graphics"]
	for number: int in sheets:
		if not RomCache.write_indices(
			RomCache.overworld_sprite_path(directory, number), sheets[number]
		):
			return _error("Could not write overworld sprite %d." % number)

	return {
		"ok": true,
		"maps": (result["maps"] as Array).size(),
		"tilesets": tilesets.size(),
		"sprites": sprites.size(),
		"encounters": (result["encounters"]["grass"] as Dictionary).size()
			+ (result["encounters"]["water"] as Dictionary).size(),
	}


## Every map and tileset, or the first thing that did not decode.
static func read_world(
	rom: RomFile, layout: Dictionary, on_progress: Callable = Callable()
) -> Dictionary:
	if layout.is_empty():
		return _error("No layout for %s." % rom.id)
	var palettes: Dictionary = _read_palettes(rom, layout)
	if not bool(palettes["ok"]):
		return palettes
	var sprites: Dictionary = _read_sprites(rom, layout)
	if not bool(sprites["ok"]):
		return sprites
	var encounters: Dictionary = _read_encounters(rom, layout)
	if not bool(encounters["ok"]):
		return encounters
	var water: PackedByteArray = _read_list(rom, int(layout["water_tilesets"]))
	var tilesets: Array = []
	var graphics: Dictionary = {}
	var count: int = Gen1Layout.tileset_count(rom.id)
	for number: int in count:
		var tileset: Dictionary = _read_tileset(rom, layout, number, water)
		if not bool(tileset.get("ok", false)):
			return tileset
		graphics[number] = tileset["pixels"]
		tileset.erase("pixels")
		tileset.erase("ok")
		tilesets.append(tileset)

	var overlap: Dictionary = _verify_block_counts(rom, layout, count)
	if not bool(overlap["ok"]):
		return overlap

	var maps: Array = []
	var map_count: int = Gen1Layout.map_count(rom.id)
	for map_id: int in map_count:
		if not Gen1Layout.is_real_map(map_id):
			continue
		var map: Dictionary = _read_map(rom, layout, tilesets, map_id)
		if not bool(map.get("ok", false)):
			return map
		map.erase("ok")
		maps.append(map)
		if on_progress.is_valid():
			on_progress.call("maps", maps.size(), map_count - Gen1Layout.UNUSED_MAPS.size())

	return {
		"ok": true,
		"maps": maps,
		"tilesets": tilesets,
		"graphics": graphics,
		"palettes": palettes["palettes"],
		"sprites": sprites["sprites"],
		"sprite_graphics": sprites["graphics"],
		"encounters": encounters["encounters"],
	}


static func _error(message: String) -> Dictionary:
	return {"ok": false, "message": message}


## A $FF-terminated run of bytes, as `IsInArray` walks one.
static func _read_list(rom: RomFile, at: int, limit: int = 256) -> PackedByteArray:
	var out := PackedByteArray()
	while out.size() < limit and rom.in_bounds(at) and rom.u8(at) != LIST_END:
		out.append(rom.u8(at))
		at += 1
	return out


## `WildDataPointers` and the rod tables behind it. Grass and water take the
## shared sections' shape under group zero; fishing keeps the Super Rod's index.
static func _read_encounters(rom: RomFile, layout: Dictionary) -> Dictionary:
	var table: int = int(layout["wild_data"])
	var count: int = Gen1Layout.map_count(rom.id)
	if rom.u16le(table + count * Gen1Layout.POINTER_SIZE) != Gen1Layout.WILD_POINTERS_END:
		return _error("WildDataPointers does not end behind map %d." % (count - 1))
	var bank: int = RomFile.bank_of(table)
	var grass: Dictionary = {}
	var water: Dictionary = {}
	for map_id: int in count:
		var at: int = RomFile.linear(
			bank, rom.u16le(table + map_id * Gen1Layout.POINTER_SIZE)
		)
		var block: Dictionary = _read_wild_block(rom, at, map_id)
		if not bool(block["ok"]):
			return block
		if not (block["row"] as Dictionary).is_empty():
			grass["0:%d" % map_id] = block["row"]
		block = _read_wild_block(rom, int(block["at"]), map_id)
		if not bool(block["ok"]):
			return block
		if not (block["row"] as Dictionary).is_empty():
			water["0:%d" % map_id] = block["row"]

	var fishing: Dictionary = _read_super_rod(rom, layout)
	if not bool(fishing["ok"]):
		return fishing
	return {"ok": true, "encounters": {
		"grass": grass, "water": water, "fishing": fishing["fishing"],
	}}


## One `def_grass_wildmons` or `def_water_wildmons` block: a rate byte, and ten
## (level, species) pairs behind it unless the rate is zero, which ends it.
static func _read_wild_block(rom: RomFile, at: int, map_id: int) -> Dictionary:
	if not rom.in_bounds(at):
		return _error("Map %d's wild data is outside the ROM." % map_id)
	var rate: int = rom.u8(at)
	if rate == 0:
		return {"ok": true, "row": {}, "at": at + 1}
	if not rom.in_bounds(at, Gen1Layout.WILD_DATA_LENGTH):
		return _error("Map %d's wild slots are outside the ROM." % map_id)
	var slots: Array = []
	for slot: int in Gen1Layout.WILD_SLOT_COUNT:
		var row: int = at + 1 + slot * 2
		var species: int = rom.u8(row + 1)
		if species < 1 or species > Gen1Layout.INDEX_COUNT:
			return _error("Map %d's wild slot %d names index %d." % [map_id, slot, species])
		slots.append({"level": rom.u8(row), "species": species})
	return {
		"ok": true,
		"row": {"map": "0:%d" % map_id, "rate": rate, "slots": slots},
		"at": at + Gen1Layout.WILD_DATA_LENGTH,
	}


## `SuperRodData`'s map index, or Yellow's `SuperRodFishingSlots`, whose row is
## its own group. An entry is the group [method GameData.world_fishing_map] reads.
static func _read_super_rod(rom: RomFile, layout: Dictionary) -> Dictionary:
	var at: int = int(layout["super_rod"])
	var bank: int = RomFile.bank_of(at)
	var flat: bool = Gen1Layout.flat_super_rod(rom.id)
	var stride: int = Gen1Layout.SUPER_ROD_ROW_SIZE_YELLOW if flat \
		else Gen1Layout.SUPER_ROD_ROW_SIZE
	var maps: Dictionary = {}
	var groups: Array = []
	var seen: Dictionary = {}
	while rom.in_bounds(at, stride) and rom.u8(at) != Gen1Layout.ROD_LIST_END:
		var map_id: int = rom.u8(at)
		if not Gen1Layout.is_real_map(map_id) or map_id >= Gen1Layout.map_count(rom.id):
			return _error("The Super Rod names map %d." % map_id)
		var key: int = at + 1 if flat else RomFile.linear(bank, rom.u16le(at + 1))
		if not seen.has(key):
			var group: Dictionary = _read_rod_group(rom, key, flat, map_id)
			if not bool(group["ok"]):
				return group
			groups.append(group["group"])
			seen[key] = groups.size()
		maps[str(map_id)] = int(seen[key])
		at += stride
	if maps.is_empty():
		return _error("The Super Rod table is empty.")
	return {"ok": true, "fishing": {"maps": maps, "groups": groups}}


## One group: a count and that many (level, species) rows, or Yellow's four
## (species, level) rows with the byte `GenerateRandomFishingEncounter` reads.
static func _read_rod_group(
	rom: RomFile, at: int, flat: bool, map_id: int
) -> Dictionary:
	var count: int = Gen1Layout.SUPER_ROD_SLOTS_YELLOW if flat else rom.u8(at)
	if count < 1 or count > Gen1Layout.SUPER_ROD_MAX_SLOTS:
		return _error("Map %d's fishing group holds %d slots." % [map_id, count])
	var first: int = at if flat else at + 1
	if not rom.in_bounds(first, count * 2):
		return _error("Map %d's fishing group is outside the ROM." % map_id)
	var slots: Array = []
	for slot: int in count:
		var row: int = first + slot * 2
		var species: int = rom.u8(row + 1 if not flat else row)
		if species < 1 or species > Gen1Layout.INDEX_COUNT:
			return _error("Map %d's fishing slot %d names index %d." % [map_id, slot, species])
		var entry: Dictionary = {
			"level": rom.u8(row if not flat else row + 1), "species": species,
		}
		if flat:
			entry["threshold"] = Gen1Layout.SUPER_ROD_THRESHOLDS_YELLOW[slot]
		slots.append(entry)
	return {"ok": true, "group": {"slots": slots}}


## `SuperPalettes`. `SetPal_Overworld` names one row a map and the
## `BlkPacket_WholeScreen` behind it gives that row art and objects alike.
static func _read_palettes(rom: RomFile, layout: Dictionary) -> Dictionary:
	var count: int = Gen1Layout.super_palette_count(rom.id)
	var at: int = int(layout["super_palettes"])
	if not rom.in_bounds(at, count * Gen1Layout.SUPER_PALETTE_BYTES):
		return _error("SuperPalettes is outside the ROM.")
	var out: Array = []
	for row: int in count:
		var colors: Array = []
		for slot: int in Gen1Layout.SUPER_PALETTE_COLORS:
			var packed: int = rom.u16le(
				Gen1Layout.super_palette_offset(layout, row) + slot * PokePalette.COLOR_BYTES
			)
			if (packed & 0x8000) != 0:
				return _error("SuperPalettes row %d has bit 15 set." % row)
			colors.append(packed)
		out.append(colors)
	return {"ok": true, "palettes": out}


## `SpriteSheetPointerTable` and the strips behind it. A walking sprite's row
## names half its graphics and `LoadMapSpriteTilePatterns` copies that many
## bytes twice, which `GetUsedSprite` also does: [Gen2WorldSprite] reads both.
static func _read_sprites(rom: RomFile, layout: Dictionary) -> Dictionary:
	var count: int = Gen1Layout.sprite_count(rom.id)
	var still_first: int = Gen1Layout.first_still_sprite(rom.id)
	var sprites: Array = []
	var graphics: Dictionary = {}
	for number: int in range(1, count + 1):
		var at: int = Gen1Layout.sprite_offset(layout, number)
		if not rom.in_bounds(at, Gen1Layout.SPRITE_RECORD_SIZE):
			return _error("Sprite %d's record is outside the ROM." % number)
		var address: int = rom.u16le(at)
		if address < RomFile.BANK_SIZE or address >= RomFile.BANK_SIZE * 2:
			return _error("Sprite %d names CPU address $%04X." % [number, address])
		var still: bool = number >= still_first
		var half: int = Gen1Layout.SPRITE_STILL_TILES if still \
			else Gen1Layout.SPRITE_WALKING_TILES
		if rom.u8(at + 2) != half * PokeTiles.TILE_BYTES:
			return _error("Sprite %d is %d bytes, wanted %d." % [
				number, rom.u8(at + 2), half * PokeTiles.TILE_BYTES,
			])
		var tiles: int = half if still else half * 2
		var raw: PackedByteArray = rom.slice(
			RomFile.linear(rom.u8(at + 3), address), tiles * PokeTiles.TILE_BYTES
		)
		if raw.size() != tiles * PokeTiles.TILE_BYTES:
			return _error("Sprite %d's graphics are truncated." % number)
		graphics[number] = PokeTiles.decode_2bpp_strip(raw, 0, tiles)
		sprites.append({
			"number": number,
			"address": address,
			"bank": rom.u8(at + 3),
			"bytes": tiles * PokeTiles.TILE_BYTES,
			"tiles": tiles,
			"type": Gen2WorldSprite.TYPE_STILL if still else Gen2WorldSprite.TYPE_WALKING,
			"palette": 0,
		})
	return {"ok": true, "sprites": sprites, "graphics": graphics}


## One row of `Tilesets`, its blockset, its graphics and the list of tiles
## `_IsTilePassable` walks. The blockset's length is the one thing no cartridge
## byte records; see [constant Gen1Layout.TILESET_BLOCKS_RED_BLUE].
static func _read_tileset(
	rom: RomFile, layout: Dictionary, number: int, water: PackedByteArray
) -> Dictionary:
	var table: int = Gen1Layout.tileset_offset(layout, number)
	if not rom.in_bounds(table, Gen1Layout.TILESET_RECORD_SIZE):
		return _error("Tileset %d record is outside the ROM." % number)

	var bank: int = rom.u8(table)
	var block_address: int = rom.u16le(table + 1)
	var graphics_address: int = rom.u16le(table + 3)
	var gap: int = block_address - graphics_address
	if gap <= 0 or gap > Gen1Layout.TILESET_TILE_COUNT * PokeTiles.TILE_BYTES:
		return _error("Tileset %d keeps %d bytes between its graphics and its blocks." % [
			number, gap,
		])

	var block_count: int = Gen1Layout.tileset_blocks(rom.id)[number]
	var meta_size: int = block_count * Gen1Layout.TILESET_BLOCK_TILES
	var meta_at: int = RomFile.linear(bank, block_address)
	if meta_at + meta_size > _bank_end(bank):
		return _error("Tileset %d's %d blocks run past bank $%02X." % [number, block_count, bank])
	var meta: PackedByteArray = rom.slice(meta_at, meta_size)
	if meta.size() != meta_size:
		return _error("Tileset %d's blocks are outside the ROM." % number)

	var passable: PackedByteArray = _read_list(
		rom, RomFile.linear(int(layout["tileset_collision_bank"]), rom.u16le(table + 5))
	)
	if passable.is_empty():
		return _error("Tileset %d has no passable tiles." % number)

	return {
		"ok": true,
		"number": number,
		"block_count": block_count,
		"tile_count": Gen1Layout.TILESET_TILE_COUNT,
		"meta": Array(meta),
		"passable_tiles": Array(passable),
		"counter_tiles": Array(rom.slice(table + 7, Gen1Layout.TILESET_COUNTER_TILES)),
		"grass_tile": rom.u8(table + 10),
		"animation": rom.u8(table + 11),
		"water": water.has(number),
		"pixels": _tileset_strip(rom, bank, graphics_address),
	}


## The other end of the pinned block counts: the assembler lays each tileset's
## graphics behind the last one's blocks, so a pin one block too long runs into
## the next row's graphics.
static func _verify_block_counts(rom: RomFile, layout: Dictionary, count: int) -> Dictionary:
	var rows: Array = []
	for number: int in count:
		var table: int = Gen1Layout.tileset_offset(layout, number)
		rows.append([rom.u8(table), rom.u16le(table + 1), rom.u16le(table + 3)])
	var blocks: Array[int] = Gen1Layout.tileset_blocks(rom.id)
	for number: int in count:
		var row: Array = rows[number]
		var start: int = RomFile.linear(int(row[0]), int(row[1]))
		var limit: int = _bank_end(int(row[0]))
		for other: Array in rows:
			var graphics: int = RomFile.linear(int(other[0]), int(other[2]))
			if int(other[0]) == int(row[0]) and graphics > start:
				limit = mini(limit, graphics)
		var end: int = start + blocks[number] * Gen1Layout.TILESET_BLOCK_TILES
		if end > limit:
			return _error("Tileset %d's %d blocks reach $%05X, past $%05X." % [
				number, blocks[number], end, limit,
			])
	return {"ok": true}


## The 96 tiles `LoadTilesetTilePatternData` copies to VRAM, blockset tail and
## all. Where that would run off the end of the bank the strip is left blank:
## the cartridge is reading past its own window and no block names a tile there.
static func _tileset_strip(rom: RomFile, bank: int, graphics_address: int) -> PackedByteArray:
	var at: int = RomFile.linear(bank, graphics_address)
	var wanted: int = Gen1Layout.TILESET_TILE_COUNT * PokeTiles.TILE_BYTES
	var graphics: PackedByteArray = rom.slice(at, mini(wanted, _bank_end(bank) - at))
	graphics.resize(wanted)
	return PokeTiles.decode_2bpp_strip(graphics, 0, Gen1Layout.TILESET_TILE_COUNT)


static func _bank_end(bank: int) -> int:
	return (bank + 1) * RomFile.BANK_SIZE


static func _bit_count(value: int) -> int:
	var out: int = 0
	while value != 0:
		out += value & 1
		value >>= 1
	return out


## One map header, the blocks it draws and the object block behind it.
static func _read_map(
	rom: RomFile, layout: Dictionary, tilesets: Array, map_id: int
) -> Dictionary:
	var bank: int = Gen1Layout.map_bank(rom, layout, map_id)
	var header: int = Gen1Layout.map_header_offset(rom, layout, map_id)
	if not rom.in_bounds(header, Gen1Layout.MAP_HEADER_SIZE):
		return _error("Map %d's header is outside the ROM." % map_id)

	var tileset_number: int = rom.u8(header)
	if tileset_number >= tilesets.size():
		return _error("Map %d references tileset %d." % [map_id, tileset_number])
	var tileset: Dictionary = tilesets[tileset_number]
	var block_count: int = int(tileset["block_count"])

	var height: int = rom.u8(header + 1)
	var width: int = rom.u8(header + 2)
	if width <= 0 or width > Gen1Layout.MAP_MAX_WIDTH_BLOCKS \
		or height <= 0 or height > Gen1Layout.MAP_MAX_HEIGHT_BLOCKS:
		return _error("Map %d is %dx%d blocks." % [map_id, width, height])

	var blocks: PackedByteArray = rom.slice(
		RomFile.linear(bank, rom.u16le(header + 3)), width * height
	)
	if blocks.size() != width * height:
		return _error("Map %d's block data is outside the ROM." % map_id)
	for block: int in blocks:
		if block >= block_count:
			return _error("Map %d uses block %d in a %d-block tileset." % [
				map_id, block, block_count,
			])

	var connection_flags: int = rom.u8(header + 9)
	if (connection_flags & 0xF0) != 0:
		return _error("Map %d has undefined connection flags $%02X." % [map_id, connection_flags])
	var connection_count: int = _bit_count(connection_flags)
	var object_address: int = header + Gen1Layout.MAP_HEADER_SIZE \
		+ connection_count * Gen1Layout.MAP_CONNECTION_RECORD_SIZE
	if not rom.in_bounds(object_address, Gen1Layout.MAP_OBJECT_POINTER_SIZE):
		return _error("Map %d's connection records run past the ROM." % map_id)
	var connections: Array = _read_connections(
		rom, header + Gen1Layout.MAP_HEADER_SIZE, connection_flags
	)

	var events: Dictionary = _read_events(
		rom, bank, rom.u16le(object_address), map_id, width, height, block_count
	)
	if not bool(events.get("ok", false)):
		return events

	return {
		"ok": true,
		"group": 0,
		"number": map_id,
		"tileset": tileset_number,
		"music": rom.u8(Gen1Layout.map_song_offset(layout, map_id)),
		"border_block": events["border_block"],
		"width_blocks": width,
		"height_blocks": height,
		"blocks": Array(blocks),
		"collision": _collision_grid(tileset, blocks, width, height),
		"collision_width": width * Gen1Layout.MAP_BLOCK_CELL_WIDTH,
		"collision_height": height * Gen1Layout.MAP_BLOCK_CELL_WIDTH,
		"connection_flags": connection_flags,
		"connections": connections,
		"scripts": {
			"bank": bank,
			"address": rom.u16le(header + 7),
			"text_address": rom.u16le(header + 5),
			"scenes": [],
			"callbacks": [],
		},
		"events": {
			"bank": bank,
			"address": rom.u16le(object_address),
			"warps": events["warps"],
			"coord_events": [],
			"bg_events": events["bg_events"],
			"objects": events["objects"],
		},
	}


## The tile every walk cell's passability is decided by; Generation 2's grid
## holds a permission byte in the same place.
static func _collision_grid(
	tileset: Dictionary, blocks: PackedByteArray, width: int, height: int
) -> Array:
	var meta: Array = tileset["meta"]
	var out: Array = []
	for cell_y: int in height * Gen1Layout.MAP_BLOCK_CELL_WIDTH:
		for cell_x: int in width * Gen1Layout.MAP_BLOCK_CELL_WIDTH:
			var block: int = blocks[(cell_y >> 1) * width + (cell_x >> 1)]
			out.append(int(meta[
				block * Gen1Layout.TILESET_BLOCK_TILES
				+ Gen1Layout.cell_tile_index(cell_x & 1, cell_y & 1)
			]))
	return out


## Connection records come north, south, west then east, whichever bits are set,
## and the caller has bounded the run. `.checkNorthMap` writes the y alignment
## into `wYCoord` and adds the x one to `wXCoord`, so the pair is an unsigned
## coordinate and a signed addend rather than Generation 2's two offsets.
static func _read_connections(rom: RomFile, at: int, connection_flags: int) -> Array:
	var directions: Array = [
		["north", Gen1Layout.MAP_CONNECTION_FLAG_NORTH],
		["south", Gen1Layout.MAP_CONNECTION_FLAG_SOUTH],
		["west", Gen1Layout.MAP_CONNECTION_FLAG_WEST],
		["east", Gen1Layout.MAP_CONNECTION_FLAG_EAST],
	]
	var out: Array = []
	for direction: Array in directions:
		if (connection_flags & int(direction[1])) == 0:
			continue
		out.append({
			"direction": String(direction[0]),
			"map_group": 0,
			"map_number": rom.u8(at),
			"target_block_pointer": rom.u16le(at + 1),
			"map_pointer": rom.u16le(at + 3),
			"length": rom.u8(at + 5),
			"target_width_blocks": rom.u8(at + 6),
			"y_alignment": rom.u8(at + 7),
			"x_alignment": rom.u8(at + 8),
			"window_pointer": rom.u16le(at + 9),
		})
		at += Gen1Layout.MAP_CONNECTION_RECORD_SIZE
	return out


## `<Map>_Object`: the border block, then warps, signs and objects, each a count
## and its rows.
static func _read_events(
	rom: RomFile, bank: int, address: int, map_id: int, width: int, height: int, block_count: int
) -> Dictionary:
	var at: int = RomFile.linear(bank, address)
	if not rom.in_bounds(at):
		return _error("Map %d's object block is outside the ROM." % map_id)
	var border_block: int = rom.u8(at)
	if border_block != Gen1Layout.TILESET_NO_TILE and border_block >= block_count:
		return _error("Map %d's border block is %d in a %d-block tileset." % [
			map_id, border_block, block_count,
		])
	at += 1

	var cell_width: int = width * Gen1Layout.MAP_BLOCK_CELL_WIDTH
	var cell_height: int = height * Gen1Layout.MAP_BLOCK_CELL_WIDTH
	var warps: Dictionary = _read_warps(rom, at, map_id, cell_width, cell_height)
	if not bool(warps.get("ok", false)):
		return warps
	var signs: Dictionary = _read_signs(rom, int(warps["at"]), map_id, cell_width, cell_height)
	if not bool(signs.get("ok", false)):
		return signs
	var objects: Dictionary = _read_objects(rom, int(signs["at"]), map_id)
	if not bool(objects.get("ok", false)):
		return objects
	# The block ends in one `warp_to` a warp, which names only WRAM.
	var end: int = int(objects["at"]) \
		+ (warps["events"] as Array).size() * Gen1Layout.WARP_TO_SIZE
	if end > _bank_end(bank):
		return _error("Map %d's object block runs past bank $%02X." % [map_id, bank])

	return {
		"ok": true,
		"border_block": border_block,
		"warps": warps["events"],
		"bg_events": signs["events"],
		"objects": objects["events"],
	}


static func _read_warps(
	rom: RomFile, at: int, map_id: int, cell_width: int, cell_height: int
) -> Dictionary:
	var count: int = rom.u8(at)
	at += 1
	if count > Gen1Layout.MAX_WARP_EVENTS:
		return _error("Map %d has %d warps." % [map_id, count])
	var out: Array = []
	for _row: int in count:
		if not rom.in_bounds(at, Gen1Layout.WARP_EVENT_SIZE):
			return _error("Map %d's warps are truncated." % map_id)
		var y: int = rom.u8(at)
		var x: int = rom.u8(at + 1)
		if x >= cell_width or y >= cell_height:
			return _error("Map %d has a warp at %d,%d outside its %dx%d cells." % [
				map_id, x, y, cell_width, cell_height,
			])
		out.append({
			"x": x,
			"y": y,
			"destination": rom.u8(at + 2),
			"map_group": 0,
			"map_number": rom.u8(at + 3),
		})
		at += Gen1Layout.WARP_EVENT_SIZE
	return {"ok": true, "events": out, "at": at}


## A sign is Generation 2's background event with a text id where that one keeps
## a script pointer.
static func _read_signs(
	rom: RomFile, at: int, map_id: int, cell_width: int, cell_height: int
) -> Dictionary:
	var count: int = rom.u8(at)
	at += 1
	if count > Gen1Layout.MAX_SIGN_EVENTS:
		return _error("Map %d has %d signs." % [map_id, count])
	var out: Array = []
	for _row: int in count:
		if not rom.in_bounds(at, Gen1Layout.SIGN_EVENT_SIZE):
			return _error("Map %d's signs are truncated." % map_id)
		var y: int = rom.u8(at)
		var x: int = rom.u8(at + 1)
		if x >= cell_width or y >= cell_height:
			return _error("Map %d has a sign at %d,%d outside its %dx%d cells." % [
				map_id, x, y, cell_width, cell_height,
			])
		out.append({"x": x, "y": y, "type": 0, "script": 0, "text": rom.u8(at + 2)})
		at += Gen1Layout.SIGN_EVENT_SIZE
	return {"ok": true, "events": out, "at": at}


## An object's coordinates may sit in the runtime's own border padding, so unlike
## a warp or a sign they are not bounded by the map. The TRAINER bit covers a
## standing wild Pokemon too; [constant Gen1Layout.OPPONENT_ID_OFFSET] splits them.
static func _read_objects(rom: RomFile, at: int, map_id: int) -> Dictionary:
	var count: int = rom.u8(at)
	at += 1
	if count > Gen1Layout.MAX_OBJECT_EVENTS:
		return _error("Map %d has %d objects." % [map_id, count])
	var out: Array = []
	for _row: int in count:
		if not rom.in_bounds(at, Gen1Layout.OBJECT_EVENT_SIZE):
			return _error("Map %d's objects are truncated." % map_id)
		var text: int = rom.u8(at + 5)
		var object: Dictionary = {
			"sprite": rom.u8(at),
			"y": rom.u8(at + 1) - Gen1Layout.OBJECT_COORD_BIAS,
			"x": rom.u8(at + 2) - Gen1Layout.OBJECT_COORD_BIAS,
			"movement": rom.u8(at + 3),
			"range": rom.u8(at + 4),
			"text": text & Gen1Layout.OBJECT_TEXT_MASK,
		}
		at += Gen1Layout.OBJECT_EVENT_SIZE
		var extra: int = _object_extra_bytes(text)
		if not rom.in_bounds(at, extra):
			return _error("Map %d's objects are truncated." % map_id)
		if (text & Gen1Layout.OBJECT_TRAINER_FLAG) != 0:
			var opponent: int = rom.u8(at)
			if opponent >= Gen1Layout.OPPONENT_ID_OFFSET:
				object["trainer_class"] = opponent - Gen1Layout.OPPONENT_ID_OFFSET
				object["trainer_number"] = rom.u8(at + 1)
			else:
				object["species"] = opponent
				object["level"] = rom.u8(at + 1)
		elif (text & Gen1Layout.OBJECT_ITEM_FLAG) != 0:
			object["item"] = rom.u8(at)
		at += extra
		out.append(object)
	return {"ok": true, "events": out, "at": at}


static func _object_extra_bytes(text: int) -> int:
	if (text & Gen1Layout.OBJECT_TRAINER_FLAG) != 0:
		return Gen1Layout.OBJECT_TRAINER_BYTES
	if (text & Gen1Layout.OBJECT_ITEM_FLAG) != 0:
		return Gen1Layout.OBJECT_ITEM_BYTES
	return 0
