class_name Gen2MartPage
extends RefCounted

## `BuyMenu`'s screen (`engine/items/mart.asm`): `BlankScreen`, the money box in
## the corner, `MenuHeader_Buy`'s scrolling list of names and BCD prices, and the
## speech box `UpdateItemDescription` writes into. [Gen2WorldMartHost] owns the
## list and the transaction; this is the picture. Three things a redraw has to
## keep: `ScrollingMenu` draws no frame, so the names sit on the blank screen; the
## fourth row's price lands on row 11, because `.PrintBCDPrices` prints one row
## below a name already on the last row the height allows; and the down arrow is
## drawn whenever the list has arrows while the up one waits for a scroll.

const TILE: int = Gen2Font.TILE

## `MoneyTopRightMenuHeader`: `menu_coords 11, 0, SCREEN_WIDTH - 1, 2`, with
## `PlaceMoneyTextbox` printing `SCREEN_WIDTH + 1` past the border coordinate.
const MONEY_AT: Vector2i = Vector2i(11, 0)
const MONEY_SIZE: Vector2i = Vector2i(9, 3)
const MONEY_TEXT_AT: Vector2i = Vector2i(12, 1)

## `constants/script_constants.asm`'s COIN count, printed by `PrintNum` as two
## bytes in four digits with `PlaceString`'s own leading blanks in front of it.
const COIN_DIGITS: int = 4

## The other two boxes of `engine/menus/menu_2.asm`, which the overworld's
## `special DisplayCoinCaseBalance` and `special DisplayMoneyAndCoinBalance`
## write over the map. `Textbox`, not `MenuBox`: the coin box places "COIN" at
## `hlcoord 12, 0`, which is its own top border row.
const COIN_CASE_AT: Vector2i = Vector2i(11, 0)
const COIN_CASE_SIZE: Vector2i = Vector2i(9, 3)
const COIN_CASE_LABEL_AT: Vector2i = Vector2i(12, 0)
const COIN_CASE_COUNT_AT: Vector2i = Vector2i(13, 1)
const BALANCES_AT: Vector2i = Vector2i(5, 0)
const BALANCES_SIZE: Vector2i = Vector2i(15, 5)
const BALANCES_MONEY_LABEL_AT: Vector2i = Vector2i(6, 1)
const BALANCES_MONEY_AT: Vector2i = Vector2i(12, 1)
const BALANCES_COIN_LABEL_AT: Vector2i = Vector2i(6, 3)
const BALANCES_COIN_AT: Vector2i = Vector2i(15, 3)

## `Mom_ContinueMenuSetup`'s own box and the three rows it prints in.
## `hlcoord 13, 6` plus `wMomBankDigitCursorPosition` is the digit the cursor
## blanks, which is the amount's first digit column.
const BANK_AT: Vector2i = Vector2i(0, 0)
const BANK_SIZE: Vector2i = Vector2i(20, 8)
const BANK_LABEL_COLUMN: int = 1
const BANK_VALUE_COLUMN: int = 12
const BANK_DIGIT_COLUMN: int = 13
const BANK_DIGITS: int = 6
const BANK_ROWS: Array[int] = [2, 4, 6]

## `MenuHeader_Buy`: `menu_coords 1, 3, SCREEN_WIDTH - 1, TEXTBOX_Y - 1`, four
## rows of eight columns. `ScrollingMenu_InitFlags` puts the cursor on the left
## border coordinate itself and steps `$20`, which is two rows.
const LIST_AT: Vector2i = Vector2i(1, 3)
const LIST_RIGHT: int = 19
const LIST_BOTTOM: int = 11
const LIST_HEIGHT: int = 4
const NAME_AT: Vector2i = Vector2i(2, 4)
const ROW_STEP: int = 2
## `ScrollingMenu_CallFunctions1and2` steps `wMenuData_ScrollingMenuWidth` from
## the name before it calls function 2.
const PRICE_COLUMN: int = NAME_AT.x + 8
## The cells a shelf row's name is drawn in, up to the column the arrows stand
## in. Every cartridge item name fits; a shelf line a mod registers is any
## length, so it is bounded and a long one ends in an ellipsis rather than being
## drawn over the border.
const NAME_CELLS: int = LIST_RIGHT - NAME_AT.x

