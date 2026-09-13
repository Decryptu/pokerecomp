class_name Gen2TrainerCardPage
extends RefCounted

## One page of the trainer card (`engine/menus/trainer_card.asm`), a tilemap
## screen written as `TrainerCard_InitBorder` writes it. `GetCardPic`'s 35-tile
## player pic at $00, `TrainerCardGFX`'s frame pieces at $23, 86 tiles at $29,
## the font from $80. Page 1's 86 start at `CardStatusGFX`, only six tiles long,
## so the copy runs on into `LeaderGFX`: that overrun is the cartridge's own.

const TILE: int = Gen2Font.TILE
const COLUMNS: int = 20
const ROWS: int = 18

const PAGE_1: int = 0
const PAGE_2: int = 1
const PAGE_3: int = 2

## Where each block of the cartridge's VRAM window begins.
const PIC_FIRST_TILE: int = 0x00
const FRAME_FIRST_TILE: int = 0x23
const STATUS_FIRST_TILE: int = 0x29
const STATUS_TILES: int = 86

## `TrainerCard_InitBorder`'s own tiles: $23 is the border, $24 the bottom-left
## piece and $1c the top-right corner. Crystal loads a tile of its own there;
## Gold and Silver point at a tile inside the card pic instead, which is the one
## thing the two versions of this routine disagree on.
const BORDER_TILE: int = 0x23
const BORDER_BOTTOM_LEFT_TILE: int = 0x24
const CORNER_TILE_CRYSTAL: int = 0x1C
const CORNER_TILE_GOLD_SILVER: int = 0x04
const BLANK_TILE: int = 0x7F

## `TrainerCard_PrintTopHalfOfCard` and `TrainerCard_Page1_PrintDexCaught_GameTime`.
const TOP_BORDER_ROWS: int = 5
const BOTTOM_BORDER_ROWS: int = 6
const BOTTOM_BORDER_AT: Vector2i = Vector2i(0, 8)

## `.Name_Money` is one string at (2,2) whose `next` moves `SCREEN_WIDTH * 2`,
## so NAME/ is on row 2, the ID tiles' empty line on row 4 and MONEY on row 6.
const NAME_LABEL_AT: Vector2i = Vector2i(2, 2)
const MONEY_LABEL_AT: Vector2i = Vector2i(2, 6)
const NAME_LABEL: String = "NAME/"
const MONEY_LABEL: String = "MONEY"
const PLAYER_NAME_AT: Vector2i = Vector2i(7, 2)
const ID_LABEL_AT: Vector2i = Vector2i(2, 4)
## `.ID_No`'s `db $27, $28`, two tiles of the card's own graphics rather than
## letters, which is why "ID No" is not spelled with the font.
const ID_LABEL_TILES: Array[int] = [0x27, 0x28]
const ID_NUMBER_AT: Vector2i = Vector2i(5, 4)
const ID_DIGITS: int = 5
const MONEY_AT: Vector2i = Vector2i(7, 6)
const MONEY_DIGITS: int = 6
const DIVIDER_AT: Vector2i = Vector2i(1, 3)
## `.HorizontalDivider`'s twelve $25 pieces and the $26 that ends it.
const DIVIDER_TILE: int = 0x25
const DIVIDER_END_TILE: int = 0x26
const DIVIDER_LENGTH: int = 12

## `hlcoord 14, 1` with `lb bc, 5, 7`: the pic is five tiles wide and seven tall.
const PIC_AT: Vector2i = Vector2i(14, 1)
const PIC_COLUMNS: int = 5
const PIC_ROWS: int = 7

## `.Dex_PlayTime`, one string at (2,10) whose own `next` puts PLAY TIME two
## rows down, beside the timer at (11,12).
const DEX_LABEL_AT: Vector2i = Vector2i(2, 10)
const PLAY_TIME_LABEL_AT: Vector2i = Vector2i(2, 12)
const DEX_LABEL: String = "#DEX"
const PLAY_TIME_LABEL: String = "PLAY TIME"
const DEX_COUNT_AT: Vector2i = Vector2i(15, 10)
const DEX_DIGITS: int = 3
## `ClearBox` at `hlcoord 1, 9` with `lb bc, 2, 17` when STATUSFLAGS_POKEDEX_F
## is clear, which takes the whole #DEX row and not only its count.
const NO_DEX_CLEAR_AT: Vector2i = Vector2i(1, 9)
const NO_DEX_CLEAR_ROWS: int = 2
const NO_DEX_CLEAR_COLUMNS: int = 17
## `hlcoord 11, 12` for the hours, then `inc hl` past the separator column.
const HOURS_AT: Vector2i = Vector2i(11, 12)
const HOURS_DIGITS: int = 4
const SEPARATOR_AT: Vector2i = Vector2i(15, 12)
const MINUTES_AT: Vector2i = Vector2i(16, 12)
const MINUTES_DIGITS: int = 2
## `xor ' ' ^ $2e` every 32 frames: the colon and a space, alternating.
const SEPARATOR_COLON_TILE: int = 0x2E

