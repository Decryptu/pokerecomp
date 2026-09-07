extends RefCounted

var _r: RefCounted = null

## Both generations' Pokedex against freshly imported real caches, the
## real-cartridge counterpart to tests/unit/test_pokedex.gd. Crystal's own
## graphics on all three of its dumps: `Pokedex_LoadGFX`'s two LZ runs,
## `gfx/footprints.asm`'s grid, `Pokedex_LoadUnownFont` and `_CGB_Pokedex`'s
## three palettes, each decompressed to exactly the tiles the source asks for.

## Generation 1's is `ShowPokedexMenu`, swept on Red, Blue and Yellow: all 151
## `PokedexEntry` rows, `LoadPokedexTilePatterns`' page, and the listing walked
## from one end to the other with its data page opened.

## `Pokedex_LoadGFX` decompresses `PokedexLZ` to `vTiles2 tile $31`, so the sheet
## number a layout writes is offset by this and the last one it can name is
## `$6a`.
const SHEET_FIRST: int = Gen2PokedexPage.SHEET_FIRST_TILE

## Every species has a footprint, so a slot with no lit pixel at all is a defect
## rather than a species that has none.
const SPECIES: int = Gen2Layout.FOOTPRINT_SPECIES

## `PokedexTypeSearchStrings` (data/types/search_strings.asm) verbatim, minus its
## terminator. [method Gen2Pokedex.search_type_string] centres the imported name
## instead of holding this table, so this is where the two are made to agree.
const SEARCH_STRINGS: Array[String] = [
	"  ----  ", " NORMAL ", "  FIRE  ", " WATER  ", " GRASS  ", "ELECTRIC",
	"  ICE   ", "FIGHTING", " POISON ", " GROUND ", " FLYING ", "PSYCHIC ",
	"  BUG   ", "  ROCK  ", " GHOST  ", " DRAGON ", "  DARK  ", " STEEL  ",
]


func run(r: RefCounted) -> void:
	_r = r
	var digests: Dictionary = {}
	for game_id: StringName in _r.GAME_IDS:
		var digest: String = _validate(game_id)
		if digest.is_empty():
			_r.fail("%s: the Pokedex graphics did not check out." % game_id)
			continue
		digests[game_id] = digest
	var unique: Dictionary = {}
	for game_id: Variant in digests:
		unique[digests[game_id]] = true
	if digests.size() == _r.GAME_IDS.size() and unique.size() != 1:
		_r.fail("The three dumps do not carry the same Pokedex art: %s" % digests)
	else:
		print("  art identical on all three: %s" % [unique.keys()])
	_r.each_game_of(RomRegistry.GEN1, _check_gen1)


