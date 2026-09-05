extends RefCounted

## Every Generation 1 map, tileset, SGB palette and overworld sprite in the
## cache, swept on Red, Blue and Yellow. The counts come from pret's own
## `data/maps`, `gfx/blocksets` and `data/sprites`, and the structural rules are
## the map macros' own assertions: a sign's text id sits above the object ids,
## an object's inside them, and every warp and connection names a real map.

## Real maps of the flat table's 248 or 249 ids, and the tilesets behind them.
const MAP_COUNTS: Dictionary = {&"red": 226, &"blue": 226, &"yellow": 227}
const TILESET_COUNTS: Dictionary = {&"red": 24, &"blue": 24, &"yellow": 25}

## What the corpus holds, which is what says a record's stride is right: a wrong
## one drifts long before the last map.
const CENSUS: Dictionary = {
	&"red": {"warps": 813, "signs": 202, "objects": 924, "connections": 78,
		"items": 106, "trainers": 334},
	&"blue": {"warps": 813, "signs": 202, "objects": 924, "connections": 78,
		"items": 106, "trainers": 334},
	&"yellow": {"warps": 817, "signs": 204, "objects": 949, "connections": 78,
		"items": 111, "trainers": 329},
}

## `PalletTown.asm` and `PalletTown.blk` whole, the one map pinned end to end.
const PALLET_TOWN: int = 0
const PALLET_BLOCKS: Array[int] = [
	0x52, 0x4F, 0x52, 0x52, 0x4F, 0x0B, 0x50, 0x52, 0x52, 0x50,
	0x4E, 0x01, 0x38, 0x39, 0x01, 0x01, 0x38, 0x39, 0x01, 0x4D,
	0x4E, 0x08, 0x3C, 0x3D, 0x01, 0x08, 0x3C, 0x3D, 0x01, 0x4D,
	0x4E, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x4D,
	0x4E, 0x01, 0x77, 0x56, 0x01, 0x0C, 0x0D, 0x0E, 0x01, 0x4D,
	0x4E, 0x01, 0x74, 0x74, 0x01, 0x10, 0x3A, 0x00, 0x01, 0x4D,
	0x4E, 0x01, 0x01, 0x01, 0x01, 0x77, 0x56, 0x77, 0x31, 0x4D,
	0x4E, 0x0A, 0x1D, 0x1E, 0x31, 0x74, 0x74, 0x0A, 0x31, 0x4D,
	0x50, 0x0A, 0x65, 0x64, 0x61, 0x61, 0x61, 0x61, 0x61, 0x4F,
]
const PALLET_WIDTH: int = 10
const PALLET_HEIGHT: int = 9
const PALLET_BORDER: int = 0x0B
const PALLET_MUSIC: int = 186
## Red's house, Blue's house and Oak's lab, by destination map and warp index.
const PALLET_WARPS: Array = [[5, 5, 37, 0], [13, 5, 39, 0], [12, 11, 40, 1]]
const PALLET_SIGNS: Array = [[13, 13, 4], [7, 9, 5], [3, 5, 6], [11, 5, 7]]
## Route 1 to the north and Route 21 to the south, both ten blocks wide.
const PALLET_CONNECTIONS: Array = [["north", 12, 35], ["south", 32, 0]]

## `Tilesets`' first row: `Overworld_Coll`, the grass tile and
## TILEANIM_WATER_FLOWER. The blockset is what every town and route draws from.
const OVERWORLD_TILESET: int = 0
const OVERWORLD_BLOCKS: int = 128
const OVERWORLD_GRASS: int = 0x52
const OVERWORLD_ANIMATION: int = 2
const OVERWORLD_PASSABLE: Array[int] = [
	0x00, 0x10, 0x1B, 0x20, 0x21, 0x23, 0x2C, 0x2D, 0x2E, 0x30,
	0x31, 0x33, 0x39, 0x3C, 0x3E, 0x52, 0x54, 0x58, 0x5B,
]