## `.StatusTilemap`'s five tiles, the "STATUS" strip over page 1's lower box.
const STATUS_TILEMAP_AT: Vector2i = Vector2i(2, 8)
const STATUS_TILEMAP: Array[int] = [0x29, 0x2A, 0x2B, 0x2C, 0x2D]

## `.Badges`, printed text rather than tiles, and the one string whose column is
## profile split: pokegold prints it two columns further right.
const BADGES_LABEL: String = "  BADGES"
const BADGES_LABEL_GOLD_SILVER: String = "BADGES"
const BADGES_LABEL_AT: Vector2i = Vector2i(10, 15)
const BADGES_LABEL_AT_GOLD_SILVER: Vector2i = Vector2i(12, 15)
## The arrow that ends it, a character code rather than a letter.
const BADGES_ARROW_CODE: int = 0xED

## Pages 2 and 3: `.BadgesTilemap`'s "BADGES" in card tiles, then the leaders'
## faces, four to a row, at $29 and $51.
const BADGES_TILEMAP_AT: Vector2i = Vector2i(2, 8)
const BADGES_TILEMAP: Array[int] = [0x79, 0x7A, 0x7B, 0x7C, 0x7D]
const LEADER_ROW_1_AT: Vector2i = Vector2i(2, 10)
const LEADER_ROW_1_FIRST_TILE: int = 0x29
const LEADER_ROW_2_AT: Vector2i = Vector2i(2, 13)
const LEADER_ROW_2_FIRST_TILE: int = 0x51
const LEADERS_PER_ROW: int = 4
## `TrainerCard_Page2_3_PlaceLeadersFaces` writes 4 tiles, then 3, then 3, all
## from one run, so a face is ten tiles in a 4x3 box with a hole at its corner.
const LEADER_FACE_COLUMNS: int = 4
const LEADER_FACE_ROWS: int = 3
const LEADER_FACE_TILES: int = 10
const LEADER_STRIDE: int = 4

## `_CGB_TrainerCard`'s attribute map in [constant
## Gen2Layout.CARD_PALETTE_CLASSES]' order, filled whatever page is on screen
## since the layout runs once in `.InitRAM`. The card takes the opposite
## gender's palette and the pic area the player's own, Clair's box is filled
## only for Kris, and the top-right corner is written twice.
const ATTRIBUTE_LEADER_BOXES: Array[Dictionary] = [
	{"at": Vector2i(2, 11), "palette": 1},
	{"at": Vector2i(6, 11), "palette": 2},
	{"at": Vector2i(10, 11), "palette": 3},
	{"at": Vector2i(14, 11), "palette": 4},
	{"at": Vector2i(2, 14), "palette": 5},
	{"at": Vector2i(6, 14), "palette": 6},
	{"at": Vector2i(10, 14), "palette": 7},
]
const ATTRIBUTE_BOX_ROWS: int = 2
const ATTRIBUTE_BOX_COLUMNS: int = 4
const CLAIR_BOX_AT: Vector2i = Vector2i(14, 14)
const CORNER_AT: Vector2i = Vector2i(18, 1)

var font: Gen2Font = null
var crystal: bool = true
var female: bool = false
## `StartMenu_TrainerInfo`'s card, which shares nothing with Crystal's three
## pages but this class's tile window and its own compose.
var gen1: bool = false
## The cartridge's VRAM window, as one indices strip per tile number.
var _tiles: Dictionary = {}


## [param data] supplies both the glyphs and the card's graphics; a cache
## without them answers null rather than drawing a card of blanks.
static func from_data(
	data: GameData, is_female: bool, is_crystal: bool
) -> Gen2TrainerCardPage:
	var glyphs: Gen2Font = Gen2Font.from_data(data)
	if glyphs == null or data == null:
		return null
	var out := Gen2TrainerCardPage.new()
	out.font = glyphs
	out.crystal = is_crystal
	out.female = is_female
	out.gen1 = data.generation == RomRegistry.GEN1
	if out.gen1:
		out._load_gen1_vram(data)
	else:
		out._load_vram(data, is_female)
	return out