## Answers a digest of the three sheets, or "" when the cache failed a check.
func _validate(game_id: StringName) -> String:
	var data: GameData = GameData.open(game_id)
	if data == null:
		print("FAIL %s: cache is not usable" % game_id)
		return ""

	var ok: bool = true
	for sheet: Array in [
		["pokedex", Gen2Layout.POKEDEX_TILES],
		["pokedex_slowpoke", Gen2Layout.POKEDEX_SLOWPOKE_TILES],
		["pokedex_question_mark", Gen2Layout.POKEDEX_QUESTION_MARK_TILES],
		["unown_font", Gen2Layout.UNOWN_FONT_TILES],
		["footprints", Gen2Layout.FOOTPRINT_SLOTS * Gen2Layout.FOOTPRINT_TILES],
	]:
		var name: String = String(sheet[0])
		var wanted: int = int(sheet[1])
		var entry: Dictionary = data.tile_sheet(name)
		if int(entry.get("tiles", 0)) != wanted:
			print("FAIL %s: %s is %d tiles, wanted %d" % [
				game_id, name, int(entry.get("tiles", 0)), wanted,
			])
			ok = false
	if not ok:
		return ""

	for name: String in ["interface", "question_mark", "cursor"]:
		if data.pokedex_palette(name).size() != PokePalette.COLORS_PER_PIC:
			print("FAIL %s: the %s palette is not four colours" % [game_id, name])
			return ""

	var page: Gen2PokedexPage = Gen2PokedexPage.from_data(data)
	if page == null or not page.ready():
		print("FAIL %s: the page would not build" % game_id)
		return ""

	var indices: PackedByteArray = data.tile_indices("footprints")
	if not _check_footprints(data, game_id, indices):
		return ""
	if not _check_entries(data, game_id, page):
		return ""

	# `Pokedex_PlaceTypeString` reads a fixed-width table, so the two search rows
	# and the results screen's line are only right if the centring answers it.
	var dex: Gen2Pokedex = Gen2Pokedex.open(data, null, Gen2Layout.DEXMODE_NEW)
	for value: int in SEARCH_STRINGS.size():
		var drawn: String = dex.search_type_string(value)
		if drawn != SEARCH_STRINGS[value]:
			print("FAIL %s: search string %d is \"%s\", wanted \"%s\"" % [
				game_id, value, drawn, SEARCH_STRINGS[value],
			])
			return ""

	# The question mark is a picture, so a strip of the right length is not
	# enough: an offset that landed on a neighbouring run would still be 49
	# tiles. Its own lit pixels are counted, and the digest below pins the art.
	var question: PackedByteArray = data.tile_indices("pokedex_question_mark")
	var question_colours: Dictionary = {}
	for index: int in question.size():
		question_colours[question[index]] = true
	if question_colours.size() < 2:
		print("FAIL %s: the question mark pic is one flat colour" % game_id)
		return ""

	print("%s: sheet=%d slowpoke=%d question_mark=%d unown_font=%d footprints=%d species=%d" % [
		game_id, Gen2Layout.POKEDEX_TILES, Gen2Layout.POKEDEX_SLOWPOKE_TILES,
		Gen2Layout.POKEDEX_QUESTION_MARK_TILES,
		Gen2Layout.UNOWN_FONT_TILES, SPECIES, Gen2Layout.SPECIES_COUNT,
	])
	return "%s/%s/%s/%s" % [
		indices.slice(0, 4096).hex_encode().sha1_text().substr(0, 8),
		data.tile_indices("pokedex").slice(0, 928).hex_encode().sha1_text().substr(0, 8),
		data.tile_indices("unown_font").hex_encode().sha1_text().substr(0, 8),
		question.hex_encode().sha1_text().substr(0, 8),
	]


## Every species' four footprint tiles, checked for being inside the strip and
## for carrying a picture: the grid's own tail is blank, and a species landing in
## it would be a stride error rather than an absent footprint.
func _check_footprints(data: GameData, game_id: StringName, indices: PackedByteArray) -> bool:
	@warning_ignore("integer_division")
	var width: int = indices.size() / PokeTiles.TILE_HEIGHT
	var blank: Array[int] = []
	for species: int in range(1, SPECIES + 1):
		var tiles: PackedInt32Array = data.footprint_tiles(species)
		if tiles.size() != Gen2Layout.FOOTPRINT_TILES:
			print("FAIL %s: species %d has no footprint" % [game_id, species])
			return false
		var lit: int = 0
		for tile: int in tiles:
			if (tile + 1) * PokeTiles.TILE_WIDTH > width:
				print("FAIL %s: footprint tile %d of species %d is off the strip" % [
					game_id, tile, species,
				])
				return false
			for y: int in PokeTiles.TILE_HEIGHT:
				for x: int in PokeTiles.TILE_WIDTH:
					if indices[y * width + tile * PokeTiles.TILE_WIDTH + x] != 0:
						lit += 1
		if lit == 0:
			blank.append(species)
	if blank.is_empty():
		return true
	print("FAIL %s: %d species have a blank footprint: %s" % [
		game_id, blank.size(), blank.slice(0, 8),
	])
	return false


