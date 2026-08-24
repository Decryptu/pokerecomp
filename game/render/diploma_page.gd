class_name Gen2DiplomaPage
extends RefCounted

## `PlaceDiplomaOnScreen` and `PrintDiplomaPage2` (`engine/events/diploma.asm`),
## the two whole screens the diploma is. Each is a stored tilemap with a few
## strings written into it, so this owns the tilemap walk and the strings and
## nothing else; node-free, so a check can read it back headless.
##
## A cell under `FONT_FIRST_CODE` names a tile of `DiplomaGFX` and a cell at or
## above it names a font glyph, which is the hardware's own split: the art is
## loaded into `vTiles2` and the font is already at the codes it prints under.

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


static func from_data(data: GameData) -> Gen2DiplomaPage:
	if data == null or not data.has_diploma():
		return null
	var page := Gen2DiplomaPage.new()
	page.font = Gen2Font.from_data(data)
	page.palette = data.diploma_palette()
	page._tiles = data.diploma_indices()
	page._maps = [data.diploma_tilemap(1), data.diploma_tilemap(2)]
	if page.font == null or page.palette.is_empty() or page._tiles.is_empty():
		return null
	for map: PackedByteArray in page._maps:
		if map.size() != RomLayout.DIPLOMA_TILEMAP_BYTES:
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
	if code >= RomLayout.FONT_FIRST_CODE:
		font.draw_code(code, into, WIDTH, at.x * TILE, at.y * TILE)
		return
	Gen2Font.blit_slot(
		_tiles, RomLayout.DIPLOMA_TILES * TILE, code, into, WIDTH, at.x * TILE, at.y * TILE
	)
