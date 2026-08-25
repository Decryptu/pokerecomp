class_name Gen2LinkPage
extends RefCounted

## The two screens the cable club draws: `InitTradeMenuDisplay`'s trade screen
## (`engine/link/link.asm`) and `ReadAndPrintLinkBattleRecord`'s record page
## (`engine/battle/core.asm`).
##
## Both are drawn with `LinkTextboxAtHL` rather than `Textbox`, which is a border
## of its own out of `LinkCommsBorderGFX` and not the frame the OPTION menu
## chooses. The two cartridges lay that border out differently and this is the
## one place that difference shows: Crystal loads seventy tiles at `vTiles2` and
## `LoadCableTradeBorderTilemap` puts a whole screen of them down, while Gold
## and Silver load nine at `$76` and `PlaceTradeScreenTextbox` draws two ordinary
## boxes with them.
##
## Node-free, the way [Gen2DiplomaPage] is: it writes palette indices into a
## buffer so a check can read a screen back headless.

const TILE: int = Gen2Font.TILE
const COLUMNS: int = 20
const ROWS: int = 18
const WIDTH: int = COLUMNS * TILE
const HEIGHT: int = ROWS * TILE

## `_LinkTextbox`'s eight tiles, in the order it places them: top left, top,
## top right, left, right, bottom left, bottom, bottom right. Crystal's are
## `$30` to `$37` in that order; Gold and Silver's `LinkTextboxAtHL` names
## `$78`, `$79`, `$7a`, `$7b`, `$77`, `$7c`, `$76`, `$7d`, which are those
## offsets from the nine-tile block it loads at `$76`.
const CRYSTAL_BOX_TILES: Array[int] = [0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37]
const GOLD_SILVER_BOX_TILES: Array[int] = [2, 3, 4, 5, 1, 6, 0, 7]

## `PlaceTradePartnerNamesAndParty` (`engine/link/time_capsule.asm`): the two
## names and the two species lists, and the `$14` tile it writes at the cell each
## name ended on. That tile is `LinkCommsBorderGFX`'s own, so it is only a tile
## on Crystal, where the whole block sits at `vTiles2` tile zero.
const PLAYER_NAME_AT: Vector2i = Vector2i(4, 0)
const PARTNER_NAME_AT: Vector2i = Vector2i(4, 8)
const PLAYER_LIST_AT: Vector2i = Vector2i(7, 1)
const PARTNER_LIST_AT: Vector2i = Vector2i(7, 9)
const NAME_END_TILE: int = 0x14

## `LinkTrade_PlayerPartyMenu` and `LinkTrade_OTPartyMenu`: `w2DMenuCursorInitX`
## is 6 on both and `InitY` is 1 and 9. `.UpdateCursor` writes `$1f` there and
## again `MON_NAME_LENGTH` columns to the right, so a selected row is marked at
## both ends of its name.
const CURSOR_COLUMN: int = 6
const CURSOR_TILE: int = 0x1F
const MON_NAME_LENGTH: int = 11

## `LinkTradePlaceArrow`, which shows which Pokemon the other player offered.
const PARTNER_ARROW: String = "▷"

## `InitTradeSpeciesList`'s own `CANCEL`, and the `'▶'`
## `LinkTradePartymonMenuCheckCancel` blinks in front of it.
const CANCEL_AT: Vector2i = Vector2i(10, 17)
const CANCEL_STRING: String = "CANCEL"
const CANCEL_ARROW_AT: Vector2i = Vector2i(9, 17)
const CANCEL_ARROW: String = "▶"
const CANCEL_ARROW_SENT: String = "▷"

## `LinkTrade_TradeStatsMenu`: a one-row box across the bottom and the two words
## in it, with the cursor at column 1 or column 11.
const FOOTER_BOX: Rect2i = Rect2i(0, 15, 18, 1)
const FOOTER_AT: Vector2i = Vector2i(2, 16)
const FOOTER_STRING: String = "STATS     TRADE"
const FOOTER_CURSOR_ROW: int = 16
const FOOTER_STATS_COLUMN: int = 1
const FOOTER_TRADE_COLUMN: int = 11