## Every entry screen, so a short dex record is found here rather than on it.
func _check_entries(data: GameData, game_id: StringName, page: Gen2PokedexPage) -> bool:
	var short_entries: Array[int] = []
	for species: int in range(1, Gen2Layout.SPECIES_COUNT + 1):
		var entry: Dictionary = data.dex_entry(species)
		if entry.is_empty() or String(entry.get("category", "")).is_empty():
			short_entries.append(species)
			continue
		page.load_footprint(data, species)
		var map: PackedInt32Array = page.entry_map(
			species, String(data.species(species).get("name", "")), entry, true, Gen2Pokedex.PAGE_1, 0
		)
		if map.size() != Gen2PokedexPage.COLUMNS * Gen2PokedexPage.ROWS:
			print("FAIL %s: species %d drew no entry screen" % [game_id, species])
			return false
	if short_entries.is_empty():
		return true
	print("FAIL %s: %d species carry no dex entry: %s" % [
		game_id, short_entries.size(), short_entries.slice(0, 8),
	])
	return false


## `PokedexEntry` rows pinned off data/pokemon/dex_entries.asm, by dex number:
## category, feet, inches and tenths of a pound. All three cartridges carry the
## same table.
const GEN1_ENTRIES: Dictionary = {
	1: ["SEED", 2, 4, 150],
	25: ["MOUSE", 1, 4, 130],
	50: ["MOLE", 0, 8, 20],
	95: ["ROCK SNAKE", 28, 10, 4630],
	151: ["NEW SPECIE", 1, 4, 90],
}
const GEN1_SPECIES: int = 151
## `page` parts every description in two and `dex` closes the second with a full
## stop `PlaceDexEnd` writes rather than the text.
const GEN1_PAGES: int = 2
const GEN1_LINES: int = 3
## The one description in the corpus that ends `@@` rather than on `dex`, so
## `PlaceDexEnd` never runs and the text carries its own punctuation.
## `_KoffingDexEntry` on Yellow alone (data/pokemon/dex_text.asm).
const GEN1_NO_DEXEND: Dictionary = {&"yellow": [109] as Array[int]}


## One Generation 1 cartridge: the table, the page and a walk over the listing.
func _check_gen1() -> void:
	var data: GameData = _r.data
	var sheet: Dictionary = data.tile_sheet("pokedex_tiles")
	if not _r.check(
		int(sheet.get("tiles", 0)) == Gen1Layout.POKEDEX_TILES,
		"pokedex_tiles is %d tiles, wanted %d" % [
			int(sheet.get("tiles", 0)), Gen1Layout.POKEDEX_TILES,
		]
	):
		return
	var page: Gen2PokedexPage = Gen2PokedexPage.from_data(data)
	if not _r.check(page != null and page.ready(), "the Pokedex page would not build"):
		return
	_check_gen1_entries(data)
	_check_gen1_listing(data, page)


