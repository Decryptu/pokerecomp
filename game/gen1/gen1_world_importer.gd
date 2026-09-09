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

## The gate's own two prefixed opcodes, and how many `push hl` it may hold a
## copy of `hl` through.
const MAP_LOAD_PREFIXES: Array[int] = [
	Gen1Layout.SCRIPT_BIT_BASE, Gen1Layout.SCRIPT_RES_BASE,
]
const MAP_LOAD_HELD_LIMIT: int = 4
## `ld hl, .GateCoordinates` and the two card key calls behind it.
const CARD_KEY_PROLOGUE_SIZE: int = 3 * Gen1Layout.SCRIPT_LONG_SIZE
## Where a map header keeps its script pointer.
const MAP_SCRIPT_AT: int = 7
## `jr nz, .fellDownHoleTo1F` hops the one `ld a, n` behind it, and how far past
## the call the pick may sit.
const DUNGEON_PICK_BRANCH: int = 0x20
const DUNGEON_PICK_HOP: int = 2
const DUNGEON_PICK_WINDOW: int = 32


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
	var card_key_floors: PackedByteArray = _read_list(
		rom, int(layout["silph_map_list"]), Gen1Layout.SILPH_MAP_LIST_MAX
	)
	var map_count: int = Gen1Layout.map_count(rom.id)
	var script_ends: Dictionary = _script_ends(rom, layout, map_count)
	for map_id: int in map_count:
		if not Gen1Layout.is_real_map(map_id):
			continue
		var map: Dictionary = _read_map(
			rom, layout, tilesets, map_id, card_key_floors, int(script_ends[map_id])
		)
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


## `LoadMonPartySpriteGfx`: every row into one strip, read back as each icon's
## two frames. `MonPartyData` names one icon per dex number, two nybbles a byte.
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
	var bike: Dictionary = _read_bike_sprite(rom, sprites)
	if not bool(bike["ok"]):
		return bike
	sprites.append(bike["sprite"])
	graphics[int((bike["sprite"] as Dictionary)["number"])] = bike["pixels"]
	return {"ok": true, "sprites": sprites, "graphics": graphics}


## `RedBikeSprite`, which the table names no row for. See [constant
## Gen1Layout.SPRITE_BIKE_BYTES] for where it stands and why it is derived.
static func _read_bike_sprite(rom: RomFile, sprites: Array) -> Dictionary:
	var player: Dictionary = sprites[Gen2WorldSprite.SPRITE_PLAYER - 1]
	var address: int = int(player["address"]) - Gen1Layout.SPRITE_BIKE_BYTES
	if address < RomFile.BANK_SIZE:
		return _error("RedBikeSprite would start at $%04X." % address)
	var tiles: int = Gen1Layout.SPRITE_WALKING_TILES * 2
	var raw: PackedByteArray = rom.slice(
		RomFile.linear(int(player["bank"]), address), Gen1Layout.SPRITE_BIKE_BYTES
	)
	if raw.size() != Gen1Layout.SPRITE_BIKE_BYTES:
		return _error("RedBikeSprite's graphics are truncated.")
	return {
		"ok": true,
		"pixels": PokeTiles.decode_2bpp_strip(raw, 0, tiles),
		"sprite": {
			"number": Gen1Layout.bike_sprite(rom.id),
			"address": address,
			"bank": int(player["bank"]),
			"bytes": Gen1Layout.SPRITE_BIKE_BYTES,
			"tiles": tiles,
			"type": Gen2WorldSprite.TYPE_WALKING,
			"palette": 0,
		},
	}


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
	rom: RomFile, layout: Dictionary, tilesets: Array, map_id: int,
	card_key_floors: PackedByteArray, script_end: int
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
	var callback: Dictionary = _read_map_callback(
		rom, layout, bank, rom.u16le(header + MAP_SCRIPT_AT), card_key_floors.has(map_id)
	)
	var states: Dictionary = _read_map_states(
		rom, layout, bank, rom.u16le(header + MAP_SCRIPT_AT), texts
	)
	## A row the table grew by may reach one higher still, which is how the
	## Safari Zone gate's own six are read rather than its first four.
	while _extend_texts(rom, layout, bank, rom.u16le(header + 5), texts, events, callback, states):
		states = _read_map_states(
			rom, layout, bank, rom.u16le(header + MAP_SCRIPT_AT), texts
		)
	var hidden: Array = _read_hidden_events(
		rom, layout, map_id, bank, rom.u16le(header + MAP_SCRIPT_AT)
	)
	for nodes: Array in [callback.get("nodes", []) as Array] \
		+ hidden.map(func(row: Dictionary) -> Array: return row.get("script", []) as Array):
		_bind_map_script_byte(nodes, int(states["byte"]))

	return {
		"ok": true,
		"group": 0,
		"number": map_id,
		"tileset": tileset_number,
		"music": rom.u8(Gen1Layout.map_song_offset(layout, map_id)),
		"music_bank": rom.u8(Gen1Layout.map_song_offset(layout, map_id) + 1),
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
			"address": rom.u16le(header + MAP_SCRIPT_AT),
			"scenes": [],
			"callbacks": [] if callback.is_empty() else [callback],
			"entry": states["entry"],
			"states": states["states"],
		},
		"texts": texts,
		"alternate_texts": _alternate_texts(rom, layout, bank, states, events),
		"movement_scripts": _movement_scripts(rom, layout, map_id),
		"events": {
			"bank": bank,
			"address": rom.u16le(object_address),
			"warps": events["warps"],
			"coord_events": [],
			"bg_events": events["bg_events"],
			"objects": events["objects"],
			"hidden_events": hidden,
			"card_key": _card_key_doors(callback),
			"dungeon_holes": _read_dungeon_holes(
				rom, layout, bank, rom.u16le(header + MAP_SCRIPT_AT), script_end
			),
		},
	}


static func _alternate_texts(
	rom: RomFile, layout: Dictionary, bank: int, states: Dictionary, events: Dictionary
) -> Dictionary:
	var out: Dictionary = {}
	for table: int in _text_tables(states["entry"] as Array):
		out[str(table)] = _read_texts(rom, layout, bank, table, events)
	return out


static func _text_tables(nodes: Array) -> Array[int]:
	var out: Array[int] = []
	for node: Dictionary in nodes:
		if String(node["op"]) == "text_table":
			out.append(int(node["table"]))
		for key: String in Gen1Layout.SCRIPT_BRANCH_KEYS:
			if node.has(key):
				out.append_array(_text_tables(node[key] as Array))
	return out


## `DecodeRLEList` fills the player's buffer from its low end and
## `GetSimulatedInput` spends it from the high one, so those legs are reversed.
static func _movement_scripts(rom: RomFile, layout: Dictionary, map_id: int) -> Dictionary:
	var out: Dictionary = {}
	var tables: Dictionary = Gen1Layout.MOVEMENT_SCRIPT_LISTS.get(map_id, {})
	for table: int in tables:
		var keys: Array = tables[table]
		var player: Array = []
		for pair: Array in _rle_pairs(rom, int(layout[keys[0]])):
			if Gen1Layout.PAD_DIRECTIONS.has(int(pair[0])):
				player.push_front({
					"direction": int(Gen1Layout.PAD_DIRECTIONS[int(pair[0])]), "steps": int(pair[1]),
				})
		var object: Array = []
		for pair: Array in _rle_pairs(rom, int(layout[keys[1]])):
			if int(pair[0]) & Gen1Layout.NPC_MOVEMENT_LOW_BITS != 0:
				continue
			for _step: int in int(pair[1]):
				object.append(int(pair[0]) >> Gen1Layout.NPC_MOVEMENT_SHIFT)
		out[str(table)] = {"player": player, "object": object}
	return out


static func _rle_pairs(rom: RomFile, at: int) -> Array:
	var pairs: Array = []
	while rom.in_bounds(at, Gen1Layout.RLE_PAIR_SIZE) and rom.u8(at) != Gen1Layout.RLE_END \
		and pairs.size() < Gen1Layout.SIMULATED_JOYPAD_MAX:
		pairs.append([rom.u8(at), rom.u8(at + 1)])
		at += Gen1Layout.RLE_PAIR_SIZE
	return pairs


## Where each map's script stops: the next script start in the same bank, or the
## bank's end. A map's own tables sit behind its script in the file they share.
static func _script_ends(rom: RomFile, layout: Dictionary, map_count: int) -> Dictionary:
	var banks: Dictionary = {}
	for map_id: int in map_count:
		if not Gen1Layout.is_real_map(map_id):
			continue
		var bank: int = Gen1Layout.map_bank(rom, layout, map_id)
		var rows: Array = banks.get(bank, [])
		rows.append([
			rom.u16le(Gen1Layout.map_header_offset(rom, layout, map_id) + MAP_SCRIPT_AT),
			map_id,
		])
		banks[bank] = rows
	var out: Dictionary = {}
	for bank: int in banks:
		var rows: Array = banks[bank]
		rows.sort()
		for index: int in rows.size():
			out[int((rows[index] as Array)[1])] = 2 * RomFile.BANK_SIZE \
				if index + 1 == rows.size() else int((rows[index + 1] as Array)[0])
	return out


## `RunMapScript` jumps to the map's own script every frame: what stands in
## front of `CallFunctionInTable` runs each time and the table behind it holds
## one body per state. No row records that table's length, so the states kept
## are the reachable ones: index 0, and whatever a `set_map_script` names.
static func _read_map_states(
	rom: RomFile, layout: Dictionary, bank: int, script: int, texts: Array
) -> Dictionary:
	var entry: Array = decode_script(rom, layout, bank, script)
	var dispatch: Dictionary = _map_script_dispatch(entry)
	if dispatch.is_empty():
		return {"entry": entry, "states": [], "byte": MAP_SCRIPT_MIRROR}
	var byte: int = int(dispatch["byte"])
	var bodies: Array = _map_script_bodies(rom, layout, bank, int(dispatch["table"]))
	_bind_map_script_byte(entry, byte)
	var pending: Array[int] = _map_script_successors(entry, byte)
	for row: Dictionary in texts:
		_bind_map_script_byte(row.get("script", []) as Array, byte)
		pending.append_array(_map_script_successors(row.get("script", []) as Array, byte))
	pending.append(0)
	var reached: Dictionary = {}
	while not pending.is_empty():
		var index: int = pending.pop_back()
		if reached.has(index) or index < 0 or index >= bodies.size():
			continue
		reached[index] = true
		if bodies[index] != null:
			_bind_map_script_byte(bodies[index] as Array, byte)
			pending.append_array(_map_script_successors(bodies[index] as Array, byte))
	var rows: Array = []
	for index: int in bodies.size():
		if reached.has(index) and bodies[index] != null:
			rows.append({"id": index, "nodes": bodies[index]})
	return {"entry": entry, "states": rows, "byte": byte}


## Every body of one `<Map>_ScriptPointers` table, read while the word addresses
## the cartridge; null is a body the walk did not get whole.
static func _map_script_bodies(
	rom: RomFile, layout: Dictionary, bank: int, table: int
) -> Array:
	var bodies: Array = []
	while bodies.size() < Gen1Layout.MAP_SCRIPT_STATES:
		var target: int = rom.u16le(
			Gen1Layout.banked(bank, table + bodies.size() * Gen1Layout.POINTER_SIZE)
		)
		if target < Gen1Layout.SCRIPT_LOWEST or target >= Gen1Layout.SCRIPT_CEILING:
			break
		bodies.append(_walk_script(
			{
				"rom": rom, "layout": layout, "bank": bank,
				"budget": [SCRIPT_BUDGET], "calls": [0],
			},
			target, {}, 0
		))
	return bodies


## The dispatch node, which a branch above it puts on both of its sides.
static func _map_script_dispatch(nodes: Array) -> Dictionary:
	for node: Dictionary in nodes:
		if String(node["op"]) == "map_script_table":
			return node
		for key: String in Gen1Layout.SCRIPT_BRANCH_KEYS:
			if not node.has(key):
				continue
			var found: Dictionary = _map_script_dispatch(node[key] as Array)
			if not found.is_empty():
				return found
	return {}


static func _map_script_successors(nodes: Array, byte: int) -> Array[int]:
	var out: Array[int] = []
	for node: Dictionary in nodes:
		## `wNextSafariZoneGateScript` stores a byte read back, not a constant.
		if String(node["op"]) == "set_map_script" and int(node["byte"]) == byte \
			and node.has("value"):
			out.append(int(node["value"]))
		for key: String in Gen1Layout.SCRIPT_BRANCH_KEYS:
			if node.has(key):
				out.append_array(_map_script_successors(node[key] as Array, byte))
	return out


## `IsPlayerOnDungeonWarp` and Pokemon Mansion 3F's copy of it both open
## `xor a` / `ld [wWhichDungeonWarp], a`, which the `ld hl, <coords>` is found by.
static func _read_dungeon_holes(
	rom: RomFile, layout: Dictionary, bank: int, script: int, script_end: int
) -> Array:
	for pc: int in range(script, script_end - 2 * Gen1Layout.SCRIPT_LONG_SIZE):
		var at: int = Gen1Layout.banked(bank, pc)
		if rom.u8(at) != Gen1Layout.SCRIPT_LD_HL \
			or rom.u8(at + Gen1Layout.SCRIPT_LONG_SIZE) not in [
				Gen1Layout.SCRIPT_JP, Gen1Layout.SCRIPT_CALL,
			]:
			continue
		var routine: int = Gen1Layout.banked(
			bank, rom.u16le(at + Gen1Layout.SCRIPT_LONG_SIZE + 1)
		)
		if rom.u8(routine) != Gen1Layout.SCRIPT_XOR_A \
			or rom.u8(routine + 1) != Gen1Layout.SCRIPT_LD_MEM_A \
			or rom.u16le(routine + 2) != int(layout["which_dungeon_warp"]):
			continue
		return _dungeon_holes(
			rom, layout, bank, rom.u16le(at + 1), pc, pc + 2 * Gen1Layout.SCRIPT_LONG_SIZE
		)
	return []


## The `dbmapcoord` list itself, each row carrying the map its own index falls to.
static func _dungeon_holes(
	rom: RomFile, layout: Dictionary, bank: int, coords: int, block: int, behind: int
) -> Array:
	var maps: Dictionary = _dungeon_destinations(rom, layout, bank, block, behind)
	var out: Array = []
	var at: int = Gen1Layout.banked(bank, coords)
	while rom.u8(at) != Gen1Layout.MAP_COORD_END:
		var index: int = out.size() + 1
		out.append({
			"y": rom.u8(at),
			"x": rom.u8(at + 1),
			"destination": int(maps.get(index, maps.get(0, -1))),
		})
		at += Gen1Layout.MAP_COORD_SIZE
	return out


## Which map each hole index falls to. Five maps write one in front of the block,
## which is key 0; Pokemon Mansion 3F picks by index behind the call, which is
## `.fellDownHoleTo1F`'s `cp n` / `ld a, m1` / `jr nz, +2` / `ld a, m2`.
static func _dungeon_destinations(
	rom: RomFile, layout: Dictionary, bank: int, block: int, behind: int
) -> Dictionary:
	var store: int = int(layout["dungeon_warp_destination"])
	var ahead: int = Gen1Layout.banked(bank, block) - Gen1Layout.SCRIPT_LONG_SIZE \
		- Gen1Layout.SCRIPT_SHORT_SIZE
	if rom.u8(ahead) == Gen1Layout.SCRIPT_LD_A \
		and rom.u8(ahead + 2) == Gen1Layout.SCRIPT_LD_MEM_A \
		and rom.u16le(ahead + 3) == store:
		return {0: rom.u8(ahead + 1)}
	for pc: int in range(behind, behind + DUNGEON_PICK_WINDOW):
		var at: int = Gen1Layout.banked(bank, pc)
		if rom.u8(at) != Gen1Layout.SCRIPT_CP_N \
			or rom.u8(at + 2) != Gen1Layout.SCRIPT_LD_A \
			or rom.u8(at + 4) != DUNGEON_PICK_BRANCH \
			or rom.u8(at + 5) != DUNGEON_PICK_HOP \
			or rom.u8(at + 6) != Gen1Layout.SCRIPT_LD_A \
			or rom.u8(at + 8) != Gen1Layout.SCRIPT_LD_MEM_A \
			or rom.u16le(at + 9) != store:
			continue
		return {0: rom.u8(at + 3), rom.u8(at + 1): rom.u8(at + 7)}
	return {}


## `RunMapScript` runs the whole of a map's script every frame, so the work a map
## does once is the body behind a `wCurrentMapScriptFlags` bit, decoded the way
## a `text_asm` row is. [method _read_map_states] reads the rest.
static func _read_map_callback(
	rom: RomFile, layout: Dictionary, bank: int, script: int, card_key: bool
) -> Dictionary:
	var body: int = _map_load_gate(rom, layout, bank, script)
	if body < 0:
		return {}
	var coordinates: Array = _card_key_coordinates(rom, bank, body) if card_key else []
	if not coordinates.is_empty():
		body += CARD_KEY_PROLOGUE_SIZE
	var nodes: Array = decode_script(rom, layout, bank, body)
	var calls: Array[int] = _map_load_calls(rom, layout, bank, script)
	if not calls.is_empty():
		nodes = []
		for target: int in calls:
			nodes.append_array(decode_script(rom, layout, bank, target))
	return {"nodes": nodes, "coordinates": coordinates}


static func _map_load_calls(rom: RomFile, layout: Dictionary, bank: int, script: int) -> Array[int]:
	var at: int = Gen1Layout.banked(bank, script)
	if rom.u8(at) == Gen1Layout.SCRIPT_CALL:
		at = Gen1Layout.banked(bank, rom.u16le(at + 1))
	var calls: Array[int] = []
	if rom.u8(at) != Gen1Layout.SCRIPT_LD_HL or rom.u16le(at + 1) != int(layout["map_script_flags"]):
		return calls
	at += 3
	var loaded: bool = false
	for _step: int in 16:
		var op: int = rom.u8(at)
		if op == Gen1Layout.SCRIPT_PREFIX:
			var code: int = rom.u8(at + 1)
			if (code & 7) != Gen1Layout.SCRIPT_OPERAND_HL:
				break
			if code < Gen1Layout.SCRIPT_RES_BASE:
				loaded = ((code - Gen1Layout.SCRIPT_BIT_BASE) / 8) in [5, 6]
			at += 2
		elif Gen1Layout.SCRIPT_STACK_HL.has(op):
			at += 1
		elif op in [0xC4, 0xCC]:
			if loaded == (op == 0xC4):
				calls.append(rom.u16le(at + 1))
			at += 3
		else:
			break
	return calls


static func _map_load_gate(rom: RomFile, layout: Dictionary, bank: int, at: int) -> int:
	var body: int = _map_load_body(rom, layout, bank, at)
	if body >= 0:
		return body
	var entry: int = Gen1Layout.banked(bank, at)
	if not rom.in_bounds(entry, Gen1Layout.SCRIPT_LONG_SIZE) \
		or rom.u8(entry) != Gen1Layout.SCRIPT_CALL:
		return -1
	return _map_load_body(rom, layout, bank, rom.u16le(entry + 1))


