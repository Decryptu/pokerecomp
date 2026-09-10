extends RefCounted

## A cache carrying a full species range and both dex order tables, written in
## the same files the importer writes.
##
## The dex is the one screen that needs all 251 species: the order tables are
## that long and [method Gen2Pokedex.order_by_mode] fills the whole listing, so
## the battle fixture's short table cannot stand in. Names, types and entry text
## are generated rather than published values, since nothing here checks content
## against a cartridge; [method RomImporter.verify_pokedex] does that.

const GAME_ID: StringName = &"pokedexfixture"
const SHA1: String = "0123456789abcdef"

## Deliberately unlike the species range and unlike each other, so a test that
## passes under the wrong table fails: NEW runs backwards, and ABC lists the
## even numbers before the odd ones.
static func new_order() -> Array:
	var out: Array = []
	for number: int in range(Gen2Layout.SPECIES_COUNT, 0, -1):
		out.append(number)
	return out


static func alpha_order() -> Array:
	var out: Array = []
	for number: int in range(2, Gen2Layout.SPECIES_COUNT + 1, 2):
		out.append(number)
	for number: int in range(1, Gen2Layout.SPECIES_COUNT + 1, 2):
		out.append(number)
	return out


static func species_name(number: int) -> String:
	return "MON%03d" % number


## Species cycle through the search order's own types, so a search for the type
## at a given search position has a known set of species behind it: species N
## carries SEARCH_TYPES[(N - 1) % 17] in both slots, except the multiples of ten,
## which carry FIRE in the second slot so a two-type search has something to
## find.
static func types_for(number: int) -> Array:
	var first: int = Gen2Pokedex.SEARCH_TYPES[(number - 1) % Gen2Pokedex.SEARCH_TYPES.size()]
	var second: int = Gen2Layout.TYPE_FIRE if number % 10 == 0 else first
	return [first, second]


## One word per Unown form, each opening on its own letter the way the
## cartridge's do, so a test can tell which form the dex is showing.
static func unown_words() -> Array:
	var out: Array = []
	for form: int in Gen2Layout.UNOWN_FORMS:
		out.append("%sWORD" % char("A".unicode_at(0) + form))
	return out


static func directory() -> String:
	return RomCache.directory_for(GAME_ID, SHA1)


static func build() -> GameData:
	var path: String = directory()
	RomCache.clear(path)
	RomCache.prepare(path)
	RomCache.write_json(RomCache.species_path(path), _species())
	RomCache.write_json(RomCache.dex_orders_path(path), {
		"new": new_order(), "alpha": alpha_order(),
	})
	RomCache.write_json(RomCache.manifest_path(path), {
		"format_version": RomCache.FORMAT_VERSION,
		"game_id": String(GAME_ID),
		"sha1": SHA1,
		"complete": true,
		"unown_words": unown_words(),
		"tiles": _tiles(path),
		## `_CGB_Pokedex`'s three, at their real values so a page test reads the
		## colours the screen actually draws through.
		"pokedex_palettes": {
			"interface": [0x7FFF, 0x2A9F, 0x195A, 0x0000],
			"question_mark": [0x2EB, 0x227, 0xCC6, 0x584],
			"cursor": [0x0000, 0x2EB, 0x227, 0x0000],
		},
	})
	return GameData.open_directory(path)


## Heights and weights are the species number and twice it, so a formatting test
## can pick a number and know what it should read without a table here.
static func _species() -> Array:
	var out: Array = []
	for number: int in range(1, Gen2Layout.SPECIES_COUNT + 1):
		out.append({
			"number": number,
			"name": species_name(number),
			"types": types_for(number),
			"dex": {
				"category": "CAT%03d" % number,
				"height": number,
				"weight": number * 2,
				"pages": ["page one %d" % number, "page two %d" % number],
			},
		})
	return out


## `Pokedex_LoadGFX`'s sheets and the font the page draws characters with, each
## at its real length and filled with its own index, so a test can say which
## sheet a cell came from by reading one pixel.
static func _tiles(path: String) -> Dictionary:
	var sheets: Dictionary = {}
	for entry: Array in [
		["font", Gen2Layout.FONT_TILES, 3, Gen2Layout.FONT_FIRST_CODE],
		["pokedex", Gen2Layout.POKEDEX_TILES, 1, 0],
		["pokedex_slowpoke", Gen2Layout.POKEDEX_SLOWPOKE_TILES, 2, 0],
		["pokedex_question_mark", Gen2Layout.POKEDEX_QUESTION_MARK_TILES, 2, 0],
		["unown_font", Gen2Layout.UNOWN_FONT_TILES, 3, 0],
		["footprints", Gen2Layout.FOOTPRINT_SLOTS * Gen2Layout.FOOTPRINT_TILES, 1, 0],
	]:
		var name: String = String(entry[0])
		var count: int = int(entry[1])
		var indices := PackedByteArray()
		indices.resize(count * PokeTiles.TILE_PIXELS)
		indices.fill(int(entry[2]))
		RomCache.write_indices(RomCache.tile_path(path, name), indices)
		sheets[name] = {
			"width": count * PokeTiles.TILE_WIDTH,
			"height": PokeTiles.TILE_HEIGHT,
			"tiles": count,
			"first_code": int(entry[3]),
			"bits": 1,
		}
	return sheets