## `UpdateItemDescription`: `hlcoord 0, 12` with `lb bc, 4, SCREEN_WIDTH - 2`,
## so a six-row frame across the screen, and the description at `decoord 1, 14`.
const TEXTBOX_AT: Vector2i = Vector2i(0, 12)
const TEXTBOX_SIZE: Vector2i = Vector2i(20, 6)
const TEXT_AT: Vector2i = Vector2i(1, 14)
const TEXT_SPACING: int = 2

## `BuyItem_MenuHeader`: `menu_coords 7, 15, SCREEN_WIDTH - 1, SCREEN_HEIGHT - 1`.
## `BuySellToss_UpdateQuantityDisplay` prints `×` and two digits one row in, and
## `BuySell_DisplaySubtotal` the running total one cell past them.
const QUANTITY_AT: Vector2i = Vector2i(7, 15)
const QUANTITY_SIZE: Vector2i = Vector2i(13, 3)
const QUANTITY_TEXT_AT: Vector2i = Vector2i(8, 16)
const QUANTITY_DIGITS: int = 2
const SUBTOTAL_AT: Vector2i = Vector2i(12, 16)

## `ScrollingMenu_UpdateDisplay.CancelString`, the row a list of any length ends
## with.
const CANCEL: String = "CANCEL"

## `Place2DMenuCursor`'s "▶" and the two arrows `SCROLLINGMENU_DISPLAY_ARROWS`
## draws. The up arrow is the one code no font strip carries.
const CURSOR_CODE: int = 0xED
const DOWN_ARROW_CODE: int = 0xEE

## `PRINTNUM_MONEY` with six digits: the `¥` is printed in front of the first
## significant digit rather than at the field's left edge, so the whole thing is
## seven cells right aligned, which is `PrintBCDNumber`'s shape too.
const MONEY_CELLS: int = 7

## Generation 1's shop stands over the map and frames its list. `MONEY_BOX_TEMPLATE`
## is (11,0) to (19,2) with "MONEY" on its own top border row, and `LIST_MENU_BOX`
## (4,2) to (19,12) (`data/text_boxes.asm`).
const GEN1_MONEY_LABEL: String = "MONEY"
const GEN1_MONEY_LABEL_AT: Vector2i = Vector2i(13, 0)
const GEN1_LIST_AT: Vector2i = Vector2i(4, 2)
const GEN1_LIST_SIZE: Vector2i = Vector2i(16, 11)
## `PrintListMenuEntries`: `hlcoord 6, 4`, four names two rows apart, each price
## one row down and five columns right of its name, and the cursor on column 5.
const GEN1_NAME_AT: Vector2i = Vector2i(6, 4)
const GEN1_CURSOR_COLUMN: int = 5
const GEN1_PRICE_COLUMN: int = 11
## `ld b, 4` names drawn against `wMaxMenuItem` 2, so the fourth row is a look
## ahead the cursor never reaches.
const GEN1_LIST_HEIGHT: int = 4
const GEN1_CURSOR_ROWS: int = 3
## A name runs to the box's own border: the price sits a row below it.
const GEN1_NAME_CELLS: int = GEN1_LIST_AT.x + GEN1_LIST_SIZE.x - 1 - GEN1_NAME_AT.x
## `PrintListMenuEntries`' other two writes: a count one row below its own name
## and eight columns right, and the `▼` in the box's bottom-right corner.
const GEN1_COUNT_COLUMN: int = GEN1_NAME_AT.x + 8
const GEN1_COUNT_DIGITS: int = 2
const GEN1_DOWN_ARROW_AT: Vector2i = Vector2i(18, 11)
## `HandleItemListSwapping`'s own marker, written over the cursor column of the
## row SELECT is holding.
const GEN1_HELD_CODE: int = 0xEC
## `DisplayChooseQuantityMenu`'s priced branch: `hlcoord 7, 9` with `lb b, 1,
## c, 11`, the same box Generation 2 draws six rows lower. Its unpriced branch is
## the same row at `hlcoord 15, 9` with `c, 3`, which is what a TOSS asks in.
const GEN1_QUANTITY_AT: Vector2i = Vector2i(7, 9)
const GEN1_COUNT_ONLY_AT: Vector2i = Vector2i(15, 9)
const GEN1_COUNT_ONLY_SIZE: Vector2i = Vector2i(5, 3)
const GEN1_COUNT_ONLY_TEXT_AT: Vector2i = Vector2i(16, 10)

