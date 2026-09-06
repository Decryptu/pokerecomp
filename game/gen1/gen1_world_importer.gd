class_name Gen1WorldImporter
extends RefCounted

## Decodes every Generation 1 map, tileset, SGB palette, overworld sprite and
## wild encounter table into the shared world sections of the cache, the
## counterpart of [Gen2WorldImporter]. A map is named by one flat id, so a
## record's group is zero and its number is that id. A script is machine code
## here, so the header keeps its address and its text pointer is followed.

const LIST_END: int = Gen1Layout.TILESET_LIST_END

## The two gifts whose carry the branch behind them reads: `AddItemToInventory`'s
## and `_GivePokemon`'s.
const GIFT_OPS: Array[String] = ["give_item", "give_pokemon"]


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
		RomCache.world_trades_path(directory): result["trades"],
	}
	for path: String in sections:
		if not RomCache.write_json(path, sections[path]):
			return _error("Could not write %s." % path.get_file())
	if not RomCache.write_section(
		RomCache.overworld_effects_path(directory),
		RomCache.blob_path(RomCache.overworld_effects_path(directory)),
		result["effects"]
	):
		return _error("Could not write overworld effect sprites.")
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
	var icons: Dictionary = result["icons"]
	for number: int in icons:
		if not RomCache.write_indices(
			RomCache.overworld_icon_path(directory, number), icons[number]
		):
			return _error("Could not write party menu icon %d." % number)
	if not RomCache.write_indices(
		RomCache.mon_menu_icons_path(directory), result["icon_species"]
	):
		return _error("Could not write the species icon table.")

	return {
		"ok": true,
		"maps": (result["maps"] as Array).size(),
		"tilesets": tilesets.size(),
		"sprites": sprites.size(),
		"icons": (result["icons"] as Dictionary).size(),
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
	var effects: Dictionary = _read_overworld_effects(rom, layout)
	if not bool(effects["ok"]):
		return effects
	var icons: Dictionary = _read_mon_icons(rom, layout)
	if not bool(icons["ok"]):
		return icons
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
		"effects": effects["effects"],
		"icons": icons["icons"],
		"icon_species": icons["icon_species"],
		"trades": read_trades(rom, layout),
	}


## `TradeMons` in the shared `world_trade` shape. A row stores no DVs and no OT
## id: `AddPartyMon` and `InGameTrade_PrepareTradeData` roll them, which -1 asks
## for, and the trainer name is the one string every row shares.
static func read_trades(rom: RomFile, layout: Dictionary) -> Array:
	var at: int = int(layout["trade_mons"])
	var out: Array = []
	for index: int in Gen1Layout.TRADE_COUNT:
		var row: int = at + index * Gen1Layout.TRADE_RECORD_SIZE
		out.append({
			"trade_id": index,
			"dialog": rom.u8(row + 2),
			"requested_species": Gen1Layout.dex_of_index(rom, layout, rom.u8(row)),
			"offered_species": Gen1Layout.dex_of_index(rom, layout, rom.u8(row + 1)),
			"nickname": Gen1Text.decode(
				rom.bytes(), row + 3, Gen1Layout.TRADE_NAME_LENGTH
			),
			"dvs": -1,
			"item": 0,
			"ot_id": -1,
			"ot_name": Gen1Text.decode(
				rom.bytes(), int(layout["trade_ot_name"]), Gen1Layout.TRADE_NAME_LENGTH
			),
			"gender": Gen2Layout.TRADE_GENDER_EITHER,
		})
	return out


## `LoadMonPartySpriteGfx` over `MonPartySpritePointers`: every row copied into
## one tile strip, then read back out as each icon's two four-tile frames.
## `MonPartyData` names one icon per dex number, two nybbles to a byte with the
## odd number in the high half, and the cache numbers species by dex number.
static func _read_mon_icons(rom: RomFile, layout: Dictionary) -> Dictionary:
	var bank := PackedByteArray()
	var width: int = Gen1Layout.MON_ICON_VRAM_TILES * PokeTiles.TILE_WIDTH
	bank.resize(width * PokeTiles.TILE_HEIGHT)
	var filled: PackedByteArray = PackedByteArray()
	filled.resize(Gen1Layout.MON_ICON_VRAM_TILES)
	var at: int = int(layout["mon_icons"])
	for row: int in Gen1Layout.mon_icon_header_count(rom.id):
		var header: int = at + row * Gen1Layout.MON_ICON_HEADER_SIZE
		if not rom.in_bounds(header, Gen1Layout.MON_ICON_HEADER_SIZE):
			return _error("Icon header %d is outside the ROM." % row)
		var tiles: int = rom.u8(header + 2)
		var source: int = RomFile.linear(rom.u8(header + 3), rom.u16le(header))
		@warning_ignore("integer_division")
		var first: int = (rom.u16le(header + 4) - Gen1Layout.MON_ICON_VRAM_AT) \
			/ PokeTiles.TILE_BYTES
		if first < 0 or first + tiles > Gen1Layout.MON_ICON_VRAM_TILES:
			return _error("Icon header %d lands outside the icon strip." % row)
		var raw: PackedByteArray = rom.slice(source, tiles * PokeTiles.TILE_BYTES)
		if raw.size() != tiles * PokeTiles.TILE_BYTES:
			return _error("Icon header %d's graphics are truncated." % row)
		var pixels: PackedByteArray = PokeTiles.decode_2bpp_strip(raw, 0, tiles)
		for tile: int in tiles:
			_copy_icon_tile(pixels, tiles, tile, bank, width, first + tile)
			filled[first + tile] = 1
	return _slice_mon_icons(rom, layout, bank, filled)


## One 8x8 tile from one strip into another, both being one row of tiles wide.
static func _copy_icon_tile(
	from: PackedByteArray, from_tiles: int, from_tile: int,
	into: PackedByteArray, into_width: int, into_tile: int
) -> void:
	var from_width: int = from_tiles * PokeTiles.TILE_WIDTH
	for row: int in PokeTiles.TILE_HEIGHT:
		var read: int = row * from_width + from_tile * PokeTiles.TILE_WIDTH
		var write: int = row * into_width + into_tile * PokeTiles.TILE_WIDTH
		for column: int in PokeTiles.TILE_WIDTH:
			into[write + column] = from[read + column]


## The strip split back into icons, and the species table beside it. An icon is
## kept only when both of its frames carry the tiles its own OAM writer reads,
## which is what leaves the nybbles no cartridge names out of the cache.
static func _slice_mon_icons(
	rom: RomFile, layout: Dictionary, bank: PackedByteArray, filled: PackedByteArray
) -> Dictionary:
	var frame: int = Gen1Layout.MON_ICON_FRAME_TILES
	var icons: Dictionary = {}
	for icon: int in Gen1Layout.MON_ICON_NYBBLES:
		var first: int = icon * frame
		var second: int = Gen1Layout.MON_ICON_FRAME_OFFSET + first
		var whole: bool = true
		for tile: int in Gen1Layout.mon_icon_tiles_read(icon):
			whole = whole and filled[first + tile] != 0 and filled[second + tile] != 0
		if not whole:
			continue
		var strip := PackedByteArray()
		strip.resize(frame * 2 * PokeTiles.TILE_WIDTH * PokeTiles.TILE_HEIGHT)
		for tile: int in frame:
			_copy_icon_tile(
				bank, Gen1Layout.MON_ICON_VRAM_TILES, first + tile,
				strip, frame * 2 * PokeTiles.TILE_WIDTH, tile
			)
			_copy_icon_tile(
				bank, Gen1Layout.MON_ICON_VRAM_TILES, second + tile,
				strip, frame * 2 * PokeTiles.TILE_WIDTH, frame + tile
			)
		icons[icon + 1] = strip

	var species: PackedByteArray = PackedByteArray()
	species.resize(Gen1Layout.SPECIES_COUNT)
	var table: int = int(layout["mon_icon_species"])
	for dex: int in range(1, Gen1Layout.SPECIES_COUNT + 1):
		@warning_ignore("integer_division")
		var byte: int = rom.u8(table + (dex - 1) / 2)
		var icon: int = (byte >> 4) if dex % 2 == 1 else (byte & 0x0F)
		if not icons.has(icon + 1):
			return _error("Dex number %d is drawn with icon %d." % [dex, icon])
		species[dex - 1] = icon + 1
	return {"ok": true, "icons": icons, "icon_species": species}


## `PokeCenterFlashingMonitorAndHealBall` with `PokeCenterOAMData` behind it, and
## `ShockEmote`: the two sheets Generation 1 draws over the map.
static func _read_overworld_effects(rom: RomFile, layout: Dictionary) -> Dictionary:
	var machine: Dictionary = _read_pinned_sheet(
		rom, int(layout.get("heal_machine_gfx", -1)),
		Gen1Layout.HEAL_MACHINE_BYTES, Gen1Layout.HEAL_MACHINE_VTILE, "heal_machine"
	)
	if not bool(machine.get("ok", false)):
		return machine
	var oam: Dictionary = _check_heal_machine_oam(
		rom, int(layout["heal_machine_gfx"]) + Gen1Layout.HEAL_MACHINE_BYTES.size()
	)
	if not bool(oam.get("ok", false)):
		return oam
	var shock: Dictionary = _read_pinned_sheet(
		rom, int(layout.get("shock_emote_gfx", -1)),
		Gen1Layout.SHOCK_EMOTE_BYTES, Gen1Layout.SHOCK_EMOTE_VTILE, "shock"
	)
	if not bool(shock.get("ok", false)):
		return shock
	return {"ok": true, "effects": [machine["effect"], shock["effect"]]}


