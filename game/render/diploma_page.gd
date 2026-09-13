class_name Gen2DiplomaPage
extends RefCounted

## `PlaceDiplomaOnScreen` and `PrintDiplomaPage2` (`engine/events/diploma.asm`):
## a stored tilemap each with a few strings written in, node-free. A cell under
## `FONT_FIRST_CODE` names a tile of `DiplomaGFX` and one at or above it a font
## glyph, the hardware's own split: the art is in `vTiles2` and the font already
## at the codes it prints under.

const TILE: int = Gen2Font.TILE
const COLUMNS: int = 20
const ROWS: int = 18
const WIDTH: int = COLUMNS * TILE
const HEIGHT: int = ROWS * TILE

## `_Diploma`'s own three `PlaceString`s. `.EmptyString` at `hlcoord 15, 5` is
## the `"@"` that prints nothing, so only the two that draw are here.
const PLAYER_LABEL_AT: Vector2i = Vector2i(2, 5)
const PLAYER_NAME_AT: Vector2i = Vector2i(9, 5)
const CERTIFICATION_AT: Vector2i = Vector2i(2, 8)
const CERTIFICATION: Array[String] = [
	"This certifies", "that you have", "completed the",
	"new #DEX.", "Congratulations!",
]

## `PrintDiplomaPage2`'s own three, and the colon `ld [hl], $67` writes between
## the two halves of the play time.
const GAME_FREAK_AT: Vector2i = Vector2i(8, 0)
const PLAY_TIME_AT: Vector2i = Vector2i(3, 15)
const PLAY_TIME_VALUE_AT: Vector2i = Vector2i(12, 15)
const PLAY_TIME_HOUR_CELLS: int = 4
## `ld [hl], $67`: a tile of `DiplomaGFX`, not a character code.
const COLON_CODE: int = 0x67

var font: Gen2Font = null
var palette: PackedColorArray = PackedColorArray()

var _tiles: PackedByteArray = PackedByteArray()
var _maps: Array[PackedByteArray] = []
var _gen1: GameData = null
var _gen1_strings: Array[PackedByteArray] = []


static func from_data(data: GameData) -> Gen2DiplomaPage:
	if data == null or not data.has_diploma():
		return null
	var page := Gen2DiplomaPage.new()
	if data.generation == RomRegistry.GEN1:
		page._gen1 = data
		page._gen1_strings = data.gen1_diploma_strings()
		var generic: Array = (data.opening().get("palettes", {}) as Dictionary).get("generic", [])
		for packed: Variant in (generic[0] as Array) if not generic.is_empty() else []:
			page.palette.append(PokePalette.from_packed(int(packed)))
		return page if page._gen1_strings.size() == Gen1Layout.DIPLOMA_STRINGS \
			and not page.palette.is_empty() else null
	page.font = Gen2Font.from_data(data)
	page.palette = data.diploma_palette()
	page._tiles = data.diploma_indices()
	page._maps = [data.diploma_tilemap(1), data.diploma_tilemap(2)]
	if page.font == null or page.palette.is_empty() or page._tiles.is_empty():
		return null
	for map: PackedByteArray in page._maps:
		if map.size() != Gen2Layout.DIPLOMA_TILEMAP_BYTES:
			return null
	return page


## `PlacePrinterStatusString`: `Textbox` at `hlcoord 0, 5` with `lb bc, 10, 18`,
## the status at `hlcoord 1, 7` and the cancel line at `hlcoord 2, 15`. It is
## written into the page's own tilemap rather than laid over it, which is what
## keeps the box the page's own colours.
const STATUS_BOX_AT: Vector2i = Vector2i(0, 5)
const STATUS_BOX_SIZE: Vector2i = Vector2i(20, 12)
const STATUS_TEXT_AT: Vector2i = Vector2i(1, 7)
const CANCEL_AT: Vector2i = Vector2i(2, 15)
const CANCEL_STRING: String = "Press B to Cancel"


## [param page] is 1 or 2. [param play_time] is `{hours, minutes}`, which page 2
## prints and page 1 has no use for. [param status] is the printer's own status
## line, empty for a page nothing is printing.
func render(
	page: int, player: String, play_time: Dictionary = {}, status: String = ""
) -> Image:
	if _gen1 != null:
		return _render_gen1(player)
	var indices := PackedByteArray()
	indices.resize(WIDTH * HEIGHT)
	var map: PackedByteArray = _maps[clampi(page, 1, 2) - 1]
	for cell: int in map.size():
		_blit(indices, int(map[cell]), Vector2i(cell % COLUMNS, cell / COLUMNS))
	if page == 2:
		_draw_page_2(indices, play_time)
	else:
		_draw_page_1(indices, player)
	if not status.is_empty():
		_draw_status(indices, status)
	return Gen2PicImage.from_indices(indices, WIDTH, HEIGHT, palette)