## Every row of `PokedexEntryPointers`, read through the dex numbers the cache
## speaks: a wrong pointer decodes to something, so the shape of all 151 is what
## says the table is right.
func _check_gen1_entries(data: GameData) -> void:
	var lines: Dictionary = {}
	var unpunctuated: Array[int] = []
	var wrong_pages: Array[int] = []
	for number: int in range(1, GEN1_SPECIES + 1):
		var entry: Dictionary = data.dex_entry(number)
		var pages: PackedStringArray = entry.get("pages", PackedStringArray())
		if String(entry.get("category", "")).is_empty():
			_r.fail("species %d has no Pokedex category" % number)
			return
		if pages.size() != GEN1_PAGES:
			wrong_pages.append(number)
			continue
		if not pages[GEN1_PAGES - 1].ends_with("."):
			unpunctuated.append(number)
		for text: String in pages:
			lines[text.split("\n").size()] = true
	_r.check(
		wrong_pages.is_empty(),
		"%d descriptions are not two pages: %s" % [
			wrong_pages.size(), wrong_pages.slice(0, 8),
		]
	)
	_r.check(
		unpunctuated == GEN1_NO_DEXEND.get(_r.game_id, [] as Array[int]),
		"%d descriptions end without PlaceDexEnd's full stop: %s" % [
			unpunctuated.size(), unpunctuated.slice(0, 8),
		]
	)
	## `bccoord 1, 11` and `<NEXT>`'s two rows leave room for exactly three.
	for count: Variant in lines:
		_r.check(
			int(count) <= GEN1_LINES,
			"a description page is %d lines, which does not fit the box" % int(count)
		)
	for number: Variant in GEN1_ENTRIES:
		var wanted: Array = GEN1_ENTRIES[number]
		var entry: Dictionary = data.dex_entry(int(number))
		var height: int = int(entry.get("height", 0))
		var read: Array = [
			String(entry.get("category", "")),
			int(height / 100), height % 100, int(entry.get("weight", 0)),
		]
		_r.check(read == wanted, "species %d reads %s, wanted %s" % [number, read, wanted])
	_r.note("151 entries, %d pages each, %s" % [GEN1_PAGES, lines.keys()])


## `ShowPokedexMenu` walked end to end: the listing pages down to the last dex
## number, the side menu opens over it, and DATA draws both description pages.
func _check_gen1_listing(data: GameData, page: Gen2PokedexPage) -> void:
	var state := Gen2WorldState.new()
	for number: int in range(1, GEN1_SPECIES + 1):
		state.set_species_seen(number)
		state.set_species_caught(number)
	var dex: Gen2Pokedex = Gen2Pokedex.open_gen1(data, state)
	if not _r.check(dex.listing_end == GEN1_SPECIES, "the listing runs to %d" % dex.listing_end):
		return
	var steps: int = 0
	while dex.gen1_move_listing(PokeButton.RIGHT):
		steps += 1
		if steps > GEN1_SPECIES:
			break
	_r.check(
		dex.selected_species() == GEN1_SPECIES - Gen2Pokedex.GEN1_LISTING_HEIGHT + 1,
		"paging to the end left the cursor on %d" % dex.selected_species()
	)
	while dex.gen1_move_listing(PokeButton.DOWN):
		pass
	_r.check(
		dex.selected_species() == GEN1_SPECIES,
		"walking down to the end left the cursor on %d" % dex.selected_species()
	)
	var rows: Array = dex.gen1_rows()
	_r.check(
		rows.size() == Gen2Pokedex.GEN1_LISTING_HEIGHT
			and int(rows[rows.size() - 1]["number"]) == GEN1_SPECIES,
		"the last page ends on %s" % [rows]
	)
	var entry: Dictionary = data.dex_entry(GEN1_SPECIES)
	for description: int in GEN1_PAGES:
		var map: PackedInt32Array = page.gen1_entry_map(
			GEN1_SPECIES, String(data.species(GEN1_SPECIES).get("name", "")),
			entry, true, description, description == 0
		)
		var text: PackedStringArray = entry["pages"]
		_r.check(
			_gen1_row(map, Gen2PokedexPage.GEN1_ENTRY_TEXT_AT.y)
				== text[description].split("\n")[0],
			"the data page's first line is not the description's"
		)
	_r.note("listing walked %d pages to species %d" % [steps, dex.selected_species()])


## One row of a drawn map back as text, so a check can read what the screen says.
## The border columns are left out: they are sheet tiles rather than characters.
func _gen1_row(map: PackedInt32Array, row: int) -> String:
	var codes := PackedByteArray()
	var from: int = Gen2PokedexPage.GEN1_ENTRY_TEXT_AT.x
	for column: int in range(from, Gen2PokedexPage.COLUMNS - 1):
		codes.append(map[row * Gen2PokedexPage.COLUMNS + column])
	return Gen1Text.decode(codes, 0, codes.size()).strip_edges()