func ready() -> bool:
	return font != null and not _tiles.is_empty()


## `GetCardPic`, `CardRightCornerGFX` and each page's own `Request2bpp`, in the
## order the cartridge copies them, so a later copy overwrites an earlier one at
## the same tile exactly as it does in VRAM.
func _load_vram(data: GameData, is_female: bool) -> void:
	var pic: String = "card_pic_female" if is_female and crystal else "card_pic_male"
	_load_sheet(data, pic, PIC_FIRST_TILE, Gen2Layout.CARD_PIC_TILES)
	_load_sheet(data, "card_frame", FRAME_FIRST_TILE, Gen2Layout.CARD_FRAME_TILES)
	if crystal:
		_load_sheet(data, "card_right_corner", CORNER_TILE_CRYSTAL, 1)


## The 86 tiles a page loads at $29. Page 1 takes them from the status strip and
## pages 2 and 3 from the leaders', which is the only difference between them.
func load_page_tiles(data: GameData, page: int) -> void:
	var sheet: String = "card_status" if page == PAGE_1 else "card_leaders"
	_load_sheet(data, sheet, STATUS_FIRST_TILE, STATUS_TILES)


## [param from] takes a run out of the middle of a sheet, which only the
## Generation 1 card's two scattered copies need.
func _load_sheet(
	data: GameData, name: String, first_tile: int, count: int, from: int = 0
) -> void:
	var indices: PackedByteArray = data.tile_indices(name)
	if indices.is_empty():
		return
	var width: int = indices.size() / TILE
	for offset: int in count:
		var tile: int = from + offset
		if (tile + 1) * TILE > width:
			break
		var cell := PackedByteArray()
		cell.resize(TILE * TILE)
		for y: int in TILE:
			for x: int in TILE:
				cell[y * TILE + x] = indices[y * width + tile * TILE + x]
		_tiles[first_tile + offset] = cell


## The whole 160x144 page as palette indices. [param page] is a `TRAINERCARD*`
## page number and [param page] one row of [method Gen2TrainerCard.page].
func draw(page: Dictionary) -> PackedByteArray:
	if gen1:
		return _draw_gen1(page)
	var map: PackedInt32Array = _blank_map()
	_draw_border(map, Vector2i.ZERO, TOP_BORDER_ROWS)
	_draw_border(map, BOTTOM_BORDER_AT, BOTTOM_BORDER_ROWS)
	_draw_top_half(map, page)
	match int(page.get("page", PAGE_1)):
		PAGE_1:
			_draw_page_1(map, page)
		_:
			_draw_badge_page(map)
	return _compose(map)


## `TrainerCard_InitBorder`: a solid row of $23, then [param rows] rows walled
## with $23, then a row that opens with $23 $24 and closes with $23, then a
## second solid row. The first row's own right-hand end carries the corner tile.
func _draw_border(map: PackedInt32Array, at: Vector2i, rows: int) -> void:
	for column: int in COLUMNS:
		_put(map, Vector2i(column, at.y), BORDER_TILE)
	_put(map, Vector2i(0, at.y + 1), BORDER_TILE)
	for column: int in range(1, COLUMNS - 2):
		_put(map, Vector2i(column, at.y + 1), BLANK_TILE)
	_put(map, Vector2i(COLUMNS - 2, at.y + 1), corner_tile())
	_put(map, Vector2i(COLUMNS - 1, at.y + 1), BORDER_TILE)
	for row: int in range(at.y + 2, at.y + 2 + rows - 1):
		_put(map, Vector2i(0, row), BORDER_TILE)
		for column: int in range(1, COLUMNS - 1):
			_put(map, Vector2i(column, row), BLANK_TILE)
		_put(map, Vector2i(COLUMNS - 1, row), BORDER_TILE)
	var closing: int = at.y + 1 + rows
	_put(map, Vector2i(0, closing), BORDER_TILE)
	_put(map, Vector2i(1, closing), BORDER_BOTTOM_LEFT_TILE)
	for column: int in range(2, COLUMNS - 1):
		_put(map, Vector2i(column, closing), BLANK_TILE)
	_put(map, Vector2i(COLUMNS - 1, closing), BORDER_TILE)
	for column: int in COLUMNS:
		_put(map, Vector2i(column, closing + 1), BORDER_TILE)


## Which tile the border's top-right corner is. Crystal loads a tile of its own
## over the pic's $1c; Gold and Silver reach into the pic at $04 instead.
func corner_tile() -> int:
	return CORNER_TILE_CRYSTAL if crystal else CORNER_TILE_GOLD_SILVER