var font: Gen2Font = null
## Which text-box border the player chose, for the three boxes this draws.
var frame_style: int = 0
## `FontsExtra2_UpArrowGFX`, the single tile `'▲'` is drawn from.
var _up_arrow: PackedByteArray = PackedByteArray()


static func from_data(data: GameData) -> Gen2MartPage:
	var glyphs: Gen2Font = Gen2Font.from_data(data)
	if glyphs == null:
		return null
	var out := Gen2MartPage.new()
	out.font = glyphs
	out.frame_style = Gen2OptionsStore.current().textbox_frame
	out._up_arrow = data.tile_indices("up_arrow")
	return out


## The whole screen. [param state] is what the host holds: `money`, `rows` of
## `{name, price}` or `{cancel}`, `cursor` for the visible row the arrow stands
## on, `scrolled` for `wMenuScrollPosition` past zero, `text` for the speech box's
## lines, `quantity` at -1 while no quantity box is up, and `subtotal`.
func render(state: Dictionary) -> Image:
	if font == null:
		return null
	var width: int = Gen2Screen.WIDTH
	var indices := PackedByteArray()
	indices.resize(width * Gen2Screen.HEIGHT)
	_draw_money(indices, width, int(state.get("money", 0)))
	_draw_list(indices, width, state)
	_draw_textbox(indices, width, String(state.get("text", "")))
	if int(state.get("quantity", -1)) >= 0:
		_draw_quantity(
			indices, width, int(state["quantity"]), int(state.get("subtotal", 0))
		)
	return Gen2PicImage.from_indices(
		indices, width, Gen2Screen.HEIGHT,
		PokePalette.pic_palette(PackedColorArray([Color.WHITE, Color.BLACK]))
	)


## `PRINTNUM_MONEY`'s own shape: `¥` against the number, the pair right aligned
## in seven cells. `PrintBCDNumber` lays the prices down the same way.
static func money_string(amount: int) -> String:
	return ("¥%d" % maxi(amount, 0)).lpad(MONEY_CELLS)


## One of the three balance windows as an image and the tile it stands at:
## `{"image": Image, "at": Vector2i}`, empty when the font is missing. The three
## are one routine's neighbours, which is why they are drawn here rather than
## beside the overworld: `PlaceMoneyTopRight` is the box this screen already
## draws and the other two are the same file's.
static func balance_window(
	data: GameData, kind: StringName, money: int, coins: int
) -> Dictionary:
	var page: Gen2MartPage = Gen2MartPage.from_data(data)
	if page == null:
		return {}
	var at: Vector2i = MONEY_AT
	var box: Vector2i = MONEY_SIZE
	match kind:
		&"coin_case":
			at = COIN_CASE_AT
			box = COIN_CASE_SIZE
		&"money_and_coins":
			at = BALANCES_AT
			box = BALANCES_SIZE
	var width: int = Gen2Screen.WIDTH
	var indices := PackedByteArray()
	indices.resize(width * Gen2Screen.HEIGHT)
	page.font.draw_box(
		page.frame_style, indices, width, at.x * TILE, at.y * TILE, box.x, box.y
	)
	match kind:
		&"coin_case":
			page._text(indices, width, "COIN", COIN_CASE_LABEL_AT)
			page._text(indices, width, coin_string(coins), COIN_CASE_COUNT_AT)
		&"money_and_coins":
			page._text(indices, width, "MONEY", BALANCES_MONEY_LABEL_AT)
			page._text(indices, width, money_string(money), BALANCES_MONEY_AT)
			page._text(indices, width, "COIN", BALANCES_COIN_LABEL_AT)
			page._text(indices, width, coin_string(coins), BALANCES_COIN_AT)
		_:
			page._text(indices, width, money_string(money), MONEY_TEXT_AT)
	var image: Image = Gen2PicImage.from_indices(
		indices, width, Gen2Screen.HEIGHT,
		PokePalette.pic_palette(PackedColorArray([Color.WHITE, Color.BLACK]))
	)
	return {
		"image": image.get_region(Rect2i(at * TILE, box * TILE)),
		"at": at,
	}