## `LinkTrade`'s question box and the TRADE/CANCEL menu it opens over it.
const MESSAGE_BOX: Rect2i = Rect2i(0, 12, 18, 4)
const MESSAGE_AT: Vector2i = Vector2i(1, 14)
## `PrintTextboxTextAt` runs the ordinary text engine, whose lines are two rows
## apart; `PlaceString` puts its own `next` on the very next row. Both print into
## this box, so the caller says which it is.
const MESSAGE_PRINTED_SPACING: int = 2
const MESSAGE_PLACED_SPACING: int = 1
const CONFIRM_BOX: Rect2i = Rect2i(10, 7, 7, 3)
const CONFIRM_AT: Vector2i = Vector2i(12, 8)
const CONFIRM_ROWS: Array[String] = ["TRADE", "CANCEL"]
## `w2DMenuCursorOffsets` is `$20`, so the two rows are two apart.
const CONFIRM_ROW_SPACING: int = 2
const CONFIRM_CURSOR_COLUMN: int = 11

## `PlaceWaitingTextAndSyncAndExchangeNybble.PlaceWaitingText`.
const WAITING_BOX: Rect2i = Rect2i(4, 10, 10, 1)
const WAITING_AT: Vector2i = Vector2i(5, 11)
const WAITING_STRING: String = "WAITING..!"

## `LinkCommunications`' own opening box, which stands while the two parties are
## exchanged.
const PLEASE_WAIT_BOX: Rect2i = Rect2i(3, 8, 12, 2)
const PLEASE_WAIT_AT: Vector2i = Vector2i(4, 10)
const PLEASE_WAIT_STRING: String = "Please wait!"

## `String_TradeCompleted` and `String_TooBadTheTradeWasCanceled`, which are
## inline `db` strings rather than `text_far` stubs.
const TRADE_COMPLETED: String = "Trade completed!"
const TRADE_CANCELED: String = "Too bad! The trade\nwas canceled!"

## `ReadAndPrintLinkBattleRecord`'s own strings and columns. `PrintNum`'s
## `lb bc, 2, 4` is two bytes printed in four cells, and the three counters are
## five columns apart.
const RECORD_TITLE_AT: Vector2i = Vector2i(1, 0)
const RECORD_TITLE: String = "'s RECORD"
const RECORD_TOTAL_AT: Vector2i = Vector2i(0, 2)
const RECORD_TOTAL: String = "TOTAL  WIN LOSE DRAW"
const RECORD_TOTALS_AT: Vector2i = Vector2i(6, 4)
const RECORD_RESULT_AT: Vector2i = Vector2i(0, 6)
const RECORD_RESULT: String = "RESULT WIN LOSE DRAW"
const RECORD_ROWS_AT: Vector2i = Vector2i(0, 8)
const RECORD_ROW_SPACING: int = 2
const RECORD_COLUMN_STRIDE: int = 5
const RECORD_DIGITS: int = 4
## `.Format`, which is what an unused row prints.
const RECORD_EMPTY_NAME: String = "  ---"
const RECORD_EMPTY_COUNTS: String = "-"

var font: Gen2Font = null
var palette: PackedColorArray = PackedColorArray()

var _tiles: PackedByteArray = PackedByteArray()
var _tile_count: int = 0
var _screen: PackedByteArray = PackedByteArray()
var _cable_top: PackedByteArray = PackedByteArray()
var _cable_bottom: PackedByteArray = PackedByteArray()
var _box_tiles: Array[int] = CRYSTAL_BOX_TILES