func _draw_top_half(map: PackedInt32Array, page: Dictionary) -> void:
	_text(map, NAME_LABEL, NAME_LABEL_AT)
	_text(map, MONEY_LABEL, MONEY_LABEL_AT)
	_tilemap(map, ID_LABEL_TILES, ID_LABEL_AT)
	_text(map, String(page.get("player_name", "")), PLAYER_NAME_AT)
	## PRINTNUM_LEADINGZEROS over five digits, so the ID keeps its columns.
	_text(map, "%0*d" % [ID_DIGITS, int(page.get("player_id", 0))], ID_NUMBER_AT)
	## PRINTNUM_MONEY over six digits, which pads with spaces rather than zeros.
	_text(map, "%*d" % [MONEY_DIGITS, int(page.get("money", 0))], MONEY_AT)
	for index: int in DIVIDER_LENGTH:
		_put(map, DIVIDER_AT + Vector2i(index, 0), DIVIDER_TILE)
	_put(map, DIVIDER_AT + Vector2i(DIVIDER_LENGTH, 0), DIVIDER_END_TILE)
	_draw_pic(map)


## `predef PlaceGraphic` at (14,1), five wide and seven tall. The importer has
## already turned Crystal's column-major pic into the picture, so both profiles
## number these tiles the same way here.
func _draw_pic(map: PackedInt32Array) -> void:
	for row: int in PIC_ROWS:
		for column: int in PIC_COLUMNS:
			_put(
				map, PIC_AT + Vector2i(column, row),
				PIC_FIRST_TILE + row * PIC_COLUMNS + column
			)


func _draw_page_1(map: PackedInt32Array, page: Dictionary) -> void:
	_text(map, DEX_LABEL, DEX_LABEL_AT)
	_text(map, PLAY_TIME_LABEL, PLAY_TIME_LABEL_AT)
	_tilemap(map, STATUS_TILEMAP, STATUS_TILEMAP_AT)
	_draw_badges_label(map)
	## `CountSetBits` over wPokedexCaught, three digits and no leading zeros.
	_text(map, "%*d" % [DEX_DIGITS, int(page.get("caught", 0))], DEX_COUNT_AT)
	if not bool(page.get("pokedex", false)):
		_clear_box(map, NO_DEX_CLEAR_AT, NO_DEX_CLEAR_ROWS, NO_DEX_CLEAR_COLUMNS)
	_text(map, String(page.get("hours", "")), HOURS_AT)
	_text(map, String(page.get("minutes", "")), MINUTES_AT)
	if bool(page.get("separator", true)):
		_put(map, SEPARATOR_AT, SEPARATOR_COLON_TILE)


func _clear_box(map: PackedInt32Array, at: Vector2i, rows: int, columns: int) -> void:
	for row: int in rows:
		for column: int in columns:
			_put(map, at + Vector2i(column, row), BLANK_TILE)


## `.Badges` and the arrow that ends it. The string and its column are the one
## profile split on this page.
func _draw_badges_label(map: PackedInt32Array) -> void:
	var label: String = BADGES_LABEL if crystal else BADGES_LABEL_GOLD_SILVER
	var at: Vector2i = BADGES_LABEL_AT if crystal else BADGES_LABEL_AT_GOLD_SILVER
	_text(map, label, at)
	_code(map, BADGES_ARROW_CODE, at + Vector2i(label.length(), 0))


## `TrainerCard_Page2_3_InitObjectsAndStrings`. The badges themselves are
## objects, so the page under them is the leaders' faces and nothing else.
func _draw_badge_page(map: PackedInt32Array) -> void:
	_tilemap(map, BADGES_TILEMAP, BADGES_TILEMAP_AT)
	_draw_leader_row(map, LEADER_ROW_1_AT, LEADER_ROW_1_FIRST_TILE)
	_draw_leader_row(map, LEADER_ROW_2_AT, LEADER_ROW_2_FIRST_TILE)


## Four faces across, each `TrainerCard_Page2_3_PlaceLeadersFaces`' own ten
## tiles: a full row of four, then three, then three, the last column of the
## lower two rows left as it was.
func _draw_leader_row(map: PackedInt32Array, at: Vector2i, first_tile: int) -> void:
	var tile: int = first_tile
	for face: int in LEADERS_PER_ROW:
		var origin: Vector2i = at + Vector2i(face * LEADER_STRIDE, 0)
		for row: int in LEADER_FACE_ROWS:
			var width: int = LEADER_FACE_COLUMNS if row == 0 else LEADER_FACE_COLUMNS - 1
			for column: int in width:
				_put(map, origin + Vector2i(column, row), tile)
				tile += 1