## Every template `object_event`'s two movement bytes decode to, and how many.
const MOVEMENTS: Array[int] = [
	Gen2WorldObject.MOVEMENT_WANDER, Gen2WorldObject.MOVEMENT_WALK_UP_DOWN,
	Gen2WorldObject.MOVEMENT_WALK_LEFT_RIGHT,
	Gen2WorldObject.MOVEMENT_SPINRANDOM_SLOW,
	Gen2WorldObject.MOVEMENT_STRENGTH_BOULDER, Gen2WorldObject.MOVEMENT_FIXED_DOWN,
	Gen2WorldObject.MOVEMENT_FIXED_UP, Gen2WorldObject.MOVEMENT_FIXED_LEFT,
	Gen2WorldObject.MOVEMENT_FIXED_RIGHT,
]
const MOVEMENT_CENSUS: Dictionary = {
	&"red": [20, 29, 50, 256, 21, 234, 79, 114, 121],
	&"blue": [20, 29, 50, 256, 21, 234, 79, 114, 121],
	&"yellow": [19, 28, 49, 260, 21, 252, 85, 114, 121],
}

## The Power Plant's Voltorbs, Electrodes and Zapdos: an object with the TRAINER
## bit and a byte below `OPP_ID_OFFSET`, which is the only shape a wild one
## takes: six Voltorbs, two Electrodes and Zapdos, as the dex numbers the cache
## stores rather than the internal indexes the cartridge writes.
const POWER_PLANT: int = 83
const POWER_PLANT_WILD: Dictionary = {100: 6, 101: 2, 145: 1}

## `SilphCoElevator_Object`'s two warps name UNUSED_MAP_ED, which has no header:
## the elevator's own script rewrites the destination before either is taken.
const SILPH_CO_ELEVATOR: int = 236

## `NUM_SGB_PALS`, and `PAL_ROUTE`'s own four, the row every route draws in.
const PALETTE_COUNTS: Dictionary = {&"red": 37, &"blue": 37, &"yellow": 40}
const ROUTE_COLORS: Dictionary = {
	&"red": [0x7FBF, 0x2F95, 0x7F54, 0x0843],
	&"blue": [0x7FBF, 0x2F95, 0x7F54, 0x0843],
	&"yellow": [0x7BFF, 0x4F57, 0x7F77, 0x18C6],
}

## Every branch of `SetPal_Overworld`, as map id, `wLastMap` and the row wanted.
## The ids are the same in all three; only the link rooms answer differently.
const PINNED_PALETTES: Array = [
	[0x00, -1, 0x01], [0x0A, -1, 0x0B], [0x0C, -1, 0x00],
	[0x28, 0x00, 0x01], [0x28, 0x0C, 0x00],
	[0x3B, -1, 0x23], [0x8F, -1, 0x19], [0xF7, -1, 0x19],
	[0xE2, -1, 0x23], [0xE4, -1, 0x23], [0xF5, -1, 0x01], [0xF6, -1, 0x23],
]
const LINK_ROOMS: Array[int] = [0xEF, 0xF0]

## What the corpus lands on with no `wLastMap`: eleven cities one each, Lorelei's
## room beside Pallet Town's, twenty caves, the Tower and Agatha grey, and the
## rest the route row. Yellow's extra grey pair is the link rooms.
const PALETTE_CENSUS: Dictionary = {
	&"red": {0: 186, 1: 2, 2: 1, 3: 1, 4: 1, 5: 1, 6: 1, 7: 1, 8: 1, 9: 1, 10: 1,
		11: 1, 25: 8, 35: 20},
	&"blue": {0: 186, 1: 2, 2: 1, 3: 1, 4: 1, 5: 1, 6: 1, 7: 1, 8: 1, 9: 1, 10: 1,
		11: 1, 25: 8, 35: 20},
	&"yellow": {0: 185, 1: 2, 2: 1, 3: 1, 4: 1, 5: 1, 6: 1, 7: 1, 8: 1, 9: 1, 10: 1,
		11: 1, 25: 10, 35: 20},
}

## Every row of `<Map>_TextPointers` the maps' signs and objects reach, by the
## byte that opens it. Yellow's six bare `text_end`s are Jessie and James, whose
## two ids share one on three maps.
const TEXT_CENSUS: Dictionary = {
	&"red": {0x08: 626, 0x17: 456, 0xF5: 3, 0xF6: 12, 0xF7: 3, 0xFE: 14, 0xFF: 12},
	&"blue": {0x08: 626, 0x17: 456, 0xF5: 3, 0xF6: 12, 0xF7: 3, 0xFE: 14, 0xFF: 12},
	&"yellow": {0x08: 675, 0x17: 429, 0x50: 6, 0xF5: 3, 0xF6: 12, 0xF7: 3,
		0xFE: 14, 0xFF: 12},
}