static func from_data(data: GameData) -> Gen2LinkPage:
	if data == null or not data.has_link_border():
		return null
	var page := Gen2LinkPage.new()
	page.font = Gen2Font.from_data(data)
	if page.font == null:
		return null
	## `SetTradeRoomBGPals` is `GetSGBLayout SCGB_DIPLOMA`, the same two colours
	## every 1bpp page here is drawn through.
	page.palette = Gen2Palette.pic_palette(PackedColorArray([Color.WHITE, Color.BLACK]))
	page._tiles = data.link_border_indices()
	page._screen = data.link_border_tilemap("screen")
	page._cable_top = data.link_border_tilemap("cable_top")
	page._cable_bottom = data.link_border_tilemap("cable_bottom")
	page._tile_count = RomLayout.LINK_BORDER_TILES_CRYSTAL if not page._screen.is_empty() \
		else RomLayout.LINK_BORDER_TILES_GOLD_SILVER
	page._box_tiles = CRYSTAL_BOX_TILES if not page._screen.is_empty() \
		else GOLD_SILVER_BOX_TILES
	return page


## Whether this cartridge lays the trade screen out from a tilemap, which is
## Crystal alone.
func has_screen_tilemap() -> bool:
	return not _screen.is_empty()


## `InitTradeMenuDisplay` and everything `LinkTradeMenu` draws over it.
##
## [param state] carries what is on screen rather than what the player may do:
## `player`/`partner` are `{name, species}` with the species names already
## resolved, `list` is 0 for the player's half and 1 for the partner's, `index`
## the cursor row, `partner_choice` the row `LinkTradePlaceArrow` marks or -1,
## `footer` -1 for no footer and 0 or 1 for STATS or TRADE, `cancel` whether the
## cursor is on CANCEL, `message` the lines the bottom box prints, `confirm` the
## TRADE/CANCEL row or -1, and `waiting` whether `WAITING..!` stands.
func draw_trade(state: Dictionary) -> PackedByteArray:
	var indices := PackedByteArray()
	indices.resize(WIDTH * HEIGHT)
	if font == null:
		return indices
	_draw_trade_background(indices)
	var player: Dictionary = state.get("player", {})
	var partner: Dictionary = state.get("partner", {})
	_draw_party(indices, player, PLAYER_NAME_AT, PLAYER_LIST_AT)
	_draw_party(indices, partner, PARTNER_NAME_AT, PARTNER_LIST_AT)
	_text(indices, CANCEL_STRING, CANCEL_AT)

	var partner_choice: int = int(state.get("partner_choice", -1))
	if partner_choice >= 0:
		_text(
			indices, PARTNER_ARROW,
			Vector2i(CURSOR_COLUMN, PARTNER_LIST_AT.y + partner_choice)
		)
	if bool(state.get("cancel", false)):
		_text(
			indices,
			CANCEL_ARROW_SENT if bool(state.get("cancel_sent", false)) else CANCEL_ARROW,
			CANCEL_ARROW_AT
		)
	else:
		_draw_cursor(indices, state)

	var footer: int = int(state.get("footer", -1))
	if footer >= 0:
		_box(indices, FOOTER_BOX)
		_text(indices, FOOTER_STRING, FOOTER_AT)
		_text(indices, CANCEL_ARROW, Vector2i(
			FOOTER_TRADE_COLUMN if footer == 1 else FOOTER_STATS_COLUMN,
			FOOTER_CURSOR_ROW
		))

	var message: Array = state.get("message", [])
	if not message.is_empty():
		_box(indices, MESSAGE_BOX)
		var spacing: int = int(state.get("message_spacing", MESSAGE_PRINTED_SPACING))
		for line: int in message.size():
			_text(
				indices, String(message[line]),
				MESSAGE_AT + Vector2i(0, line * spacing)
			)
	var confirm: int = int(state.get("confirm", -1))
	if confirm >= 0:
		_box(indices, CONFIRM_BOX)
		for row: int in CONFIRM_ROWS.size():
			_text(
				indices, CONFIRM_ROWS[row],
				CONFIRM_AT + Vector2i(0, row * CONFIRM_ROW_SPACING)
			)
		_text(indices, CANCEL_ARROW, Vector2i(
			CONFIRM_CURSOR_COLUMN, CONFIRM_AT.y + confirm * CONFIRM_ROW_SPACING
		))
	if bool(state.get("waiting", false)):
		_box(indices, WAITING_BOX)
		_text(indices, WAITING_STRING, WAITING_AT)
	return indices