## One sheet, refused rather than decoded once the pinned bytes have moved.
static func _read_pinned_sheet(
	rom: RomFile, at: int, pinned: Array[int], vtile: int, name: String
) -> Dictionary:
	if at < 0 or not rom.in_bounds(at, pinned.size()) \
		or rom.slice(at, pinned.size()) != PackedByteArray(pinned):
		return _error("The %s sheet is not at $%X." % [name, at])
	@warning_ignore("integer_division")
	var tiles: int = pinned.size() / PokeTiles.TILE_BYTES
	var pixels: PackedByteArray = PokeTiles.decode_2bpp_strip(
		rom.slice(at, pinned.size()), 0, tiles
	)
	if pixels.size() != tiles * PokeTiles.TILE_PIXELS:
		return _error("The %s sheet did not decode." % name)
	return {"ok": true, "effect": {
		"name": name, "tiles": tiles, "vtile": vtile, "bytes": Array(pixels),
	}}


static func _check_heal_machine_oam(rom: RomFile, at: int) -> Dictionary:
	for row: int in Gen1Layout.HEAL_MACHINE_OAM.size():
		var entry: int = at + row * Gen1Layout.HEAL_MACHINE_OAM_SIZE
		var pinned: Array = Gen1Layout.HEAL_MACHINE_OAM[row]
		if not rom.in_bounds(entry, Gen1Layout.HEAL_MACHINE_OAM_SIZE):
			return _error("Heal machine OAM row %d is outside the cartridge." % row)
		## The attribute byte carries a Game Boy Color palette on Yellow and not
		## on Red or Blue, so only the flip is compared.
		var flipped: bool = (rom.u8(entry + 3) & Gen1Layout.HEAL_MACHINE_OAM_XFLIP) != 0
		if [rom.u8(entry), rom.u8(entry + 1), rom.u8(entry + 2), flipped] != pinned:
			return _error("Heal machine OAM row %d is not %s." % [row, pinned])
	return {"ok": true}


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
		var block: Dictionary = _read_wild_block(rom, layout, at, map_id)
		if not bool(block["ok"]):
			return block
		if not (block["row"] as Dictionary).is_empty():
			grass["0:%d" % map_id] = block["row"]
		block = _read_wild_block(rom, layout, int(block["at"]), map_id)
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
static func _read_wild_block(
	rom: RomFile, layout: Dictionary, at: int, map_id: int
) -> Dictionary:
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
		var dex: int = Gen1Layout.dex_of_index(rom, layout, rom.u8(row + 1))
		if dex < 1:
			return _error("Map %d's wild slot %d names index %d." % [
				map_id, slot, rom.u8(row + 1),
			])
		slots.append({"level": rom.u8(row), "species": dex})
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
			var group: Dictionary = _read_rod_group(rom, layout, key, flat, map_id)
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
	rom: RomFile, layout: Dictionary, at: int, flat: bool, map_id: int
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
		var dex: int = Gen1Layout.dex_of_index(rom, layout, species)
		if dex < 1:
			return _error("Map %d's fishing slot %d names index %d." % [map_id, slot, species])
		var entry: Dictionary = {
			"level": rom.u8(row if not flat else row + 1), "species": dex,
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
	if meta_at + meta_size > RomFile.bank_end(bank):
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
		"bookshelves": _read_bookshelves(rom, layout, number),
		"water": water.has(number),
		"pixels": _tileset_strip(rom, bank, graphics_address),
	}