## `Mom_ContinueMenuSetup`'s box, drawn here for the reason the three balance
## windows are: it is a money box, and `PrintNum` with PRINTNUM_MONEY fills all
## four. `Textbox` at `hlcoord 0, 0` with `lb bc, 6, 18`, so eight rows and the
## whole screen's width, SAVED against her balance and HELD against the player's.
## `Mom_WithdrawDepositMenuJoypad` blanks the digit the cursor stands on for
## sixteen frames in every thirty-two, `hVBlankCounter`'s bit 4, so an off half of
## the blink is a missing digit rather than a mark beside one.
static func bank_window(
	data: GameData, word: String, saved: int, held: int, amount: String,
	cursor: int, cursor_up: bool
) -> Dictionary:
	var page: Gen2MartPage = Gen2MartPage.from_data(data)
	if page == null:
		return {}
	var width: int = Gen2Screen.WIDTH
	var indices := PackedByteArray()
	indices.resize(width * Gen2Screen.HEIGHT)
	page.font.draw_box(
		page.frame_style, indices, width,
		BANK_AT.x * TILE, BANK_AT.y * TILE, BANK_SIZE.x, BANK_SIZE.y
	)
	var rows: Array = [
		["SAVED", money_string(saved)], ["HELD", money_string(held)], [word, amount],
	]
	for index: int in rows.size():
		var row: Array = rows[index]
		var line: int = BANK_ROWS[index]
		page._text(indices, width, String(row[0]), Vector2i(BANK_LABEL_COLUMN, line))
		page._text(indices, width, String(row[1]), Vector2i(BANK_VALUE_COLUMN, line))
	if not cursor_up:
		page._text(
			indices, width, " ",
			Vector2i(BANK_DIGIT_COLUMN + clampi(cursor, 0, BANK_DIGITS - 1), BANK_ROWS[2])
		)
	var image: Image = Gen2PicImage.from_indices(
		indices, width, Gen2Screen.HEIGHT,
		PokePalette.pic_palette(PackedColorArray([Color.WHITE, Color.BLACK]))
	)
	return {
		"image": image.get_region(Rect2i(BANK_AT * TILE, BANK_SIZE * TILE)),
		"at": BANK_AT,
	}


## `PrintNum` with `lb bc, 2, 4`: four digits, right aligned, no `¥`.
static func coin_string(coins: int) -> String:
	return ("%d" % maxi(coins, 0)).lpad(COIN_DIGITS)


## `DisplayPokemartDialogue_` draws the money box and `DisplayListMenuID` the
## list. Transparent everywhere else, so the map and the message box show.
func render_gen1(state: Dictionary) -> Image:
	if font == null:
		return null
	var image := Image.create_empty(
		Gen2Screen.WIDTH, Gen2Screen.HEIGHT, false, Image.FORMAT_RGBA8
	)
	_blit_gen1_money(image, int(state.get("money", 0)))
	if bool(state.get("listing", false)):
		_blit_gen1_list(image, state)
	if int(state.get("quantity", -1)) >= 0:
		_blit_gen1_quantity(
			image, int(state["quantity"]), int(state.get("subtotal", 0))
		)
	return image