## `LinkCommunications`' opening screen, which is the border with one box on it
## and nothing else: the two parties have not been exchanged yet.
func draw_please_wait() -> PackedByteArray:
	var indices := PackedByteArray()
	indices.resize(WIDTH * HEIGHT)
	if font == null:
		return indices
	_draw_trade_background(indices)
	_box(indices, PLEASE_WAIT_BOX)
	_text(indices, PLEASE_WAIT_STRING, PLEASE_WAIT_AT)
	return indices


## `ReadAndPrintLinkBattleRecord`. [param record] is
## [member Gen2SaveData.link_record]; [param saved] is `wSavedAtLeastOnce`,
## which is what makes a slot with no save behind it print zeros and dashes.
func draw_record(record: Dictionary, player: String, saved: bool = true) -> PackedByteArray:
	var indices := PackedByteArray()
	indices.resize(WIDTH * HEIGHT)
	if font == null:
		return indices
	var normalized: Dictionary = Gen2LinkSession.normalize_record(record)
	_text(indices, player + RECORD_TITLE, RECORD_TITLE_AT)
	_text(indices, RECORD_TOTAL, RECORD_TOTAL_AT)
	_text(indices, RECORD_RESULT, RECORD_RESULT_AT)
	for column: int in 3:
		var key: String = ["wins", "losses", "draws"][column]
		var value: String = str(int(normalized[key])) if saved else "0"
		_text(indices, value.lpad(RECORD_DIGITS), RECORD_TOTALS_AT + Vector2i(
			column * RECORD_COLUMN_STRIDE, 0
		))
	var rows: Array = normalized["records"]
	for row: int in rows.size():
		var entry: Dictionary = rows[row]
		var at: Vector2i = RECORD_ROWS_AT + Vector2i(0, row * RECORD_ROW_SPACING)
		if String(entry.get("name", "")).is_empty() or not saved:
			_text(indices, RECORD_EMPTY_NAME, at)
			for column: int in 3:
				_text(indices, RECORD_EMPTY_COUNTS, at + Vector2i(
					RECORD_TOTALS_AT.x + column * RECORD_COLUMN_STRIDE + 3, 1
				))
			continue
		_text(indices, String(entry["name"]), at)
		for column: int in 3:
			var key: String = ["wins", "losses", "draws"][column]
			_text(indices, str(int(entry[key])).lpad(RECORD_DIGITS), at + Vector2i(
				RECORD_TOTALS_AT.x + column * RECORD_COLUMN_STRIDE, 1
			))
	return indices


func image(indices: PackedByteArray) -> Image:
	return Gen2PicImage.from_indices(indices, WIDTH, HEIGHT, palette)


## `LoadCableTradeBorderTilemap`: the mobile screen laid down whole and the two
## cable strips written over its first and last two rows. Gold and Silver have
## no tilemap at all, so `PlaceTradeScreenTextbox`'s two boxes are the screen.
func _draw_trade_background(indices: PackedByteArray) -> void:
	if _screen.is_empty():
		_box(indices, Rect2i(0, 0, 18, 6))
		_box(indices, Rect2i(0, 8, 18, 6))
		return
	for cell: int in _screen.size():
		_blit(indices, int(_screen[cell]), Vector2i(cell % COLUMNS, cell / COLUMNS))
	_blit_strip(indices, _cable_top, 0)
	_blit_strip(indices, _cable_bottom, ROWS - 2)


func _blit_strip(indices: PackedByteArray, strip: PackedByteArray, top: int) -> void:
	for cell: int in strip.size():
		_blit(indices, int(strip[cell]), Vector2i(cell % COLUMNS, top + cell / COLUMNS))