## `BookshelfTileIDs`: the tile a tileset draws a bookshelf with and the box
## `PrintBookshelfText` answers with, read in that routine's own bank.
static func _read_bookshelves(rom: RomFile, layout: Dictionary, number: int) -> Dictionary:
	var at: int = int(layout["bookshelf_tiles"])
	var bank: int = RomFile.bank_of(at)
	var out: Dictionary = {}
	while rom.u8(at) != Gen1Layout.HIDDEN_EVENT_END:
		if rom.u8(at) == number:
			var nodes: Array = _predef_nodes(rom, layout, bank, rom.u8(at + 2))
			if not nodes.is_empty():
				out[rom.u8(at + 1)] = nodes
		at += Gen1Layout.BOOKSHELF_ROW_SIZE
	return out


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
		var limit: int = RomFile.bank_end(int(row[0]))
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
	var graphics: PackedByteArray = rom.slice(at, mini(wanted, RomFile.bank_end(bank) - at))
	graphics.resize(wanted)
	return PokeTiles.decode_2bpp_strip(graphics, 0, Gen1Layout.TILESET_TILE_COUNT)


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
		rom, layout, bank, rom.u16le(object_address), map_id, width, height, block_count
	)
	if not bool(events.get("ok", false)):
		return events

	var texts: Array = _read_texts(rom, layout, bank, rom.u16le(header + 5), events)
	_carry_trainer_headers(events["objects"], texts)
	_carry_toggleable_objects(rom, layout, events["objects"], map_id)

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
			"scenes": [],
			"callbacks": [],
		},
		"texts": texts,
		"events": {
			"bank": bank,
			"address": rom.u16le(object_address),
			"warps": events["warps"],
			"coord_events": [],
			"bg_events": events["bg_events"],
			"objects": events["objects"],
			"hidden_events": _read_hidden_events(
				rom, layout, map_id, bank, rom.u16le(header + 7)
			),
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
	rom: RomFile, layout: Dictionary, bank: int, address: int, map_id: int,
	width: int, height: int, block_count: int
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
	var objects: Dictionary = _read_objects(rom, layout, int(signs["at"]), map_id)
	if not bool(objects.get("ok", false)):
		return objects
	# The block ends in one `warp_to` a warp, which names only WRAM.
	var end: int = int(objects["at"]) \
		+ (warps["events"] as Array).size() * Gen1Layout.WARP_TO_SIZE
	if end > RomFile.bank_end(bank):
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
static func _read_objects(
	rom: RomFile, layout: Dictionary, at: int, map_id: int
) -> Dictionary:
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
			"movement": Gen1Layout.object_movement(rom.u8(at + 3), rom.u8(at + 4)),
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
				object["species"] = Gen1Layout.dex_of_index(rom, layout, opponent)
				object["level"] = rom.u8(at + 1)
		elif (text & Gen1Layout.OBJECT_ITEM_FLAG) != 0:
			object["item"] = rom.u8(at)
		at += extra
		out.append(object)
	return {"ok": true, "events": out, "at": at}


## The header an object's text row carries, copied onto the object so a flag
## read reaches it without the text.
static func _carry_trainer_headers(objects: Array, texts: Array) -> void:
	for object: Dictionary in objects:
		var id: int = int(object.get("text", 0))
		if id < 1 or id > texts.size():
			continue
		var header: Variant = (texts[id - 1] as Dictionary).get("trainer", {})
		if not header is Dictionary or (header as Dictionary).is_empty():
			continue
		object["object_type"] = Gen2WorldObject.OBJECTTYPE_TRAINER
		object["sight_range"] = int((header as Dictionary)["sight_range"])
		## `CheckForEngagingTrainers` walks a trainer and a standing wild alike,
		## and so does `TrainerFlagAction`; only `EndTrainerBattle`'s
		## `predef HideObject` tells the two apart.
		object["trainer"] = {"event_flag": int((header as Dictionary)["event_flag"])}


## `wToggleableObjectList`: the map's own run of `ToggleableObjectStates`. Three
## rows of the corpus name an object their map does not have.
static func read_toggleable_rows(rom: RomFile, layout: Dictionary, map_id: int) -> Array:
	var table: int = int(layout["toggleable_states"])
	var at: int = Gen1Layout.banked(RomFile.bank_of(table), rom.u16le(
		int(layout["toggleable_pointers"]) + map_id * Gen1Layout.POINTER_SIZE
	))
	@warning_ignore("integer_division")
	var first: int = (at - table) / Gen1Layout.TOGGLE_STATE_SIZE
	var out: Array = []
	while rom.in_bounds(at, Gen1Layout.TOGGLE_STATE_SIZE) and rom.u8(at) == map_id:
		out.append({
			"object": rom.u8(at + 1),
			"index": first + out.size(),
			"on": rom.u8(at + 2) == Gen1Layout.TOGGLE_ON,
		})
		at += Gen1Layout.TOGGLE_STATE_SIZE
	return out


## Each row carried onto its object, so a mask read reaches it without the table.
static func _carry_toggleable_objects(
	rom: RomFile, layout: Dictionary, objects: Array, map_id: int
) -> void:
	for row: Dictionary in read_toggleable_rows(rom, layout, map_id):
		var slot: int = int(row["object"]) - 1
		if slot < 0 or slot >= objects.size():
			continue
		var object: Dictionary = objects[slot]
		object["toggle_index"] = int(row["index"])
		object["toggle_on"] = bool(row["on"])


## `<Map>_TextPointers`, which `DisplayTextID` indexes with a text id. A row is
## machine code; only `text_far` and `text_start` are a text, and the rest keep
## the byte naming them. The table has no end, so the map's own events bound it.
static func _read_texts(
	rom: RomFile, layout: Dictionary, bank: int, address: int, events: Dictionary
) -> Array:
	var table: int = Gen1Layout.banked(bank, address)
	var out: Array = []
	for id: int in _highest_text_id(events):
		out.append(_read_text(rom, layout, bank, rom.u16le(table + id * 2)))
	return out


## A `TX_SCRIPT_*` row keeps its own inventory where it has one, so nothing
## downstream has to read the cartridge again to open the shop.
static func _read_text(
	rom: RomFile, layout: Dictionary, bank: int, pointer: int
) -> Dictionary:
	var at: int = Gen1Layout.banked(bank, pointer)
	var decoded: Dictionary = Gen1Text.decode_stream(rom, at)
	var row: Dictionary = {"command": rom.u8(at), "text": ""}
	if not bool(decoded.get("ok", false)):
		if int(row["command"]) == Gen1Layout.TEXT_SCRIPT_MART:
			row["items"] = _read_mart_items(rom, at)
		elif String(decoded.get("reason", "")) != "text_script":
			row["reason"] = String(decoded.get("reason", "invalid_text"))
		return row
	var header: int = _asm_operand(rom, bank, at, int(layout["talk_to_trainer"]))
	if header >= 0:
		row["trainer"] = _read_trainer_header(rom, layout, bank, header)
		return row
	row["text"] = String(decoded["text"])
	row["prompt"] = bool(decoded.get("prompt", false))
	var code: int = _text_code_at(decoded)
	if code < 0:
		return row
	var script: Array = decode_script(rom, layout, bank, code)
	if script.is_empty():
		return row
	if not String(row["text"]).is_empty():
		script.push_front({"op": "text", "text": String(row["text"])})
	row["script"] = script
	return row


## Where a text's own machine code begins, or -1. `text_asm` is the one command
## the stream stops on rather than reads past.
static func _text_code_at(decoded: Dictionary) -> int:
	return int(decoded.get("bytes", -1)) if bool(decoded.get("stop", false)) else -1


## `CheckForHiddenEvent`: the rows the A button walks before it looks for a sign
## or a sprite.
static func _read_hidden_events(
	rom: RomFile, layout: Dictionary, map_id: int, script_bank: int, script: int
) -> Array:
	var table: int = int(layout["hidden_event_maps"])
	var pointers: int = int(layout["hidden_event_pointers"])
	var stride: int = 1 if pointers > 0 else Gen1Layout.HIDDEN_EVENT_MAP_SIZE
	var index: int = 0
	while rom.u8(table + index * stride) != Gen1Layout.HIDDEN_EVENT_END:
		if rom.u8(table + index * stride) == map_id:
			return _read_hidden_rows(rom, layout, RomFile.bank_of(table), rom.u16le(
				pointers + index * 2 if pointers > 0 else table + index * stride + 1
			), map_id, _gym_names(rom, layout, script_bank, script))
		index += 1
	return []


static func _read_hidden_rows(
	rom: RomFile, layout: Dictionary, bank: int, pointer: int, map_id: int, names: Array
) -> Array:
	var at: int = Gen1Layout.banked(bank, pointer)
	var out: Array = []
	while rom.u8(at) != Gen1Layout.HIDDEN_EVENT_END:
		out.append(_read_hidden_row(rom, layout, at, map_id, names))
		at += Gen1Layout.HIDDEN_EVENT_SIZE
	return out


## The gym's own city and leader names, which its map script hands
## `LoadGymLeaderAndCityName` and `_GymStatueText1` reads back out of RAM. Red
## and Blue tail-call it and Yellow calls and returns.
static func _gym_names(rom: RomFile, layout: Dictionary, bank: int, script: int) -> Array:
	var at: int = Gen1Layout.banked(bank, script)
	for step: int in Gen1Layout.GYM_NAME_SEARCH:
		if rom.u8(at + step) != Gen1Layout.SCRIPT_LD_HL \
			or rom.u8(at + step + 3) != Gen1Layout.SCRIPT_LD_DE \
			or rom.u16le(at + step + 7) != int(layout["load_gym_names"]) \
			or rom.u8(at + step + 6) not in Gen1Layout.GYM_NAME_TAILS:
			continue
		return [
			Gen1Text.decode(rom.bytes(), Gen1Layout.banked(bank, rom.u16le(at + step + 1)),
				Gen1Layout.GYM_CITY_LENGTH),
			Gen1Text.decode(rom.bytes(), Gen1Layout.banked(bank, rom.u16le(at + step + 4)),
				Gen1Layout.GYM_LEADER_LENGTH),
		]
	return []


## One `hidden_event`: the faced cell, then the routine behind it. Four walk a
## table of their own; the rest are machine code, read with the argument in `a`.
static func _read_hidden_row(
	rom: RomFile, layout: Dictionary, at: int, map_id: int, names: Array
) -> Dictionary:
	var row: Dictionary = {"y": rom.u8(at), "x": rom.u8(at + 1)}
	var argument: int = rom.u8(at + 2)
	var bank: int = rom.u8(at + 3)
	var address: int = rom.u16le(at + 4)
	var named: String = Gen1Layout.hidden_routine(layout, Gen1Layout.banked(bank, address))
	var script: Array = decode_script(
		rom, layout, bank, address, {"hidden_argument": argument}
	) if named.is_empty() else _hidden_table_nodes(
		rom, layout, named, bank, map_id, argument, row, names
	)
	if not script.is_empty():
		row["script"] = script
	return row


static func _hidden_table_nodes(
	rom: RomFile, layout: Dictionary, named: String, bank: int, map_id: int,
	argument: int, row: Dictionary, names: Array
) -> Array:
	match named:
		"hidden_items":
			return _hidden_item_nodes(rom, layout, bank, map_id, argument, row)
		"hidden_coins":
			return _hidden_coin_nodes(rom, layout, bank, map_id, argument, row)
		"bench_guy_text":
			return _bench_guy_nodes(rom, layout, bank, map_id)
		"gym_statues":
			return _gym_statue_nodes(rom, layout, bank, map_id, names)
	return []


## `FindHiddenItemOrCoinsIndex`: a row's place in the list is its own flag bit.
static func _hidden_coord_index(
	rom: RomFile, at: int, map_id: int, row: Dictionary
) -> int:
	var index: int = 0
	while rom.u8(at) != Gen1Layout.HIDDEN_EVENT_END:
		if rom.u8(at) == map_id and rom.u8(at + 1) == int(row["y"]) \
			and rom.u8(at + 2) == int(row["x"]):
			return index
		at += Gen1Layout.HIDDEN_COORD_SIZE
		index += 1
	return -1


## `HiddenItems`: the argument is the item, and `GetItemName` runs in front of
## the box, so the receipt reads even when the bag turns the item away.
static func _hidden_item_nodes(
	rom: RomFile, layout: Dictionary, bank: int, map_id: int, item: int, row: Dictionary
) -> Array:
	var index: int = _hidden_coord_index(
		rom, int(layout["hidden_item_coords"]), map_id, row
	)
	if index < 0:
		return []
	var flag: int = Gen1Layout.engine_flag_base("obtained_hidden_items") + index
	var found: String = _predef_text(rom, layout, bank, "found_hidden_item")
	var full: String = _predef_text(rom, layout, bank, "hidden_item_bag_full")
	if found.is_empty() or full.is_empty():
		return []
	return [{"op": "branch", "flag": flag, "engine": true, "then": [], "else": [
		{"op": "name_item", "item": item},
		{"op": "text", "text": found, "press": false},
		{"op": "give_item", "item": item, "count": 1,
			"ok": [{"op": "flag", "flag": flag, "set": true, "engine": true}],
			"full": [{"op": "text", "text": full}]},
	]}]


## `HiddenCoins`: no coin case answers nothing, and the box behind the sum is
## `AddBCD`'s ceiling being reached rather than the sum overflowing.
static func _hidden_coin_nodes(
	rom: RomFile, layout: Dictionary, bank: int, map_id: int, argument: int, row: Dictionary
) -> Array:
	var index: int = _hidden_coord_index(
		rom, int(layout["hidden_coin_coords"]), map_id, row
	)
	if index < 0:
		return []
	var flag: int = Gen1Layout.engine_flag_base("obtained_hidden_coins") + index
	var found: String = _predef_text(rom, layout, bank, "found_hidden_coins")
	var dropped: String = _predef_text(rom, layout, bank, "dropped_hidden_coins")
	if found.is_empty() or dropped.is_empty():
		return []
	return [{"op": "has_item", "item": Gen1Layout.ITEM_COIN_CASE, "else": [], "then": [
		{"op": "branch", "flag": flag, "engine": true, "then": [], "else": [
			{"op": "add_coins", "amount": Gen1Layout.hidden_coin_amount(argument)},
			{"op": "flag", "flag": flag, "set": true, "engine": true},
			{"op": "has_coins", "coins": Gen1Layout.HIDDEN_COIN_CEILING,
				"test": "exactly",
				"then": [{"op": "text", "text": dropped}],
				"else": [{"op": "text", "text": found}]},
		]},
	]}]


## `BenchGuyTextPointers`: the map, the side he is spoken to from and his own
## `tx_pre` id. Any other side walks the source's own misaligned loop, which
## reads past the table and says nothing here.
static func _bench_guy_nodes(
	rom: RomFile, layout: Dictionary, bank: int, map_id: int
) -> Array:
	var at: int = int(layout["bench_guy_texts"])
	while rom.u8(at) != Gen1Layout.HIDDEN_EVENT_END:
		if rom.u8(at) != map_id:
			at += Gen1Layout.BENCH_GUY_ROW_SIZE
			continue
		return _facing_nodes(
			rom.u8(at + 1), _predef_nodes(rom, layout, bank, rom.u8(at + 2))
		)
	return []


## `GymStatues`: `MapBadgeFlags` names one badge per gym, and its second box is
## the one a player wearing it reads.
static func _gym_statue_nodes(
	rom: RomFile, layout: Dictionary, bank: int, map_id: int, names: Array
) -> Array:
	var at: int = int(layout["map_badge_flags"])
	while rom.u8(at) != Gen1Layout.HIDDEN_EVENT_END:
		if rom.u8(at) != map_id:
			at += Gen1Layout.BADGE_ROW_SIZE
			continue
		var badge: int = _bit_index(rom.u8(at + 1))
		if badge < 0:
			return []
		var badge_text: int = Gen1Layout.text_predef(rom.id, "gym_statue_badge")
		var plain_text: int = Gen1Layout.text_predef(rom.id, "gym_statue")
		return _facing_nodes(Gen1Layout.FACING_UP, [{"op": "badge", "badge": badge,
			"then": _named_nodes(_predef_nodes(rom, layout, bank, badge_text), names),
			"else": _named_nodes(_predef_nodes(rom, layout, bank, plain_text), names)}])
	return []


static func _bit_index(mask: int) -> int:
	for bit: int in 8:
		if mask == 1 << bit:
			return bit
	return -1


## `text_ram`'s markers filled in the order the boxes read them, which is the
## city and then the leader.
static func _named_nodes(nodes: Array, names: Array) -> Array:
	for node: Dictionary in nodes:
		if String(node["op"]) != "text":
			continue
		for name: String in names:
			node["text"] = Gen2TextStream.fill_marker(
				String(node["text"]), Gen2TextStream.RAM_MARKER, name
			)
	return nodes


## A routine's own `cp SPRITE_FACING_*` and the `ret nz` behind it.
static func _facing_nodes(facing: int, nodes: Array) -> Array:
	return [] if nodes.is_empty() \
		else [{"op": "facing", "facing": facing, "then": nodes, "else": []}]


## One `TextPredefs` row as the nodes it prints, read in [param bank].
static func _predef_nodes(
	rom: RomFile, layout: Dictionary, bank: int, id: int
) -> Array:
	if id < 1 or id > Gen1Layout.text_predef_count(rom.id):
		return []
	var ctx: Dictionary = {
		"rom": rom, "layout": layout, "bank": bank,
		"budget": [SCRIPT_BUDGET], "calls": [0],
	}
	var out: Array = []
	return out if _script_text_row(ctx, _predef_pointer(rom, layout, id), {}, out, 0) \
		else []


static func _predef_pointer(rom: RomFile, layout: Dictionary, id: int) -> int:
	return rom.u16le(
		int(layout["text_predefs"]) + (id - 1) * Gen1Layout.TEXT_PREDEF_SIZE
	)


## The string one [constant Gen1Layout.TEXT_PREDEFS] row prints.
static func _predef_text(
	rom: RomFile, layout: Dictionary, bank: int, name: String
) -> String:
	var decoded: Dictionary = Gen1Text.decode_stream(rom, Gen1Layout.banked(
		bank, _predef_pointer(rom, layout, Gen1Layout.text_predef(rom.id, name))
	))
	return String(decoded["text"]) if bool(decoded.get("ok", false)) else ""


## Where a `text_asm` row's `ld hl` points when the code behind it calls
## [param target], or -1 for any other machine code. `TalkToTrainer` is 322 of
## the corpus's 626 such rows; a map sharing one landing `jr`s onto it.
static func _asm_operand(rom: RomFile, bank: int, at: int, target: int) -> int:
	if rom.u8(at) != Gen1Layout.TEXT_ASM \
		or rom.u8(at + 1) != Gen1Layout.SCRIPT_LD_HL:
		return -1
	var landing: int = at + 4
	if rom.u8(landing) == Gen1Layout.SCRIPT_JR:
		## `jr` counts from the byte after its own operand.
		var hop: int = rom.u8(landing + 1)
		landing += 2 + (hop - 0x100 if hop > 0x7F else hop)
	if rom.u8(landing) != Gen1Layout.SCRIPT_CALL \
		or rom.u16le(landing + 1) != target:
		return -1
	return Gen1Layout.banked(bank, rom.u16le(at + 2))


## What one walk may read, how deep its branches may nest, and the two answers
## [method _script_step] gives that are not an address.
const SCRIPT_BUDGET: int = 512
const SCRIPT_DEPTH: int = 8
const SCRIPT_END: int = -2
const SCRIPT_UNREAD: int = -1
## What a branch is testing: an event flag by index, or one of these.
const SCRIPT_TESTS_CHOICE: int = -1
const SCRIPT_TESTS_NOTHING: int = -2
const SCRIPT_TESTS_CARRY: int = -3
const SCRIPT_TESTS_ITEM: int = -4
const SCRIPT_TESTS_MONEY: int = -5
const SCRIPT_TESTS_COINS: int = -6
## `cp` against the faced direction and the species count the dex holds.
const SCRIPT_TESTS_FACING: int = -7
const SCRIPT_TESTS_DEX: int = -8
## `cp` against the map's tileset and against one `lda_coord` screen position,
## which is how a bookshelf tells a sculpture apart.
const SCRIPT_TESTS_TILESET: int = -9
const SCRIPT_TESTS_TILE: int = -10


## One `text_asm` row's machine code, as the boxes it prints and the branches
## choosing between them. Only the routines the layout names are read, and a
## path reaching anything else is dropped whole rather than kept as a prefix.
## [param known] is what the caller knows already: the argument byte
## `wHiddenEventFunctionArgument` hands a hidden event's own routine.
static func decode_script(
	rom: RomFile, layout: Dictionary, bank: int, at: int, known: Dictionary = {}
) -> Array:
	var walked: Variant = _walk_script(
		{
			"rom": rom, "layout": layout, "bank": bank,
			"budget": [SCRIPT_BUDGET], "calls": [0],
		},
		at, known.duplicate(), 0
	)
	return walked as Array if walked is Array else []


## One straight run and the branch that ends it, or null for a path that does
## not reach `TextScriptEnd`.
static func _walk_script(
	ctx: Dictionary, pc: int, state: Dictionary, depth: int
) -> Variant:
	if depth > SCRIPT_DEPTH:
		return null
	var out: Array = []
	var budget: Array = ctx["budget"]
	while budget[0] > 0:
		budget[0] -= 1
		var op: int = (ctx["rom"] as RomFile).u8(Gen1Layout.banked(int(ctx["bank"]), pc))
		if Gen1Layout.SCRIPT_BRANCHES.has(op) or Gen1Layout.SCRIPT_CARRY_BRANCHES.has(op):
			return _script_branch(ctx, op, pc, state, depth, out)
		if Gen1Layout.SCRIPT_RET_BRANCHES.has(op):
			return _script_ret_branch(ctx, op, pc, state, depth, out)
		var next: int = _script_step(ctx, pc, state, out, depth)
		if next == SCRIPT_END:
			return _script_ended(state, out)
		if next == SCRIPT_UNREAD:
			return null
		pc = next
	return null


## `AfterDisplayingTextID` reads `wDoNotWaitForButtonPress...` once the row is
## done, so the flag belongs to the last box and not to each.
static func _script_ended(state: Dictionary, out: Array) -> Array:
	if bool(state.get("no_press", false)) and not out.is_empty() \
		and String((out[-1] as Dictionary)["op"]) == "text":
		(out[-1] as Dictionary)["press"] = false
	return out


## One instruction: the next address, [constant SCRIPT_END] or SCRIPT_UNREAD.
## The register writes are here and [method _script_flow] has the rest.
static func _script_step(
	ctx: Dictionary, pc: int, state: Dictionary, out: Array, depth: int
) -> int:
	var rom: RomFile = ctx["rom"]
	var at: int = Gen1Layout.banked(int(ctx["bank"]), pc)
	match rom.u8(at):
		Gen1Layout.SCRIPT_LD_HL:
			state["hl"] = rom.u16le(at + 1)
			return pc + Gen1Layout.SCRIPT_LONG_SIZE
		Gen1Layout.SCRIPT_LD_DE:
			state["de"] = rom.u16le(at + 1)
			return pc + Gen1Layout.SCRIPT_LONG_SIZE
		Gen1Layout.SCRIPT_LD_BC:
			## `lb bc, ITEM, COUNT`: the high byte is what `GiveItem` reads as b.
			state["b"] = rom.u8(at + 2)
			state["c"] = rom.u8(at + 1)
			return pc + Gen1Layout.SCRIPT_LONG_SIZE
		Gen1Layout.SCRIPT_LD_B:
			state["b"] = rom.u8(at + 1)
			return pc + Gen1Layout.SCRIPT_SHORT_SIZE
		Gen1Layout.SCRIPT_LD_C:
			state["c"] = rom.u8(at + 1)
			return pc + Gen1Layout.SCRIPT_SHORT_SIZE
		Gen1Layout.SCRIPT_LD_B_A:
			if not state.has("a"):
				return SCRIPT_UNREAD
			state["b"] = int(state["a"])
			return pc + 1
		Gen1Layout.SCRIPT_LD_A:
			_script_wrote_a(state)
			state["a"] = rom.u8(at + 1)
			return pc + Gen1Layout.SCRIPT_SHORT_SIZE
		Gen1Layout.SCRIPT_XOR_A:
			## Zero and a Z the `ld a, 0` above does not raise, so whatever a
			## branch behind it was reading is gone.
			_script_wrote_a(state)
			state["a"] = 0
			state.erase("tests")
			return pc + 1
	return _script_flow(ctx, pc, at, state, out, depth)


## What reads memory, tests it or leaves the instruction after this one.
static func _script_flow(
	ctx: Dictionary, pc: int, at: int, state: Dictionary, out: Array, depth: int
) -> int:
	var rom: RomFile = ctx["rom"]
	match rom.u8(at):
		Gen1Layout.SCRIPT_LD_A_MEM:
			_script_loaded(ctx, rom.u16le(at + 1), state)
			return pc + Gen1Layout.SCRIPT_LONG_SIZE
		Gen1Layout.SCRIPT_LD_MEM_A:
			return pc + Gen1Layout.SCRIPT_LONG_SIZE \
				if _script_stored(ctx, rom.u16le(at + 1), state) else SCRIPT_UNREAD
		Gen1Layout.SCRIPT_LDH_MEM_A:
			return pc + Gen1Layout.SCRIPT_SHORT_SIZE if _script_stored(
				ctx, Gen1Layout.SCRIPT_HRAM_BASE + rom.u8(at + 1), state
			) else SCRIPT_UNREAD
		Gen1Layout.SCRIPT_AND_A:
			_script_test_bit(ctx, state, -1)
			state["tests_and_a"] = true
			return pc + 1
		Gen1Layout.SCRIPT_RRCA:
			return _script_rotated(ctx, pc, state, int(state.get("rotated", 0)))
		Gen1Layout.SCRIPT_ADD_A:
			return _script_rotated(ctx, pc, state, Gen1Layout.SCRIPT_HIGH_BIT)
		Gen1Layout.SCRIPT_CP_N:
			return _script_compared(ctx, pc, state, rom.u8(at + 1))
		Gen1Layout.SCRIPT_AND_N:
			## `CheckEitherEventSet`, whose two flags share a byte and a mask.
			_script_tested(state, _script_mask(ctx, state, rom.u8(at + 1)))
			return pc + Gen1Layout.SCRIPT_SHORT_SIZE
		Gen1Layout.SCRIPT_PREFIX:
			return _script_prefix(ctx, pc, state, out)
		Gen1Layout.SCRIPT_JR:
			return pc + Gen1Layout.SCRIPT_SHORT_SIZE + _script_hop(rom.u8(at + 1))
		Gen1Layout.SCRIPT_JP:
			return _script_jump(ctx, pc, rom.u16le(at + 1), state, out, depth)
		Gen1Layout.SCRIPT_RET:
			return SCRIPT_END
		Gen1Layout.SCRIPT_CALL:
			return _script_call(ctx, pc, rom.u16le(at + 1), state, out, depth)
	if Gen1Layout.SCRIPT_CONDITIONAL_CALLS.has(rom.u8(at)):
		return _script_call_if(ctx, pc, rom.u16le(at + 1), state)
	return SCRIPT_UNREAD


## A conditional `call`, which only a routine spending nothing here may be: both
## sides of `call z, WaitForTextScrollButtonPress` print the same boxes.
static func _script_call_if(
	ctx: Dictionary, pc: int, target: int, state: Dictionary
) -> int:
	if not _script_routine(ctx["layout"], target) in Gen1Layout.SCRIPT_SILENT_CALLS:
		return SCRIPT_UNREAD
	_script_untested(state)
	return pc + Gen1Layout.SCRIPT_LONG_SIZE


## What a branch is reading, and whether it is reading it out of carry.
static func _script_untested(state: Dictionary) -> void:
	for key: String in ["tests", "tests_in_carry", "tests_engine", "tests_and_a"]:
		state.erase(key)


static func _script_tested(
	state: Dictionary, value: Variant, in_carry: bool = false, engine: bool = false
) -> void:
	state["tests"] = value
	state["tests_in_carry"] = in_carry
	state["tests_engine"] = engine
	state.erase("tests_and_a")


## One rotation of `CheckEvent flag, 1`'s run, or `add a` standing for all eight
## of them: the bit that has just landed in carry is the flag being asked about.
static func _script_rotated(
	ctx: Dictionary, pc: int, state: Dictionary, rotated: int
) -> int:
	state["rotated"] = rotated + 1
	_script_test_bit(ctx, state, rotated, true)
	return pc + 1


static func _script_hop(operand: int) -> int:
	return operand - 0x100 if operand > 0x7F else operand


## Anything that writes `a` leaves `CheckEvent`'s rotation and the answer
## `and a` gave about the register behind it.
static func _script_wrote_a(state: Dictionary) -> void:
	state.erase("source")
	state.erase("rotated")
	state.erase("tests_and_a")


## `ld a, [nn]`. `ShowPokedexDataInternal` leaves `wPokedexNum` in
## `wCurPartySpecies`, which the Fighting Dojo's two gifts read the species from.
static func _script_loaded(ctx: Dictionary, address: int, state: Dictionary) -> void:
	_script_wrote_a(state)
	state.erase("a")
	state["source"] = address
	var layout: Dictionary = ctx["layout"]
	if address == int(layout["cur_party_species"]) and state.has("species_index"):
		state["a"] = int(state["species_index"])
	## `wHiddenEventFunctionArgument` is `wWhichTrade`'s own byte.
	if address == int(layout["which_trade"]) and state.has("hidden_argument"):
		state["a"] = int(state["hidden_argument"])


## `jp` reaching `TextScriptEnd`, a routine the layout names, or an address in
## the same bank. A tail call returns where the row's own `ret` would.
static func _script_jump(
	ctx: Dictionary, pc: int, target: int, state: Dictionary, out: Array, depth: int
) -> int:
	var layout: Dictionary = ctx["layout"]
	if target == int(layout["text_script_end"]):
		return SCRIPT_END
	if _script_routine(layout, target).is_empty():
		return target
	return SCRIPT_END if _script_call(ctx, pc, target, state, out, depth) != SCRIPT_UNREAD \
		else SCRIPT_UNREAD


## Which flags `and n` is asking about: the bits of the byte `ld a, [wEventFlags
## + n]` just read, which is what `CheckEitherEventSet` compiles to.
static func _script_mask(ctx: Dictionary, state: Dictionary, mask: int) -> Variant:
	var flags: Array[int] = []
	for bit: int in 8:
		if mask & (1 << bit) == 0:
			continue
		var flag: int = _script_flag(ctx, int(state.get("source", -1)), bit)
		if flag < 0:
			return SCRIPT_TESTS_NOTHING
		flags.append(flag)
	if flags.is_empty():
		return SCRIPT_TESTS_NOTHING
	return flags


## `DisableWaitingAfterTextDisplay` by hand, `RemoveItemByID`'s own item, and
## the map script index a row leaves behind it, which this port has no
## interpreter to hand to and so stores nowhere.
static func _script_stored(ctx: Dictionary, address: int, state: Dictionary) -> bool:
	var layout: Dictionary = ctx["layout"]
	var scripts: int = int(layout["map_scripts"])
	if address == int(layout["cur_map_script"]) \
		or (address >= scripts and address < scripts + Gen1Layout.MAP_SCRIPT_BYTES):
		return true
	if address == int(layout["do_not_wait"]):
		if int(state.get("a", 0)) != 1:
			return false
		state["no_press"] = true
		return true
	if address == int(layout["text_box_id"]):
		if not state.has("a"):
			return false
		state["text_box"] = int(state["a"])
		return true
	if address == int(layout["text_id_hram"]):
		if not state.has("a"):
			return false
		state["map_text"] = int(state["a"])
		return true
	## `Mansion1Script_Switches` blanks the held buttons and `OpenPokemonCenterPC`
	## turns the automatic box off; this port reads nothing out of either.
	if address == int(layout["joy_held"]) \
		or address == int(layout["auto_text_box_control"]):
		return true
	if _script_bcd_stored(ctx, address, state):
		return true
	if address == int(layout["toggleable_index"]):
		if not state.has("a"):
			return false
		state["toggle"] = int(state["a"])
		return true
	if address != int(layout["item_to_remove"]) or int(state.get("a", 0)) < 1:
		return false
	state["remove"] = int(state["a"])
	return true


## What the flags hold, as the index and whether it is one of Generation 1's own
## engine flags rather than a `wEventFlags` bit. [param bit] is -1 for `and a`,
## which only asks whether the whole byte is zero and so names no flag.
static func _script_tests(ctx: Dictionary, state: Dictionary, bit: int) -> Array:
	var layout: Dictionary = ctx["layout"]
	var source: int = int(state.get("source", -1))
	if source == int(layout["current_menu_item"]):
		return [SCRIPT_TESTS_CHOICE, false]
	if bit >= 0:
		var flag: int = _script_flag(ctx, source, bit)
		if flag >= 0:
			return [flag, false]
		var engine: int = _script_engine_flag(ctx, source, bit)
		if engine >= 0:
			return [engine, true]
	return [SCRIPT_TESTS_NOTHING, false]


## Reads what a test is asking about into [param state].
static func _script_test_bit(
	ctx: Dictionary, state: Dictionary, bit: int, in_carry: bool = false
) -> void:
	var tested: Array = _script_tests(ctx, state, bit)
	_script_tested(state, tested[0], in_carry, bool(tested[1]))


## An address in `wEventFlags` and a bit as one flag index, the way
## [method _read_trainer_header] counts one.
static func _script_flag(ctx: Dictionary, address: int, bit: int) -> int:
	var base: int = int((ctx["layout"] as Dictionary)["event_flags"])
	if address < base or address >= base + Gen1Layout.EVENT_FLAG_BYTES:
		return -1
	return (address - base) * 8 + bit


## The same for one of [constant Gen1Layout.ENGINE_FLAG_BYTES], the saved bytes
## outside `wEventFlags` a row reads.
static func _script_engine_flag(ctx: Dictionary, address: int, bit: int) -> int:
	var layout: Dictionary = ctx["layout"]
	for run: String in Gen1Layout.ENGINE_FLAG_BYTES:
		var base: int = int(layout.get(run, -1))
		var width: int = int(Gen1Layout.ENGINE_FLAG_BYTES[run])
		if address < base or address >= base + width:
			continue
		return Gen1Layout.engine_flag_base(run) \
			+ (address - base) * Gen1Layout.ENGINE_FLAG_BITS + bit
	return -1


## `bit b, a` names the flag a branch tests; `set`/`res b, [hl]` writes one.
static func _script_prefix(
	ctx: Dictionary, pc: int, state: Dictionary, out: Array
) -> int:
	var code: int = (ctx["rom"] as RomFile).u8(
		Gen1Layout.banked(int(ctx["bank"]), pc) + 1
	)
	var bit: int = (code >> 3) & 7
	var operand: int = code & 7
	if operand == Gen1Layout.SCRIPT_OPERAND_A \
		and code >= Gen1Layout.SCRIPT_BIT_BASE and code < Gen1Layout.SCRIPT_RES_BASE:
		_script_test_bit(ctx, state, bit)
		return pc + Gen1Layout.SCRIPT_SHORT_SIZE
	if operand != Gen1Layout.SCRIPT_OPERAND_HL or code < Gen1Layout.SCRIPT_RES_BASE:
		return SCRIPT_UNREAD
	var written: int = _script_flag(ctx, int(state.get("hl", -1)), bit)
	var engine: int = _script_engine_flag(ctx, int(state.get("hl", -1)), bit)
	if written < 0 and engine < 0:
		return SCRIPT_UNREAD
	var node: Dictionary = {
		"op": "flag", "flag": written if written >= 0 else engine,
		"set": code >= Gen1Layout.SCRIPT_SET_BASE,
	}
	if written < 0:
		node["engine"] = true
	out.append(node)
	return pc + Gen1Layout.SCRIPT_SHORT_SIZE


## The routines a row may call. No audio driver here, so a cry and the wait
## behind it spend nothing and the walk carries on past them.
static func _script_call(
	ctx: Dictionary, pc: int, target: int, state: Dictionary, out: Array, depth: int
) -> int:
	var layout: Dictionary = ctx["layout"]
	var next: int = pc + Gen1Layout.SCRIPT_LONG_SIZE
	## A routine returns with flags of its own, so a `jr z` behind a call is
	## reading them rather than whatever set them before it.
	_script_untested(state)
	var routine: String = _script_routine(layout, target)
	if routine in Gen1Layout.SCRIPT_SILENT_CALLS:
		return next
	match routine:
		"print_text":
			var box: Dictionary = _script_box(ctx, int(state.get("hl", 0)))
			if box.is_empty():
				return SCRIPT_UNREAD
			out.append(box)
			return next
		"text_script_end":
			return SCRIPT_END
		"disable_waiting":
			state["no_press"] = true
			return next
		"yes_no_choice":
			state["source"] = int(layout["current_menu_item"])
			state.erase("a")
			return next
		"give_item":
			return _script_gift(state, out, next)
		"is_item_in_bag":
			return _script_asked(state, next)
		"bankswitch":
			return _script_far(ctx, state, out, next, depth)
		"predef":
			return _script_predef(ctx, state, out, next)
		"display_pokedex":
			return _script_pokedex(ctx, state, out, next)
		"give_pokemon":
			return _script_gift_pokemon(ctx, state, out, next)
		"has_enough_money":
			return _script_money_asked(state, next)
		"has_enough_coins":
			return _script_coins_asked(state, next)
		"display_text_box":
			return _script_money_box(state, out, next)
		"print_predef_text":
			return _script_predef_text(ctx, state, out, next, depth)
		"display_text_id":
			return _script_map_text(state, out, next)
	if _script_banked_routine(layout, int(ctx["bank"]), target) == "coin_box":
		out.append({"op": "coin_box"})
		return next
	return _script_routine_call(ctx, int(ctx["bank"]), target, state, out, next, depth)


## A `call` to a routine the layout does not name, walked in [param bank] and
## returned from: `MtMoonB2FReceivedFossilText` is an `ld hl` and a tail
## `jp PrintText`, and Yellow keeps 22 rows behind a `callfar`.
static func _script_routine_call(
	ctx: Dictionary, bank: int, target: int, state: Dictionary, out: Array,
	next: int, depth: int
) -> int:
	var nesting: Array = ctx["calls"]
	if nesting[0] >= Gen1Layout.SCRIPT_CALL_DEPTH or bank < 0 or target < 0:
		return SCRIPT_UNREAD
	nesting[0] += 1
	var outer: int = int(ctx["bank"])
	ctx["bank"] = bank
	var walked: Variant = _walk_script(ctx, target, state, depth + 1)
	ctx["bank"] = outer
	nesting[0] -= 1
	if not walked is Array:
		return SCRIPT_UNREAD
	out.append_array(walked as Array)
	return next


static func _script_routine(layout: Dictionary, target: int) -> String:
	for name: String in Gen1Layout.SCRIPT_CALLS:
		if int(layout.get(name, -1)) == target:
			return name
	return ""


static func _script_banked_routine(layout: Dictionary, bank: int, target: int) -> String:
	var at: int = Gen1Layout.banked(bank, target)
	for name: String in Gen1Layout.SCRIPT_BANKED_CALLS:
		if int(layout.get(name, -1)) == at:
			return name
	return ""


## `DisplayPokedex` writes `a` to `wPokedexNum` and opens that page, which is the
## eight Safari Zone signs. The register holds an internal index and the cache
## speaks dex numbers, so it is translated the way an evolution's target is.
static func _script_pokedex(
	ctx: Dictionary, state: Dictionary, out: Array, next: int
) -> int:
	if not state.has("a"):
		return SCRIPT_UNREAD
	var dex: int = Gen1Layout.dex_of_index(ctx["rom"], ctx["layout"], int(state["a"]))
	if dex < 1:
		return SCRIPT_UNREAD
	out.append({"op": "pokedex", "species": dex})
	state["species_index"] = int(state["a"])
	state.erase("a")
	return next


## `GivePokemon` reads the species in b and the level in c and answers in carry,
## which `_GivePokemon` clears only when the party and the box are both full.
## The register holds an internal index; the cache speaks dex numbers.
static func _script_gift_pokemon(
	ctx: Dictionary, state: Dictionary, out: Array, next: int
) -> int:
	if not state.has("b") or not state.has("c") or int(state["c"]) < 1:
		return SCRIPT_UNREAD
	var dex: int = Gen1Layout.dex_of_index(ctx["rom"], ctx["layout"], int(state["b"]))
	if dex < 1:
		return SCRIPT_UNREAD
	out.append({"op": "give_pokemon", "species": dex, "level": int(state["c"])})
	state.erase("b")
	state.erase("c")
	_script_tested(state, SCRIPT_TESTS_CARRY)
	return next


## `GiveItem` reads the item in b and the count in c, answers in carry, drops bc.
static func _script_gift(state: Dictionary, out: Array, next: int) -> int:
	if not state.has("b") or not state.has("c") or int(state["c"]) < 1:
		return SCRIPT_UNREAD
	out.append({"op": "give_item", "item": int(state["b"]), "count": int(state["c"])})
	state.erase("b")
	state.erase("c")
	_script_tested(state, SCRIPT_TESTS_CARRY)
	return next


## `IsItemInBag` reads b and sets zero when the bag does not hold it.
static func _script_asked(state: Dictionary, next: int) -> int:
	if not state.has("b"):
		return SCRIPT_UNREAD
	state["asked"] = int(state["b"])
	state.erase("b")
	_script_tested(state, SCRIPT_TESTS_ITEM)
	return next


## `farcall` is `ld b, BANK`, `ld hl, target`, `call Bankswitch`, and `callfar`
## the same two the other way about.
static func _script_far(
	ctx: Dictionary, state: Dictionary, out: Array, next: int, depth: int
) -> int:
	var layout: Dictionary = ctx["layout"]
	var bank: int = int(state.get("b", -1))
	var target: int = int(state.get("hl", -1))
	if bank != int(layout["remove_item_bank"]) or target != int(layout["remove_item"]):
		return _script_routine_call(ctx, bank, target, state, out, next, depth)
	if int(state.get("remove", 0)) < 1:
		return SCRIPT_UNREAD
	out.append({"op": "take_item", "item": int(state["remove"])})
	state.erase("remove")
	return next


## One byte of `hMoney` or `wPriceTemp`, whose first byte is `wWhichTrade`'s
## own, so a store there is kept as both.
static func _script_bcd_stored(
	ctx: Dictionary, address: int, state: Dictionary
) -> bool:
	var layout: Dictionary = ctx["layout"]
	for name: String in Gen1Layout.SCRIPT_BCD_BUFFERS:
		var base: int = int(layout[name])
		if address < base or address >= base + Gen1Layout.MONEY_BYTES:
			continue
		if not state.has("a"):
			return false
		## Duplicated, because a branch's two sides share this state's values.
		var bytes: Dictionary = (state.get(name, {}) as Dictionary).duplicate()
		bytes[address - base] = int(state["a"])
		state[name] = bytes
		if name == "which_trade" and address == base:
			state["trade"] = int(state["a"])
		return true
	return false


## A run of packed-decimal bytes as a number, -1 until every one is written.
static func _script_bcd_value(
	state: Dictionary, name: String, count: int = Gen1Layout.MONEY_BYTES, first: int = 0
) -> int:
	var bytes: Dictionary = state.get(name, {})
	var value: int = 0
	for index: int in count:
		if not bytes.has(first + index):
			return -1
		var byte: int = int(bytes[first + index])
		value = value * 100 + (byte >> 4) * 10 + (byte & 0xF)
	return value


## `HasEnoughMoney` compares `hMoney` with the player's own three bytes through
## `StringCmp`, which sets carry when the player is short.
static func _script_money_asked(state: Dictionary, next: int) -> int:
	var price: int = _script_bcd_value(state, Gen1Layout.SCRIPT_BCD_BUFFERS[0])
	if price < 1:
		return SCRIPT_UNREAD
	state["price"] = price
	_script_tested(state, SCRIPT_TESTS_MONEY, true)
	return next


## `HasEnoughCoins` is `StringCmp` over `hCoins`: `Has9990Coins` behind a `jr nc` is a full coin
## case, and `GameCornerGentlemanText`'s `jr z` an exact 9990.
static func _script_coins_asked(state: Dictionary, next: int) -> int:
	var coins: int = _script_bcd_value(
		state, Gen1Layout.SCRIPT_BCD_BUFFERS[0],
		Gen1Layout.COIN_BYTES, Gen1Layout.COIN_BUFFER_AT
	)
	if coins < 1:
		return SCRIPT_UNREAD
	state["coins"] = coins
	_script_tested(state, SCRIPT_TESTS_COINS)
	return next


## `DisplayMoneyBox` draws the balance over the map and returns, and MONEY_BOX
## is the only `wTextBoxID` a text row writes.
static func _script_money_box(state: Dictionary, out: Array, next: int) -> int:
	if int(state.get("text_box", -1)) != Gen1Layout.MONEY_BOX_ID:
		return SCRIPT_UNREAD
	out.append({"op": "money_box"})
	return next


## `predef SubBCDPredef` with `wPlayerMoney + 2` in de and three in c.
static func _script_spend(
	ctx: Dictionary, state: Dictionary, out: Array, next: int
) -> int:
	var layout: Dictionary = ctx["layout"]
	var last: int = Gen1Layout.MONEY_BYTES - 1
	if int(state.get("de", -1)) != int(layout["player_money"]) + last \
		or int(state.get("c", -1)) != Gen1Layout.MONEY_BYTES:
		return SCRIPT_UNREAD
	for name: String in Gen1Layout.SCRIPT_BCD_BUFFERS:
		if int(state.get("hl", -1)) != int(layout[name]) + last:
			continue
		var amount: int = _script_bcd_value(state, name)
		if amount < 1:
			return SCRIPT_UNREAD
		out.append({"op": "spend_money", "amount": amount})
		return next
	return SCRIPT_UNREAD


## `predef AddBCDPredef` with `wPlayerCoins + 1` in de and two in c; the Day-Care's own sum is not.
static func _script_add_coins(
	ctx: Dictionary, state: Dictionary, out: Array, next: int
) -> int:
	var layout: Dictionary = ctx["layout"]
	if int(state.get("de", -1)) != int(layout["player_coins"]) + Gen1Layout.COIN_BYTES - 1 \
		or int(state.get("c", -1)) != Gen1Layout.COIN_BYTES:
		return SCRIPT_UNREAD
	var amount: int = _script_bcd_value(
		state, Gen1Layout.SCRIPT_BCD_BUFFERS[0],
		Gen1Layout.COIN_BYTES, Gen1Layout.COIN_BUFFER_AT
	)
	if amount < 1:
		return SCRIPT_UNREAD
	out.append({"op": "add_coins", "amount": amount})
	return next


## `predef` is `ld a, id` and `call Predef`; `PredefPointers` is the bank and
## address that id names. `ShowObject2` shares `ShowObject`'s address, so
## resolving the address rather than the id reads both.
static func _script_predef(
	ctx: Dictionary, state: Dictionary, out: Array, next: int
) -> int:
	var layout: Dictionary = ctx["layout"]
	var id: int = int(state.get("a", -1))
	if id < 0:
		return SCRIPT_UNREAD
	var rom: RomFile = ctx["rom"]
	var row: int = int(layout["predef_pointers"]) + id * Gen1Layout.PREDEF_SIZE
	var target: int = Gen1Layout.banked(rom.u8(row), rom.u16le(row + 1))
	if target == int(layout["pick_up_item"]):
		out.append({"op": "pick_up_item"})
		return next
	if target == int(layout["sub_bcd"]):
		return _script_spend(ctx, state, out, next)
	if target == int(layout["add_bcd"]):
		return _script_add_coins(ctx, state, out, next)
	if target == int(layout["in_game_trade"]):
		if not state.has("trade"):
			return SCRIPT_UNREAD
		out.append({"op": "trade", "trade_id": int(state["trade"])})
		state.erase("trade")
		return next
	var hidden: bool = target == int(layout["hide_object"])
	if not state.has("toggle") \
		or (not hidden and target != int(layout["show_object"])):
		return SCRIPT_UNREAD
	out.append({"op": "toggle_object", "index": int(state["toggle"]), "hidden": hidden})
	state.erase("toggle")
	return next


## One `PrintText` box, empty when the pointer does not decode to a string.
static func _script_box(ctx: Dictionary, pointer: int) -> Dictionary:
	var decoded: Dictionary = Gen1Text.decode_stream(
		ctx["rom"], Gen1Layout.banked(int(ctx["bank"]), pointer)
	)
	if not bool(decoded.get("ok", false)) or String(decoded["text"]).is_empty():
		return {}
	return {"op": "text", "text": String(decoded["text"])}


## A conditional, walked both ways. A side reaching machine code this decoder
## does not read becomes an `unknown` node, so an interaction taking that side
## says nothing at all, as an undecoded row does.
static func _script_branch(
	ctx: Dictionary, op: int, pc: int, state: Dictionary, depth: int, out: Array
) -> Variant:
	var tests: Variant = state.get("tests", SCRIPT_TESTS_NOTHING)
	var carry: bool = Gen1Layout.SCRIPT_CARRY_BRANCHES.has(op)
	if not _script_reads_flag(state, tests, carry):
		return null
	var rom: RomFile = ctx["rom"]
	var at: int = Gen1Layout.banked(int(ctx["bank"]), pc)
	var short: bool = op < Gen1Layout.SCRIPT_HOP_LIMIT
	var size: int = Gen1Layout.SCRIPT_SHORT_SIZE if short else Gen1Layout.SCRIPT_LONG_SIZE
	var jumped: int = pc + size + _script_hop(rom.u8(at + 1)) if short else rom.u16le(at + 1)
	var table: Dictionary = Gen1Layout.SCRIPT_CARRY_BRANCHES if carry \
		else Gen1Layout.SCRIPT_BRANCHES
	var jumped_state: Dictionary = state.duplicate()
	var fell_state: Dictionary = state.duplicate()
	if bool(state.get("tests_and_a", false)):
		## `and a` leaves `a` where it was and raises Z only when it is zero, so
		## the side a `jp nz` does not take knows the register is zero.
		var zero: Dictionary = fell_state if bool(table[op]) else jumped_state
		zero["a"] = 0
	var branches: Array = [
		_walk_script(ctx, jumped, jumped_state, depth + 1),
		_walk_script(ctx, pc + size, fell_state, depth + 1),
	]
	if not bool(table[op]):
		branches.reverse()
	if branches[0] == null and branches[1] == null:
		return null
	var node: Variant = _script_node(tests, branches, state, out, carry)
	if node == null:
		return null
	out.append(node)
	return out


## A conditional `ret`, which a wrong facing is refused with: the side that
## returns prints nothing and the other carries on behind it.
static func _script_ret_branch(
	ctx: Dictionary, op: int, pc: int, state: Dictionary, depth: int, out: Array
) -> Variant:
	var tests: Variant = state.get("tests", SCRIPT_TESTS_NOTHING)
	if not _script_reads_flag(state, tests, false):
		return null
	var walked: Variant = _walk_script(ctx, pc + 1, state.duplicate(), depth + 1)
	if walked == null:
		return null
	var branches: Array = [[], walked]
	if not bool(Gen1Layout.SCRIPT_RET_BRANCHES[op]):
		branches.reverse()
	var node: Variant = _script_node(tests, branches, state, out, false)
	if node == null:
		return null
	out.append(node)
	return out


## `cp n` against the faced direction, the species count `CountSetBits` left,
## the map's tileset or one screen position; anything else ends the path.
static func _script_compared(
	ctx: Dictionary, pc: int, state: Dictionary, value: int
) -> int:
	var layout: Dictionary = ctx["layout"]
	var source: int = int(state.get("source", -1))
	var next: int = pc + Gen1Layout.SCRIPT_SHORT_SIZE
	if source == int(layout["facing_direction"]):
		state["facing"] = value
		_script_tested(state, SCRIPT_TESTS_FACING)
		return next
	if source == int(layout["cur_map_tileset"]):
		state["tileset"] = value
		_script_tested(state, SCRIPT_TESTS_TILESET)
		return next
	var screen: int = source - int(layout["tile_map"])
	if screen >= 0 and screen < Gen1Layout.SCREEN_WIDTH_TILES * Gen1Layout.SCREEN_HEIGHT_TILES:
		state["screen"] = screen
		state["tile"] = value
		_script_tested(state, SCRIPT_TESTS_TILE)
		return next
	if source != int(layout["num_set_bits"]):
		return SCRIPT_UNREAD
	state["dex_count"] = value
	_script_tested(state, SCRIPT_TESTS_DEX, true)
	return next


## `PrintPredefTextID`: `TextPredefs` counts from 1 and a row is read in the
## bank the routine that named it runs in.
static func _script_predef_text(
	ctx: Dictionary, state: Dictionary, out: Array, next: int, depth: int
) -> int:
	var rom: RomFile = ctx["rom"]
	var id: int = int(state.get("a", 0))
	if id < 1 or id > Gen1Layout.text_predef_count(rom.id):
		return SCRIPT_UNREAD
	var pointer: int = rom.u16le(
		int((ctx["layout"] as Dictionary)["text_predefs"])
		+ (id - 1) * Gen1Layout.TEXT_PREDEF_SIZE
	)
	state.erase("a")
	return next if _script_text_row(ctx, pointer, state, out, depth) else SCRIPT_UNREAD


## One text pointer in the walk's own bank: the box it prints, the facility it
## opens instead, and the machine code a `text_asm` behind it runs.
static func _script_text_row(
	ctx: Dictionary, pointer: int, state: Dictionary, out: Array, depth: int
) -> bool:
	var rom: RomFile = ctx["rom"]
	var at: int = Gen1Layout.banked(int(ctx["bank"]), pointer)
	var decoded: Dictionary = Gen1Text.decode_stream(rom, at)
	if not bool(decoded.get("ok", false)):
		if String(decoded.get("reason", "")) != "text_script":
			return false
		out.append({"op": "facility", "command": int(decoded["command"])})
		return true
	if not String(decoded["text"]).is_empty():
		out.append({"op": "text", "text": String(decoded["text"])})
	var code: int = _text_code_at(decoded)
	if code < 0:
		return true
	var walked: Variant = _walk_script(ctx, code, state, depth + 1)
	if not walked is Array:
		return false
	out.append_array(walked as Array)
	return true


## `ldh [hTextID], a` and `jp DisplayTextID`: one of the map's own text rows.
static func _script_map_text(state: Dictionary, out: Array, next: int) -> int:
	if not state.has("map_text"):
		return SCRIPT_UNREAD
	out.append({"op": "map_text", "text": int(state["map_text"])})
	state.erase("map_text")
	return next


## Whether the flag this branch reads is the one the test left: a flag index is in Z alone.
static func _script_reads_flag(state: Dictionary, tests: Variant, carry: bool) -> bool:
	if tests is Array:
		return not carry
	if int(tests) == SCRIPT_TESTS_COINS:
		return true
	if int(tests) == SCRIPT_TESTS_NOTHING:
		return false
	return carry == (
		int(tests) == SCRIPT_TESTS_CARRY or bool(state.get("tests_in_carry", false))
	)


## `wCurrentMenuItem` is 0 for YES, so the branch taken when it is not zero is
## NO. Every other test reads the other way about: the taken side is the set
## one, a set carry or an item the bag holds.
static func _script_node(
	tests: Variant, branches: Array, state: Dictionary, out: Array, carry: bool
) -> Variant:
	var taken: Array = branches[0] if branches[0] != null else [{"op": "unknown"}]
	var fell: Array = branches[1] if branches[1] != null else [{"op": "unknown"}]
	if tests is Array:
		return {"op": "branch", "flag": int((tests as Array)[0]),
			"either": (tests as Array).slice(1), "then": taken, "else": fell}
	match int(tests):
		SCRIPT_TESTS_CHOICE:
			return {"op": "choice", "no": taken, "yes": fell}
		SCRIPT_TESTS_CARRY:
			return _script_receipt(out, taken, fell)
		SCRIPT_TESTS_ITEM:
			return {"op": "has_item", "item": int(state["asked"]),
				"then": taken, "else": fell}
		SCRIPT_TESTS_MONEY:
			## Carry is set when the player is short, so the taken side of a
			## `jr c` is the refusal and the other one is the sale.
			return {"op": "has_money", "price": int(state["price"]),
				"then": fell, "else": taken}
		SCRIPT_TESTS_COINS:
			return {"op": "has_coins", "coins": int(state["coins"]),
				"test": "at_least" if carry else "exactly",
				"then": fell, "else": taken}
		SCRIPT_TESTS_FACING:
			## `cp` raises Z on a match, so a `ret nz` leaves the right side.
			return {"op": "facing", "facing": int(state["facing"]),
				"then": fell, "else": taken}
		SCRIPT_TESTS_DEX:
			## Carry is set below the count, so the taken side owns fewer.
			return {"op": "dex_count", "count": int(state["dex_count"]),
				"then": fell, "else": taken}
		SCRIPT_TESTS_TILESET:
			return {"op": "tileset", "tileset": int(state["tileset"]),
				"then": fell, "else": taken}
		SCRIPT_TESTS_TILE:
			return {"op": "screen_tile", "screen": int(state["screen"]),
				"tile": int(state["tile"]), "then": fell, "else": taken}
	var branch: Dictionary = {
		"op": "branch", "flag": int(tests), "then": taken, "else": fell,
	}
	if bool(state.get("tests_engine", false)):
		branch["engine"] = true
	return branch


## The carry belongs to the gift in front of it, so both sides fold onto it.
static func _script_receipt(out: Array, taken: Array, fell: Array) -> Variant:
	if out.is_empty() or String((out[-1] as Dictionary)["op"]) not in GIFT_OPS:
		return null
	var gift: Dictionary = out.pop_back()
	gift["ok"] = taken
	gift["full"] = fell
	return gift


## One `trainer` row. `TrainerFlagAction` counts the bit off the address two
## bytes in, so the flag is that address's distance from `wEventFlags` in bits
## plus the stored bit.
static func _read_trainer_header(
	rom: RomFile, layout: Dictionary, bank: int, at: int
) -> Dictionary:
	var offsets: Dictionary = Gen1Layout.TRAINER_HEADER_AT
	var flag_address: int = rom.u16le(at + int(offsets["flag_address"]))
	var out: Dictionary = {
		"event_flag": (flag_address - int(layout["event_flags"])) * 8
			+ rom.u8(at + int(offsets["flag_bit"])),
		"sight_range": rom.u8(at + int(offsets["range"])) >> Gen1Layout.TRAINER_RANGE_SHIFT,
	}
	for name: String in ["before", "after", "end"]:
		out[name] = _read_trainer_text(
			rom, layout, bank, rom.u16le(at + int(offsets[name]))
		)
	return out


## One of a header's three texts. `RocketHideoutB4FRocket3AfterBattleText` is
## the corpus's one that is machine code, and says its `PrintText` operand.
static func _read_trainer_text(
	rom: RomFile, layout: Dictionary, bank: int, pointer: int
) -> String:
	var at: int = Gen1Layout.banked(bank, pointer)
	var printed: int = _asm_operand(rom, bank, at, int(layout["print_text"]))
	var decoded: Dictionary = Gen1Text.decode_stream(rom, at if printed < 0 else printed)
	return String(decoded["text"]) if bool(decoded.get("ok", false)) else ""


## `script_mart`'s inline list, which `LoadItemList` copies straight out of the
## text pointer. A count past `wItemList` is not a shop at all.
static func _read_mart_items(rom: RomFile, at: int) -> Array:
	var count: int = rom.u8(at + Gen1Layout.MART_COUNT_AT)
	if count < 1 or count > Gen1Layout.MART_MAX_ITEMS:
		return []
	var out: Array = []
	for slot: int in count:
		var item: int = rom.u8(at + Gen1Layout.MART_ITEMS_AT + slot)
		if item < 1:
			return []
		out.append(item)
	return out


static func _highest_text_id(events: Dictionary) -> int:
	var highest: int = 0
	for kind: String in ["bg_events", "objects"]:
		for event: Dictionary in events.get(kind, []) as Array:
			highest = maxi(highest, int(event.get("text", 0)))
	return highest


static func _object_extra_bytes(text: int) -> int:
	if (text & Gen1Layout.OBJECT_TRAINER_FLAG) != 0:
		return Gen1Layout.OBJECT_TRAINER_BYTES
	if (text & Gen1Layout.OBJECT_ITEM_FLAG) != 0:
		return Gen1Layout.OBJECT_ITEM_BYTES
	return 0