## `_CGB_TrainerCard`, as one palette slot per tile.
func attributes() -> PackedInt32Array:
	var map := PackedInt32Array()
	map.resize(COLUMNS * ROWS)
	map.fill(1 if not female else 0)
	_fill_attributes(map, PIC_AT, PIC_ROWS, PIC_COLUMNS, 0 if not female else 1)
	for box: Dictionary in ATTRIBUTE_LEADER_BOXES:
		_fill_attributes(
			map, box["at"], ATTRIBUTE_BOX_ROWS, ATTRIBUTE_BOX_COLUMNS, int(box["palette"])
		)
	if female:
		_fill_attributes(map, CLAIR_BOX_AT, ATTRIBUTE_BOX_ROWS, ATTRIBUTE_BOX_COLUMNS, 1)
	## The corner is written twice; this second write is the one that stands, and
	## it is the border's palette rather than the pic's.
	map[CORNER_AT.y * COLUMNS + CORNER_AT.x] = 1 if not female else 0
	return map


func _fill_attributes(
	map: PackedInt32Array, at: Vector2i, rows: int, columns: int, palette: int
) -> void:
	for row: int in rows:
		for column: int in columns:
			var x: int = at.x + column
			var y: int = at.y + row
			if x < 0 or y < 0 or x >= COLUMNS or y >= ROWS:
				continue
			map[y * COLUMNS + x] = palette


func _blank_map() -> PackedInt32Array:
	var map := PackedInt32Array()
	map.resize(COLUMNS * ROWS)
	map.fill(BLANK_TILE)
	return map


func _put(map: PackedInt32Array, at: Vector2i, tile: int) -> void:
	if at.x < 0 or at.y < 0 or at.x >= COLUMNS or at.y >= ROWS:
		return
	map[at.y * COLUMNS + at.x] = tile


func _tilemap(map: PackedInt32Array, tiles: Array[int], at: Vector2i) -> void:
	for index: int in tiles.size():
		_put(map, at + Vector2i(index, 0), tiles[index])


## Printed text is character codes, which are tile numbers in the font's own
## window, so it goes into the same map as everything else.
##
## `#` ($54) is not a tile: [method Gen2Text.encode] prints `PlacePOKe`'s four
## characters for it, so the label the source writes as "#DEX" occupies seven
## columns and reads POKéDEX.
func _text(map: PackedInt32Array, text: String, at: Vector2i) -> void:
	var codes: PackedByteArray = Gen2Text.encode(text)
	for index: int in codes.size():
		_put(map, at + Vector2i(index, 0), codes[index])


func _code(map: PackedInt32Array, code: int, at: Vector2i) -> void:
	_put(map, at, code)


## Resolves every tile number to pixels: the card's own graphics out of the VRAM
## window, everything else out of the font.
func _compose(map: PackedInt32Array) -> PackedByteArray:
	var width: int = COLUMNS * TILE
	var indices := PackedByteArray()
	indices.resize(width * ROWS * TILE)
	for row: int in ROWS:
		for column: int in COLUMNS:
			var tile: int = map[row * COLUMNS + column]
			var at := Vector2i(column * TILE, row * TILE)
			if _tiles.has(tile):
				_blit(indices, width, _tiles[tile], at)
			elif tile != BLANK_TILE:
				font.draw_code(tile, indices, width, at.x, at.y, Gen2Text.FONT_MAIN)
	return indices


func _blit(
	indices: PackedByteArray, width: int, cell: PackedByteArray, at: Vector2i
) -> void:
	for y: int in TILE:
		for x: int in TILE:
			indices[(at.y + y) * width + at.x + x] = cell[y * TILE + x]


## `StartMenu_TrainerInfo`'s card (engine/menus/start_sub_menus.asm): one page,
## `DrawTrainerInfo`'s two boxes and three lines with `DrawBadges`' eight cells.

const GEN1_PAGE: int = 3

