extends RefCounted

var _r: RefCounted = null

## Verifies the diploma's art, the printer's status run and the Unown printer's own
## browser against freshly imported real caches on all three cartridges.
## `DiplomaGFX` and its two tilemaps are one pinned run: the LZ stream has to
## decompress to exactly its own tile count and both tilemaps have to index inside
## it, so an address one byte out fails rather than drawing rubbish. The strings are
## the other half of the pin: `GBPrinterStrings` opens on the empty string a status
## of zero prints, and a run pinned wrong would put a line there.

## `PlaceDiplomaOnScreen`'s tilemaps are whole screens, and page 1's own corner
## is the certificate's top-left border tile.
const SCREEN_CELLS: int = 360

## What each `GBPrinterStrings` entry has to contain, by the status it names.
## The four errors differ only in their digit, which is what tells a run in the
## table's own order from one read backwards.
const STATUS_CONTAINS: Dictionary = {
	"null": "", "checking_link": "CHECKING LINK", "transmitting": "TRANSMITTING",
	"printing": "PRINTING", "error_1": "Printer Error 1", "error_2": "Printer Error 2",
	"error_3": "Printer Error 3", "error_4": "Printer Error 4",
}

## `.Certification`'s own last line, which the page draws under the player's
## name and no tilemap carries.
const CERTIFICATION_LAST: String = "Congratulations!"


func run(r: RefCounted) -> void:
	_r = r
	var pages: Array = []
	for game_id: StringName in _r.GAME_IDS:
		var data: GameData = GameData.open(game_id)
		if data == null:
			_r.fail("%s cache is unavailable. Import roms/%s.gbc first." % [game_id, game_id])
			continue
		_r.game_id = game_id
		if not _r.check(data.has_diploma(), "%s: no diploma art in the cache." % game_id):
			continue
		_verify_tilemaps(game_id, data)
		_verify_strings(game_id, data)
		pages.append(_verify_page(game_id, data))
		_verify_unown_printer(game_id, data)
	_r.game_id = &""
	_verify_pages_agree(pages)


## Both tilemaps index inside `DiplomaGFX` and neither is short: a cell past the
## art is a wrong pin and a short map is a wrong length.
func _verify_tilemaps(game_id: StringName, data: GameData) -> void:
	var tiles: int = data.diploma_indices().size() / (
		Gen2Tiles.TILE_WIDTH * Gen2Tiles.TILE_HEIGHT
	)
	_r.check(
		tiles == RomLayout.DIPLOMA_TILES,
		"%s: the diploma's strip is %d tiles, not %d." % [
			game_id, tiles, RomLayout.DIPLOMA_TILES,
		]
	)
	for page: int in [1, 2]:
		var map: PackedByteArray = data.diploma_tilemap(page)
		if not _r.check(
			map.size() == SCREEN_CELLS,
			"%s: diploma page %d is %d cells, not %d." % [
				game_id, page, map.size(), SCREEN_CELLS,
			]
		):
			continue
		var highest: int = 0
		for code: int in map:
			highest = maxi(highest, code)
		_r.check(
			highest < RomLayout.DIPLOMA_TILES,
			"%s: diploma page %d indexes tile %d, past its own art." % [
				game_id, page, highest,
			]
		)
	_r.check(
		data.diploma_palette().size() == RomLayout.PREDEF_PALETTE_COLORS,
		"%s: the diploma's palette is not four colours." % game_id
	)


func _verify_strings(game_id: StringName, data: GameData) -> void:
	for name: Variant in STATUS_CONTAINS:
		var wanted: String = String(STATUS_CONTAINS[name])
		var line: String = data.printer_status_string(String(name))
		if wanted.is_empty():
			_r.check(
				line.is_empty(),
				"%s: the printer's %s status prints \"%s\", not nothing." % [
					game_id, name, line,
				]
			)
			continue
		_r.check(
			line.contains(wanted),
			"%s: the printer's %s status is \"%s\"." % [game_id, name, line]
		)


## The page as it is drawn, which is the half a tilemap check cannot reach: the
## strings `PlaceString` writes over the art, and the play time `PrintNum` puts
## between them.
func _verify_page(game_id: StringName, data: GameData) -> Array:
	var page: Gen2DiplomaPage = Gen2DiplomaPage.from_data(data)
	if not _r.check(page != null, "%s: the diploma page did not build." % game_id):
		return []
	var out: Array = []
	for number: int in [1, 2]:
		var image: Image = page.render(
			number, "RED", {"hours": 41, "minutes": 7}
		)
		if not _r.check(
			image != null and image.get_width() == Gen2DiplomaPage.WIDTH \
				and image.get_height() == Gen2DiplomaPage.HEIGHT,
			"%s: diploma page %d did not render at screen size." % [game_id, number]
		):
			return []
		out.append(image.get_data())
	## The two pages are different pictures, which is what says page 2 is drawn
	## from its own tilemap rather than page 1 twice.
	_r.check(
		out[0] != out[1],
		"%s: both diploma pages drew the same picture." % game_id
	)
	return out


## The art is byte identical between the three cartridges, so the drawn pages
## are too: a difference would be a wrong pin on one of them.
func _verify_pages_agree(pages: Array) -> void:
	var complete: Array = []
	for entry: Variant in pages:
		if not (entry as Array).is_empty():
			complete.append(entry)
	if complete.size() < 2:
		return
	for index: int in range(1, complete.size()):
		_r.check(
			complete[index] == complete[0],
			"the diploma is drawn differently on cartridge %d." % index
		)


## `_UnownPrinter`'s browser, over every slot the cursor reaches: each of the
## twenty-six letters is its own picture, the vacant slot past them is not one of
## them, and the page A sends carries the stamp rather than nothing.
func _verify_unown_printer(game_id: StringName, data: GameData) -> void:
	var page: Gen2UnownPrinterPage = Gen2UnownPrinterPage.from_data(data)
	if not _r.check(page != null, "%s: the Unown printer page did not build." % game_id):
		return
	var seen: Dictionary = {}
	for slot: int in Gen2UnownPrinterPage.SLOTS:
		var image: Image = page.render(slot)
		if not _r.check(
			image != null and image.get_width() == Gen2UnownPrinterPage.WIDTH,
			"%s: Unown printer slot %d did not render." % [game_id, slot]
		):
			return
		var key: String = image.get_data().hex_encode()
		_r.check(
			not seen.has(key),
			"%s: Unown printer slot %d draws the same page as %d." % [
				game_id, slot, int(seen.get(key, -1)),
			]
		)
		seen[key] = slot
	## `PlaceUnownPrinterFrontpic` blanks the screen and puts the rotated stamp
	## on it, so a letter's stamp page is not an empty one.
	var blank: PackedByteArray = page.render_stamp(Gen2UnownPrinterPage.LETTERS).get_data()
	for slot: int in Gen2UnownPrinterPage.LETTERS:
		if not _r.check(
			page.render_stamp(slot).get_data() != blank,
			"%s: the stamp for Unown slot %d is a blank page." % [game_id, slot]
		):
			return
	## A quarter turn, twice, is a half turn: the rotation is its own inverse
	## after four, which is what says it is a rotation rather than a transpose.
	var square := PackedByteArray([0, 1, 2, 3])
	_r.check(
		Gen2UnownPrinterPage._rotated(square, 2, 2) == PackedByteArray([2, 0, 3, 1]),
		"%s: the stamp rotation is not a quarter turn clockwise." % game_id
	)