func _blit_gen1_quantity(image: Image, quantity: int, subtotal: int) -> void:
	var indices: PackedByteArray = _panel(QUANTITY_SIZE)
	var width: int = QUANTITY_SIZE.x * TILE
	font.draw_box(frame_style, indices, width, 0, 0, QUANTITY_SIZE.x, QUANTITY_SIZE.y)
	var inset: Vector2i = QUANTITY_TEXT_AT - QUANTITY_AT
	_text(
		indices, width,
		"×%s" % String.num_int64(maxi(quantity, 0)).lpad(QUANTITY_DIGITS, "0"), inset
	)
	_text(
		indices, width, money_string(subtotal),
		Vector2i(SUBTOTAL_AT.x - QUANTITY_AT.x, inset.y)
	)
	_blit_panel(image, indices, QUANTITY_SIZE, GEN1_QUANTITY_AT)


func _blit_gen1_money(image: Image, money: int) -> void:
	var indices: PackedByteArray = _panel(MONEY_SIZE)
	var width: int = MONEY_SIZE.x * TILE
	font.draw_box(frame_style, indices, width, 0, 0, MONEY_SIZE.x, MONEY_SIZE.y)
	_text(indices, width, GEN1_MONEY_LABEL, GEN1_MONEY_LABEL_AT - MONEY_AT)
	_text(indices, width, money_string(money), MONEY_TEXT_AT - MONEY_AT)
	_blit_panel(image, indices, MONEY_SIZE, MONEY_AT)


## `wPrintItemPrices` is the one place the two callers of
## `PrintListMenuEntries` differ, so a row carries a `price` or a `quantity`.
func _blit_gen1_list(image: Image, state: Dictionary) -> void:
	var indices: PackedByteArray = _panel(GEN1_LIST_SIZE)
	var width: int = GEN1_LIST_SIZE.x * TILE
	font.draw_box(frame_style, indices, width, 0, 0, GEN1_LIST_SIZE.x, GEN1_LIST_SIZE.y)
	var rows: Array = state.get("rows", [])
	for index: int in mini(rows.size(), GEN1_LIST_HEIGHT):
		var row: Dictionary = rows[index]
		var at: Vector2i = GEN1_NAME_AT - GEN1_LIST_AT + Vector2i(0, index * ROW_STEP)
		if bool(row.get("cancel", false)):
			_text(indices, width, CANCEL, at)
			continue
		_text(indices, width, String(row.get("name", "")), at, GEN1_NAME_CELLS)
		if row.has("price"):
			_text(
				indices, width, money_string(int(row["price"])),
				Vector2i(GEN1_PRICE_COLUMN - GEN1_LIST_AT.x, at.y + 1)
			)
		elif row.has("quantity") and bool(row.get("show_quantity", true)):
			_text(
				indices, width, "×%s" % String.num_int64(
					maxi(int(row["quantity"]), 0)
				).lpad(GEN1_COUNT_DIGITS),
				Vector2i(GEN1_COUNT_COLUMN - GEN1_LIST_AT.x, at.y + 1)
			)
	var cursor_column: int = GEN1_CURSOR_COLUMN - GEN1_LIST_AT.x
	var first_row: int = GEN1_NAME_AT.y - GEN1_LIST_AT.y
	var held: int = int(state.get("held", -1))
	if held >= 0 and held < mini(rows.size(), GEN1_LIST_HEIGHT):
		_code(indices, width, GEN1_HELD_CODE, Vector2i(
			cursor_column, first_row + held * ROW_STEP
		))
	var cursor: int = int(state.get("cursor", -1))
	if cursor >= 0 and cursor < mini(rows.size(), GEN1_CURSOR_ROWS):
		_code(indices, width, CURSOR_CODE, Vector2i(
			cursor_column, first_row + cursor * ROW_STEP
		))
	## `.printCancelMenuItem` is a `jp PlaceString`: a pass that reached the
	## terminator returns without writing the arrow.
	if rows.size() >= GEN1_LIST_HEIGHT \
		and not bool((rows[GEN1_LIST_HEIGHT - 1] as Dictionary).get("cancel", false)):
		_code(indices, width, DOWN_ARROW_CODE, GEN1_DOWN_ARROW_AT - GEN1_LIST_AT)
	_blit_panel(image, indices, GEN1_LIST_SIZE, GEN1_LIST_AT)