## `DisplayPicCenteredOrUpperRight`'s corner and the 7x7 `CopyUncompressedPicToHL`
## writes from it. Two columns run off the right onto the next row, which is the
## spill `TrainerInfo_DrawVerticalLine` blanks.
const GEN1_PIC_AT := Vector2i(15, 1)
const GEN1_PIC_TILES: int = 7
## `ld hl, vChars2 tile $07 / ld de, vChars2 tile $00 / ld bc, $1c tiles`: the
## picture walks one column forward in VRAM, so a tile number draws its neighbour.
const GEN1_PIC_SHIFT: int = 0x07
const GEN1_PIC_SHIFTED: int = 0x1C
const GEN1_SPILL_AT := Vector2i(0, 2)
const GEN1_SPILL_COLUMNS: int = 2
const GEN1_SPILL_ROWS: int = 8

## `TrainerInfo_DrawTextBox`'s eight tiles and its two boxes, six rows inside.
const GEN1_BOX_TOP_LEFT: int = 0x79
const GEN1_BOX_TOP: int = 0x7A
const GEN1_BOX_TOP_RIGHT: int = 0x7B
const GEN1_BOX_LEFT: int = 0x7C
const GEN1_BOX_RIGHT: int = 0x78
const GEN1_BOX_BOTTOM_LEFT: int = 0x7D
const GEN1_BOX_BOTTOM: int = 0x77
const GEN1_BOX_BOTTOM_RIGHT: int = 0x7E
const GEN1_BOX_ROWS: int = 6
const GEN1_TOP_BOX_AT := Vector2i(0, 0)
const GEN1_TOP_BOX_WIDTH: int = 18
const GEN1_BOTTOM_BOX_AT := Vector2i(1, 10)
const GEN1_BOTTOM_BOX_WIDTH: int = 16
## The two columns beside the lower box, filled with the card's own background.
const GEN1_SIDE_COLUMNS: Array[int] = [0, COLUMNS - 1]
const GEN1_SIDE_AT: int = 10
const GEN1_SIDE_ROWS: int = 8

## `TrainerInfo_NameMoneyTimeText`, whose `next` drops two rows.
const GEN1_LABELS: Array[String] = ["NAME/", "MONEY/", "TIME/"]
const GEN1_LABELS_AT := Vector2i(2, 2)
const GEN1_ROW_STEP: int = 2
const GEN1_NAME_AT := Vector2i(7, 2)
const GEN1_MONEY_AT := Vector2i(8, 4)
const GEN1_TIME_AT := Vector2i(9, 6)
## `TrainerInfo_BadgesText`'s `db $76,"BADGES",$76`.
const GEN1_BADGES_LABEL: String = "BADGES"
const GEN1_BADGES_LABEL_AT := Vector2i(6, 9)

## `DrawBadges`' two `hlcoord`s and four cells each, four columns apart: a number
## tile, two name tiles beside it and a 2x2 face under those.
const GEN1_BADGE_ROWS: Array[Vector2i] = [Vector2i(2, 11), Vector2i(2, 14)]
const GEN1_BADGES_PER_ROW: int = 4
const GEN1_BADGE_STRIDE: int = 4
## `.FaceBadgeTiles`, and the `add 4` that swaps a leader's face for the badge.
const GEN1_FACE_TILES: Array[int] = [
	0x20, 0x28, 0x30, 0x38, 0x40, 0x48, 0x50, 0x58,
]

## `BlkPacket_TrainerCard`'s ten blocks as (x1, y1, x2, y2, palette), verbatim.
## Every other cell takes palette 0. Three of them are the Rainbow badge and
## none of the three is on it: the cell is (15,12) to (16,13) and the packet
## colours (16,11), (14,13) and (16,13) instead, which is the cartridge's.
const GEN1_ATTRIBUTE_BLOCKS: Array[Array] = [
	[3, 12, 4, 13, 0], [7, 12, 8, 13, 1], [11, 12, 12, 13, 3],
	[16, 11, 17, 12, 2], [14, 13, 15, 14, 1], [16, 13, 17, 14, 3],
	[3, 15, 4, 16, 2], [7, 15, 8, 16, 3], [11, 15, 12, 16, 2],
	[15, 15, 16, 16, 1],
]
## `PalPacket_TrainerCard`'s own `SuperPalettes` rows, in packet order.
const GEN1_PALETTES: Array[int] = [
	Gen1Layout.PAL_MEWMON, Gen1Layout.PAL_BADGE,
	Gen1Layout.PAL_REDMON, Gen1Layout.PAL_YELLOWMON,
]


## `DrawTrainerInfo` in write order: the picture, the spill blanked over it, both
## boxes, the labels, then `DrawBadges`.
func _draw_gen1(page: Dictionary) -> PackedByteArray:
	return _compose(gen1_map(page))