## Rows of `script_mart` across the corpus. Yellow's Celadon 5F clerk sells one
## more than Red and Blue's.
const MART_ITEMS: Dictionary = {&"red": 97, &"blue": 97, &"yellow": 98}

## `_MtMoonPokecenterClipboardText`, the corpus's one empty box.
const EMPTY_TEXTS: Dictionary = {&"red": 1, &"blue": 1, &"yellow": 1}

## `NUM_SPRITES` and `FIRST_STILL_SPRITE`, with `SpriteSheetPointerTable`'s
## first row: `RedSprite`, $C0 bytes in bank $05.
const SPRITE_COUNTS: Dictionary = {&"red": 72, &"blue": 72, &"yellow": 82}
const SPRITE_STILL_FIRST: Dictionary = {&"red": 0x3D, &"blue": 0x3D, &"yellow": 0x47}
const PLAYER_SPRITE: Array = [0x4180, 0x05]
const PLAYER_SPRITE_YELLOW: Array = [0x4571, 0x05]

var _r: RefCounted = null
var _maps: Dictionary = {}
var _movements: Array[int] = []


func run(r: RefCounted) -> void:
	_r = r
	r.each_game_of(RomRegistry.GEN1, _one_game)


func _one_game() -> void:
	_maps = {}
	for map: Gen2WorldMap in _r.data.world_maps():
		_maps[map.number] = map
	_counts()
	_tilesets()
	_pallet_town()
	_geometry()
	_movements = []
	_movements.resize(MOVEMENTS.size())
	_events()
	_r.check(_movements == MOVEMENT_CENSUS[_r.game_id],
		"the movement census reads %s." % str(_movements))
	_texts()
	_wild_objects()
	_palettes()
	_sprites()


func _counts() -> void:
	var wanted: int = int(MAP_COUNTS[_r.game_id])
	if not _r.check(_maps.size() == wanted, "the cache holds %d maps, wanted %d." % [
		_maps.size(), wanted,
	]):
		return
	for map_id: int in Gen1Layout.UNUSED_MAPS:
		_r.check(not _maps.has(map_id), "unused map $%02X decoded to a record." % map_id)
	var census: Dictionary = {"warps": 0, "signs": 0, "objects": 0, "connections": 0,
		"items": 0, "trainers": 0}
	for map: Gen2WorldMap in _maps.values():
		census["warps"] += (map.events["warps"] as Array).size()
		census["signs"] += (map.events["bg_events"] as Array).size()
		census["connections"] += map.connections.size()
		for object: Dictionary in map.events["objects"] as Array:
			census["objects"] += 1
			census["items"] += 1 if object.has("item") else 0
			census["trainers"] += 1 if object.has("trainer_class") else 0
	var pinned: Dictionary = CENSUS[_r.game_id]
	for key: String in pinned:
		_r.check(census[key] == int(pinned[key]), "the corpus holds %d %s, pinned %d." % [
			census[key], key, int(pinned[key]),
		])
	_r.note("gen1 maps %s" % census)