## `StartMenu_Item`'s screen: the same `DisplayListMenuID` box the shop opens,
## with counts where the shop prints prices and no money box over it.
func render_gen1_pack(state: Dictionary) -> Image:
	if font == null:
		return null
	var image := Image.create_empty(
		Gen2Screen.WIDTH, Gen2Screen.HEIGHT, false, Image.FORMAT_RGBA8
	)
	if bool(state.get("listing", true)):
		_blit_gen1_list(image, state)
	if int(state.get("quantity", -1)) >= 0:
		_blit_gen1_count(image, int(state["quantity"]))
	return image


## `DisplayChooseQuantityMenu`'s unpriced branch, `InitialQuantityText`'s own
## `×01` in a box five cells wide.
func _blit_gen1_count(image: Image, quantity: int) -> void:
	var indices: PackedByteArray = _panel(GEN1_COUNT_ONLY_SIZE)
	var width: int = GEN1_COUNT_ONLY_SIZE.x * TILE
	font.draw_box(
		frame_style, indices, width, 0, 0,
		GEN1_COUNT_ONLY_SIZE.x, GEN1_COUNT_ONLY_SIZE.y
	)
	_text(
		indices, width,
		"×%s" % String.num_int64(maxi(quantity, 0)).lpad(GEN1_COUNT_DIGITS, "0"),
		GEN1_COUNT_ONLY_TEXT_AT - GEN1_COUNT_ONLY_AT
	)
	_blit_panel(image, indices, GEN1_COUNT_ONLY_SIZE, GEN1_COUNT_ONLY_AT)


## `VendingMachineMenu`'s box: `TextBoxBorder hlcoord 0, 3` at eight by twelve,
## `DrinkText` on the menu's rows and `DrinkPriceText` on the rows between them,
## placed rather than right aligned, which is what fits a price in a box six
## columns narrower than the shop's. Beside it is `BuyMenu`'s own `MONEY_BOX`.
const GEN1_VENDING_AT: Vector2i = Vector2i(0, 3)
const GEN1_VENDING_SIZE: Vector2i = Vector2i(14, 10)
const GEN1_VENDING_NAME_AT: Vector2i = Vector2i(2, 5)
const GEN1_VENDING_PRICE_AT: Vector2i = Vector2i(9, 6)
const GEN1_VENDING_CURSOR_COLUMN: int = 1


func render_gen1_vending(state: Dictionary) -> Image:
	if font == null:
		return null
	var image := Image.create_empty(
		Gen2Screen.WIDTH, Gen2Screen.HEIGHT, false, Image.FORMAT_RGBA8
	)
	_blit_gen1_money(image, int(state.get("money", 0)))
	var indices: PackedByteArray = _panel(GEN1_VENDING_SIZE)
	var width: int = GEN1_VENDING_SIZE.x * TILE
	font.draw_box(
		frame_style, indices, width, 0, 0, GEN1_VENDING_SIZE.x, GEN1_VENDING_SIZE.y
	)
	var rows: Array = state.get("rows", [])
	var name_at: Vector2i = GEN1_VENDING_NAME_AT - GEN1_VENDING_AT
	var price_at: Vector2i = GEN1_VENDING_PRICE_AT - GEN1_VENDING_AT
	for index: int in rows.size():
		var row: Dictionary = rows[index]
		var step := Vector2i(0, index * ROW_STEP)
		_text(indices, width, String(row.get("name", "")), name_at + step)
		_text(indices, width, "¥%d" % int(row.get("price", 0)), price_at + step)
	_text(indices, width, CANCEL, name_at + Vector2i(0, rows.size() * ROW_STEP))
	var cursor: int = int(state.get("cursor", -1))
	if cursor >= 0 and cursor <= rows.size():
		_code(indices, width, CURSOR_CODE, Vector2i(
			GEN1_VENDING_CURSOR_COLUMN - GEN1_VENDING_AT.x,
			name_at.y + cursor * ROW_STEP
		))
	_blit_panel(image, indices, GEN1_VENDING_SIZE, GEN1_VENDING_AT)
	return image