## The card as tile numbers, which is what a sweep reads: the pixels behind them
## are the four sheets' own.
func gen1_map(page: Dictionary) -> PackedInt32Array:
	var map: PackedInt32Array = _blank_map()
	for row: int in GEN1_PIC_TILES:
		for column: int in GEN1_PIC_TILES:
			_put_wrapped(
				map, GEN1_PIC_AT.y * COLUMNS + GEN1_PIC_AT.x + column * 1 + row * COLUMNS,
				column * GEN1_PIC_TILES + row
			)
	for column: int in GEN1_SPILL_COLUMNS:
		for row: int in GEN1_SPILL_ROWS:
			_put(map, GEN1_SPILL_AT + Vector2i(column, row), BLANK_TILE)
	_gen1_box(map, GEN1_TOP_BOX_AT, GEN1_TOP_BOX_WIDTH)
	_gen1_box(map, GEN1_BOTTOM_BOX_AT, GEN1_BOTTOM_BOX_WIDTH)
	for column: int in GEN1_SIDE_COLUMNS:
		for row: int in GEN1_SIDE_ROWS:
			_put(map, Vector2i(column, GEN1_SIDE_AT + row), Gen1Layout.TRAINER_CARD_FILL_CODE)
	_put(map, GEN1_BADGES_LABEL_AT, Gen1Layout.TRAINER_CARD_CIRCLE_CODE)
	_gen1_text(map, GEN1_BADGES_LABEL, GEN1_BADGES_LABEL_AT + Vector2i(1, 0))
	_put(
		map, GEN1_BADGES_LABEL_AT + Vector2i(GEN1_BADGES_LABEL.length() + 1, 0),
		Gen1Layout.TRAINER_CARD_CIRCLE_CODE
	)
	for index: int in GEN1_LABELS.size():
		_gen1_text(
			map, GEN1_LABELS[index], GEN1_LABELS_AT + Vector2i(0, index * GEN1_ROW_STEP)
		)
	_gen1_text(map, String(page.get("player_name", "")), GEN1_NAME_AT)
	## `PrintBCDNumber` with LEFT_ALIGN and the money sign, so the `¥` sits
	## against the first digit and nothing is padded.
	_gen1_text(map, Gen2MartPage.money_string(int(page.get("money", 0)), true), GEN1_MONEY_AT)
	_gen1_time(map, page)
	_draw_gen1_badges(map, page.get("badges", []) as Array)
	return map


## `PrintNumber` with LEFT_ALIGN, the colon the card copies in, then the minutes.
func _gen1_time(map: PackedInt32Array, page: Dictionary) -> void:
	var hours: String = String(page.get("hours", "")).strip_edges()
	_gen1_text(map, hours, GEN1_TIME_AT)
	var at: Vector2i = GEN1_TIME_AT + Vector2i(hours.length(), 0)
	_put(map, at, Gen1Layout.TRAINER_CARD_COLON_CODE)
	_gen1_text(map, String(page.get("minutes", "")), at + Vector2i(1, 0))


## `DrawBadges`: both counters step whether or not their tile is drawn, and an
## owned badge shows the badge rather than the leader's face and no name.
func _draw_gen1_badges(map: PackedInt32Array, badges: Array) -> void:
	var number: int = Gen1Layout.BADGE_NUMBER_CODE
	var name_tile: int = Gen1Layout.TRAINER_CARD_NAME_CODE
	for row: int in GEN1_BADGE_ROWS.size():
		for column: int in GEN1_BADGES_PER_ROW:
			var index: int = row * GEN1_BADGES_PER_ROW + column
			var at: Vector2i = GEN1_BADGE_ROWS[row] \
				+ Vector2i(column * GEN1_BADGE_STRIDE, 0)
			_put(map, at, number)
			number += 1
			var owned: bool = index < badges.size() and bool(badges[index])
			if not owned:
				_put(map, at + Vector2i(1, 0), name_tile)
				_put(map, at + Vector2i(2, 0), name_tile + 1)
			name_tile += 2
			var face: int = GEN1_FACE_TILES[index] \
				+ (Gen1Layout.BADGE_FACE_BADGE_AT if owned else 0)
			for cell: int in 4:
				@warning_ignore("integer_division")
				_put(map, at + Vector2i(1 + cell % 2, 1 + cell / 2), face + cell)