func _tilesets() -> void:
	var wanted: int = int(TILESET_COUNTS[_r.game_id])
	if not _r.check(_r.data.world_tileset_count() == wanted,
		"the cache holds %d tilesets, wanted %d." % [_r.data.world_tileset_count(), wanted]):
		return
	var blocks: Array[int] = Gen1Layout.tileset_blocks(_r.game_id)
	for number: int in wanted:
		var tileset: Gen2WorldTileset = _r.data.world_tileset(number)
		if not _r.check(tileset != null, "tileset %d is missing." % number):
			continue
		_r.check(tileset.block_count == blocks[number],
			"tileset %d holds %d blocks, pinned %d." % [number, tileset.block_count, blocks[number]])
		_r.check(
			tileset.meta.size() == tileset.block_count * Gen1Layout.TILESET_BLOCK_TILES,
			"tileset %d's blockset is %d bytes for %d blocks." % [
				number, tileset.meta.size(), tileset.block_count,
			]
		)
		_r.check(tileset.tile_count == Gen1Layout.TILESET_TILE_COUNT,
			"tileset %d loads %d tiles, wanted %d." % [
				number, tileset.tile_count, Gen1Layout.TILESET_TILE_COUNT,
			])
		_r.check(not tileset.passable_tiles.is_empty(),
			"tileset %d lists no passable tile." % number)
		_r.check(
			_r.data.world_tileset_indices(number).size()
			== tileset.tile_count * PokeTiles.TILE_PIXELS,
			"tileset %d's graphics strip is the wrong size." % number
		)
	var overworld: Gen2WorldTileset = _r.data.world_tileset(OVERWORLD_TILESET)
	_r.check(overworld.block_count == OVERWORLD_BLOCKS and overworld.grass_tile == OVERWORLD_GRASS
		and overworld.animation == OVERWORLD_ANIMATION and overworld.water,
		"the overworld tileset reads %d blocks, grass $%02X, animation %d, water %s." % [
			overworld.block_count, overworld.grass_tile, overworld.animation, overworld.water,
		])
	_r.check(Array(overworld.passable_tiles) == OVERWORLD_PASSABLE,
		"Overworld_Coll reads %s." % [Array(overworld.passable_tiles)])


func _pallet_town() -> void:
	var map: Gen2WorldMap = _maps.get(PALLET_TOWN, null)
	if not _r.check(map != null, "Pallet Town is missing."):
		return
	_r.check(
		map.width_blocks == PALLET_WIDTH and map.height_blocks == PALLET_HEIGHT
		and map.tileset == OVERWORLD_TILESET and map.border_block == PALLET_BORDER
		and map.music == PALLET_MUSIC,
		"Pallet Town reads %dx%d, tileset %d, border $%02X, music %d." % [
			map.width_blocks, map.height_blocks, map.tileset, map.border_block, map.music,
		]
	)
	_r.check(Array(map.blocks) == PALLET_BLOCKS, "Pallet Town's blocks differ from PalletTown.blk.")
	_r.check(_rows(map.events["warps"], ["x", "y", "map_number", "destination"]) == PALLET_WARPS,
		"Pallet Town's warps read %s." % [_rows(map.events["warps"], ["x", "y", "map_number", "destination"])])
	_r.check(_rows(map.events["bg_events"], ["x", "y", "text"]) == PALLET_SIGNS,
		"Pallet Town's signs read %s." % [_rows(map.events["bg_events"], ["x", "y", "text"])])
	_r.check(
		_rows(map.connections, ["direction", "map_number", "y_alignment"]) == PALLET_CONNECTIONS,
		"Pallet Town's connections read %s." % [
			_rows(map.connections, ["direction", "map_number", "y_alignment"]),
		]
	)
	## `text/PalletTown.asm` as pret writes it: the town sign's `cont` is a
	## scroll and the two house signs keep the names a print fills in.
	var pinned: Array[String] = [
		"OAK POKéMON\nRESEARCH LAB",
		"PALLET TOWN\nShades of your%sjourney await!" % Gen2TextStream.SCROLL_BREAK,
		"<PLAYER>'s house ",
		"<RIVAL>'s house ",
	]
	for index: int in pinned.size():
		var text: String = String(map.text_at(index + 4).get("text", ""))
		_r.check(text == pinned[index], "Pallet Town's text %d reads %s." % [index + 4, text])


## Every decoded text in the corpus: what each row opens with, and that every
## character of a box draws a tile. `FontGraphics` is blank from $c0 to $df, so a
## code from the wrong generation's codec is a hole rather than a wrong letter.
func _texts() -> void:
	var font: Gen2Font = Gen2Font.from_data(_r.data)
	if not _r.check(font != null, "the cache has no font."):
		return
	var census: Dictionary = {}
	var empty: int = 0
	var blank: Array[String] = []
	for map: Gen2WorldMap in _maps.values():
		for row: Dictionary in map.texts:
			var command: int = int(row["command"])
			census[command] = int(census.get(command, 0)) + 1
			var text: String = String(row.get("text", ""))
			if text.is_empty():
				empty += 1 if command in [Gen1Text.TEXT_FAR, Gen1Text.TEXT_START] else 0
				continue
			for line: String in text.split("\n"):
				if not _drawn(font, line) and blank.size() < 4:
					blank.append("map %d: %s" % [map.number, line])
	_r.check(blank.is_empty(), "texts draw a blank tile: %s." % [blank])
	_r.check(census == TEXT_CENSUS[_r.game_id], "the text rows read %s." % [census])
	_r.check(empty == int(EMPTY_TEXTS[_r.game_id]),
		"%d texts decoded to nothing, pinned %d." % [empty, int(EMPTY_TEXTS[_r.game_id])])
	_r.note("gen1 texts %s" % [census])
	_marts()