func _draw_status(indices: PackedByteArray, status: String) -> void:
	## `Textbox` is `ClearBox` and then the border, so the page under it is
	## blanked rather than showing through: the certificate's own lines sit in
	## the same rows this box covers.
	for row: int in STATUS_BOX_SIZE.y * TILE:
		var start: int = (STATUS_BOX_AT.y * TILE + row) * WIDTH + STATUS_BOX_AT.x * TILE
		for column: int in STATUS_BOX_SIZE.x * TILE:
			indices[start + column] = 0
	font.draw_box(
		Gen2OptionsStore.current().textbox_frame, indices, WIDTH,
		STATUS_BOX_AT.x * TILE, STATUS_BOX_AT.y * TILE,
		STATUS_BOX_SIZE.x, STATUS_BOX_SIZE.y
	)
	var line: int = 0
	for row: String in status.split("\n"):
		_text(indices, row, STATUS_TEXT_AT + Vector2i(0, line))
		line += 1
	_text(indices, CANCEL_STRING, CANCEL_AT)


func _draw_page_1(indices: PackedByteArray, player: String) -> void:
	_text(indices, "PLAYER", PLAYER_LABEL_AT)
	_text(indices, player, PLAYER_NAME_AT)
	for line: int in CERTIFICATION.size():
		_text(indices, CERTIFICATION[line], CERTIFICATION_AT + Vector2i(0, line))


## `PrintNum` twice: the hours in four cells with leading blanks, then the
## colon, then the minutes in two with leading zeros.
func _draw_page_2(indices: PackedByteArray, play_time: Dictionary) -> void:
	_text(indices, "GAME FREAK", GAME_FREAK_AT)
	_text(indices, "PLAY TIME", PLAY_TIME_AT)
	var hours: String = String.num_int64(maxi(int(play_time.get("hours", 0)), 0))
	_text(indices, hours.lpad(PLAY_TIME_HOUR_CELLS), PLAY_TIME_VALUE_AT)
	var at: Vector2i = PLAY_TIME_VALUE_AT + Vector2i(PLAY_TIME_HOUR_CELLS, 0)
	## `ld [hl], $67` writes a tile number rather than a character: the colon is
	## `DiplomaGFX`'s own, since the art is what `vTiles2` holds while the page
	## is up.
	_blit(indices, COLON_CODE, at)
	_text(
		indices,
		String.num_int64(maxi(int(play_time.get("minutes", 0)), 0)).lpad(2, "0"),
		at + Vector2i(1, 0)
	)


func _text(indices: PackedByteArray, text: String, at: Vector2i) -> void:
	font.draw_text(text, indices, WIDTH, at.x * TILE, at.y * TILE)


func _blit(into: PackedByteArray, code: int, at: Vector2i) -> void:
	if code >= Gen2Layout.FONT_FIRST_CODE:
		font.draw_code(code, into, WIDTH, at.x * TILE, at.y * TILE)
		return
	Gen2Font.blit_slot(
		_tiles, Gen2Layout.DIPLOMA_TILES * TILE, code, into, WIDTH, at.x * TILE, at.y * TILE
	)