## `CeladonPrizeMenu`'s box: `TextBoxBorder hlcoord 0, 2` at eight by sixteen,
## with `PrintPrizePrice`'s COIN panel where the shop puts its money. A cost is
## `PrintBCDNumber`'s two bytes with leading zeroes, so always four digits.
const GEN1_PRIZE_AT: Vector2i = Vector2i(0, 2)
const GEN1_PRIZE_SIZE: Vector2i = Vector2i(18, 10)
const GEN1_PRIZE_NAME_AT: Vector2i = Vector2i(2, 4)
const GEN1_PRIZE_COST_AT: Vector2i = Vector2i(13, 5)
const GEN1_PRIZE_CURSOR_COLUMN: int = 1
const GEN1_PRIZE_DIGITS: int = 4
const GEN1_COIN_LABEL: String = "COIN"
const GEN1_COIN_LABEL_AT: Vector2i = Vector2i(12, 0)
const GEN1_COIN_AT: Vector2i = Vector2i(13, 1)
const GEN1_NO_THANKS: String = "NO THANKS"


func render_gen1_prizes(state: Dictionary) -> Image:
	if font == null:
		return null
	var image := Image.create_empty(
		Gen2Screen.WIDTH, Gen2Screen.HEIGHT, false, Image.FORMAT_RGBA8
	)
	_blit_gen1_coins(image, int(state.get("coins", 0)))
	var indices: PackedByteArray = _panel(GEN1_PRIZE_SIZE)
	var width: int = GEN1_PRIZE_SIZE.x * TILE
	font.draw_box(frame_style, indices, width, 0, 0, GEN1_PRIZE_SIZE.x, GEN1_PRIZE_SIZE.y)
	var rows: Array = state.get("rows", [])
	var name_at: Vector2i = GEN1_PRIZE_NAME_AT - GEN1_PRIZE_AT
	var cost_at: Vector2i = GEN1_PRIZE_COST_AT - GEN1_PRIZE_AT
	for index: int in rows.size():
		var row: Dictionary = rows[index]
		var step := Vector2i(0, index * ROW_STEP)
		_text(indices, width, String(row.get("name", "")), name_at + step)
		_text(indices, width, String.num_int64(
			maxi(int(row.get("cost", 0)), 0)
		).lpad(GEN1_PRIZE_DIGITS, "0"), cost_at + step)
	_text(indices, width, GEN1_NO_THANKS, name_at + Vector2i(0, rows.size() * ROW_STEP))
	var cursor: int = int(state.get("cursor", -1))
	if cursor >= 0 and cursor <= rows.size():
		_code(indices, width, CURSOR_CODE, Vector2i(
			GEN1_PRIZE_CURSOR_COLUMN - GEN1_PRIZE_AT.x, name_at.y + cursor * ROW_STEP
		))
	_blit_panel(image, indices, GEN1_PRIZE_SIZE, GEN1_PRIZE_AT)
	return image


## `PrintPrizePrice`: the money box's corners with COIN on the border row.
func _blit_gen1_coins(image: Image, coins: int) -> void:
	var indices: PackedByteArray = _panel(MONEY_SIZE)
	var width: int = MONEY_SIZE.x * TILE
	font.draw_box(frame_style, indices, width, 0, 0, MONEY_SIZE.x, MONEY_SIZE.y)
	_text(indices, width, GEN1_COIN_LABEL, GEN1_COIN_LABEL_AT - MONEY_AT)
	_text(
		indices, width,
		String.num_int64(maxi(coins, 0)).lpad(GEN1_PRIZE_DIGITS, "0"),
		GEN1_COIN_AT - MONEY_AT
	)
	_blit_panel(image, indices, MONEY_SIZE, MONEY_AT)


static func _panel(size: Vector2i) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(size.x * TILE * size.y * TILE)
	return out