## Every `script_mart` row's inline inventory: `LoadItemList` reads the count out
## of the text pointer itself, so a stride that has slipped shows up as a shelf
## naming an item the cartridge has no name for.
func _marts() -> void:
	var shelves: int = 0
	var items: int = 0
	for map: Gen2WorldMap in _maps.values():
		for row: Dictionary in map.texts:
			if int(row["command"]) != Gen1Layout.TEXT_SCRIPT_MART:
				continue
			var shelf: Array = row.get("items", [])
			shelves += 1
			items += shelf.size()
			if not _r.check(not shelf.is_empty(), "map %d's shop is empty." % map.number):
				continue
			for item: Variant in shelf:
				_r.check(not _r.data.item_name(int(item)).is_empty(),
					"map %d's shop sells item %d, which has no name." % [map.number, int(item)])
	_r.check(shelves == int(TEXT_CENSUS[_r.game_id][Gen1Layout.TEXT_SCRIPT_MART]),
		"%d shops carry an inventory." % shelves)
	_r.check(items == int(MART_ITEMS[_r.game_id]),
		"the shops sell %d items, pinned %d." % [items, int(MART_ITEMS[_r.game_id])])
	_r.note("gen1 shops %d selling %d items" % [shelves, items])


## Whether every code [param line] encodes to has ink behind it.
static func _drawn(font: Gen2Font, line: String) -> bool:
	for code: int in font.encode(line):
		if code == Gen1Text.SPACE \
			or (code >= Gen1Layout.FONT_EXTRA_FIRST_CODE and code <= Gen1Layout.FRAME_LAST_CODE):
			continue
		var inked: bool = false
		for ink: Array in Gen1Layout.FONT_INK_RUNS:
			inked = inked or (code >= int(ink[0]) and code <= int(ink[1]))
		if not inked:
			return false
	return true


static func _rows(events: Array, fields: Array) -> Array:
	var out: Array = []
	for event: Dictionary in events:
		var row: Array = []
		for field: String in fields:
			row.append(event[field])
		out.append(row)
	return out


## Every map's own shape, and that a player has somewhere to stand on it.
func _geometry() -> void:
	for map: Gen2WorldMap in _maps.values():
		var cells: int = map.width_blocks * map.height_blocks * 4
		if not _r.check(
			map.blocks.size() == map.width_blocks * map.height_blocks
			and map.collision.size() == cells,
			"map %d is %dx%d blocks with %d blocks and %d cells." % [
				map.number, map.width_blocks, map.height_blocks,
				map.blocks.size(), map.collision.size(),
			]
		):
			continue
		var tileset: Gen2WorldTileset = _r.data.world_tileset(map.tileset)
		if not _r.check(tileset != null, "map %d names tileset %d." % [map.number, map.tileset]):
			continue
		var walkable: int = 0
		for code: int in map.collision:
			walkable += 1 if tileset.tile_passable(code) else 0
		_r.check(walkable > 0, "map %d has no cell a player can stand on." % map.number)