## `ld hl, wCurrentMapScriptFlags`, `bit`, `res` and the branch under them. -1
## when the map opens on anything else.
static func _map_load_body(rom: RomFile, layout: Dictionary, bank: int, at: int) -> int:
	var pc: int = at
	var opening: int = Gen1Layout.banked(bank, pc)
	if not rom.in_bounds(opening, Gen1Layout.SCRIPT_LONG_SIZE) \
		or rom.u8(opening) != Gen1Layout.SCRIPT_LD_HL \
		or rom.u16le(opening + 1) != int(layout["map_script_flags"]):
		return -1
	pc += Gen1Layout.SCRIPT_LONG_SIZE
	for base: int in MAP_LOAD_PREFIXES:
		if not _map_load_prefixed(rom, bank, pc, base):
			return -1
		pc += Gen1Layout.SCRIPT_SHORT_SIZE
	for held: int in MAP_LOAD_HELD_LIMIT:
		if not Gen1Layout.SCRIPT_STACK_HL.has(rom.u8(Gen1Layout.banked(bank, pc))):
			break
		pc += 1
	var branch: int = rom.u8(Gen1Layout.banked(bank, pc))
	if not Gen1Layout.MAP_LOAD_GATE_BRANCHES.has(branch):
		return -1
	return _map_load_branch(rom, bank, pc, Gen1Layout.MAP_LOAD_GATE_BRANCHES[branch])


static func _map_load_prefixed(rom: RomFile, bank: int, pc: int, base: int) -> bool:
	var at: int = Gen1Layout.banked(bank, pc)
	if not rom.in_bounds(at, Gen1Layout.SCRIPT_SHORT_SIZE) \
		or rom.u8(at) != Gen1Layout.SCRIPT_PREFIX:
		return false
	var code: int = rom.u8(at + 1)
	return code >= base and code < base + Gen1Layout.SCRIPT_PREFIX_BLOCK \
		and (code & 7) == Gen1Layout.SCRIPT_OPERAND_HL


static func _map_load_branch(rom: RomFile, bank: int, pc: int, row: Dictionary) -> int:
	var size: int = int(row["size"])
	if not bool(row["target"]):
		return pc + size
	var operand: int = Gen1Layout.banked(bank, pc) + 1
	if size == Gen1Layout.SCRIPT_LONG_SIZE:
		return rom.u16le(operand)
	return pc + size + _script_hop(rom.u8(operand))


## `SilphCo2F_SetCardKeyDoorYScript` and `<Map>_UnlockedDoorEventScript` both
## loop over the gate table, so the pair is read by hand and the callback is
## walked for the blocks behind them.
static func _card_key_coordinates(rom: RomFile, bank: int, at: int) -> Array:
	var opening: int = Gen1Layout.banked(bank, at)
	if not rom.in_bounds(opening, CARD_KEY_PROLOGUE_SIZE) \
		or rom.u8(opening) != Gen1Layout.SCRIPT_LD_HL:
		return []
	for call_index: int in 2:
		var call_at: int = opening + Gen1Layout.SCRIPT_LONG_SIZE * (call_index + 1)
		if rom.u8(call_at) != Gen1Layout.SCRIPT_CALL:
			return []
	var list: int = Gen1Layout.banked(bank, rom.u16le(opening + 1))
	var out: Array = []
	while rom.in_bounds(list, Gen1Layout.MAP_COORD_SIZE) \
		and rom.u8(list) != Gen1Layout.MAP_COORD_END:
		out.append({"x": rom.u8(list + 1), "y": rom.u8(list)})
		list += Gen1Layout.MAP_COORD_SIZE
	return out


## One card key door per gate coordinate: the block the callback puts back while
## the door's own flag is clear, in the order
## `<Map>_UnlockedDoorEventScript` numbers them.
static func _card_key_doors(callback: Dictionary) -> Array:
	if callback.is_empty() or (callback["coordinates"] as Array).is_empty():
		return []
	var doors: Array = []
	_card_key_walk(callback["nodes"], doors)
	return doors if doors.size() == (callback["coordinates"] as Array).size() else []


static func _card_key_walk(nodes: Array, doors: Array) -> void:
	for node: Dictionary in nodes:
		if String(node["op"]) != "branch":
			continue
		for blocked: Dictionary in node["else"] as Array:
			if String(blocked["op"]) != "replace_block":
				continue
			doors.append({
				"x": int(blocked["x"]), "y": int(blocked["y"]),
				"block": int(blocked["block"]), "flag": int(node["flag"]),
			})
		_card_key_walk(node["else"] as Array, doors)


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


## Connection records come north, south, west then east. `.checkNorthMap` writes
## the y alignment into `wYCoord` and adds the x one to `wXCoord`.
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
		out.append(_read_text(rom, layout, bank, rom.u16le(table + id * 2), id + 1))
	return out