func _blit_panel(
	image: Image, indices: PackedByteArray, size: Vector2i, at: Vector2i
) -> void:
	var part: Image = Gen2PicImage.from_indices(
		indices, size.x * TILE, size.y * TILE,
		PokePalette.pic_palette(PackedColorArray([Color.WHITE, Color.BLACK]))
	)
	if part != null:
		image.blit_rect(part, Rect2i(Vector2i.ZERO, part.get_size()), at * TILE)


func _draw_money(indices: PackedByteArray, width: int, money: int) -> void:
	font.draw_box(
		frame_style, indices, width, MONEY_AT.x * TILE, MONEY_AT.y * TILE,
		MONEY_SIZE.x, MONEY_SIZE.y
	)
	_text(indices, width, money_string(money), MONEY_TEXT_AT)


func _draw_list(indices: PackedByteArray, width: int, state: Dictionary) -> void:
	var rows: Array = state.get("rows", [])
	var cursor: int = int(state.get("cursor", 0))
	for index: int in mini(rows.size(), LIST_HEIGHT + 1):
		var row: Dictionary = rows[index]
		var at: Vector2i = NAME_AT + Vector2i(0, index * ROW_STEP)
		if bool(row.get("cancel", false)):
			_text(indices, width, CANCEL, at)
			continue
		_text(indices, width, String(row.get("name", "")), at, NAME_CELLS)
		_text(
			indices, width, money_string(int(row.get("price", 0))),
			Vector2i(PRICE_COLUMN, at.y + 1)
		)
	if cursor >= 0 and cursor < mini(rows.size(), LIST_HEIGHT + 1):
		_code(
			indices, width, CURSOR_CODE,
			Vector2i(LIST_AT.x, NAME_AT.y + cursor * ROW_STEP)
		)
	if bool(state.get("scrolled", false)):
		_up(indices, width, Vector2i(LIST_RIGHT, LIST_AT.y))
	_code(indices, width, DOWN_ARROW_CODE, Vector2i(LIST_RIGHT, LIST_BOTTOM))


func _draw_textbox(indices: PackedByteArray, width: int, text: String) -> void:
	font.draw_box(
		frame_style, indices, width, TEXTBOX_AT.x * TILE, TEXTBOX_AT.y * TILE,
		TEXTBOX_SIZE.x, TEXTBOX_SIZE.y
	)
	var line: int = 0
	for row: String in text.split("\n", false):
		_text(indices, width, row, TEXT_AT + Vector2i(0, line * TEXT_SPACING))
		line += 1


func _draw_quantity(
	indices: PackedByteArray, width: int, quantity: int, subtotal: int
) -> void:
	font.draw_box(
		frame_style, indices, width, QUANTITY_AT.x * TILE, QUANTITY_AT.y * TILE,
		QUANTITY_SIZE.x, QUANTITY_SIZE.y
	)
	## `PRINTNUM_LEADINGZEROS | 1` over two digits, which is what makes a single
	## item read `×01`.
	_text(
		indices, width,
		"×%s" % String.num_int64(maxi(quantity, 0)).lpad(QUANTITY_DIGITS, "0"),
		QUANTITY_TEXT_AT
	)
	_text(indices, width, money_string(subtotal), SUBTOTAL_AT)


func _text(
	indices: PackedByteArray, width: int, text: String, at: Vector2i, cells: int = -1
) -> void:
	font.draw_text(
		text, indices, width, at.x * TILE, at.y * TILE, Gen2Text.FONT_MAIN, cells
	)


func _code(indices: PackedByteArray, width: int, code: int, at: Vector2i) -> void:
	font.draw_code(code, indices, width, at.x * TILE, at.y * TILE)


## `'▲'` comes off its own imported tile: it sits inside the run the battle font
## owns, so neither strip [Gen2Font] draws from can answer for it. A cache
## imported without it leaves the corner empty rather than drawing a wrong tile.
func _up(indices: PackedByteArray, width: int, at: Vector2i) -> void:
	if _up_arrow.size() < TILE * TILE:
		return
	Gen2Font.blit_slot(_up_arrow, TILE, 0, indices, width, at.x * TILE, at.y * TILE)