func _draw_party(
	indices: PackedByteArray, side: Dictionary, name_at: Vector2i, list_at: Vector2i
) -> void:
	var name: String = String(side.get("name", ""))
	_text(indices, name, name_at)
	## `ld a, $14 / ld [bc], a` puts a tile of the border block at the cell the
	## name ended on. Only Crystal's block is at `vTiles2` tile zero, so on Gold
	## and Silver that cell is left as the screen found it.
	if not _screen.is_empty():
		_blit(indices, NAME_END_TILE, name_at + Vector2i(name.length(), 0))
	var species: Array = side.get("species", [])
	for row: int in species.size():
		_text(indices, String(species[row]), list_at + Vector2i(0, row))


## `.UpdateCursor`, which marks the row at the cursor column and again
## `MON_NAME_LENGTH` columns along.
func _draw_cursor(indices: PackedByteArray, state: Dictionary) -> void:
	var list: int = int(state.get("list", 0))
	var index: int = int(state.get("index", 0))
	var side: Dictionary = state.get("partner", {}) if list == 1 \
		else state.get("player", {})
	if index < 0 or index >= (side.get("species", []) as Array).size():
		return
	var row: int = (PARTNER_LIST_AT.y if list == 1 else PLAYER_LIST_AT.y) + index
	_blit(indices, CURSOR_TILE, Vector2i(CURSOR_COLUMN, row))
	_blit(indices, CURSOR_TILE, Vector2i(CURSOR_COLUMN + MON_NAME_LENGTH, row))


## `_LinkTextbox`, whose [param box] is the interior the source passes in `b`
## and `c`: the border is drawn one cell outside it on every side.
func _box(indices: PackedByteArray, box: Rect2i) -> void:
	var left: int = box.position.x
	var top: int = box.position.y
	var right: int = left + box.size.x + 1
	var bottom: int = top + box.size.y + 1
	_blit(indices, _box_tiles[0], Vector2i(left, top))
	_blit(indices, _box_tiles[2], Vector2i(right, top))
	_blit(indices, _box_tiles[5], Vector2i(left, bottom))
	_blit(indices, _box_tiles[7], Vector2i(right, bottom))
	for column: int in range(left + 1, right):
		_blit(indices, _box_tiles[1], Vector2i(column, top))
		_blit(indices, _box_tiles[6], Vector2i(column, bottom))
	for row: int in range(top + 1, bottom):
		_blit(indices, _box_tiles[3], Vector2i(left, row))
		_blit(indices, _box_tiles[4], Vector2i(right, row))
		## `ld a, ' ' / call .PlaceRow` clears the interior, so a box opened over
		## the border's own art hides it rather than letting it show through.
		for column: int in range(left + 1, right):
			_clear(indices, Vector2i(column, row))


func _text(indices: PackedByteArray, text: String, at: Vector2i) -> void:
	var line: int = 0
	for row: String in text.split("\n"):
		font.draw_text(row, indices, WIDTH, at.x * TILE, (at.y + line) * TILE)
		line += 1


func _clear(indices: PackedByteArray, at: Vector2i) -> void:
	for row: int in TILE:
		var start: int = (at.y * TILE + row) * WIDTH + at.x * TILE
		for column: int in TILE:
			indices[start + column] = 0


## A cell of the border block by its tile number, which is what the tilemaps and
## `_LinkTextbox` both name. A code at or above the font's own first code is a
## glyph instead, the way [Gen2DiplomaPage] splits them.
func _blit(into: PackedByteArray, code: int, at: Vector2i) -> void:
	if code >= RomLayout.FONT_FIRST_CODE:
		font.draw_code(code, into, WIDTH, at.x * TILE, at.y * TILE)
		return
	if code >= _tile_count:
		return
	Gen2Font.blit_slot(
		_tiles, _tile_count * TILE, code, into, WIDTH, at.x * TILE, at.y * TILE
	)