## A `TX_SCRIPT_*` row keeps its own inventory where it has one, so nothing
## downstream has to read the cartridge again to open the shop.
static func _read_text(
	rom: RomFile, layout: Dictionary, bank: int, pointer: int, text_id: int = 0
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
	## The corpus's other row the world owns whole: a party list and `MoveMon`
	## both ways are no more readable here than `TalkToTrainer` is.
	if at == int(layout["day_care_script"]):
		row["script"] = [{"op": "day_care"}]
		return row
	row["text"] = String(decoded["text"])
	row["prompt"] = bool(decoded.get("prompt", false))
	var code: int = _text_code_at(decoded)
	if code < 0:
		return row
	var script: Array = decode_script(rom, layout, bank, code,
		{"map_text": text_id} if text_id > 0 else {})
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
	var found: String = predef_text(rom, layout, bank, "found_hidden_item")
	var full: String = predef_text(rom, layout, bank, "hidden_item_bag_full")
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
	var found: String = predef_text(rom, layout, bank, "found_hidden_coins")
	var dropped: String = predef_text(rom, layout, bank, "dropped_hidden_coins")
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
static func predef_text(
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
## A `set_map_script` through `wCurMapScript`, whose byte the dispatch names.
const MAP_SCRIPT_MIRROR: int = -1
const SCRIPT_BUDGET: int = 4096
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
const SCRIPT_TESTS_COORD: int = -11
## `ArePlayerCoordsInArray`, whose carry is the player standing on one row of a
## `db y, x` list.
const SCRIPT_TESTS_COORD_ARRAY: int = -12
## `wStatusFlags5`'s own two bits, and `wCoordIndex`, the row that list matched.
const SCRIPT_TESTS_MOVEMENT: int = -13
const SCRIPT_TESTS_COORD_INDEX: int = -14
## `RemoveGuardDrink` answers zero in `hItemToRemoveID` for an empty bag.
const SCRIPT_TESTS_GUARD_DRINK: int = -15
## `DecodeArrowMovementRLE` leaves $FF when the player stands on no arrow tile.
const SCRIPT_TESTS_ARROW: int = -16
## `wIsInBattle` and `wBattleResult`, read by a post-battle state alone.
const SCRIPT_TESTS_BATTLE: int = -17
## `wSavedCoordIndex`, read back by a state after the one that matched.
const SCRIPT_TESTS_SAVED_INDEX: int = -18
const SCRIPT_TESTS_RIDING: int = -19
const SCRIPT_TESTS_STARTER: int = -20
const SCRIPT_TESTS_MOVEMENT_SCRIPT: int = -21
const SCRIPT_TESTS_VOLATILE: int = -22
const SCRIPT_TESTS_BOULDER: int = -23
const SCRIPT_TESTS_BADGES: int = -24
const SCRIPT_TESTS_RANDOM: int = -25
const SCRIPT_TESTS_RANDOM_BIT: int = -26
const SCRIPT_TESTS_TALKING: int = -27
const SCRIPT_TESTS_SCRATCH: int = -28
const SCRIPT_TESTS_FILTERED: int = -29
const SCRIPT_TESTS_MENU_CANCEL: int = -30
const SCRIPT_TESTS_MENU_ROW: int = -31
const SCRIPT_TESTS_MENU_ITEM: int = -32
const SCRIPT_TESTS_SAFARI_ADMISSION: int = -33
const SCRIPT_TESTS_ANY_MONEY: int = -34
const SCRIPT_TESTS_PARTY_MENU: int = -35
const SCRIPT_TESTS_MON_OT: int = -36
const SCRIPT_TESTS_NAME_ENTRY: int = -37
const SCRIPT_TESTS_INDEXED_FLAG: int = -38
const SCRIPT_AIDE: int = -3
## What `push af` saves and `pop af` puts back, which is how
## `CheckEventAfterBranchReuseA` still reads the event byte a block write
## clobbered.
const SCRIPT_AF_KEYS: Array[String] = [
	"a", "source", "rotated", "tests", "tests_in_carry", "tests_engine",
	"tests_and_a", "a_runtime", "a_symbolic", "tests_snapshot", "tests_all",
]
## The stores a row is read for that are `a` under another name. `hSpriteIndex`
## shares `hTextID`'s byte, so the routine behind a store says which was meant.
const SCRIPT_STORED_REGISTERS: Dictionary = {
	"text_box_id": "text_box", "text_id_hram": "map_text",
	"toggleable_index": "toggle", "new_tile_block": "new_block",
	"sprite_facing_hram": "sprite_facing",
}


## One `text_asm` row's machine code, as the boxes it prints and the branches
## choosing between them; a path reaching anything unread is dropped whole.
## [param known] is the argument byte a hidden event's own routine is handed.
static func decode_script(
	rom: RomFile, layout: Dictionary, bank: int, at: int, known: Dictionary = {}
) -> Array:
	var ctx: Dictionary = {
		"rom": rom, "layout": layout, "bank": bank,
		"budget": [SCRIPT_BUDGET], "calls": [0],
	}
	var walked: Variant = _walk_script(ctx, at, known.duplicate(), 0)
	return walked as Array if walked is Array else []


## One straight run and the branch that ends it, or null for a path that does
## not reach `TextScriptEnd`.
static func _walk_script(
	ctx: Dictionary, pc: int, state: Dictionary, depth: int
) -> Variant:
	if depth > SCRIPT_DEPTH:
		return null
	## A `jp nc, CheckFightingMapTrainers` lands here rather than on a call, and
	## a `<Map>_ScriptPointers` row may stand at a routine outright, so a routine
	## that spends nothing is answered before its machine code is walked at all.
	if _script_routine(ctx["layout"], pc) in Gen1Layout.SCRIPT_SILENT_CALLS \
		or _script_banked_routine(ctx["layout"], int(ctx["bank"]), pc) \
			in Gen1Layout.SCRIPT_SILENT_BANKED_CALLS:
		return []
	var special: Variant = _script_special_body(ctx, pc)
	if special != null:
		return special
	if depth == 0:
		ctx["first_box"] = _script_first_box_row(ctx, pc)
	var out: Array = []
	var budget: Array = ctx["budget"]
	while budget[0] > 0:
		budget[0] -= 1
		var op: int = (ctx["rom"] as RomFile).u8(Gen1Layout.banked(int(ctx["bank"]), pc))
		if Gen1Layout.SCRIPT_BRANCHES.has(op) or Gen1Layout.SCRIPT_CARRY_BRANCHES.has(op):
			return _script_branch(ctx, op, pc, state, depth, out)
		if Gen1Layout.SCRIPT_CONDITIONAL_CALLS.has(op):
			return _script_call_branch(ctx, op, pc, state, depth, out)
		if Gen1Layout.SCRIPT_RET_BRANCHES.has(op) \
			or Gen1Layout.SCRIPT_RET_CARRY_BRANCHES.has(op):
			return _script_ret_branch(ctx, op, pc, state, depth, out)
		var next: int = _script_step(ctx, pc, state, out, depth)
		if next == SCRIPT_END:
			return _script_ended(state, out)
		if next == SCRIPT_UNREAD:
			return null
		if next == SCRIPT_AIDE:
			return _script_aide_branch(ctx, pc + Gen1Layout.SCRIPT_LONG_SIZE, state, depth, out)
		pc = next
	return null


const SCRIPT_TEST_DOMAINS: Dictionary = {
	SCRIPT_TESTS_FACING: "facing", SCRIPT_TESTS_STARTER: "starter",
}


static func _script_domain(ctx: Dictionary, state: Dictionary, tests: int) -> Array:
	if tests == SCRIPT_TESTS_FACING:
		return Gen1Layout.FACING_STEPS.keys()
	return Gen1Layout.script_starters(
		(ctx["rom"] as RomFile).id, String(state.get("starter_who", ""))
	)


static func _script_domain_settled(
	ctx: Dictionary, state: Dictionary, tests: Variant
) -> Variant:
	if not (tests is int) or not SCRIPT_TEST_DOMAINS.has(int(tests)):
		return null
	var key: int = int(tests)
	var domain: Array = _script_domain(ctx, state, key)
	var value: int = int(state[SCRIPT_TEST_DOMAINS[key]])
	if domain.is_empty():
		return null
	var known: Dictionary = state.get("domains", {})
	var fixed: Dictionary = known.get("fixed", {})
	if fixed.has(key):
		return int(fixed[key]) == value
	var seen: Array = (known.get("excluded", {}) as Dictionary).get(key, [])
	if seen.has(value) or not domain.has(value):
		return false
	for other: int in domain:
		if other != value and not seen.has(other):
			return null
	return true


static func _script_domain_learn(
	state: Dictionary, tests: Variant, miss: Dictionary, match_side: Dictionary
) -> void:
	if not (tests is int) or not SCRIPT_TEST_DOMAINS.has(int(tests)):
		return
	var key: int = int(tests)
	var value: int = int(state[SCRIPT_TEST_DOMAINS[key]])
	var known: Dictionary = state.get("domains", {})
	var excluded: Dictionary = (known.get("excluded", {}) as Dictionary).duplicate()
	excluded[key] = (excluded.get(key, []) as Array) + [value]
	miss["domains"] = {"fixed": known.get("fixed", {}), "excluded": excluded}
	var fixed: Dictionary = (known.get("fixed", {}) as Dictionary).duplicate()
	fixed[key] = value
	match_side["domains"] = {"fixed": fixed, "excluded": known.get("excluded", {})}


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
			_script_loaded_register(state, "b", rom.u8(at + 2))
			_script_loaded_register(state, "c", rom.u8(at + 1))
			return pc + Gen1Layout.SCRIPT_LONG_SIZE
		Gen1Layout.SCRIPT_LD_B:
			_script_loaded_register(state, "b", rom.u8(at + 1))
			return pc + Gen1Layout.SCRIPT_SHORT_SIZE
		Gen1Layout.SCRIPT_LD_C:
			_script_loaded_register(state, "c", rom.u8(at + 1))
			return pc + Gen1Layout.SCRIPT_SHORT_SIZE
		Gen1Layout.SCRIPT_LD_B_A, Gen1Layout.SCRIPT_LD_C_A:
			var register: String = "b" \
				if rom.u8(at) == Gen1Layout.SCRIPT_LD_B_A else "c"
			return pc + 1 if _script_moved_a(state, register) else SCRIPT_UNREAD
		Gen1Layout.SCRIPT_LD_A_B:
			if state.has("b_source"):
				_script_wrote_a(state)
				state.erase("a")
				state["source"] = int(state["b_source"])
				return pc + 1
			if not state.has("b"):
				return SCRIPT_UNREAD
			_script_wrote_a(state)
			state["a"] = int(state["b"])
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
		Gen1Layout.SCRIPT_DEC_A, Gen1Layout.SCRIPT_INC_A:
			## `dec a` is what takes `DecodeRLEList`'s own sentinel back off its
			## count, and `inc a` how a row spells PLAYER_DIR_RIGHT over `xor a`.
			if not state.has("a"):
				if int(state.get("source", -1)) \
					!= int((ctx["layout"] as Dictionary).get("filtered_bag_count", -1)):
					return SCRIPT_UNREAD
				state.erase("source")
				return pc + 1
			var step: int = 1 if rom.u8(at) == Gen1Layout.SCRIPT_INC_A else -1
			var symbolic: String = String(state.get("a_symbolic", ""))
			_script_wrote_a(state)
			state["a"] = int(state["a"]) + step
			if not symbolic.is_empty():
				state["a_symbolic"] = symbolic
			else:
				## `OaksAideScript`'s own `dec a ; jr nz` is the whole of this Z.
				_script_untested(state)
				state["known_zero"] = int(state["a"]) == 0
			return pc + 1
	return _script_step_more(ctx, pc, at, state, out, depth)


static func _script_step_more(
	ctx: Dictionary, pc: int, at: int, state: Dictionary, out: Array, depth: int
) -> int:
	var rom: RomFile = ctx["rom"]
	match rom.u8(at):
		Gen1Layout.SCRIPT_LD_HL_A:
			return pc + 1 \
				if _script_stored(ctx, int(state.get("hl", -1)), state, out) else SCRIPT_UNREAD
		Gen1Layout.SCRIPT_LD_HL_N:
			return _script_stored_immediate(ctx, pc, at, state, out)
		Gen1Layout.SCRIPT_DEC_HL:
			var layout: Dictionary = ctx["layout"]
			if int(state.get("hl", -1)) != int(layout.get("npc_sprite_offset", -1)) \
				or not state.has("npc_path"):
				return SCRIPT_UNREAD
			(state["npc_path"] as Dictionary)["y_adjust"] -= 1
			return pc + 1
		Gen1Layout.SCRIPT_INC_HL, Gen1Layout.SCRIPT_INC_DE:
			var pair: String = "hl" if rom.u8(at) == Gen1Layout.SCRIPT_INC_HL else "de"
			if not state.has(pair):
				return SCRIPT_UNREAD
			state[pair] = int(state[pair]) + 1
			return pc + 1
		Gen1Layout.SCRIPT_LD_A_HLI:
			var folded: int = _script_money_fold(ctx, pc, state)
			return folded if folded != SCRIPT_NOT_FOLDED \
				else _script_read_table(ctx, pc, state)
		Gen1Layout.SCRIPT_LD_A_HL:
			var next: int = _script_read_table(ctx, pc, state)
			if next != SCRIPT_UNREAD:
				state["hl"] = int(state["hl"]) - 1
			return next
		Gen1Layout.SCRIPT_ADD_N, Gen1Layout.SCRIPT_SUB_N:
			return _script_added(ctx, pc, at, state)
		Gen1Layout.SCRIPT_LD_D:
			var filtered: int = _script_filtered_index(ctx, pc, at, state)
			return filtered if filtered != SCRIPT_UNREAD else _script_table_register(ctx, pc, at, state)
		Gen1Layout.SCRIPT_LD_E, Gen1Layout.SCRIPT_ADD_HL_DE, \
		Gen1Layout.SCRIPT_LD_H_HL, Gen1Layout.SCRIPT_LD_L_A, Gen1Layout.SCRIPT_INC_H:
			return _script_table_register(ctx, pc, at, state)
		Gen1Layout.SCRIPT_CP_B:
			return _script_compared_b(ctx, pc, state)
	return _script_step_registers(ctx, pc, at, state, out, depth)


static func _script_step_registers(
	ctx: Dictionary, pc: int, at: int, state: Dictionary, out: Array, depth: int
) -> int:
	var rom: RomFile = ctx["rom"]
	match rom.u8(at):
		Gen1Layout.SCRIPT_LD_A_C:
			if state.has("c_source"):
				_script_wrote_a(state)
				state.erase("a")
				state["source"] = int(state["c_source"])
				return pc + 1
			if not state.has("c"):
				return SCRIPT_UNREAD
			_script_wrote_a(state)
			state["a"] = int(state["c"])
			return pc + 1
		Gen1Layout.SCRIPT_LD_A_L, Gen1Layout.SCRIPT_LD_A_H:
			if not state.has("hl"):
				return SCRIPT_UNREAD
			var low: bool = rom.u8(at) == Gen1Layout.SCRIPT_LD_A_L
			_script_wrote_a(state)
			state["a"] = int(state["hl"]) & 0xFF if low else int(state["hl"]) >> 8
			state["a_half_of"] = int(state["hl"])
			return pc + 1
		Gen1Layout.SCRIPT_LD_H_D, Gen1Layout.SCRIPT_LD_L_E, \
		Gen1Layout.SCRIPT_LD_D_H, Gen1Layout.SCRIPT_LD_E_L:
			return _script_moved_half(pc, rom.u8(at), state)
		Gen1Layout.SCRIPT_OR_N:
			if state.has("a") and not state.has("a_symbolic"):
				state["a"] = int(state["a"]) | rom.u8(at + 1)
			elif _script_flag(ctx, int(state.get("source", -1)), 0) >= 0:
				state["mask_set"] = rom.u8(at + 1)
			else:
				return SCRIPT_UNREAD
			return pc + Gen1Layout.SCRIPT_SHORT_SIZE
		Gen1Layout.SCRIPT_AND_B:
			if not state.has("b_source"):
				return SCRIPT_UNREAD
			_script_wrote_a(state)
			state.erase("a")
			state["source"] = int(state["b_source"])
			_script_test_bit(ctx, state, -1)
			state["tests_and_a"] = true
			return pc + 1
		Gen1Layout.SCRIPT_DEC_B:
			if not state.has("b"):
				return SCRIPT_UNREAD
			state["b"] = int(state["b"]) - 1
			_script_untested(state)
			state["known_zero"] = int(state["b"]) == 0
			return pc + 1
		Gen1Layout.SCRIPT_DEC_L, Gen1Layout.SCRIPT_LD_B_L:
			if not bool(state.get("menu_rows", false)):
				return SCRIPT_UNREAD
			state.erase("b")
			return pc + 1
	return _script_flow(ctx, pc, at, state, out, depth)


## `ld a, [hli] / or [hl] / inc hl / or [hl]` over `wPlayerMoney`: Z is raised
## only by three zero bytes, so the `jr nz` behind it is a balance of one or more.
const SCRIPT_NOT_FOLDED: int = -3
const SCRIPT_MONEY_FOLD: Array[int] = [0xB6, Gen1Layout.SCRIPT_INC_HL, 0xB6]
static func _script_money_fold(ctx: Dictionary, pc: int, state: Dictionary) -> int:
	var layout: Dictionary = ctx["layout"]
	if int(state.get("hl", -1)) != int(layout.get("player_money", -2)):
		return SCRIPT_NOT_FOLDED
	var rom: RomFile = ctx["rom"]
	for step: int in SCRIPT_MONEY_FOLD.size():
		if rom.u8(Gen1Layout.banked(int(ctx["bank"]), pc + 1 + step)) \
			!= SCRIPT_MONEY_FOLD[step]:
			return SCRIPT_NOT_FOLDED
	_script_wrote_a(state)
	state.erase("a")
	state.erase("hl")
	_script_tested(state, SCRIPT_TESTS_ANY_MONEY)
	return pc + 1 + SCRIPT_MONEY_FOLD.size()


static func _script_read_table(ctx: Dictionary, pc: int, state: Dictionary) -> int:
	var hl: int = int(state.get("hl", -1))
	if hl < 0 or hl >= Gen1Layout.SCRIPT_CEILING:
		return SCRIPT_UNREAD
	_script_wrote_a(state)
	state["a"] = (ctx["rom"] as RomFile).u8(Gen1Layout.banked(int(ctx["bank"]), hl))
	state["hl"] = hl + 1
	return pc + 1


static func _script_table_register(ctx: Dictionary, pc: int, at: int, state: Dictionary) -> int:
	var rom: RomFile = ctx["rom"]
	var op: int = rom.u8(at)
	if op == Gen1Layout.SCRIPT_INC_H:
		if not state.has("hl"):
			return SCRIPT_UNREAD
		state["hl"] = (int(state["hl"]) + 0x100) & 0xFFFF
		_script_untested(state)
		state["known_zero"] = int(state["hl"]) < 0x100
		return pc + 1
	if op in [Gen1Layout.SCRIPT_LD_D, Gen1Layout.SCRIPT_LD_E]:
		var high: bool = op == Gen1Layout.SCRIPT_LD_D
		var mask: int = 0x00FF if high else 0xFF00
		state["de"] = (int(state.get("de", 0)) & mask) \
			| (rom.u8(at + 1) << (8 if high else 0))
		return pc + 2
	if not state.has("hl"):
		return SCRIPT_UNREAD
	match op:
		Gen1Layout.SCRIPT_ADD_HL_DE:
			if not state.has("de"):
				return SCRIPT_UNREAD
			state["hl"] = (int(state["hl"]) + int(state["de"])) & 0xFFFF
		Gen1Layout.SCRIPT_LD_H_HL:
			if int(state["hl"]) < 0 or int(state["hl"]) >= Gen1Layout.SCRIPT_CEILING:
				return SCRIPT_UNREAD
			state["hl"] = (int(state["hl"]) & 0xFF) \
				| (rom.u8(Gen1Layout.banked(int(ctx["bank"]), int(state["hl"]))) << 8)
		Gen1Layout.SCRIPT_LD_L_A:
			if not state.has("a"):
				return SCRIPT_UNREAD
			state["hl"] = (int(state["hl"]) & 0xFF00) | (int(state["a"]) & 0xFF)
	return pc + 1


static func _script_moved_half(pc: int, op: int, state: Dictionary) -> int:
	var to_hl: bool = op in [Gen1Layout.SCRIPT_LD_H_D, Gen1Layout.SCRIPT_LD_L_E]
	## `ld h, d` with `ld l, e` is a copy: the unwritten half is not read.
	if to_hl and not state.has("hl"):
		state["hl"] = 0
	if not state.has("de") or not state.has("hl"):
		return SCRIPT_UNREAD
	var high: bool = op in [Gen1Layout.SCRIPT_LD_H_D, Gen1Layout.SCRIPT_LD_D_H]
	var source: int = int(state["de"]) if to_hl else int(state["hl"])
	var target: String = "hl" if to_hl else "de"
	var mask: int = 0xFF00 if high else 0x00FF
	state[target] = (int(state[target]) & ~mask) | (source & mask)
	return pc + 1


static func _script_added(ctx: Dictionary, pc: int, at: int, state: Dictionary) -> int:
	var value: int = (ctx["rom"] as RomFile).u8(at + 1)
	if (ctx["rom"] as RomFile).u8(at) == Gen1Layout.SCRIPT_SUB_N:
		value = -value
	var layout: Dictionary = ctx["layout"]
	if int(state.get("source", -1)) == int(layout.get("rival_starter", -1)):
		_script_wrote_a(state)
		state["a"] = value
		state["a_symbolic"] = "rival_starter"
		return pc + Gen1Layout.SCRIPT_SHORT_SIZE
	if not state.has("a") or state.has("a_symbolic"):
		return SCRIPT_UNREAD
	var runtime: int = int(state.get("a_runtime", -1))
	_script_wrote_a(state)
	state["a"] = (int(state["a"]) + value) & 0xFF
	if runtime >= 0:
		state["a_runtime"] = runtime
	return pc + Gen1Layout.SCRIPT_SHORT_SIZE


static func _script_filtered_index(
	ctx: Dictionary, pc: int, at: int, state: Dictionary
) -> int:
	var rom: RomFile = ctx["rom"]
	var layout: Dictionary = ctx["layout"]
	if int(state.get("hl", -1)) != int(layout.get("filtered_bag_items", -1)) \
		or int(state.get("source", -1)) != int(layout["current_menu_item"]):
		return SCRIPT_UNREAD
	for offset: int in Gen1Layout.SCRIPT_FILTERED_INDEX.size():
		if rom.u8(at + offset) != int(Gen1Layout.SCRIPT_FILTERED_INDEX[offset]):
			return SCRIPT_UNREAD
	_script_wrote_a(state)
	state.erase("a")
	state["source"] = Gen1Layout.SCRIPT_MENU_ITEM_SOURCE
	return pc + Gen1Layout.SCRIPT_FILTERED_INDEX.size()


static func _script_compared_b(ctx: Dictionary, pc: int, state: Dictionary) -> int:
	if not state.has("a"):
		return SCRIPT_UNREAD
	var layout: Dictionary = ctx["layout"]
	for who: String in ["rival", "player"]:
		if int(state.get("b_source", -1)) != int(layout.get(who + "_starter", -1)):
			continue
		state["starter_who"] = who
		state["starter"] = int(state["a"])
		_script_tested(state, SCRIPT_TESTS_STARTER)
		return pc + 1
	if not state.has("b"):
		return SCRIPT_UNREAD
	_script_untested(state)
	state["known_zero"] = int(state["a"]) == int(state["b"])
	return pc + 1


static func _script_stored_immediate(
	ctx: Dictionary, pc: int, at: int, state: Dictionary, out: Array
) -> int:
	var had: bool = state.has("a")
	var was: int = int(state.get("a", 0))
	state["a"] = (ctx["rom"] as RomFile).u8(at + 1)
	var ok: bool = _script_stored(ctx, int(state.get("hl", -1)), state, out)
	if had:
		state["a"] = was
	else:
		state.erase("a")
	return pc + Gen1Layout.SCRIPT_SHORT_SIZE if ok else SCRIPT_UNREAD


## What reads memory, tests it or leaves the instruction after this one.
static func _script_flow(
	ctx: Dictionary, pc: int, at: int, state: Dictionary, out: Array, depth: int
) -> int:
	var rom: RomFile = ctx["rom"]
	match rom.u8(at):
		Gen1Layout.SCRIPT_LD_A_MEM:
			_script_loaded(ctx, rom.u16le(at + 1), state)
			return pc + Gen1Layout.SCRIPT_LONG_SIZE
		Gen1Layout.SCRIPT_LDH_A_MEM:
			_script_loaded(ctx, Gen1Layout.SCRIPT_HRAM_BASE + rom.u8(at + 1), state)
			return pc + Gen1Layout.SCRIPT_SHORT_SIZE
		Gen1Layout.SCRIPT_LD_MEM_A:
			return pc + Gen1Layout.SCRIPT_LONG_SIZE \
				if _script_stored(ctx, rom.u16le(at + 1), state, out) else SCRIPT_UNREAD
		Gen1Layout.SCRIPT_LDH_MEM_A:
			return pc + Gen1Layout.SCRIPT_SHORT_SIZE if _script_stored(
				ctx, Gen1Layout.SCRIPT_HRAM_BASE + rom.u8(at + 1), state, out
			) else SCRIPT_UNREAD
		Gen1Layout.SCRIPT_LD_HLI_A:
			return _script_stored_hli(ctx, pc, state, out)
		Gen1Layout.SCRIPT_AND_A:
			_script_test_bit(ctx, state, -1)
			if Gen1Layout.script_zero_source(
				ctx["layout"], int(state.get("source", -1))
			):
				state["known_zero"] = true
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
			state["mask"] = rom.u8(at + 1)
			return pc + Gen1Layout.SCRIPT_SHORT_SIZE
		Gen1Layout.SCRIPT_PREFIX:
			return _script_prefix(ctx, pc, state, out)
	return _script_jumped(ctx, pc, at, state, out, depth)


## What leaves this instruction for another, and the two register pairs a row
## saves over one.
static func _script_jumped(
	ctx: Dictionary, pc: int, at: int, state: Dictionary, out: Array, depth: int
) -> int:
	var rom: RomFile = ctx["rom"]
	match rom.u8(at):
		Gen1Layout.SCRIPT_JR:
			return pc + Gen1Layout.SCRIPT_SHORT_SIZE + _script_hop(rom.u8(at + 1))
		Gen1Layout.SCRIPT_JP:
			return _script_jump(ctx, pc, rom.u16le(at + 1), state, out, depth)
		Gen1Layout.SCRIPT_RET:
			return SCRIPT_END
		Gen1Layout.SCRIPT_CALL:
			return _script_call(ctx, pc, rom.u16le(at + 1), state, out, depth)
		Gen1Layout.SCRIPT_PUSH_HL:
			_script_push(state, "hl_saved", int(state.get("hl", -1)))
			return pc + 1
		Gen1Layout.SCRIPT_POP_HL:
			if (state.get("hl_saved", []) as Array).is_empty():
				return SCRIPT_UNREAD
			state["hl"] = int(_script_pop(state, "hl_saved"))
			return pc + 1
		Gen1Layout.SCRIPT_PUSH_AF:
			_script_push(state, "af", _script_pushed_af(state))
			return pc + 1
		Gen1Layout.SCRIPT_POP_AF:
			return SCRIPT_UNREAD if (state.get("af", []) as Array).is_empty() \
				else _script_popped_af(state, pc)
	if Gen1Layout.SCRIPT_CONDITIONAL_CALLS.has(rom.u8(at)):
		return _script_call_if(ctx, pc, rom.u16le(at + 1), state, out, depth)
	return SCRIPT_UNREAD


## A conditional `call`, which only a routine spending nothing here may be: both
## sides of `call z, WaitForTextScrollButtonPress` print the same boxes.
static func _script_call_if(
	ctx: Dictionary, pc: int, target: int, state: Dictionary, out: Array, depth: int
) -> int:
	var next: int = pc + Gen1Layout.SCRIPT_LONG_SIZE
	var op: int = (ctx["rom"] as RomFile).u8(Gen1Layout.banked(int(ctx["bank"]), pc))
	if state.has("known_zero") and Gen1Layout.SCRIPT_ZERO_CALLS.has(op):
		var calls: bool = bool(Gen1Layout.SCRIPT_ZERO_CALLS[op]) \
			!= bool(state["known_zero"])
		state.erase("known_zero")
		return _script_call(ctx, pc, target, state, out, depth) if calls else next
	if not _script_routine(ctx["layout"], target) in Gen1Layout.SCRIPT_SILENT_CALLS:
		return SCRIPT_UNREAD
	_script_untested(state)
	return next


static func _script_push(state: Dictionary, key: String, value: Variant) -> void:
	var stack: Array = (state.get(key, []) as Array).duplicate()
	stack.append(value)
	state[key] = stack


static func _script_pop(state: Dictionary, key: String) -> Variant:
	var stack: Array = (state[key] as Array).duplicate()
	var value: Variant = stack.pop_back()
	state[key] = stack
	return value


static func _script_pushed_af(state: Dictionary) -> Dictionary:
	var saved: Dictionary = {}
	for key: String in SCRIPT_AF_KEYS:
		if state.has(key):
			saved[key] = state[key]
	return saved


static func _script_popped_af(state: Dictionary, pc: int) -> int:
	var saved: Dictionary = _script_pop(state, "af")
	for key: String in SCRIPT_AF_KEYS:
		state.erase(key)
		if saved.has(key):
			state[key] = saved[key]
	return pc + 1


## What a branch is reading, and whether it is reading it out of carry.
static func _script_untested(state: Dictionary) -> void:
	for key: String in [
		"tests", "tests_in_carry", "tests_engine", "tests_and_a", "tests_all",
		"known_zero", "tests_snapshot",
	]:
		state.erase(key)


static func _script_tested(
	state: Dictionary, value: Variant, in_carry: bool = false, engine: bool = false
) -> void:
	state["tests"] = value
	state["tests_in_carry"] = in_carry
	state["tests_engine"] = engine
	state.erase("tests_and_a")
	state.erase("tests_snapshot")
	state.erase("tests_all")
	state.erase("known_zero")


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
static func _script_loaded_register(state: Dictionary, register: String, value: int) -> void:
	state[register] = value
	state.erase(register + "_source")
	state.erase(register + "_runtime")


## `ld b, a` and `ld c, a`: a register handed a value the walk does not know
## carries where it was read from, which is what says `DecodeArrowMovementRLE`'s
## b and c are the player's own coordinates.
static func _script_moved_a(state: Dictionary, register: String) -> bool:
	if state.has("a"):
		_script_loaded_register(state, register, int(state["a"]))
		if state.has("a_runtime"):
			state[register + "_runtime"] = int(state["a_runtime"])
		state.erase(register + "_symbolic")
		if state.has("a_symbolic"):
			state[register + "_symbolic"] = String(state["a_symbolic"])
		return true
	if not state.has("source"):
		return false
	state.erase(register)
	state.erase(register + "_runtime")
	state.erase(register + "_symbolic")
	state[register + "_source"] = int(state["source"])
	return true


static func _script_wrote_a(state: Dictionary) -> void:
	state.erase("source")
	state.erase("rotated")
	state.erase("tests_and_a")
	state.erase("a_symbolic")
	state.erase("a_half_of")
	state.erase("a_runtime")


## `ld a, [nn]`. `ShowPokedexDataInternal` leaves `wPokedexNum` in
## `wCurPartySpecies`, which the Fighting Dojo's two gifts read the species from.
static func _script_loaded(ctx: Dictionary, address: int, state: Dictionary) -> void:
	_script_wrote_a(state)
	state.erase("a")
	state["source"] = address
	var layout: Dictionary = ctx["layout"]
	if address == int(layout.get("text_id_hram", -1)) and state.has("map_text"):
		state["a"] = int(state["map_text"])
		state.erase("source")
	if address == int(layout["cur_party_species"]) and state.has("species_index"):
		state["a"] = int(state["species_index"])
	## `wHiddenEventFunctionArgument` is `wWhichTrade`'s own byte.
	if address == int(layout.get("which_trade", -1)) and state.has("hidden_argument"):
		state["a"] = int(state["hidden_argument"])
	if address == int(layout.get("npc_sprite_offset", -1)) and state.has("npc_path"):
		state["a"] = 0
		state["a_symbolic"] = "npc_y_distance"
	if address == int(layout.get("trainer_header_flag_bit", -1)):
		state["a"] = 0
		state["a_runtime"] = address
	var temps: Dictionary = state.get("mem", {})
	if temps.has(address):
		state["a"] = int(temps[address])
		state.erase("a_runtime")
		state.erase("source")
	if address == int(layout.get("which_trade", -1)) and state.has("coord_array"):
		state["a"] = 0
		state["a_symbolic"] = Gen1Layout.SCRIPT_SYMBOLIC_COORD_INDEX
	elif address == int(layout.get("which_trade", -1)) and state.has("which_badge"):
		state["a"] = int(state["which_badge"])
	if address == int(layout.get("sprite_index_wram", -1)) and state.has("sprite_index_wram"):
		state["a"] = int(state["sprite_index_wram"])
	## `wChannelSoundIDs`, spun on until a jingle ends: silence here.
	if address == int(layout.get("channel_sound_ids", -1)):
		state["a"] = 0
		state.erase("source")
	if address == int(layout["item_to_remove"]) and state.has("aide_outcome"):
		state["a"] = int(state["aide_outcome"])
		state.erase("source")


## `jp` reaching `TextScriptEnd`, a routine the layout names, or an address in
## the same bank. A tail call returns where the row's own `ret` would.
static func _script_jump(
	ctx: Dictionary, pc: int, target: int, state: Dictionary, out: Array, depth: int
) -> int:
	var layout: Dictionary = ctx["layout"]
	if target == int(layout["text_script_end"]):
		return SCRIPT_END
	if _script_routine(layout, target).is_empty() \
		and _script_banked_routine(layout, int(ctx["bank"]), target).is_empty():
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
## the map script index a row leaves behind it, which the next frame's
## `CallFunctionInTable` dispatches on.
static func _script_stored(
	ctx: Dictionary, address: int, state: Dictionary, out: Array
) -> bool:
	var layout: Dictionary = ctx["layout"]
	if address == int(layout["cur_map_script"]):
		return _script_map_script_mirror(state, out)
	var byte: int = _map_script_byte(layout, address)
	if byte >= 0:
		## `wNextSafariZoneGateScript` is a union over `wSavedCoordIndex`.
		if not state.has("a"):
			if int(state.get("source", -1)) != int(layout.get("saved_coord_index", -1)):
				return false
			out.append({"op": "set_map_script", "byte": byte, "from": "saved_coord_index"})
			return true
		out.append({"op": "set_map_script", "byte": byte, "value": int(state["a"])})
		return true
	if address == int(layout["do_not_wait"]):
		if int(state.get("a", 0)) == 0:
			state.erase("no_press")
			return true
		if int(state.get("a", 0)) != 1:
			return false
		state["no_press"] = true
		return true
	var named: int = _script_stored_named(ctx, layout, address, state, out)
	if named >= 0:
		return named == STORE_OK
	## `ResetEventRange` and `SetEventRange` inside one byte.
	if _script_flag(ctx, address, 0) >= 0:
		return _script_stored_flag_byte(ctx, address, state, out)
	for name: String in SCRIPT_STORED_REGISTERS:
		if address != int(layout.get(name, -1)):
			continue
		if not state.has("a"):
			return false
		state[String(SCRIPT_STORED_REGISTERS[name])] = int(state["a"])
		return true
	if address == int(layout["facing_direction"]) and state.has("a") \
		and Gen1Layout.FACING_STEPS.has(int(state["a"])):
		out.append({"op": "player_facing", "facing": int(state["a"])})
		return true
	var safari: int = _script_stored_safari(layout, address, state, out)
	if safari != STORE_NOT_NAMED:
		return safari == STORE_OK
	if _script_stored_silently(layout, address):
		return true
	return _script_stored_more(ctx, layout, address, state, out)


## The held buttons, the automatic box, `wJoyIgnore`, a redraw gate and the list
## `LoadItemList` already left behind: nothing here reads any of them.
static func _script_stored_silently(layout: Dictionary, address: int) -> bool:
	for silent: String in Gen1Layout.SCRIPT_SILENT_STORES:
		if address == int(layout.get(silent, -1)):
			return true
	for word: String in Gen1Layout.SCRIPT_SILENT_WORDS:
		if address - int(layout.get(word, -3)) in [0, 1]:
			return true
	return false


## `.success` writes 30 balls and 502 steps; the gate's `xor a` is the way out.
static func _script_stored_safari(
	layout: Dictionary, address: int, state: Dictionary, out: Array
) -> int:
	var steps: int = int(layout.get("safari_steps", -1))
	var admitted: bool = state.has("safari_admission") and not state.has("a")
	if address == int(layout.get("num_safari_balls", -1)):
		if admitted:
			out.append({"op": "safari_balls", "from": String(state["safari_admission"])})
			return STORE_OK
		if not state.has("a"):
			return STORE_REFUSED
		out.append({"op": "safari_balls", "count": int(state["a"])})
		return STORE_OK
	if address == steps:
		if not state.has("a"):
			return STORE_REFUSED
		state["safari_steps_high"] = int(state["a"])
		return STORE_OK
	if address != steps + 1:
		return STORE_NOT_NAMED
	if not state.has("a") or not state.has("safari_steps_high"):
		return STORE_REFUSED
	out.append({"op": "safari_steps",
		"steps": (int(state["safari_steps_high"]) << 8) | int(state["a"])})
	state.erase("safari_steps_high")
	return STORE_OK


static func _script_snapshot_flags(ctx: Dictionary, state: Dictionary, out: Array) -> void:
	if state.has("tests_snapshot"):
		return
	var tests: Variant = state.get("tests", -1)
	if not tests is Array and int(tests) < 0:
		return
	var id: int = int(ctx.get("flag_snapshots", 0))
	ctx["flag_snapshots"] = id + 1
	var node: Dictionary = {"op": "flag_test", "snapshot": id,
		"flag": int(tests[0]) if tests is Array else int(tests),
		"engine": bool(state.get("tests_engine", false))}
	if tests is Array:
		node["all" if bool(state.get("tests_all", false)) else "either"] = tests.slice(1)
	out.append(node)
	state["tests_snapshot"] = id


static func _script_stored_flag_byte(
	ctx: Dictionary, address: int, state: Dictionary, out: Array
) -> bool:
	_script_snapshot_flags(ctx, state, out)
	var same: bool = address == int(state.get("source", -1))
	if same and state.has("mask_set"):
		for bit: int in 8:
			if int(state["mask_set"]) & (1 << bit) != 0:
				out.append({"op": "flag", "flag": _script_flag(ctx, address, bit), "set": true})
		state.erase("mask_set")
		return true
	var masked: bool = same and state.has("mask")
	if not masked and (not state.has("a") or state.has("source")):
		return false
	var kept: int = int(state["mask"]) if masked else int(state["a"])
	for bit: int in 8:
		var lit: bool = kept & (1 << bit) != 0
		if masked and lit:
			continue
		out.append({"op": "flag", "flag": _script_flag(ctx, address, bit), "set": lit})
	return true


const STORE_OK: int = 1
const STORE_REFUSED: int = 0
const STORE_NOT_NAMED: int = -1
static func _script_stored_named(
	_ctx: Dictionary, layout: Dictionary, address: int, state: Dictionary, out: Array
) -> int:
	var a: int = int(state.get("a", -1))
	var known: bool = state.has("a")
	var name: String = _script_address_name(layout, address, STORE_NAMES)
	if name.is_empty():
		return _script_stored_scratch(layout, address, state, out)
	if STORE_STATE_KEYS.has(name):
		if known:
			state[String(STORE_STATE_KEYS[name])] = a
			_script_movement_script(state, out)
		elif STORE_NEEDS_A.has(name):
			return STORE_REFUSED
		return STORE_OK
	if not known and STORE_NEEDS_A.has(name):
		return STORE_REFUSED
	match name:
		"last_map":
			out.append({"op": "set_last_map", "map": a})
		"last_blackout_map":
			out.append({"op": "set_blackout_map", "map": a})
		"npc_sprite_offset":
			return _script_stored_path_input(state, known, a)
		"sprite_index_wram":
			if known:
				state["sprite_index_wram"] = a
				_script_movement_script(state, out)
			elif int(state.get("source", -1)) != int(layout.get("text_id_hram", -1)):
				return STORE_REFUSED
		"trainer_no":
			return _script_trainer_number(state, out, a)
		"rival_starter", "player_starter":
			return _script_starter_stored(layout, name, state, out, known, a)
		_:
			return _script_stored_named_more(name, state, out, known, a)
	return STORE_OK


static func _script_stored_named_more(
	name: String, state: Dictionary, out: Array, known: bool, a: int
) -> int:
	match name:
		"destination_warp_id":
			if not state.has("warp_map"):
				return STORE_REFUSED
			out.append({"op": "warp_to", "map": int(state["warp_map"]), "warp": a})
		"cur_map_text_ptr":
			if not state.has("a_half_of"):
				return STORE_REFUSED
			out.append({"op": "text_table", "table": int(state["a_half_of"])})
		"player_y", "player_x":
			out.append({"op": "set_player_coord",
				"axis": Gen1Layout.SCRIPT_COORD_SOURCES.find(name), "value": a})
		"num_set_bits":
			## `wNamedObjectIndex` is the same byte.
			if known:
				state["named_index"] = a
			else:
				state["named_source"] = int(state.get("source", -1))
		"fossil_item", "fossil_mon":
			return _script_fossil_stored(name, state, out, known, a)
	return STORE_OK


## `.fossilSelected`: the item is the menu's row and the mon the species it revives.
static func _script_fossil_stored(
	name: String, state: Dictionary, out: Array, known: bool, a: int
) -> int:
	var node: Dictionary = {"op": "set_fossil", "which": name.trim_prefix("fossil_")}
	if known:
		node["value"] = a
	elif int(state.get("source", -1)) == Gen1Layout.SCRIPT_MENU_ITEM_SOURCE:
		node["from"] = "menu"
	else:
		return STORE_REFUSED
	out.append(node)
	return STORE_OK


const STORE_STATE_KEYS: Dictionary = {
	"npc_relative_perspective": "npc_perspective", "npc_movement_table": "npc_table",
	"battle_type": "battle_type", "sprite_map_y": "sprite_map_y",
	"sprite_map_x": "sprite_map_x", "emotion_bubble_sprite": "emote_object",
	"which_emotion_bubble": "emote_kind", "warp_destination_map": "warp_map",
	"cur_party_species": "species_index", "oaks_aide_reward": "aide_item",
}
const STORE_NEEDS_A: Array[String] = [
	"last_map", "last_blackout_map", "npc_relative_perspective", "npc_movement_table",
	"trainer_no", "battle_type", "emotion_bubble_sprite", "which_emotion_bubble",
	"warp_destination_map", "destination_warp_id", "player_y", "player_x",
	"oaks_aide_reward",
]


static func _script_starter_stored(
	layout: Dictionary, name: String, state: Dictionary, out: Array, known: bool, a: int
) -> int:
	var who: String = name.trim_suffix("_starter")
	if known:
		out.append({"op": "set_starter", "who": who, "value": a})
		return STORE_OK
	if int(state.get("source", -1)) != int(layout["which_trade"]):
		return STORE_REFUSED
	out.append({"op": "set_starter", "who": who, "scratch": int(state["source"])})
	return STORE_OK


## `wWhichTrade` is also the trade's own index and a price buffer, so the
## store is handed on.
static func _script_stored_scratch(
	layout: Dictionary, address: int, state: Dictionary, out: Array
) -> int:
	for name: String in Gen1Layout.SCRIPT_SCRATCH_BYTES:
		if address == int(layout.get(name, -1)) and state.has("a"):
			out.append({"op": "scratch", "address": address, "value": int(state["a"])})
			if name == "trainer_header_flag_bit":
				var temps: Dictionary = (state.get("mem", {}) as Dictionary).duplicate()
				temps[address] = int(state["a"])
				state["mem"] = temps
				return STORE_OK
	return _script_stored_sprite({}, layout, address, state, out)


const STORE_NAMES: Array[String] = [
	"last_map", "last_blackout_map", "npc_relative_perspective", "npc_sprite_offset",
	"npc_movement_table", "npc_movement_function", "sprite_index_wram", "trainer_no",
	"battle_type", "emotion_bubble_sprite", "which_emotion_bubble",
	"warp_destination_map", "destination_warp_id", "cur_map_text_ptr",
	"player_y", "player_x", "sprite_map_y", "sprite_map_x", "rival_starter",
	"player_starter", "cur_party_species", "num_set_bits", "oaks_aide_reward",
	"fossil_item", "fossil_mon",
]


static func _script_address_name(layout: Dictionary, address: int, names: Array) -> String:
	for name: String in names:
		if int(layout.get(name, -1)) == address:
			return name
	if address == int(layout.get("cur_map_text_ptr", -1)) + 1:
		return "cur_map_text_ptr_high"
	return ""


static func _script_movement_script(state: Dictionary, out: Array) -> void:
	if not state.has("npc_table") or not state.has("sprite_index_wram"):
		return
	out.append({
		"op": "npc_movement_script", "table": int(state["npc_table"]),
		"object": int(state["sprite_index_wram"]) - 1,
	})
	state.erase("npc_table")


## `hNPCSpriteOffset` shares `hNPCPlayerYDistance`'s byte.
static func _script_stored_path_input(state: Dictionary, known: bool, a: int) -> int:
	if String(state.get("a_symbolic", "")) == "npc_y_distance" and state.has("npc_path"):
		(state["npc_path"] as Dictionary)["y_adjust"] = a
		return STORE_OK
	if not known:
		return STORE_REFUSED
	state["npc_sprite_offset"] = a
	return STORE_OK


static func _script_trainer_number(state: Dictionary, out: Array, number: int) -> int:
	if not state.has("trainer_class"):
		return STORE_REFUSED
	var node: Dictionary = {
		"op": "trainer_battle", "class": int(state["trainer_class"]), "number": number,
	}
	if String(state.get("a_symbolic", "")) == "rival_starter":
		node["number_from"] = "rival_starter"
	if state.has("end_texts"):
		node["end_texts"] = state["end_texts"]
	out.append(node)
	state["trainer_node"] = node
	state.erase("trainer_class")
	return STORE_OK


## `SPRITESTATEDATA2_MAPY` and `_MAPX` are each four above the cell; the pixel
## fields are the renderer's.
static func _script_stored_sprite(
	_ctx: Dictionary, layout: Dictionary, address: int, state: Dictionary, out: Array
) -> int:
	for temp: String in Gen1Layout.SCRIPT_TEMP_BYTES:
		if address != int(layout.get(temp, -1)):
			continue
		if not state.has("a"):
			return STORE_REFUSED
		var temps: Dictionary = state.get("mem", {})
		temps[address] = int(state["a"])
		state["mem"] = temps
		return STORE_OK
	var base: int = int(layout["sprite_state_data"])
	var offset: int = address - base
	if offset < 0 or offset >= 2 * Gen1Layout.SPRITE_SLOTS * Gen1Layout.SPRITE_SLOT_SIZE:
		return STORE_NOT_NAMED
	var field: int = offset % Gen1Layout.SPRITE_SLOT_SIZE
	if offset < Gen1Layout.SPRITE_SLOTS * Gen1Layout.SPRITE_SLOT_SIZE:
		return STORE_OK if Gen1Layout.SPRITE_PIXEL_FIELDS.has(field) else STORE_NOT_NAMED
	@warning_ignore("integer_division")
	var slot: int = (offset - Gen1Layout.SPRITE_SLOTS * Gen1Layout.SPRITE_SLOT_SIZE) \
		/ Gen1Layout.SPRITE_SLOT_SIZE
	if not state.has("a"):
		return STORE_OK
	if field != Gen1Layout.SPRITE_MAP_Y_AT and field != Gen1Layout.SPRITE_MAP_X_AT:
		return STORE_NOT_NAMED
	out.append({"op": "object_position", "object": slot - 1,
		"axis": "y" if field == Gen1Layout.SPRITE_MAP_Y_AT else "x",
		"value": int(state["a"]) - Gen1Layout.SPRITE_MAP_OFFSET})
	return STORE_OK


## The rest of [method _script_stored]: what a store moves or fights with.
static func _script_stored_more(
	ctx: Dictionary, layout: Dictionary, address: int, state: Dictionary, out: Array
) -> bool:
	if address == int(layout.get("player_moving_direction", -1)):
		return _script_player_facing(state, out)
	var slot: int = Gen1Layout.sprite_facing_slot(layout, address)
	if slot >= 0:
		if not Gen1Layout.FACING_STEPS.has(int(state.get("a", -1))):
			return false
		out.append({"op": "object_facing", "object": slot, "facing": int(state["a"])})
		return true
	if _script_saved_index(layout, address, state, out):
		return true
	if address == int(layout["cur_opponent"]):
		return _script_opponent(ctx, state) and _script_wild_battle(state, out, false)
	if address == int(layout["cur_enemy_level"]):
		if not state.has("a"):
			return false
		state["level"] = int(state["a"])
		return _script_wild_battle(state, out, false)
	if _script_joypad_stored(layout, address, state, out):
		return true
	if _script_bcd_stored(ctx, address, state):
		return true
	var source: int = int(state.get("source", -2))
	var marked: int = Gen1Layout.SCRIPT_MENU_ITEM_SOURCE \
		if source == Gen1Layout.SCRIPT_MENU_ITEM_SOURCE \
		else (Gen1Layout.SCRIPT_FOSSIL_ITEM_SOURCE \
			if source == int(layout.get("fossil_item", -1)) else 0)
	if address == int(layout["item_to_remove"]) and marked != 0:
		state["remove"] = marked
		return true
	if address == int(layout["item_to_remove"]) and state.has("a_runtime"):
		return true
	if address != int(layout["item_to_remove"]) or int(state.get("a", 0)) < 1:
		return false
	state["remove"] = int(state["a"])
	state["aide_requirement"] = int(state["a"])
	return true


## `wSavedCoordIndex` and the `hSavedCoordIndex` sharing `hItemToRemoveID`'s
## byte: only the index is ever written out of `wCoordIndex`, and -1 is it.
static func _script_saved_index(
	layout: Dictionary, address: int, state: Dictionary, out: Array
) -> bool:
	var index: bool = int(state.get("source", -1)) == int(layout.get("which_trade", -1))
	if address != int(layout.get("saved_coord_index", -1)) \
		and not (index and address == int(layout["item_to_remove"])):
		return false
	if not index and not state.has("a"):
		return false
	out.append({"op": "save_coord_index", "value": -1 if index else int(state["a"])})
	return true


## `wCurOpponent` and `wCurEnemyLevel`, which `OverworldLoop` fights once the
## script returns. The register holds an internal index and the cache speaks dex
## numbers; at or above `OPP_ID_OFFSET` it is a trainer, which has no level.
static func _script_opponent(ctx: Dictionary, state: Dictionary) -> bool:
	var index: int = int(state.get("a", -1))
	if index >= Gen1Layout.OPPONENT_ID_OFFSET:
		state["trainer_class"] = index - Gen1Layout.OPPONENT_ID_OFFSET
		return true
	if index < 1:
		return false
	var dex: int = Gen1Layout.dex_of_index(ctx["rom"], ctx["layout"], index)
	if dex < 1:
		return false
	state["opponent"] = dex
	return true


## The pair lands in either order: Viridian City's old man writes the level first.
static func _script_wild_battle(state: Dictionary, out: Array, required: bool = true) -> bool:
	if not state.has("opponent") or not state.has("level"):
		return not required
	if int(state["level"]) < 1:
		return false
	var node: Dictionary = {
		"op": "wild_battle", "species": int(state["opponent"]), "level": int(state["level"]),
	}
	state.erase("level")
	if state.has("battle_type"):
		node["battle_type"] = int(state["battle_type"])
		state.erase("battle_type")
	out.append(node)
	state.erase("opponent")
	return true


## `wPlayerMovingDirection`, which the comment beside it says a map script
## writes to turn the player.
static func _script_player_facing(state: Dictionary, out: Array) -> bool:
	if not state.has("a"):
		return false
	var facing: int = Gen1Layout.player_dir_facing(int(state["a"]))
	if facing >= 0:
		out.append({"op": "player_facing", "facing": facing})
	return true


## `wSimulatedJoypadStatesIndex` is how many entries are left to spend and
## `wSimulatedJoypadStatesEnd` the buffer, which Yellow's Oak's Lab writes two
## bytes of by hand.
static func _script_joypad_stored(
	layout: Dictionary, address: int, state: Dictionary, out: Array
) -> bool:
	if not state.has("a"):
		return false
	if address == int(layout["simulated_joypad_index"]):
		if String(state.get("a_symbolic", "")) == Gen1Layout.SCRIPT_SYMBOLIC_COORD_INDEX:
			state["walk_steps_symbolic"] = int(state["a"])
			return true
		state["walk_steps"] = int(state["a"])
		return true
	var offset: int = address - int(layout["simulated_joypad_end"])
	if offset < 0 or offset > Gen1Layout.SIMULATED_JOYPAD_MAX:
		return false
	_script_joypad_wrote(state, offset, int(state["a"]))
	if state.has("walk_pending") and state.has("walk_steps"):
		state.erase("walk_pending")
		return _script_walk(state, out, 0) != SCRIPT_UNREAD
	return true


static func _script_joypad_wrote(state: Dictionary, offset: int, pad: int) -> void:
	var buffer: Array = state.get("walk_buffer", [])
	while buffer.size() <= offset:
		buffer.append(0)
	buffer[offset] = pad
	state["walk_buffer"] = buffer


## `ld [hli], a`, which only the joypad buffer is written through here.
static func _script_stored_hli(
	ctx: Dictionary, pc: int, state: Dictionary, out: Array
) -> int:
	var address: int = int(state.get("hl", -1))
	if address < 0 or not _script_stored(ctx, address, state, out):
		return SCRIPT_UNREAD
	state["hl"] = address + 1
	return pc + 1


## What the flags hold, as the index and whether it is one of Generation 1's own
## engine flags rather than a `wEventFlags` bit. [param bit] is -1 for `and a`,
## which only asks whether the whole byte is zero and so names no flag.
static func _script_tests(ctx: Dictionary, state: Dictionary, bit: int) -> Array:
	var layout: Dictionary = ctx["layout"]
	var source: int = int(state.get("source", -1))
	if bool(state.get("menu_open", false)):
		var menu: Array = _script_menu_tests(layout, state, source, bit)
		if not menu.is_empty():
			return menu
	if source == int(layout.get("filtered_bag_count", -1)):
		return [SCRIPT_TESTS_FILTERED, false]
	if source == int(layout["current_menu_item"]):
		return [SCRIPT_TESTS_CHOICE, false]
	var movement: String = Gen1Layout.script_movement_test(layout, source, bit)
	if not movement.is_empty():
		state["movement_who"] = movement
		return [SCRIPT_TESTS_MOVEMENT, false]
	if source == int(layout["item_to_remove"]) and state.has("drinks"):
		return [SCRIPT_TESTS_GUARD_DRINK, false]
	## `and a ; cp SPRITE_FACING_DOWN`, which the source spells as a comment.
	if source == int(layout["facing_direction"]) and bit < 0:
		state["facing"] = 0
		return [SCRIPT_TESTS_FACING, false]
	if bit < 0:
		var whole: Array = _script_tests_byte(layout, source, state)
		if not whole.is_empty():
			return whole
	if bit >= 0 and source == int(layout.get("random_add", -1)):
		state["random_bit"] = bit
		return [SCRIPT_TESTS_RANDOM_BIT, false]
	if bit >= 0:
		var flag: int = _script_flag(ctx, source, bit)
		if flag >= 0:
			return [flag, false]
		var engine: int = _script_engine_flag(ctx, source, bit)
		if engine >= 0:
			return [engine, true]
	return [SCRIPT_TESTS_NOTHING, false]


static func _script_menu_tests(
	layout: Dictionary, state: Dictionary, source: int, bit: int
) -> Array:
	if bit == Gen1Layout.SCRIPT_PAD_B_BIT and not state.has("source"):
		return [SCRIPT_TESTS_MENU_CANCEL, false]
	if source == int(layout["current_menu_item"]):
		state["menu_row"] = 0
		return [SCRIPT_TESTS_MENU_ROW, false]
	return []


static func _script_tests_byte(layout: Dictionary, source: int, state: Dictionary) -> Array:
	if source == int(layout.get("walk_bike_surf_state", -1)):
		return [SCRIPT_TESTS_RIDING, false]
	if source == int(layout.get("npc_movement_table", -1)) \
		or source == int(layout.get("npc_movement_function", -1)):
		return [SCRIPT_TESTS_MOVEMENT_SCRIPT, false]
	if source == int(layout.get("battle_result", -1)):
		state["outcome"] = Gen1Layout.BATTLE_OUTCOME_WON
		return [SCRIPT_TESTS_BATTLE, false]
	if source == Gen1Layout.SCRIPT_ITEM_QUANTITY_SOURCE and state.has("asked"):
		return [SCRIPT_TESTS_ITEM, false]
	if source == Gen1Layout.SCRIPT_FLAG_ACTION_SOURCE and state.has("flag_action"):
		var action: Array = state["flag_action"]
		return [SCRIPT_TESTS_INDEXED_FLAG if int(action[2]) >= 0 else int(action[0]),
			bool(action[1])]
	if source == int(layout.get("saved_coord_index", -1)):
		state["coord_index"] = 0
		return [SCRIPT_TESTS_SAVED_INDEX, false]
	return []


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
	var alias: int = Gen1Layout.script_flag_alias(layout, address, bit)
	if alias >= 0:
		return alias
	for run: String in Gen1Layout.ENGINE_FLAG_BYTES:
		var base: int = int(layout.get(run, -1))
		var width: int = int(Gen1Layout.ENGINE_FLAG_BYTES[run])
		if address < base or address >= base + width:
			continue
		return Gen1Layout.engine_flag_base(run) \
			+ (address - base) * Gen1Layout.ENGINE_FLAG_BITS + bit
	return -1


## `bit b, a` and `bit b, [hl]` name the flag a branch tests, `set`/`res` writes one.
static func _script_prefix(
	ctx: Dictionary, pc: int, state: Dictionary, out: Array
) -> int:
	var code: int = (ctx["rom"] as RomFile).u8(
		Gen1Layout.banked(int(ctx["bank"]), pc) + 1
	)
	var bit: int = (code >> 3) & 7
	var operand: int = code & 7
	if code == Gen1Layout.SCRIPT_SWAP_A:
		if not state.has("a"):
			return SCRIPT_UNREAD
		var was: int = int(state["a"])
		_script_wrote_a(state)
		state["a"] = ((was & 0xF) << 4) | (was >> 4)
		return pc + Gen1Layout.SCRIPT_SHORT_SIZE
	if operand == Gen1Layout.SCRIPT_OPERAND_A \
		and code >= Gen1Layout.SCRIPT_BIT_BASE and code < Gen1Layout.SCRIPT_RES_BASE:
		if _script_zero_bit(ctx["layout"], int(state.get("source", -1)), bit):
			_script_untested(state)
			state["known_zero"] = true
			return pc + Gen1Layout.SCRIPT_SHORT_SIZE
		_script_test_bit(ctx, state, bit)
		return pc + Gen1Layout.SCRIPT_SHORT_SIZE
	if operand != Gen1Layout.SCRIPT_OPERAND_HL:
		return SCRIPT_UNREAD
	var volatile: String = _script_volatile_bit(ctx["layout"], int(state.get("hl", -1)), bit)
	if not volatile.is_empty():
		if code < Gen1Layout.SCRIPT_RES_BASE:
			state["volatile"] = volatile
			_script_tested(state, SCRIPT_TESTS_VOLATILE)
		else:
			out.append({"op": "volatile", "name": volatile,
				"set": code >= Gen1Layout.SCRIPT_SET_BASE})
		return pc + Gen1Layout.SCRIPT_SHORT_SIZE
	## `wCurrentMapScriptFlags` is clear on every frame but the one a map is
	## loaded on, which [method _read_map_callback] reads instead, so the gate
	## in front of a per-frame script tests false and its `res` spends nothing.
	if int(state.get("hl", -1)) == int((ctx["layout"] as Dictionary)["map_script_flags"]):
		if code < Gen1Layout.SCRIPT_RES_BASE:
			_script_untested(state)
			state["known_zero"] = true
		return pc + Gen1Layout.SCRIPT_SHORT_SIZE
	if code < Gen1Layout.SCRIPT_RES_BASE:
		## `CheckEventHL` names its flag in `hl` where `CheckEvent` loads it.
		state["source"] = int(state.get("hl", -1))
		_script_test_bit(ctx, state, bit)
		return pc + Gen1Layout.SCRIPT_SHORT_SIZE
	if Gen1Layout.script_silent_flag(ctx["layout"], int(state.get("hl", -1)), bit):
		return pc + Gen1Layout.SCRIPT_SHORT_SIZE
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
	_script_snapshot_flags(ctx, state, out)
	out.append(node)
	return pc + Gen1Layout.SCRIPT_SHORT_SIZE


static func _script_zero_bit(layout: Dictionary, address: int, bit: int) -> bool:
	for name: String in Gen1Layout.SCRIPT_ZERO_BITS:
		if int(layout.get(name, -1)) == address:
			return (int(Gen1Layout.SCRIPT_ZERO_BITS[name]) & (1 << bit)) != 0
	return false


static func _script_volatile_bit(layout: Dictionary, address: int, bit: int) -> String:
	for name: String in Gen1Layout.SCRIPT_VOLATILE_BITS:
		if int(layout.get(name, -1)) != address:
			continue
		return String((Gen1Layout.SCRIPT_VOLATILE_BITS[name] as Dictionary).get(bit, ""))
	return ""


## A conditional `call` to a routine that spends something is a branch whose
## calling side walks the routine first.
static func _script_call_branch(
	ctx: Dictionary, op: int, pc: int, state: Dictionary, depth: int, out: Array
) -> Variant:
	var rom: RomFile = ctx["rom"]
	var target: int = rom.u16le(Gen1Layout.banked(int(ctx["bank"]), pc) + 1)
	var next: int = pc + Gen1Layout.SCRIPT_LONG_SIZE
	if state.has("known_zero") and Gen1Layout.SCRIPT_ZERO_CALLS.has(op):
		var calls: bool = bool(Gen1Layout.SCRIPT_ZERO_CALLS[op]) != bool(state["known_zero"])
		state.erase("known_zero")
		return _script_walked_on(ctx, next, state, depth, out) if not calls \
			else _script_call_walked_on(ctx, pc, target, state, depth, out)
	if _script_routine(ctx["layout"], target) in Gen1Layout.SCRIPT_SILENT_CALLS:
		_script_untested(state)
		return _script_walked_on(ctx, next, state, depth, out)
	var tests: Variant = state.get("tests", SCRIPT_TESTS_NOTHING)
	var carry: bool = Gen1Layout.SCRIPT_CARRY_CALLS.has(op)
	if not _script_reads_flag(state, tests, carry):
		return null
	var called: Variant = _script_call_walked_on(ctx, pc, target, state.duplicate(), depth + 1, [])
	var passed: Variant = _walk_script(ctx, next, state.duplicate(), depth + 1)
	var branches: Array = [called, passed] if Gen1Layout.SCRIPT_CALLS_ON_SET.has(op) \
		else [passed, called]
	if branches[0] == null and branches[1] == null:
		return null
	var node: Variant = _script_node(tests, branches, state, out, carry)
	if node == null:
		return null
	out.append(node)
	return out


static func _script_call_walked_on(
	ctx: Dictionary, pc: int, target: int, state: Dictionary, depth: int, out: Array
) -> Variant:
	var called: int = _script_call(ctx, pc, target, state, out, depth)
	if called == SCRIPT_UNREAD:
		return null
	if called == SCRIPT_END:
		return _script_ended(state, out)
	return _script_walked_on(ctx, called, state, depth, out)


static func _script_first_box_row(ctx: Dictionary, pc: int) -> bool:
	var layout: Dictionary = ctx["layout"]
	var at: int = Gen1Layout.banked(int(ctx["bank"]), pc) - 1
	for name: String in Gen1Layout.SCRIPT_FIRST_BOX_ROWS:
		if int(layout.get(name, -1)) == at:
			return true
	return false


## `OaksAideScript` answers in `hOaksAideResult`, so the rest of the row is
## walked once each way.
static func _script_aide_branch(
	ctx: Dictionary, next: int, state: Dictionary, depth: int, out: Array
) -> Variant:
	var node: Dictionary = {
		"op": "oaks_aide", "requirement": int(state.get("aide_requirement", 0)),
		"item": int(state.get("aide_item", 0)),
	}
	for arm: String in ["got", "other"]:
		var branch: Dictionary = state.duplicate()
		branch["aide_outcome"] = Gen1Layout.OAKS_AIDE_GOT_ITEM if arm == "got" else 0
		var walked: Variant = _walk_script(ctx, next, branch, depth + 1)
		node[arm] = walked if walked is Array else [{"op": "unknown"}]
	out.append(node)
	return out


## `Route23DefaultScript`: the guard on the player's row and the check flag
## `c` counts down to.
static func _script_special_body(ctx: Dictionary, pc: int) -> Variant:
	var layout: Dictionary = ctx["layout"]
	var rom: RomFile = ctx["rom"]
	var at: int = Gen1Layout.banked(int(ctx["bank"]), pc)
	if pc == int(layout.get("update_gym_gates", -1)):
		return _script_gym_gates(ctx)
	if at != int(layout.get("route23_default_script", -1)):
		return null
	var guards: int = Gen1Layout.banked(int(ctx["bank"]), rom.u16le(at + 1))
	var rows: Array = []
	var bits: int = -1
	var flags: int = -1
	var compares: Array = []
	var offset: int = 0
	## By instruction: Yellow's table address carries an `ld c` byte.
	while offset < Gen1Layout.ROUTE23_SCAN and Gen1Layout.ROUTE23_OPCODE_SIZES.has(rom.u8(at + offset)):
		var op: int = rom.u8(at + offset)
		if op == Gen1Layout.SCRIPT_LD_C and bits < 0:
			bits = rom.u8(at + offset + 1)
		if op == Gen1Layout.SCRIPT_LD_HL and _script_flag(ctx, rom.u16le(at + offset + 1), 0) >= 0:
			flags = _script_flag(ctx, rom.u16le(at + offset + 1), 0)
		if op == Gen1Layout.SCRIPT_CP_N and rom.u8(at + offset + 1) != Gen1Layout.MAP_COORD_END:
			compares.append(rom.u8(at + offset + 1))
		offset += int(Gen1Layout.ROUTE23_OPCODE_SIZES[op])
	if bits < 0 or flags < 0 or compares.size() < 2:
		return null
	var texts: int = int(layout["route23_badge_texts"])
	var index: int = 0
	while rom.u8(guards + index) != Gen1Layout.MAP_COORD_END:
		var bit: int = bits - index - 1
		var pointer: int = Gen1Layout.banked(int(ctx["bank"]), rom.u16le(texts + bit * Gen1Layout.POINTER_SIZE))
		rows.append({"y": rom.u8(guards + index), "text": index + 1, "flag": flags + bit,
			"badge": Gen1Text.decode(rom.slice(pointer, Gen1Layout.BADGE_NAME_MAX), 0,
				Gen1Layout.BADGE_NAME_MAX)})
		index += 1
	return [{"op": "badge_guards", "rows": rows, "past_y": compares[0], "past_x": compares[1]}]


## The routines a row may call. No node carries a sound, so a cry and the wait
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
	var shaped: int = _script_shaped_routine(ctx, target, state, out)
	if shaped != SCRIPT_NOT_SHAPED:
		return next if shaped == SCRIPT_SHAPE_READ else SCRIPT_UNREAD
	match routine:
		"update_gym_gates":
			out.append_array(_script_gym_gates(ctx))
			return next
		"print_text":
			var box: Dictionary = _script_box(ctx, int(state.get("hl", 0)))
			if box.is_empty():
				return SCRIPT_UNREAD
			out.append(box)
			return SCRIPT_END if bool(ctx.get("first_box", false)) else next
		"text_script_end":
			return SCRIPT_END
		"disable_waiting":
			state["no_press"] = true
			return next
		"yes_no_choice":
			## The YES/NO writes `wCurrentMenuItem` over a menu's own row.
			state.erase("menu_open")
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
		"display_party_menu":
			_script_tested(state, SCRIPT_TESTS_PARTY_MENU, true)
			return next
		"get_party_mon_name":
			out.append({"op": "name_party_mon",
				"buffer": int((ctx["layout"] as Dictionary).get("name_buffer", -1))})
			return next
	return _script_called(ctx, routine, target, state, out, next, depth)


## The rest of [method _script_call]'s own rows.
static func _script_called(
	ctx: Dictionary, routine: String, target: int, state: Dictionary, out: Array,
	next: int, depth: int
) -> int:
	match routine:
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
		"start_simulating_joypad":
			return _script_walk(state, out, next)
		"player_coords_in_array":
			return _script_coord_array(ctx, state, next)
		"call_function_in_table":
			return _script_map_script_table(ctx, state, out, int(state.get("hl", -1)))
		"execute_map_script":
			return _script_map_script_table(ctx, state, out, int(state.get("de", -1)))
		"load_item_list":
			if not state.has("hl"):
				return SCRIPT_UNREAD
			state["item_list"] = int(state["hl"])
			return next
		"add_n_times":
			state.erase("hl")
			state["menu_rows"] = true
			return next
		"text_box_border":
			return _script_menu_box(ctx, state, next)
		"place_string":
			return _script_menu_string(ctx, state, next)
		"handle_menu_input":
			return _script_menu(state, out, next)
		"display_list_menu":
			return _script_list_menu(ctx, state, out, next, depth)
	return _script_called_more(ctx, routine, target, state, out, next, depth)


static func _script_called_more(
	ctx: Dictionary, routine: String, target: int, state: Dictionary, out: Array,
	next: int, depth: int
) -> int:
	match routine:
		"fill_memory":
			return _script_fill_memory(ctx, state, out, next)
		"sprite_pointer_1", "sprite_pointer_2":
			return _script_sprite_pointer(ctx, routine, state, next)
		"init":
			out.append({"op": "reset_game"})
			return SCRIPT_END
		"save_end_battle_text":
			return _script_end_battle_texts(ctx, state, next)
		"engage_map_trainer":
			return _script_engage_trainer(state, out, next)
		"check_boulder_coords":
			return _script_boulder_coords(ctx, state, next)
		"set_sprite_position":
			return _script_sprite_position(state, out, next)
		"get_mon_name":
			return _script_name_species(ctx, state, out, next)
		"get_item_name":
			var layout: Dictionary = ctx["layout"]
			var named: Dictionary = {"op": "name_item", "buffer": int(layout.get("name_buffer", -1))}
			if state.has("named_index"):
				named["item"] = int(state["named_index"])
			elif int(state.get("named_source", -1)) == int(layout.get("fossil_item", -1)):
				named["from"] = "fossil_item"
			else:
				return SCRIPT_UNREAD
			out.append(named)
			state["de"] = int(layout.get("name_buffer", -1))
			return next
		"copy_to_string_buffer":
			## `wNameBuffer` into `wStringBuffer`: one box names two things.
			out.append({"op": "copy_name",
				"from": int((ctx["layout"] as Dictionary).get("name_buffer", -1)),
				"to": int((ctx["layout"] as Dictionary).get("string_buffer", -1))})
			return next
		"add_party_mon":
			return _script_party_mon(ctx, state, out, next)
	return _script_sprite_called(ctx, routine, target, state, out, next, depth)


static func _script_name_species(
	ctx: Dictionary, state: Dictionary, out: Array, next: int
) -> int:
	var layout: Dictionary = ctx["layout"]
	if state.has("named_index"):
		var dex: int = Gen1Layout.dex_of_index(ctx["rom"], layout, int(state["named_index"]))
		if dex < 1:
			return SCRIPT_UNREAD
		out.append({"op": "name_species", "species": dex})
		return next
	for source: String in ["player_starter", "fossil_mon"]:
		if int(state.get("named_source", -1)) == int(layout.get(source, -1)):
			out.append({"op": "name_species", "from": source,
				"buffer": int(layout.get("name_buffer", -1))})
			return next
	return SCRIPT_UNREAD


## `AddPartyMon` for the starter: the party is empty, so nothing asks about room.
static func _script_party_mon(
	ctx: Dictionary, state: Dictionary, out: Array, next: int
) -> int:
	if not state.has("species_index") or not state.has("level"):
		return SCRIPT_UNREAD
	var dex: int = Gen1Layout.dex_of_index(ctx["rom"], ctx["layout"], int(state["species_index"]))
	if dex < 1:
		return SCRIPT_UNREAD
	out.append({"op": "give_pokemon", "species": dex, "level": int(state["level"])})
	state.erase("level")
	return next


static func _script_fill_memory(
	ctx: Dictionary, state: Dictionary, out: Array, next: int
) -> int:
	var layout: Dictionary = ctx["layout"]
	if not state.has("a") or not state.has("b") or not state.has("c"):
		return SCRIPT_UNREAD
	var count: int = (int(state["b"]) << 8) | int(state["c"])
	var first: int = _script_flag(ctx, int(state.get("hl", -1)), 0)
	if first >= 0:
		out.append({"op": "flag_range", "first": first, "count": count * 8,
			"set": int(state["a"]) != 0})
		return next
	if int(state.get("hl", -1)) != int(layout["simulated_joypad_end"]):
		return SCRIPT_UNREAD
	if String(state.get("c_symbolic", "")) == Gen1Layout.SCRIPT_SYMBOLIC_COORD_INDEX:
		state["walk_symbolic"] = {"pad": int(state["a"]), "offset": int(state["c"])}
		state.erase("c_symbolic")
		return next
	if count < 1 or count > Gen1Layout.SIMULATED_JOYPAD_MAX:
		return SCRIPT_UNREAD
	var buffer: Array = []
	buffer.resize(count)
	buffer.fill(int(state["a"]))
	state["walk_buffer"] = buffer
	return next


## `UpdateCinnabarGymGateTileBlocks_` counts gates six through one.
static func _script_gym_gates(ctx: Dictionary) -> Array:
	var rom: RomFile = ctx["rom"]
	var table: int = int((ctx["layout"] as Dictionary)["gym_gate_coords"])
	var nodes: Array = []
	for gate: int in range(6, 0, -1):
		var at: int = table + (gate - 1) * 4
		var block: Dictionary = {"op": "replace_block", "x": rom.u8(at),
			"y": rom.u8(at + 1), "block": 0x0E}
		var closed: Dictionary = block.duplicate()
		closed["block"] = rom.u8(at + 2)
		nodes.append({"op": "branch", "flag": 0x2A8 + gate,
			"then": [block], "else": [closed]})
	return nodes


## `hSpriteDataOffset` shares `hWarpDestinationMap`'s byte.
static func _script_sprite_pointer(
	ctx: Dictionary, routine: String, state: Dictionary, next: int
) -> int:
	var layout: Dictionary = ctx["layout"]
	if not state.has("map_text") or not state.has("warp_map"):
		return SCRIPT_UNREAD
	var page: int = 0 if routine == "sprite_pointer_1" \
		else Gen1Layout.SPRITE_SLOTS * Gen1Layout.SPRITE_SLOT_SIZE
	state["hl"] = int(layout["sprite_state_data"]) + page \
		+ int(state["map_text"]) * Gen1Layout.SPRITE_SLOT_SIZE + int(state["warp_map"])
	state.erase("warp_map")
	return next


## `hl` is what the trainer says beaten and `de` what they say winning.
static func _script_end_battle_texts(ctx: Dictionary, state: Dictionary, next: int) -> int:
	var won: Dictionary = _script_box(ctx, int(state.get("hl", -1)))
	var lost: Dictionary = _script_box(ctx, int(state.get("de", -1)))
	if won.is_empty() or lost.is_empty():
		return SCRIPT_UNREAD
	var texts: Dictionary = {"won": String(won["text"]), "lost": String(lost["text"])}
	state["end_texts"] = texts
	if state.has("trainer_node"):
		(state["trainer_node"] as Dictionary)["end_texts"] = texts
	return next


static func _script_engage_trainer(state: Dictionary, out: Array, next: int) -> int:
	var node: Dictionary = {"op": "trainer_battle_object"}
	if state.has("end_texts"):
		node["end_texts"] = state["end_texts"]
	out.append(node)
	state["trainer_node"] = node
	return next


## `CheckBoulderCoords`: the boulder `TryPushingBoulder` last moved, in carry.
static func _script_boulder_coords(ctx: Dictionary, state: Dictionary, next: int) -> int:
	var cells: Array = _script_cell_list(ctx, int(state.get("hl", -1)))
	if cells.is_empty():
		return SCRIPT_UNREAD
	state["cells"] = cells
	state["coord_array"] = true
	_script_tested(state, SCRIPT_TESTS_BOULDER, true)
	return next


static func _script_cell_list(ctx: Dictionary, table: int) -> Array:
	var rom: RomFile = ctx["rom"]
	if table < 0:
		return []
	var at: int = Gen1Layout.banked(int(ctx["bank"]), table)
	var cells: Array = []
	while rom.in_bounds(at, Gen1Layout.MAP_COORD_SIZE) \
		and rom.u8(at) != Gen1Layout.MAP_COORD_END:
		cells.append({"y": rom.u8(at), "x": rom.u8(at + 1)})
		at += Gen1Layout.MAP_COORD_SIZE
	return cells


static func _script_sprite_position(state: Dictionary, out: Array, next: int) -> int:
	if not state.has("sprite_index_wram") or not state.has("sprite_map_y") \
		or not state.has("sprite_map_x"):
		return SCRIPT_UNREAD
	for axis: String in ["y", "x"]:
		out.append({"op": "object_position", "object": int(state["sprite_index_wram"]) - 1,
			"axis": axis, "value": int(state["sprite_map_" + axis])})
	return next


## The four routines a script moves an object with, and the buffer the fifth
## fills for the player. The `...AndDelay` row is six frames of nothing more.
static func _script_sprite_called(
	ctx: Dictionary, routine: String, target: int, state: Dictionary, out: Array,
	next: int, depth: int
) -> int:
	match routine:
		"set_sprite_facing", "set_sprite_facing_delay":
			return _script_object_facing(state, out, next)
		"sprite_stay":
			return _script_object_stay(state, out, next)
		"move_sprite":
			return _script_object_move(ctx, state, out, next)
		"decode_rle":
			return _script_decode_rle(ctx, state, next)
		"decode_arrow_movement":
			return _script_arrow_movement(ctx, state, next)
	var bank: int = int(ctx["bank"])
	var banked: String = _script_banked_routine(ctx["layout"], bank, target)
	if banked in ["safari_low_cost", "safari_nag"]:
		return _script_safari_admission(state, banked, next)
	match banked:
		"coin_box":
			out.append({"op": "coin_box"})
			return next
		"is_player_on_dungeon_warp":
			## The fall is `gen1_dungeon_fall`'s; only `wCoordIndex` is read back.
			var cells: Array = _script_cell_list(ctx, int(state.get("hl", -1)))
			if cells.is_empty():
				return SCRIPT_UNREAD
			out.append({"op": "coord_lookup", "cells": cells})
			state["coord_array"] = true
			return next
	return _script_routine_call(ctx, bank, target, state, out, next, depth)


## `hSpriteIndex` counts the player as slot 0, so an object is one below it.
static func _script_sprite_object(state: Dictionary) -> int:
	return int(state.get("map_text", 0)) - 1 if state.has("map_text") else -1


static func _script_object_facing(state: Dictionary, out: Array, next: int) -> int:
	var object: int = _script_sprite_object(state)
	var facing: int = int(state.get("sprite_facing", -1))
	if object < 0 or not Gen1Layout.FACING_STEPS.has(facing):
		return SCRIPT_UNREAD
	out.append({"op": "object_facing", "object": object, "facing": facing})
	return next


## `SetSpriteMovementBytesToFF` puts STAY over the map's own template: the
## object stops walking and turns where it stands.
static func _script_object_stay(state: Dictionary, out: Array, next: int) -> int:
	var object: int = _script_sprite_object(state)
	if object < 0:
		return SCRIPT_UNREAD
	out.append({"op": "object_stay", "object": object})
	return next


static func _script_object_move(
	ctx: Dictionary, state: Dictionary, out: Array, next: int
) -> int:
	var object: int = _script_sprite_object(state)
	if object < 0:
		return SCRIPT_UNREAD
	if int(state.get("de", -1)) == int((ctx["layout"] as Dictionary).get("npc_movement_directions", -1)):
		if not state.has("npc_path_ready"):
			return SCRIPT_UNREAD
		var path: Dictionary = state["npc_path"]
		out.append({"op": "object_path", "object": object, "target": int(path["target"]),
			"perspective": int(path["perspective"]), "y_adjust": int(path["y_adjust"])})
		state.erase("npc_path")
		state.erase("npc_path_ready")
		return next
	var moves: Array = _script_movement_list(ctx, int(state.get("de", -1)))
	if moves.is_empty():
		return SCRIPT_UNREAD
	out.append({"op": "object_move", "object": object, "moves": moves})
	return next


## `MoveSprite`'s own list, `NPC_MOVEMENT_*` bytes under a $FF. A `de` naming
## WRAM is `FindPathToPlayer`'s answer, which nothing here computes.
static func _script_movement_list(ctx: Dictionary, address: int) -> Array:
	if address < 0 or address >= Gen1Layout.SCRIPT_WRAM_BASE:
		return []
	var rom: RomFile = ctx["rom"]
	var at: int = Gen1Layout.banked(int(ctx["bank"]), address)
	var moves: Array = []
	while rom.in_bounds(at, 1) and moves.size() < Gen1Layout.NPC_MOVEMENT_MAX:
		var byte: int = rom.u8(at)
		if byte == Gen1Layout.NPC_MOVEMENT_END:
			return moves
		if byte & Gen1Layout.NPC_MOVEMENT_LOW_BITS != 0:
			return []
		moves.append(byte >> Gen1Layout.NPC_MOVEMENT_SHIFT)
		at += 1
	return []


## `DecodeRLEList` into `wSimulatedJoypadStatesEnd`, repeats unrolled.
static func _script_decode_rle(ctx: Dictionary, state: Dictionary, next: int) -> int:
	var layout: Dictionary = ctx["layout"]
	var address: int = int(state.get("de", -1))
	if int(state.get("hl", -1)) != int(layout.get("simulated_joypad_end", -1)) \
		or address < 0 or address >= Gen1Layout.SCRIPT_WRAM_BASE:
		return SCRIPT_UNREAD
	var buffer: Variant = _script_rle_list(ctx, address)
	if not buffer is Array:
		return SCRIPT_UNREAD
	state["walk_buffer"] = buffer
	_script_wrote_a(state)
	state["a"] = (buffer as Array).size() + 1
	return next


## One `<value> <repetitions>` list under a $FF as the pads it fills, or null.
static func _script_rle_list(ctx: Dictionary, address: int) -> Variant:
	var rom: RomFile = ctx["rom"]
	var at: int = Gen1Layout.banked(int(ctx["bank"]), address)
	var buffer: Array = []
	while rom.in_bounds(at, Gen1Layout.RLE_PAIR_SIZE) \
		and buffer.size() <= Gen1Layout.SIMULATED_JOYPAD_MAX:
		if rom.u8(at) == Gen1Layout.RLE_END:
			return buffer
		for _repeat: int in rom.u8(at + 1):
			buffer.append(rom.u8(at))
		at += Gen1Layout.RLE_PAIR_SIZE
	return null


## `DecodeArrowMovementRLE`: the `map_coord_movement` row the player stands on
## fills the joypad buffer from its own list, and `a` is $FF when none does.
static func _script_arrow_movement(ctx: Dictionary, state: Dictionary, next: int) -> int:
	var rom: RomFile = ctx["rom"]
	var layout: Dictionary = ctx["layout"]
	if int(state.get("b_source", -1)) != int(layout[Gen1Layout.SCRIPT_COORD_SOURCES[0]]) \
		or int(state.get("c_source", -1)) != int(layout[Gen1Layout.SCRIPT_COORD_SOURCES[1]]):
		return SCRIPT_UNREAD
	var table: int = int(state.get("hl", -1))
	var cells: Array = []
	while table >= 0 and cells.size() < Gen1Layout.ARROW_TILE_MAX:
		var at: int = Gen1Layout.banked(
			int(ctx["bank"]), table + cells.size() * Gen1Layout.ARROW_ROW_SIZE
		)
		if rom.u8(at) == Gen1Layout.MAP_COORD_END:
			break
		var list: Variant = _script_rle_list(
			ctx, rom.u16le(at + Gen1Layout.MAP_COORD_SIZE)
		)
		if not list is Array:
			return SCRIPT_UNREAD
		var moves: Array = _script_walk_moves(
			{"walk_buffer": list, "walk_steps": (list as Array).size()}
		)
		if moves.is_empty():
			return SCRIPT_UNREAD
		cells.append({"y": rom.u8(at), "x": rom.u8(at + 1), "moves": moves})
	if cells.is_empty():
		return SCRIPT_UNREAD
	state["arrows"] = cells
	_script_wrote_a(state)
	state.erase("a")
	return next


## `StartSimulatingJoypadStates`, whose buffer is one walking step per entry.
static func _script_walk(state: Dictionary, out: Array, next: int) -> int:
	## The `arrow_movement` node behind it carries every row's legs already.
	if state.has("arrows"):
		return next
	if not state.has("walk_buffer") and not state.has("walk_symbolic"):
		state["walk_pending"] = true
		return next
	if state.has("walk_symbolic"):
		var symbolic: Dictionary = state["walk_symbolic"]
		if not Gen1Layout.PAD_DIRECTIONS.has(int(symbolic["pad"])):
			return SCRIPT_UNREAD
		out.append({"op": "walk", "moves": [
			{"direction": int(Gen1Layout.PAD_DIRECTIONS[int(symbolic["pad"])]), "steps": 0},
		], "steps_offset": int(symbolic["offset"])})
		state.erase("walk_symbolic")
		state.erase("walk_steps_symbolic")
		return next
	var moves: Array = _script_walk_moves(state)
	if moves.is_empty():
		return SCRIPT_UNREAD
	out.append({"op": "walk", "moves": moves})
	state.erase("walk_buffer")
	state.erase("walk_steps")
	return next


## `GetSimulatedInput` counts the index down before it reads the buffer at what
## is left, so the entries are spent back to front; a run of one pad is a leg.
static func _script_walk_moves(state: Dictionary) -> Array:
	var buffer: Array = state.get("walk_buffer", [])
	var count: int = int(state.get("walk_steps", 0))
	if count < 1 or count > buffer.size():
		return []
	var moves: Array = []
	for index: int in count:
		var pad: int = int(buffer[count - 1 - index])
		if not Gen1Layout.PAD_DIRECTIONS.has(pad):
			return []
		var direction: int = int(Gen1Layout.PAD_DIRECTIONS[pad])
		var leg: Dictionary = moves[-1] if not moves.is_empty() else {}
		if int(leg.get("direction", -1)) == direction:
			leg["steps"] = int(leg["steps"]) + 1
			continue
		moves.append({"direction": direction, "steps": 1})
	return moves


## `ArePlayerCoordsInArray`: the `db y, x` list `hl` names, terminated by $FF,
## and carry for the player standing on one of its rows.
static func _script_coord_array(ctx: Dictionary, state: Dictionary, next: int) -> int:
	var rom: RomFile = ctx["rom"]
	var at: int = Gen1Layout.banked(int(ctx["bank"]), int(state.get("hl", -1)))
	var cells: Array = []
	while rom.in_bounds(at, Gen1Layout.MAP_COORD_SIZE) \
		and rom.u8(at) != Gen1Layout.MAP_COORD_END:
		cells.append({"y": rom.u8(at), "x": rom.u8(at + 1)})
		at += Gen1Layout.MAP_COORD_SIZE
	if cells.is_empty():
		return SCRIPT_UNREAD
	state["cells"] = cells
	state["coord_array"] = true
	_script_tested(state, SCRIPT_TESTS_COORD_ARRAY, true)
	return next


## `CallFunctionInTable` and `ExecuteCurMapScriptInTable`: the map's own state
## machine, whose table is in `hl` for one and `de` for the other and whose
## index is the `w<Map>CurScript` byte the `ld a` above it read.
static func _script_map_script_table(
	ctx: Dictionary, state: Dictionary, out: Array, table: int
) -> int:
	var byte: int = _map_script_byte(ctx["layout"], int(state.get("source", -1)))
	if table < 0:
		return SCRIPT_UNREAD
	if byte < 0 and state.has("a") and not state.has("source"):
		var rom: RomFile = ctx["rom"]
		var target: int = rom.u16le(Gen1Layout.banked(
			int(ctx["bank"]), table + int(state["a"]) * Gen1Layout.POINTER_SIZE
		))
		return _script_routine_call(ctx, int(ctx["bank"]), target, state, out, SCRIPT_END, 0)
	if byte < 0:
		return SCRIPT_UNREAD
	out.append({"op": "map_script_table", "table": table, "byte": byte})
	return SCRIPT_END


## `<Map>_Script` copies `wCurMapScript` into the map's own byte on the next
## frame, and Viridian Gym and the two Rocket Hideout floors write nothing else.
## The dispatch names that byte, so [method _bind_map_script_byte] fills it in.
static func _script_map_script_mirror(state: Dictionary, out: Array) -> bool:
	if not state.has("a"):
		return false
	var value: int = int(state["a"])
	if not out.is_empty():
		var last: Dictionary = out[-1]
		if String(last["op"]) == "set_map_script" and int(last["value"]) == value:
			return true
	out.append({"op": "set_map_script", "byte": MAP_SCRIPT_MIRROR, "value": value})
	return true


## Every unbound mirror store in [param nodes], as the map's own byte.
static func _bind_map_script_byte(nodes: Array, byte: int) -> void:
	for node: Dictionary in nodes:
		if String(node["op"]) == "set_map_script" and int(node["byte"]) == MAP_SCRIPT_MIRROR:
			node["byte"] = byte
		for key: String in Gen1Layout.SCRIPT_BRANCH_KEYS:
			if node.has(key):
				_bind_map_script_byte(node[key] as Array, byte)


static func _map_script_byte(layout: Dictionary, address: int) -> int:
	var base: int = int(layout["map_scripts"])
	if address < base or address >= base + Gen1Layout.MAP_SCRIPT_BYTES:
		return -1
	return address - base


## A `call` to a routine the layout does not name, walked in [param bank] and
## returned from: `MtMoonB2FReceivedFossilText` is an `ld hl` and a tail
## `jp PrintText`, and Yellow keeps 22 rows behind a `callfar`.
static func _script_routine_call(
	ctx: Dictionary, bank: int, target: int, state: Dictionary, out: Array,
	next: int, depth: int
) -> int:
	var banked: String = _script_banked_routine(ctx["layout"], bank, target)
	if banked in Gen1Layout.SCRIPT_SILENT_BANKED_CALLS:
		return next
	match banked:
		"route23_copy_badge_text":
			return _script_name_badge(ctx, state, out, next)
		"name_rater_check_ot":
			_script_tested(state, SCRIPT_TESTS_MON_OT, true)
			return next
		"name_rater_screen":
			state["entry_buffer"] = int((ctx["layout"] as Dictionary).get("entry_buffer", -1))
			_script_tested(state, SCRIPT_TESTS_NAME_ENTRY, true)
			return next
	var named: int = _script_predef_named(
		ctx["layout"], Gen1Layout.banked(bank, target), state, out
	)
	if named >= 0:
		return next if named == STORE_OK else SCRIPT_UNREAD
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


static func _script_name_badge(ctx: Dictionary, state: Dictionary, out: Array, next: int) -> int:
	if not state.has("which_badge"):
		return SCRIPT_UNREAD
	var rom: RomFile = ctx["rom"]
	var texts: int = int((ctx["layout"] as Dictionary)["route23_badge_texts"])
	var pointer: int = Gen1Layout.banked(
		int(ctx["bank"]), rom.u16le(texts + int(state["which_badge"]) * Gen1Layout.POINTER_SIZE)
	)
	out.append({"op": "name_badge", "name": Gen1Text.decode(
		rom.slice(pointer, Gen1Layout.BADGE_NAME_MAX), 0, Gen1Layout.BADGE_NAME_MAX
	)})
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
	var layout: Dictionary = ctx["layout"]
	if not state.has("c") or int(state["c"]) < 1:
		return SCRIPT_UNREAD
	if int(state.get("b_source", -1)) == int(layout.get("fossil_mon", -1)):
		out.append({"op": "give_pokemon", "from": "fossil_mon", "level": int(state["c"])})
		state.erase("b_source")
		state.erase("c")
		_script_tested(state, SCRIPT_TESTS_CARRY)
		return next
	if not state.has("b"):
		return SCRIPT_UNREAD
	var dex: int = Gen1Layout.dex_of_index(ctx["rom"], layout, int(state["b"]))
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
	if bank >= 0 and target >= 0 \
		and RomFile.linear(bank, target) == int(layout.get("display_town_map", -1)):
		out.append({"op": "town_map"})
		return next
	if bank >= 0 and target >= 0 \
		and RomFile.linear(bank, target) == int(layout.get("remove_guard_drink", -1)):
		state["drinks"] = _script_guard_drinks(ctx, bank, target)
		return next
	if bank != int(layout["remove_item_bank"]) or target != int(layout["remove_item"]):
		return _script_routine_call(ctx, bank, target, state, out, next, depth)
	if int(state.get("remove", 0)) < 1 and int(state.get("remove", 0)) not in [
		Gen1Layout.SCRIPT_MENU_ITEM_SOURCE, Gen1Layout.SCRIPT_FOSSIL_ITEM_SOURCE,
	]:
		return SCRIPT_UNREAD
	out.append({"op": "take_item", "item": int(state["remove"])})
	state.erase("remove")
	return next


## `GuardDrinksList`, off `RemoveGuardDrink`'s own opening `ld hl`. The routine
## spends the first row the bag holds, so the list and its test are one node.
static func _script_guard_drinks(ctx: Dictionary, bank: int, target: int) -> Array:
	var rom: RomFile = ctx["rom"]
	var list: int = rom.u16le(Gen1Layout.banked(bank, target) + 1)
	var out: Array = []
	while out.size() < Gen1Layout.GUARD_DRINK_MAX:
		var item: int = rom.u8(Gen1Layout.banked(bank, list + out.size()))
		if item < 1:
			break
		out.append(item)
	return out


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
			state["which_badge"] = int(state["a"])
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


## Yellow's two admission routines, each printing its lines, deciding a ball
## count and answering carry when it hands nothing over.
static func _script_safari_admission(state: Dictionary, routine: String, next: int) -> int:
	## Both return `ld hl, 502` with the count in `a`, so only the count is here.
	state.erase("a")
	state["hl"] = Gen1Layout.SAFARI_STEPS
	state["safari_admission"] = routine.trim_prefix("safari_")
	_script_tested(state, SCRIPT_TESTS_SAFARI_ADMISSION, true)
	return next


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
	if target == int(layout["replace_tile_block"]):
		return _script_replace_block(state, out, next)
	if target == int(layout.get("elevator_floor_menu", -1)):
		return _script_elevator(ctx, state, out, next)
	var named: int = _script_predef_named(layout, target, state, out)
	if named == STORE_BRANCHED:
		return SCRIPT_AIDE
	if named >= 0:
		return next if named == STORE_OK else SCRIPT_UNREAD
	var hidden: bool = target == int(layout["hide_object"])
	if not state.has("toggle") \
		or (not hidden and target != int(layout["show_object"])):
		return SCRIPT_UNREAD
	out.append({"op": "toggle_object", "index": int(state["toggle"]), "hidden": hidden})
	state.erase("toggle")
	return next


static func _script_predef_named(
	layout: Dictionary, target: int, state: Dictionary, out: Array
) -> int:
	match _script_predef_name(layout, target):
		"emotion_bubble":
			if not state.has("emote_object") or not state.has("emote_kind"):
				return STORE_REFUSED
			out.append({"op": "emote", "object": int(state["emote_object"]) - 1,
				"kind": int(state["emote_kind"])})
		"calc_player_relative":
			if not state.has("npc_sprite_offset"):
				return STORE_REFUSED
			state["npc_path"] = {
				"target": (int(state["npc_sprite_offset"]) >> 4) - 1,
				"perspective": int(state.get("npc_perspective", 0)), "y_adjust": 0,
			}
		"find_path_to_player":
			if not state.has("npc_path"):
				return STORE_REFUSED
			state["npc_path_ready"] = true
		"hall_of_fame_pc":
			out.append({"op": "hall_of_fame"})
		"save_game_data":
			out.append({"op": "save_game"})
		"heal_party":
			out.append({"op": "heal_party"})
		"pewter_guys", "convert_npc_directions":
			pass
		"get_item_quantity":
			if not state.has("b"):
				return STORE_REFUSED
			state["asked"] = int(state["b"])
			state.erase("b")
			state["b_source"] = Gen1Layout.SCRIPT_ITEM_QUANTITY_SOURCE
		"flag_action":
			return _script_flag_action(layout, state, out)
		"starter_dex":
			if not state.has("species_index"):
				return STORE_REFUSED
			out.append({"op": "pokedex", "species": int(state["species_index"])})
		"display_dex_rating":
			out.append({"op": "dex_rating"})
		"oaks_aide":
			return STORE_BRANCHED
		_:
			return STORE_NOT_NAMED
	return STORE_OK


const STORE_BRANCHED: int = 2


## `FlagActionPredef`'s test answers in `c`.
static func _script_flag_action(layout: Dictionary, state: Dictionary, out: Array) -> int:
	if not state.has("b") or not state.has("c") or not state.has("hl"):
		return STORE_REFUSED
	var ctx: Dictionary = {"layout": layout}
	var flag: int = _script_flag(ctx, int(state["hl"]), int(state["c"]))
	var engine: bool = flag < 0
	var runtime: int = int(state.get("c_runtime", -1))
	if engine:
		flag = _script_engine_flag(ctx, int(state["hl"]), int(state["c"]))
	if flag < 0:
		return STORE_REFUSED
	match int(state["b"]):
		Gen1Layout.FLAG_ACTION_TEST:
			state["c_offset"] = int(state["c"])
			state.erase("c")
			state["c_source"] = Gen1Layout.SCRIPT_FLAG_ACTION_SOURCE
			state["flag_action"] = [flag, engine, runtime, int(state.get("c_offset", 0))]
		Gen1Layout.FLAG_ACTION_SET, Gen1Layout.FLAG_ACTION_RESET:
			var node: Dictionary = {"op": "flag", "flag": flag,
				"set": int(state["b"]) == Gen1Layout.FLAG_ACTION_SET}
			if engine:
				node["engine"] = true
			if runtime >= 0:
				node["index_source"] = runtime
				node["index_offset"] = int(state["c"])
				node["flag"] = flag - int(state["c"])
			out.append(node)
		_:
			return STORE_REFUSED
	return STORE_OK


static func _script_predef_name(layout: Dictionary, target: int) -> String:
	for name: String in Gen1Layout.SCRIPT_BANKED_CALLS:
		if int(layout.get(name, -1)) == target:
			return name
	return ""


## `DisplayElevatorFloorMenu`, reached with `LoadItemList`'s floor names behind
## it and `hl` on `.UpdateWarp`'s own warp table, whose bytes are already the
## 0-based index `warp_event`'s `\4 - 1` stores.
static func _script_elevator(
	ctx: Dictionary, state: Dictionary, out: Array, next: int
) -> int:
	if not state.has("item_list") or not state.has("hl"):
		return SCRIPT_UNREAD
	var rom: RomFile = ctx["rom"]
	var bank: int = int(ctx["bank"])
	var list: int = Gen1Layout.banked(bank, int(state["item_list"]))
	var count: int = rom.u8(list)
	if count <= 0 or count > Gen1Layout.ELEVATOR_MAX_FLOORS \
		or rom.u8(list + 1 + count) != Gen1Layout.ELEVATOR_FLOOR_END:
		return SCRIPT_UNREAD
	var maps: int = Gen1Layout.banked(bank, int(state["hl"]))
	var floors: Array = []
	for index: int in count:
		floors.append({
			"floor": rom.u8(list + 1 + index),
			"warp": rom.u8(maps + index * Gen1Layout.ELEVATOR_WARP_SIZE),
			"map": rom.u8(maps + index * Gen1Layout.ELEVATOR_WARP_SIZE + 1),
		})
	out.append({"op": "elevator", "floors": floors})
	state.erase("item_list")
	return next


const SCRIPT_NOT_SHAPED: int = 0
const SCRIPT_SHAPE_READ: int = 1
const SCRIPT_SHAPE_REFUSED: int = 2


## Three loops a walk cannot step through, each read by the bytes it opens with
## rather than by an address: `<Map>Script_Get*InBag` filters a `db` run through
## `GetQuantityOfItemInBag`, `Print*InBag` draws what is left, and
## `OaksLabScript_RemoveParcel` spends one bag row.
static func _script_shaped_routine(
	ctx: Dictionary, target: int, state: Dictionary, out: Array
) -> int:
	var layout: Dictionary = ctx["layout"]
	var rom: RomFile = ctx["rom"]
	var at: int = Gen1Layout.banked(int(ctx["bank"]), target)
	if rom.u8(at) != Gen1Layout.SCRIPT_LD_HL and rom.u8(at) != Gen1Layout.SCRIPT_XOR_A:
		return SCRIPT_NOT_SHAPED
	var items: int = int(layout.get("filtered_bag_items", -1))
	if rom.u8(at) == Gen1Layout.SCRIPT_LD_HL and rom.u16le(at + 1) == items:
		return _script_filter_printed(ctx, at, state)
	if rom.u8(at) == Gen1Layout.SCRIPT_LD_HL and rom.u16le(at + 1) == int(layout.get("bag_items", -1)):
		return _script_bag_scan(ctx, at, out)
	if rom.u8(at) != Gen1Layout.SCRIPT_XOR_A \
		or rom.u8(at + 1) != Gen1Layout.SCRIPT_LD_MEM_A \
		or rom.u16le(at + 2) != int(layout.get("filtered_bag_count", -1)) \
		or rom.u8(at + 4) != Gen1Layout.SCRIPT_LD_DE or rom.u16le(at + 5) != items \
		or rom.u8(at + 7) != Gen1Layout.SCRIPT_LD_HL:
		return SCRIPT_NOT_SHAPED
	var list: int = Gen1Layout.banked(int(ctx["bank"]), rom.u16le(at + 8))
	var rows: Array = []
	while rows.size() < Gen1Layout.FILTERED_BAG_MAX and rom.u8(list + rows.size()) > 0:
		rows.append(rom.u8(list + rows.size()))
	if rows.is_empty():
		return SCRIPT_SHAPE_REFUSED
	state["filtered"] = rows
	return SCRIPT_SHAPE_READ


static func _script_bag_scan(ctx: Dictionary, at: int, out: Array) -> int:
	var rom: RomFile = ctx["rom"]
	var layout: Dictionary = ctx["layout"]
	var item: int = -1
	var taken: bool = false
	for offset: int in Gen1Layout.BAG_SCAN_SIZE:
		var op: int = rom.u8(at + offset)
		if item < 1 and op == Gen1Layout.SCRIPT_CP_N \
			and rom.u8(at + offset + 1) != Gen1Layout.MAP_COORD_END:
			item = rom.u8(at + offset + 1)
		taken = taken or (op == Gen1Layout.SCRIPT_JP \
			and rom.u16le(at + offset + 1) == int(layout.get("remove_item_from_inventory", -1)))
	if item < 1 or not taken:
		return SCRIPT_SHAPE_REFUSED
	out.append({"op": "take_item", "item": item})
	return SCRIPT_SHAPE_READ


static func _script_filter_printed(ctx: Dictionary, at: int, state: Dictionary) -> int:
	if not state.has("filtered"):
		return SCRIPT_NOT_SHAPED
	var rom: RomFile = ctx["rom"]
	var layout: Dictionary = ctx["layout"]
	for offset: int in range(Gen1Layout.SCRIPT_LONG_SIZE, Gen1Layout.FILTER_PRINT_SCAN):
		if rom.u8(at + offset) != Gen1Layout.SCRIPT_LD_HL:
			continue
		var cell: int = _script_screen_cell(layout, rom.u16le(at + offset + 1))
		if cell < 0:
			continue
		state["filtered_at"] = {
			"y": cell / Gen1Layout.SCREEN_WIDTH_TILES,
			"x": cell % Gen1Layout.SCREEN_WIDTH_TILES,
		}
		return SCRIPT_SHAPE_READ
	return SCRIPT_SHAPE_REFUSED


## `CeruleanBadgeHouseMiddleAgedManText`, the one `SPECIALLISTMENU` outside an
## elevator: badges, a text table the row indexes, and a `jr .loop` onto the
## list, which is one node because a walk cannot return to itself.
static func _script_list_menu(
	ctx: Dictionary, state: Dictionary, out: Array, next: int, depth: int
) -> int:
	if not state.has("item_list"):
		return SCRIPT_UNREAD
	var rom: RomFile = ctx["rom"]
	var bank: int = int(ctx["bank"])
	var at: int = Gen1Layout.banked(bank, next)
	if rom.u8(at) != Gen1Layout.SCRIPT_JR_CARRY \
		or rom.u8(at + 2) != Gen1Layout.SCRIPT_LD_HL \
		or rom.u8(at + 5) != Gen1Layout.SCRIPT_LD_A_MEM \
		or rom.u8(at + 8) != Gen1Layout.SCRIPT_SUB_N:
		return SCRIPT_UNREAD
	var texts: int = rom.u16le(at + 3)
	var base: int = rom.u8(at + 9)
	var list: int = Gen1Layout.banked(bank, int(state["item_list"]))
	var count: int = rom.u8(list)
	if count < 1 or count > Gen1Layout.LIST_MENU_MAX:
		return SCRIPT_UNREAD
	var rows: Array = []
	for index: int in count:
		var item: int = rom.u8(list + 1 + index)
		var pointer: int = rom.u16le(
			Gen1Layout.banked(bank, texts + (item - base) * Gen1Layout.POINTER_SIZE)
		)
		var box: Dictionary = _script_box(ctx, pointer)
		if item < base or box.is_empty():
			return SCRIPT_UNREAD
		rows.append({"item": item, "text": String(box["text"])})
	var done: Variant = _walk_script(
		ctx, next + Gen1Layout.SCRIPT_SHORT_SIZE + _script_hop(rom.u8(at + 1)),
		state.duplicate(), depth + 1
	)
	if not done is Array:
		return SCRIPT_UNREAD
	out.append({"op": "list_menu", "rows": rows, "done": done})
	state.erase("item_list")
	return SCRIPT_END


## `TextBoxBorder`: `hl` is the corner, `b` and `c` the interior; a box sized off
## the filtered count has no readable `b` and counts two rows an entry.
static func _script_menu_box(ctx: Dictionary, state: Dictionary, next: int) -> int:
	var layout: Dictionary = ctx["layout"]
	var corner: int = _script_screen_cell(layout, int(state.get("hl", -1)))
	if corner < 0 or not state.has("c"):
		return SCRIPT_UNREAD
	state["menu_box"] = {
		"y": corner / Gen1Layout.SCREEN_WIDTH_TILES,
		"x": corner % Gen1Layout.SCREEN_WIDTH_TILES,
		"width": int(state["c"]),
		"height": int(state["b"]) if state.has("b") \
			else Gen1Layout.SCRIPT_MENU_SIZED_BY_COUNT,
	}
	state["menu_strings"] = []
	state["menu_labels"] = []
	state.erase("menu_rows")
	return next


static func _script_screen_cell(layout: Dictionary, address: int) -> int:
	var cell: int = address - int(layout.get("tile_map", -1))
	var cells: int = Gen1Layout.SCREEN_WIDTH_TILES * Gen1Layout.SCREEN_HEIGHT_TILES
	return cell if address >= 0 and cell >= 0 and cell < cells else -1


static func _script_menu_string(ctx: Dictionary, state: Dictionary, next: int) -> int:
	if not state.has("menu_box") or not state.has("de"):
		return SCRIPT_UNREAD
	var layout: Dictionary = ctx["layout"]
	var cell: int = _script_screen_cell(layout, int(state.get("hl", -1)))
	if cell < 0:
		return SCRIPT_UNREAD
	var rom: RomFile = ctx["rom"]
	var at: int = Gen1Layout.banked(int(ctx["bank"]), int(state["de"]))
	var text: String = Gen1Text.decode(
		rom.slice(at, Gen1Layout.MENU_STRING_MAX), 0, Gen1Layout.MENU_STRING_MAX
	)
	var rows: PackedStringArray = text.split(Gen1Layout.MENU_ROW_BREAK)
	var placed: Dictionary = {
		"y": cell / Gen1Layout.SCREEN_WIDTH_TILES,
		"x": cell % Gen1Layout.SCREEN_WIDTH_TILES,
		"rows": rows,
	}
	var key: String = "menu_strings" if rows.size() > 1 else "menu_labels"
	(state[key] as Array).append(placed)
	return next


## `HandleMenuInput`, which owns every step behind it as a `YesNoChoice` does.
static func _script_menu(state: Dictionary, out: Array, next: int) -> int:
	if not state.has("menu_box"):
		return SCRIPT_UNREAD
	var node: Dictionary = {"op": "menu", "box": state["menu_box"]}
	var strings: Array = state.get("menu_strings", [])
	if state.has("filtered"):
		node["filter"] = (state["filtered"] as Array).duplicate()
		node["entries_at"] = state.get("filtered_at", {})
	elif not strings.is_empty():
		node["entries_at"] = {"y": int(strings[0]["y"]), "x": int(strings[0]["x"])}
		node["entries"] = (strings[0] as Dictionary)["rows"]
	else:
		return SCRIPT_UNREAD
	node["labels"] = state.get("menu_labels", [])
	out.append(node)
	state["menu_open"] = true
	for key: String in ["menu_box", "menu_strings", "menu_labels", "a", "source"]:
		state.erase(key)
	return next


## `ReplaceTileBlock`, which is how a map draws a door, a gate or an exit its
## own block data has none of.
static func _script_replace_block(state: Dictionary, out: Array, next: int) -> int:
	if not state.has("new_block") or not state.has("b") or not state.has("c"):
		return SCRIPT_UNREAD
	out.append({
		"op": "replace_block", "block": int(state["new_block"]),
		"y": int(state["b"]), "x": int(state["c"]),
	})
	state.erase("new_block")
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
## does not read becomes an `unknown` node the runtime can do nothing with.
static func _script_branch(
	ctx: Dictionary, op: int, pc: int, state: Dictionary, depth: int, out: Array
) -> Variant:
	var tests: Variant = state.get("tests", SCRIPT_TESTS_NOTHING)
	var carry: bool = Gen1Layout.SCRIPT_CARRY_BRANCHES.has(op)
	if state.has("known_zero") and not carry:
		return _script_known_branch(ctx, op, pc, state, depth, out)
	var settled: Variant = null if carry else _script_domain_settled(ctx, state, tests)
	if settled != null:
		state["known_zero"] = bool(settled)
		return _script_known_branch(ctx, op, pc, state, depth, out)
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
	if not carry:
		_script_domain_learn(state, tests, jumped_state if bool(table[op]) else fell_state,
			fell_state if bool(table[op]) else jumped_state)
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


## A branch whose zero flag the walk already knows: only the side taken is
## walked, and it carries on in front of whatever the caller has read already.
static func _script_known_branch(
	ctx: Dictionary, op: int, pc: int, state: Dictionary, depth: int, out: Array
) -> Variant:
	var rom: RomFile = ctx["rom"]
	var at: int = Gen1Layout.banked(int(ctx["bank"]), pc)
	var short: bool = op < Gen1Layout.SCRIPT_HOP_LIMIT
	var size: int = Gen1Layout.SCRIPT_SHORT_SIZE if short else Gen1Layout.SCRIPT_LONG_SIZE
	var jumps: bool = bool(Gen1Layout.SCRIPT_BRANCHES[op]) != bool(state["known_zero"])
	var target: int = pc + size
	if jumps:
		target = pc + size + _script_hop(rom.u8(at + 1)) if short else rom.u16le(at + 1)
	state.erase("known_zero")
	var walked: Variant = _walk_script(ctx, target, state, depth)
	if walked == null:
		return null
	out.append_array(walked as Array)
	return out


## A conditional `ret`: the side that returns prints nothing.
static func _script_ret_branch(
	ctx: Dictionary, op: int, pc: int, state: Dictionary, depth: int, out: Array
) -> Variant:
	var tests: Variant = state.get("tests", SCRIPT_TESTS_NOTHING)
	var carry: bool = Gen1Layout.SCRIPT_RET_CARRY_BRANCHES.has(op)
	var table: Dictionary = Gen1Layout.SCRIPT_RET_CARRY_BRANCHES if carry \
		else Gen1Layout.SCRIPT_RET_BRANCHES
	if state.has("known_zero") and not carry:
		if bool(table[op]) != bool(state["known_zero"]):
			return _script_ended(state, out)
		state.erase("known_zero")
		return _script_walked_on(ctx, pc + 1, state, depth, out)
	if not _script_reads_flag(state, tests, carry):
		return null
	var walked: Variant = _walk_script(ctx, pc + 1, state.duplicate(), depth + 1)
	if walked == null:
		return null
	var branches: Array = [[], walked]
	if not bool(table[op]):
		branches.reverse()
	var node: Variant = _script_node(tests, branches, state, out, carry)
	if node == null:
		return null
	out.append(node)
	return out


## The rest of a path, appended to what the caller has read already.
static func _script_walked_on(
	ctx: Dictionary, pc: int, state: Dictionary, depth: int, out: Array
) -> Variant:
	var walked: Variant = _walk_script(ctx, pc, state, depth)
	if walked == null:
		return null
	out.append_array(walked as Array)
	return out


## `cp n` against the faced direction, the species count `CountSetBits` left,
## the map's tileset, one screen position or where the player stands; anything
## else ends the path.
static func _script_compared(
	ctx: Dictionary, pc: int, state: Dictionary, value: int
) -> int:
	var layout: Dictionary = ctx["layout"]
	var source: int = int(state.get("source", -1))
	var next: int = pc + Gen1Layout.SCRIPT_SHORT_SIZE
	if _script_compared_byte(layout, state, source, value):
		return next
	## `CheckBothEventsSet` is `and mask` with `cp mask` behind it: every flag.
	if state.get("tests") is Array and value == int(state.get("mask", -1)):
		state["tests_all"] = true
		return next
	if source in [int(layout.get("saved_coord_index", -1)), int(layout["item_to_remove"])]:
		state["coord_index"] = value
		_script_tested(state, SCRIPT_TESTS_SAVED_INDEX)
		return next
	var outcome: String = Gen1Layout.script_battle_outcome(layout, source, value)
	if not outcome.is_empty():
		state["outcome"] = outcome
		_script_tested(state, SCRIPT_TESTS_BATTLE)
		return next
	if state.has("arrows") and value == Gen1Layout.MAP_COORD_END:
		_script_tested(state, SCRIPT_TESTS_ARROW)
		return next
	if source == Gen1Layout.SCRIPT_MENU_ITEM_SOURCE:
		state["menu_item"] = value
		_script_tested(state, SCRIPT_TESTS_MENU_ITEM)
		return next
	if source == int(layout["current_menu_item"]) and bool(state.get("menu_open", false)):
		state["menu_row"] = value
		_script_tested(state, SCRIPT_TESTS_MENU_ROW)
		return next
	## `cp $0` where every other row spends `and a`, YES being 0 either way.
	if source == int(layout["current_menu_item"]) and value == 0:
		_script_test_bit(ctx, state, -1)
		return next
	return _script_compared_more(ctx, state, source, value, next)


static func _script_compared_more(
	ctx: Dictionary, state: Dictionary, source: int, value: int, next: int
) -> int:
	var layout: Dictionary = ctx["layout"]
	if source == int(layout["facing_direction"]):
		state["facing"] = value
		_script_tested(state, SCRIPT_TESTS_FACING)
		return next
	for who: String in ["rival", "player"]:
		if source != int(layout.get(who + "_starter", -1)):
			continue
		state["starter_who"] = who
		state["starter"] = value
		_script_tested(state, SCRIPT_TESTS_STARTER)
		return next
	if source == int(layout["cur_map_tileset"]):
		state["tileset"] = value
		_script_tested(state, SCRIPT_TESTS_TILESET)
		return next
	var screen: int = source - int(layout.get("tile_map", -1))
	if screen >= 0 and screen < Gen1Layout.SCREEN_WIDTH_TILES * Gen1Layout.SCREEN_HEIGHT_TILES:
		state["screen"] = screen
		state["tile"] = value
		_script_tested(state, SCRIPT_TESTS_TILE)
		return next
	for axis: int in Gen1Layout.SCRIPT_COORD_SOURCES.size():
		if source != int(layout[Gen1Layout.SCRIPT_COORD_SOURCES[axis]]):
			continue
		state["axis"] = axis
		state["coord"] = value
		_script_tested(state, SCRIPT_TESTS_COORD)
		return next
	if source == int(layout.get("which_trade", -1)) and state.has("coord_array"):
		state["coord_index"] = value
		_script_tested(state, SCRIPT_TESTS_COORD_INDEX)
		return next
	if source != int(layout["num_set_bits"]):
		return SCRIPT_UNREAD
	state["dex_count"] = value
	_script_tested(state, SCRIPT_TESTS_DEX, true)
	return next


## `cp n` against a byte the walk knows or one the runtime alone holds.
static func _script_compared_byte(
	layout: Dictionary, state: Dictionary, source: int, value: int
) -> bool:
	if state.has("a") and not state.has("source") and not state.has("a_symbolic") \
		and not state.has("a_runtime"):
		_script_untested(state)
		state["known_zero"] = int(state["a"]) == value
		return true
	if source == int(layout.get("text_id_hram", -1)):
		_script_untested(state)
		state["known_zero"] = false
		return true
	var tests: Dictionary = {
		int(layout.get("obtained_badges", -1)): ["badges", SCRIPT_TESTS_BADGES, 0],
		int(layout.get("random_add", -1)): ["random_below", SCRIPT_TESTS_RANDOM, 0],
		int(layout.get("sprite_index_wram", -1)): ["talking", SCRIPT_TESTS_TALKING, -1],
	}
	if source in [int(layout.get("rival_starter_ball", -1)),
		int(layout.get("trainer_header_flag_bit", -1))]:
		state["scratch_test"] = [source, value]
		_script_tested(state, SCRIPT_TESTS_SCRATCH)
		return true
	if not tests.has(source) or source < 0:
		return false
	var row: Array = tests[source]
	state[String(row[0])] = value + int(row[2])
	_script_tested(state, int(row[1]), int(row[1]) == SCRIPT_TESTS_RANDOM)
	return true


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
	## The third row the world owns whole. `TownMapText`'s own code clears
	## `BIT_NO_TEXT_DELAY` and pushes a return address behind `CloseTextDisplay`,
	## and none of that is the screen it opens.
	if at == int((ctx["layout"] as Dictionary).get("town_map_text", -1)):
		out.append({"op": "town_map"})
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
	## `cp` answers in both flags, so a row against a number may read either.
	if int(tests) in [
		SCRIPT_TESTS_COINS, SCRIPT_TESTS_COORD_INDEX, SCRIPT_TESTS_SAVED_INDEX,
		SCRIPT_TESTS_COORD, SCRIPT_TESTS_RANDOM,
	]:
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
	if state.has("tests_snapshot"):
		var all: bool = bool(state.get("tests_all", false))
		return {"op": "branch", "snapshot": int(state["tests_snapshot"]),
			"then": fell if all else taken, "else": taken if all else fell}
	if tests is Array:
		var rest: Array = (tests as Array).slice(1)
		var all: bool = bool(state.get("tests_all", false))
		return {"op": "branch", "flag": int((tests as Array)[0]),
			"all" if all else "either": rest,
			"then": fell if all else taken, "else": taken if all else fell}
	match int(tests):
		SCRIPT_TESTS_INDEXED_FLAG:
			var action: Array = state["flag_action"]
			return {"op": "branch", "flag": int(action[0]) - int(action[3]),
				"index_source": int(action[2]), "index_offset": int(action[3]),
				"then": taken, "else": fell}
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
		SCRIPT_TESTS_SAFARI_ADMISSION:
			## Carry is the refusal, so the `jr c` takes the walk back down.
			return {"op": "safari_admission", "kind": String(state["safari_admission"]),
				"then": fell, "else": taken}
		SCRIPT_TESTS_ANY_MONEY:
			## Z is an empty purse, so the `jr nz` takes the side with money in it.
			return {"op": "has_money", "price": 1, "then": taken, "else": fell}
	return _script_node_compared(tests, taken, fell, state, carry)


## The rest of [method _script_node]'s own rows. A `cp` raises Z on the match,
## so a match is the side the branch did not take.
static func _script_node_compared(
	tests: Variant, taken: Array, fell: Array, state: Dictionary, carry: bool
) -> Variant:
	match int(tests):
		SCRIPT_TESTS_FACING:
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
		SCRIPT_TESTS_COORD:
			return {"op": "player_coord", "axis": int(state["axis"]),
				"value": int(state["coord"]), "test": "below" if carry else "exactly",
				"then": taken if carry else fell, "else": fell if carry else taken}
		SCRIPT_TESTS_COORD_ARRAY:
			return {"op": "player_in_array", "cells": state["cells"],
				"then": taken, "else": fell}
		SCRIPT_TESTS_MOVEMENT:
			return {"op": "movement_running", "who": String(state["movement_who"]),
				"then": taken, "else": fell}
		SCRIPT_TESTS_SAVED_INDEX:
			return {"op": "saved_coord_index", "index": int(state["coord_index"]),
				"test": "below" if carry else "exactly",
				"then": taken if carry else fell, "else": fell if carry else taken}
		SCRIPT_TESTS_COORD_INDEX:
			## A `jr c` takes an earlier row of the list and a `jr z` that row.
			return {"op": "coord_index", "index": int(state["coord_index"]),
				"test": "below" if carry else "exactly",
				"then": taken if carry else fell, "else": fell if carry else taken}
	return _script_node_state(tests, taken, fell, state)


static func _script_node_state(
	tests: Variant, taken: Array, fell: Array, state: Dictionary
) -> Variant:
	match int(tests):
		SCRIPT_TESTS_BATTLE:
			## `cp` raises Z on the match, so the outcome is the other side.
			return {"op": "battle_outcome", "outcome": String(state["outcome"]),
				"then": fell, "else": taken}
		SCRIPT_TESTS_ARROW:
			## `cp $ff` raises Z on no match, so the spin is the other side.
			return {"op": "arrow_movement", "cells": state["arrows"],
				"then": taken, "else": fell}
		SCRIPT_TESTS_GUARD_DRINK:
			return {"op": "guard_drink", "items": state["drinks"],
				"then": taken, "else": fell}
		SCRIPT_TESTS_RIDING:
			return {"op": "riding", "then": taken, "else": fell}
		SCRIPT_TESTS_STARTER:
			return {"op": "starter", "who": String(state["starter_who"]),
				"value": int(state["starter"]), "then": fell, "else": taken}
		SCRIPT_TESTS_MOVEMENT_SCRIPT:
			return {"op": "movement_script_running", "then": taken, "else": fell}
		SCRIPT_TESTS_VOLATILE:
			return {"op": "volatile_test", "name": String(state["volatile"]),
				"then": taken, "else": fell}
		SCRIPT_TESTS_BOULDER:
			return {"op": "boulder_on", "cells": state["cells"], "then": taken, "else": fell}
		SCRIPT_TESTS_BADGES:
			return {"op": "badges_byte", "value": int(state["badges"]),
				"then": fell, "else": taken}
		SCRIPT_TESTS_RANDOM:
			return {"op": "random", "below": int(state["random_below"]),
				"then": taken, "else": fell}
		SCRIPT_TESTS_RANDOM_BIT:
			return {"op": "random_bit", "bit": int(state["random_bit"]),
				"then": taken, "else": fell}
		SCRIPT_TESTS_TALKING:
			return {"op": "talking_to", "object": int(state["talking"]),
				"then": fell, "else": taken}
		SCRIPT_TESTS_SCRATCH:
			return {"op": "scratch_test", "address": int(state["scratch_test"][0]),
				"value": int(state["scratch_test"][1]), "then": fell, "else": taken}
	return _script_node_menu(tests, taken, fell, state)


static func _script_node_menu(
	tests: Variant, taken: Array, fell: Array, state: Dictionary
) -> Variant:
	match int(tests):
		SCRIPT_TESTS_FILTERED:
			return {"op": "filtered_bag", "items": state.get("filtered", []),
				"then": taken, "else": fell}
		SCRIPT_TESTS_MENU_CANCEL:
			return {"op": "menu_cancel", "then": taken, "else": fell}
		SCRIPT_TESTS_MENU_ROW:
			return {"op": "menu_row", "row": int(state["menu_row"]),
				"then": fell, "else": taken}
		SCRIPT_TESTS_MENU_ITEM:
			return {"op": "menu_item", "item": int(state["menu_item"]),
				"then": fell, "else": taken}
		## Carry is CANCEL on all three: B, a foreign OT, an empty entry.
		SCRIPT_TESTS_PARTY_MENU:
			return {"op": "party_menu", "then": taken, "else": fell}
		SCRIPT_TESTS_MON_OT:
			return {"op": "mon_ot", "then": taken, "else": fell}
		SCRIPT_TESTS_NAME_ENTRY:
			return {"op": "name_mon", "buffer": int(state.get("entry_buffer", -1)),
				"then": taken, "else": fell}
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


## A row only a map script reaches stands above every id the map's events name,
## and those are what bound the table: Mt. Moon B2F's tenth row is the super
## nerd's line. True when the table grew and the states want reading again.
static func _extend_texts(
	rom: RomFile, layout: Dictionary, bank: int, address: int, texts: Array,
	events: Dictionary, callback: Dictionary, states: Dictionary
) -> bool:
	var scripts: Array = [states["entry"], callback.get("nodes", [])]
	for row: Dictionary in (states["states"] as Array) + texts:
		scripts.append(row.get("script", row.get("nodes", [])))
	for row: Dictionary in events.get("hidden_events", []) as Array:
		scripts.append(row.get("script", []))
	var highest: int = 0
	for nodes: Array in scripts:
		highest = maxi(highest, _highest_map_text(nodes))
	if highest <= texts.size():
		return false
	var table: int = Gen1Layout.banked(bank, address)
	while texts.size() < highest:
		texts.append(_read_text(
			rom, layout, bank, rom.u16le(table + texts.size() * Gen1Layout.POINTER_SIZE),
			texts.size() + 1
		))
	return true


static func _highest_map_text(nodes: Array) -> int:
	var highest: int = 0
	for node: Dictionary in nodes:
		if String(node["op"]) == "map_text":
			highest = maxi(highest, int(node["text"]))
		for key: String in Gen1Layout.SCRIPT_BRANCH_KEYS:
			if node.has(key):
				highest = maxi(highest, _highest_map_text(node[key] as Array))
	return highest


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