## `DisplayDiploma` on a [Gen1Lcd], with `DrawPlayerCharacter`'s sprite moved 33
## pixels right behind the background; Yellow's `DisplayDiplomaTop` draws none.
func _render_gen1(player: String) -> Image:
	var lcd := Gen1Lcd.new()
	lcd.wy = Gen1Opening.WINDOW_OFF
	lcd.bgp = Gen1Opening.GB_PAL_NORMAL_BGP
	lcd.obp0 = Gen1Layout.DIPLOMA_OBP0
	lcd.fill_map(0, Gen1Text.SPACE)
	_gen1_load(lcd, "font", Gen1Lcd.BLOCK_TILES)
	if _gen1.id == RomRegistry.YELLOW:
		_gen1_load(lcd, "diploma_gfx", Gen1Lcd.SIGNED_BASE)
		_gen1_yellow_border(lcd)
	else:
		_gen1_load(lcd, "trainer_card_box", Gen1Lcd.SIGNED_BASE + Gen1Layout.DIPLOMA_BOX_TILES)
		_gen1_load(lcd, "trainer_card_names", Gen1Lcd.SIGNED_BASE + Gen1Layout.DIPLOMA_CIRCLE_CODE,
			Gen1Layout.DIPLOMA_CIRCLE_TILE, 1)
		_gen1_border(lcd)
		_gen1_load(lcd, "title_player", 0)
		_gen1_player_sprite(lcd)
	for index: int in _gen1_strings.size():
		_gen1_place(lcd, Gen1Layout.DIPLOMA_STRINGS_AT[index], _gen1_strings[index])
	_gen1_place(lcd, Gen1Layout.DIPLOMA_NAME_AT, Gen1Text.encode(player))
	return Gen1OpeningPage.colour(lcd.render(), [], [palette])


func _gen1_load(lcd: Gen1Lcd, sheet: String, at: int, first: int = 0, count: int = -1) -> void:
	var tiles: int = int(_gen1.tile_sheet(sheet).get("tiles", 0))
	lcd.load_tiles(at, _gen1.tile_indices(sheet), tiles, first, count if count >= 0 else tiles)


## `CableClub_TextBoxBorder` with `lb bc, 16, 18`.
func _gen1_border(lcd: Gen1Lcd) -> void:
	var edge: Dictionary = Gen1Layout.DIPLOMA_BORDER
	var map: PackedByteArray = lcd.maps[0]
	for row: int in ROWS:
		for column: int in COLUMNS:
			var tile: int = -1
			if row == 0:
				tile = int(edge["top_left"]) if column == 0 \
					else (int(edge["top_right"]) if column == COLUMNS - 1 else int(edge["top"]))
			elif row == ROWS - 1:
				tile = int(edge["bottom_left"]) if column == 0 \
					else (int(edge["bottom_right"]) if column == COLUMNS - 1 else int(edge["bottom"]))
			elif column == 0:
				tile = int(edge["left"])
			elif column == COLUMNS - 1:
				tile = int(edge["right"])
			if tile >= 0:
				map[row * Gen1Lcd.MAP_SIDE + column] = tile


## `DiplomaDrawHorizontalBorder` and `..VerticalBorder`, the corners written 0.
func _gen1_yellow_border(lcd: Gen1Lcd) -> void:
	var map: PackedByteArray = lcd.maps[0]
	for column: int in COLUMNS:
		map[column] = Gen1Layout.DIPLOMA_YELLOW_TOP[column % 2]
	for row: int in ROWS:
		for column: int in [0, COLUMNS - 1]:
			map[row * Gen1Lcd.MAP_SIDE + column] = Gen1Layout.DIPLOMA_YELLOW_SIDE[row % 2]
	map[0] = 0
	map[COLUMNS - 1] = 0


## `DrawPlayerCharacter`, then `.adjustPlayerGfxLoop` over every slot.
func _gen1_player_sprite(lcd: Gen1Lcd) -> void:
	var tile: int = 0
	for row: int in Gen1Opening.TITLE_PLAYER_ROWS:
		for column: int in Gen1Opening.TITLE_PLAYER_COLUMNS:
			lcd.set_sprite(
				tile, Gen1Opening.TITLE_PLAYER_AT.y + row * TILE,
				Gen1Opening.TITLE_PLAYER_AT.x + column * TILE + Gen1Layout.DIPLOMA_PLAYER_SHIFT,
				tile, Gen1Lcd.OAM_PRIO
			)
			tile += 1


## `PlaceString`: `next` drops two rows and `PlaceNextChar` spells `#` out.
func _gen1_place(lcd: Gen1Lcd, at: Vector2i, codes: PackedByteArray) -> void:
	var cell: Vector2i = at
	for code: int in codes:
		if code == Gen1Text.NEXT_LINE:
			cell = Vector2i(at.x, cell.y + 2)
			continue
		var word: String = String(Gen1Text.CONTROL_CHARACTERS.get(code, ""))
		var tiles: PackedByteArray = Gen1Text.encode(word) if not word.is_empty() \
			and not word.begins_with("<") else PackedByteArray([code])
		for tile: int in tiles:
			if cell.x < COLUMNS and cell.y < ROWS:
				lcd.maps[0][cell.y * Gen1Lcd.MAP_SIDE + cell.x] = tile
			cell.x += 1