## `TrainerInfo_DrawTextBox`, whose width is the inside.
func _gen1_box(map: PackedInt32Array, at: Vector2i, width: int) -> void:
	_gen1_edge(map, at, width, GEN1_BOX_TOP_LEFT, GEN1_BOX_TOP, GEN1_BOX_TOP_RIGHT)
	for row: int in GEN1_BOX_ROWS:
		_put(map, Vector2i(at.x, at.y + 1 + row), GEN1_BOX_LEFT)
		_put(map, Vector2i(at.x + width + 1, at.y + 1 + row), GEN1_BOX_RIGHT)
	_gen1_edge(
		map, Vector2i(at.x, at.y + GEN1_BOX_ROWS + 1), width,
		GEN1_BOX_BOTTOM_LEFT, GEN1_BOX_BOTTOM, GEN1_BOX_BOTTOM_RIGHT
	)


func _gen1_edge(
	map: PackedInt32Array, at: Vector2i, width: int, left: int, middle: int, right: int
) -> void:
	_put(map, at, left)
	for column: int in width:
		_put(map, at + Vector2i(1 + column, 0), middle)
	_put(map, at + Vector2i(width + 1, 0), right)


## `_CGB_TrainerCard`'s counterpart: `BlkPacket_TrainerCard`'s ten blocks over
## palette 0.
func gen1_attributes() -> PackedInt32Array:
	var map := PackedInt32Array()
	map.resize(COLUMNS * ROWS)
	for block: Array in GEN1_ATTRIBUTE_BLOCKS:
		for y: int in range(int(block[1]), int(block[3]) + 1):
			for x: int in range(int(block[0]), int(block[2]) + 1):
				if x < COLUMNS and y < ROWS:
					map[y * COLUMNS + x] = int(block[4])
	return map


## `hlcoord 15, 1`'s own write, which runs past the right edge onto the next row.
func _put_wrapped(map: PackedInt32Array, cell: int, tile: int) -> void:
	if cell < 0 or cell >= map.size():
		return
	map[cell] = tile


func _gen1_text(map: PackedInt32Array, text: String, at: Vector2i) -> void:
	var codes: PackedByteArray = Gen1Text.encode(text)
	for index: int in codes.size():
		_put(map, at + Vector2i(index, 0), codes[index])


## The card's own VRAM, in copy order: the picture at $00, the leaders' faces over
## its tail, the erased names, the box pieces, and the two tiles it drops into the
## font's window.
func _load_gen1_vram(data: GameData) -> void:
	_load_gen1_pic(data)
	_load_sheet(data, "badge_faces", Gen1Layout.BADGE_FACE_CODE, Gen1Layout.BADGE_FACE_TILES)
	_load_sheet(
		data, "trainer_card_names", Gen1Layout.TRAINER_CARD_NAME_CODE,
		Gen1Layout.TRAINER_CARD_NAME_TILES
	)
	_load_sheet(
		data, "trainer_card_box", Gen1Layout.TRAINER_CARD_BOX_CODE,
		Gen1Layout.TRAINER_CARD_BOX_TILES - 1
	)
	_load_sheet(
		data, "badge_numbers", Gen1Layout.BADGE_NUMBER_CODE, Gen1Layout.BADGE_NUMBER_TILES
	)
	_load_sheet(
		data, "font_extra", Gen1Layout.TRAINER_CARD_COLON_CODE, 1,
		Gen1Layout.TRAINER_CARD_COLON_TILE
	)
	_load_sheet(
		data, "trainer_card_box", Gen1Layout.TRAINER_CARD_FILL_CODE, 1,
		Gen1Layout.TRAINER_CARD_BOX_TILES - 1
	)


## `RedPicFront` cut into the 7x7 block column by column, then walked forward by
## [constant GEN1_PIC_SHIFT].
func _load_gen1_pic(data: GameData) -> void:
	var record: Dictionary = data.player_frontpic()
	if record.is_empty():
		return
	var cell: Dictionary = Gen2PicImage.atlas_cell(
		data.atlas_indices("player_front"), data.atlas("player_front"), record
	)
	if cell.is_empty():
		return
	var indices: PackedByteArray = cell["indices"]
	var width: int = int(cell["width"])
	var tiles: Array = []
	for column: int in GEN1_PIC_TILES:
		for row: int in GEN1_PIC_TILES:
			var block := PackedByteArray()
			block.resize(TILE * TILE)
			for y: int in TILE:
				for x: int in TILE:
					block[y * TILE + x] = indices[
						(row * TILE + y) * width + column * TILE + x
					]
			tiles.append(block)
	for tile: int in tiles.size():
		var from: int = tile + GEN1_PIC_SHIFT if tile < GEN1_PIC_SHIFTED else tile
		if from < tiles.size():
			_tiles[tile] = tiles[from]