## The map macros' own assertions, plus the tables an event points into.
func _events() -> void:
	for map: Gen2WorldMap in _maps.values():
		var objects: Array = map.events["objects"]
		for warp: Dictionary in map.events["warps"] as Array:
			var destination: int = int(warp["map_number"])
			if destination == Gen1Layout.WARP_TO_LAST_MAP:
				continue
			if map.number == SILPH_CO_ELEVATOR:
				_r.check(not Gen1Layout.is_real_map(destination),
					"the Silph Co elevator now warps to map %d." % destination)
				continue
			var target: Gen2WorldMap = _maps.get(destination, null)
			if not _r.check(target != null, "map %d warps to map %d, which has no header." % [
				map.number, destination,
			]):
				continue
			_r.check(int(warp["destination"]) < (target.events["warps"] as Array).size(),
				"map %d warps to map %d's warp %d, which it does not have." % [
					map.number, destination, int(warp["destination"]),
				])
		for connection: Dictionary in map.connections:
			var neighbour: Gen2WorldMap = _maps.get(int(connection["map_number"]), null)
			if not _r.check(neighbour != null, "map %d connects %s to map %d, which has no header." % [
				map.number, connection["direction"], int(connection["map_number"]),
			]):
				continue
			_r.check(int(connection["target_width_blocks"]) == neighbour.width_blocks,
				"map %d's %s connection calls map %d %d blocks wide, and it is %d." % [
					map.number, connection["direction"], neighbour.number,
					int(connection["target_width_blocks"]), neighbour.width_blocks,
				])
		for board: Dictionary in map.events["bg_events"] as Array:
			_r.check(int(board["text"]) > objects.size(),
				"map %d has a sign with text id %d over %d objects." % [
					map.number, int(board["text"]), objects.size(),
				])
		for object: Dictionary in objects:
			_object(map, object, objects.size())


func _object(map: Gen2WorldMap, object: Dictionary, object_count: int) -> void:
	var text: int = int(object["text"])
	_r.check(text >= 1 and text <= object_count,
		"map %d has an object with text id %d over %d objects." % [map.number, text, object_count])
	if object.has("trainer_class"):
		var trainer_class: int = int(object["trainer_class"])
		_r.check(trainer_class >= 1 and trainer_class <= _r.data.trainer_count(),
			"map %d has a trainer of class %d." % [map.number, trainer_class])
	if object.has("species"):
		var species: int = int(object["species"])
		_r.check(species >= 1 and species <= Gen1Layout.INDEX_COUNT,
			"map %d has a wild object of species index %d." % [map.number, species])
	if object.has("item"):
		_r.check(_is_item(int(object["item"])),
			"map %d has an item ball holding item %d." % [map.number, int(object["item"])])
	var movement: int = int(object["movement"])
	var slot: int = MOVEMENTS.find(movement)
	if _r.check(slot >= 0, "map %d has an object on movement %d." % [map.number, movement]):
		_movements[slot] += 1


## An item id an item ball can hold: a named item, or one of the machines above
## them. Blue's house carries two zeroes, which the cartridge never reads: both
## objects are people whose event only sets the ITEM bit.
static func _is_item(item: int) -> bool:
	if item == 0:
		return true
	if item <= Gen1Layout.ITEM_COUNT:
		return true
	return item >= Gen1Layout.HM_FIRST_ITEM \
		and item < Gen1Layout.TM_FIRST_ITEM + Gen1Layout.TM_COUNT


## `SuperPalettes` and the row `SetPal_Overworld` hands each map.
func _palettes() -> void:
	var wanted: int = int(PALETTE_COUNTS[_r.game_id])
	var last: PackedColorArray = _r.data.world_palette(wanted - 1)
	if not _r.check(
		_r.data.world_palette(wanted).is_empty() and last.size() == 4,
		"the cache holds %d SGB palettes, wanted %d." % [_palette_count(), wanted]
	):
		return
	var route: Array = []
	for color: Color in _r.data.world_palette(Gen1Layout.PAL_ROUTE):
		route.append(_packed(color))
	_r.check(route == ROUTE_COLORS[_r.game_id], "PAL_ROUTE reads %s." % [route])

	for row: Array in PINNED_PALETTES:
		_pinned_palette(int(row[0]), int(row[1]), int(row[2]))
	# Yellow gives the two link rooms `PAL_GRAYMON` by name; Red and Blue have
	# the same two maps and let them fall through to `wLastMap`.
	var link: int = Gen1Layout.PAL_GRAYMON if _r.game_id == RomRegistry.YELLOW \
		else Gen1Layout.PAL_PALLET
	for map_id: int in LINK_ROOMS:
		_pinned_palette(map_id, 0x00, link)

	var census: Dictionary = {}
	for map: Gen2WorldMap in _maps.values():
		var palette: int = Gen1Layout.overworld_palette(_r.game_id, map.number, map.tileset)
		if not _r.check(palette >= 0 and palette < wanted,
			"map %d draws in SGB palette %d." % [map.number, palette]):
			continue
		census[palette] = int(census.get(palette, 0)) + 1
	var pinned: Dictionary = PALETTE_CENSUS[_r.game_id]
	for palette: int in pinned:
		_r.check(int(census.get(palette, 0)) == int(pinned[palette]),
			"%d maps draw in SGB palette %d, pinned %d." % [
				int(census.get(palette, 0)), palette, int(pinned[palette]),
			])
	_r.check(census.size() == pinned.size(), "the corpus lands on %d palettes, pinned %d." % [
		census.size(), pinned.size(),
	])
	_r.note("gen1 map palettes %s" % census)