const GEN1_GAME_ID: StringName = &"pokedexfixturegen1"
## `PAL_BROWNMON`'s own four colours (data/sgb/sgb_palettes.asm), so a page test
## reads what `PalPacket_Pokedex` actually draws through.
const GEN1_BROWNMON: Array = [0x7FBF, 0x3E9C, 0x25D5, 0x0843]


static func gen1_directory() -> String:
	return RomCache.directory_for(GEN1_GAME_ID, SHA1)


## `CreditsOrder` as a fixture: one string and a mon, one string faded, the
## same string with a mon, the copyright with a mon, and The End.
const GEN1_CREDITS: Dictionary = {
	"script": [0, 0xFF, 1, 0xFD, 1, 0xFE, 0xFB, 0xFF, 0xFA],
	"strings": [[0x92, 0x93, 0x80, 0x85, 0x85], [0x8D, 0x80, 0x8C, 0x84]],
	"columns": [7, 7],
	"mons": [1, 2, 3],
	"copyright_rows": [[0x60, 0x61], [0x62], [0x63]],
}
const GEN1_DEX_RATINGS: Dictionary = {
	"counts": "POKéDEX comp-\nletion is:\n<NUM_CC5B> POKéMON seen\n<NUM_CC5C> POKéMON owned",
	"ratings": [{
		"threshold": 10,
		"text": "You still have\nlots to do." + Gen2TextStream.SCROLL_BREAK
			+ "Look for POKéMON\nin grassy areas!",
	}],
}
const GEN1_HALL_OF_FAME_TEXT: Dictionary = {
	"seen_owned": "POKéDEX   Seen:<NUM_CC5B>\n         Owned:<NUM_CC5C>",
	"rating": "POKéDEX Rating<COLON>",
}


## The same cache shaped the way `Gen1Importer` writes one: 151 species, no order
## tables, the four sheets `LoadPokedexTilePatterns` assembles its page from, and
## what the Hall of Fame and the credits read.
static func build_gen1() -> GameData:
	var path: String = gen1_directory()
	RomCache.clear(path)
	RomCache.prepare(path)
	RomCache.write_json(RomCache.species_path(path), _gen1_species())
	var palettes: Array = []
	for index: int in Gen1Layout.PAL_BROWNMON + 1:
		palettes.append(GEN1_BROWNMON)
	RomCache.write_json(RomCache.world_palettes_path(path), palettes)
	RomCache.write_json(RomCache.manifest_path(path), {
		"format_version": RomCache.FORMAT_VERSION,
		"game_id": String(GEN1_GAME_ID),
		"sha1": SHA1,
		"complete": true,
		"generation": RomRegistry.GEN1,
		"tiles": _gen1_tiles(path),
		"credits": GEN1_CREDITS,
		"oak_ratings": GEN1_DEX_RATINGS,
		"special_text": {"hall_of_fame": GEN1_HALL_OF_FAME_TEXT},
	})
	return GameData.open_directory(path)


## Heights are feet and inches packed the way the importer packs them and weights
## are tenths of a pound, so a formatting test reads a real measurement.
static func _gen1_species() -> Array:
	var out: Array = []
	for number: int in range(1, Gen1Layout.SPECIES_COUNT + 1):
		out.append({
			"number": number,
			"name": species_name(number),
			"types": types_for(number),
			"dex": {
				"category": "CAT%03d" % number,
				"height": 100 + number,
				"weight": number * 10,
				"pages": ["page one %d" % number, "page two %d." % number],
			},
		})
	return out


static func _gen1_tiles(path: String) -> Dictionary:
	var sheets: Dictionary = {}
	for entry: Array in [
		["font", Gen1Layout.FONT_TILES, 3, Gen1Layout.FONT_FIRST_CODE],
		["font_extra", Gen1Layout.FONT_EXTRA_TILES, 1, Gen1Layout.FONT_EXTRA_FIRST_CODE],
		[
			"battle_font", Gen1Layout.BATTLE_FONT_TILES, 2,
			Gen1Layout.BATTLE_FONT_FIRST_CODE,
		],
		["battle_balls", Gen1Layout.BALL_TILES, 1, 0],
		["pokedex_tiles", Gen1Layout.POKEDEX_TILES, 2, Gen1Layout.POKEDEX_FIRST_CODE],
		["copyright", 4, 2, Gen1Layout.CREDITS_TILES_FIRST_CODE],
		[
			"credits_the_end", Gen1Layout.CREDITS_THE_END_TILES, 3,
			Gen1Layout.CREDITS_TILES_FIRST_CODE,
		],
	]:
		var name: String = String(entry[0])
		var count: int = int(entry[1])
		var indices := PackedByteArray()
		indices.resize(count * PokeTiles.TILE_PIXELS)
		indices.fill(int(entry[2]))
		RomCache.write_indices(RomCache.tile_path(path, name), indices)
		sheets[name] = {
			"width": count * PokeTiles.TILE_WIDTH,
			"height": PokeTiles.TILE_HEIGHT,
			"tiles": count,
			"first_code": int(entry[3]),
			"bits": 1,
		}
	return sheets
