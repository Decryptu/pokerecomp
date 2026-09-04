extends RefCounted

## Every Generation 1 map and tileset in the cache, swept on Red, Blue and
## Yellow. The counts come from pret's own `data/maps` and `gfx/blocksets`, and
## the structural rules are the map macros' own assertions: a sign's text id
## sits above the object ids, an object's inside them, and every warp and
## connection names a map that exists.

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

## The Power Plant's Voltorbs, Electrodes and Zapdos: an object with the TRAINER
## bit and a byte below `OPP_ID_OFFSET`, which is the only shape a wild one
## takes: six Voltorbs, two Electrodes and Zapdos. Internal indexes, not dex
## numbers.
const POWER_PLANT: int = 83
const POWER_PLANT_WILD: Dictionary = {0x06: 6, 0x8D: 2, 0x4B: 1}

## `SilphCoElevator_Object`'s two warps name UNUSED_MAP_ED, which has no header:
## the elevator's own script rewrites the destination before either is taken.
const SILPH_CO_ELEVATOR: int = 236

var _r: RefCounted = null
var _maps: Dictionary = {}


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
	_events()
	_wild_objects()


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