func _pinned_palette(map_id: int, last_map: int, wanted: int) -> void:
	var map: Gen2WorldMap = _maps.get(map_id, null)
	if not _r.check(map != null, "map $%02X is missing." % map_id):
		return
	var got: int = Gen1Layout.overworld_palette(_r.game_id, map_id, map.tileset, last_map)
	_r.check(got == wanted, "map $%02X out of map %d draws in palette %d, wanted %d." % [
		map_id, last_map, got, wanted,
	])


## How many rows the cache really holds, for the message when the count is wrong.
func _palette_count() -> int:
	var out: int = 0
	while not _r.data.world_palette(out).is_empty():
		out += 1
	return out


static func _packed(color: Color) -> int:
	return int(round(color.r * 31.0)) | (int(round(color.g * 31.0)) << 5) \
		| (int(round(color.b * 31.0)) << 10)


## `SpriteSheetPointerTable`'s strips, and the picture id every object names.
func _sprites() -> void:
	var wanted: int = int(SPRITE_COUNTS[_r.game_id])
	var still_first: int = int(SPRITE_STILL_FIRST[_r.game_id])
	if not _r.check(_r.data.overworld_sprite_count() == wanted,
		"the cache holds %d overworld sprites, wanted %d." % [
			_r.data.overworld_sprite_count(), wanted,
		]):
		return
	var player: Array = PLAYER_SPRITE_YELLOW if _r.game_id == RomRegistry.YELLOW \
		else PLAYER_SPRITE
	var red: Gen2WorldSprite = _r.data.overworld_sprite(1)
	_r.check(red.address == int(player[0]) and red.bank == int(player[1]),
		"RedSprite reads $%02X:$%04X." % [red.bank, red.address])

	var census: Dictionary = {"walking": 0, "still": 0}
	for number: int in range(1, wanted + 1):
		var sprite: Gen2WorldSprite = _r.data.overworld_sprite(number)
		if not _r.check(sprite != null, "sprite %d is missing." % number):
			continue
		var still: bool = number >= still_first
		var tiles: int = Gen1Layout.SPRITE_STILL_TILES if still \
			else Gen1Layout.SPRITE_WALKING_TILES * 2
		census["still" if still else "walking"] += 1
		_r.check(sprite.tiles == tiles and sprite.is_walking() != still,
			"sprite %d holds %d tiles as type %d, wanted %d." % [
				number, sprite.tiles, sprite.sprite_type, tiles,
			])
		_r.check(
			_r.data.overworld_sprite_indices(number).size() == tiles * PokeTiles.TILE_PIXELS,
			"sprite %d's strip is the wrong size." % number
		)
	_r.check(census == {"walking": still_first - 1, "still": wanted - still_first + 1},
		"the sheets read %s." % [census])

	for map: Gen2WorldMap in _maps.values():
		for object: Dictionary in map.events["objects"] as Array:
			var picture: int = int(object["sprite"])
			_r.check(picture >= 1 and picture <= wanted,
				"map %d has an object drawn with picture id %d." % [map.number, picture])


func _wild_objects() -> void:
	var map: Gen2WorldMap = _maps.get(POWER_PLANT, null)
	if not _r.check(map != null, "the Power Plant is missing."):
		return
	var species: Dictionary = {}
	for object: Dictionary in map.events["objects"] as Array:
		if object.has("species"):
			species[int(object["species"])] = int(species.get(int(object["species"]), 0)) + 1
	_r.check(species == POWER_PLANT_WILD,
		"the Power Plant's standing wild objects read %s." % [species])
