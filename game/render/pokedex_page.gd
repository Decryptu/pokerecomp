class_name Gen2PokedexPage
extends RefCounted

## The Pokedex's own tile screens (engine/pokedex/pokedex.asm). [Gen2Pokedex] owns
## the listing, the cursor and the mode; this is the picture. Every layout is one
## of the source's `Pokedex_Draw*BG` routines read as tile writes. Three sheets
## share the dex's VRAM numbering: `$00` to `$30` is the font **inverted**, since
## `Pokedex_LoadInvertedFont` XORs every byte and the whole screen is light on
## dark; `$31` to `$6a` is `PokedexLZ`; `$6b` up is `LoadFontsExtra`, inverted by
## the same pass. The main screen is not a plain grid: its listing is in the
## window layer at `hWX`, so it is composed in pixels by [method image_main].

const COLUMNS: int = 20
const ROWS: int = 18
const TILE: int = 8
const WIDTH: int = COLUMNS * TILE
const HEIGHT: int = ROWS * TILE

## Where `PokedexLZ` lands, which is what a sheet tile number is offset by.
const SHEET_FIRST_TILE: int = 0x31

## `Pokedex_PlaceFrontpicAtHL`'s own box, which is also `PadFrontpic`'s.
const PIC_COLUMNS: int = 7

## `Pokedex_FillBackgroundColor2`'s fill, and the tile every cleared cell is.
const BACKGROUND_TILE: int = 0x32

## `Pokedex_PlaceBorder`'s nine tiles, in the order it writes them: the top row,
## then each middle row, then the bottom.
const BORDER_TOP_LEFT: int = 0x33
const BORDER_TOP: int = 0x34
const BORDER_TOP_RIGHT: int = 0x35
const BORDER_LEFT: int = 0x36
const BORDER_RIGHT: int = 0x37
const BORDER_BOTTOM_LEFT: int = 0x38
const BORDER_BOTTOM: int = 0x39
const BORDER_BOTTOM_RIGHT: int = 0x3A
## The border's inside, which is a space rather than one of its own tiles.
const BORDER_FILL: int = 0x7F

## The sidebar's own column and its three joints (`Pokedex_DrawMainScreenBG`).
const SIDEBAR_TOP: int = 0x59
const SIDEBAR: int = 0x5A
const SIDEBAR_BOTTOM: int = 0x5B
const SIDEBAR_SPLIT_TOP: int = 0x53
const SIDEBAR_SPLIT_BOTTOM: int = 0x54
## The search results screen's own pair below the split, where the main screen
## has the second box's top.
const RESULTS_SPLIT_TOP: int = 0x69
const RESULTS_SPLIT_BOTTOM: int = 0x6A

## `DrawPokedexListWindow`: the listing's frame, its scroll bar and the two
## tiles that replace the bar in DEXMODE_OLD.
const WINDOW_LEFT_JOINT: int = 0x3F
const WINDOW_LEFT_JOINT_BOTTOM: int = 0x40
const SCROLL_TOP: int = 0x50
const SCROLL: int = 0x51
const SCROLL_BOTTOM: int = 0x52
const NO_SCROLL_TOP: int = 0x66
const NO_SCROLL: int = 0x67
const NO_SCROLL_BOTTOM: int = 0x68

## The entry screen's divider under the picture, and the page marker beside it.
const ENTRY_DIVIDER: int = 0x61
const PAGE_MARKER_TOP: int = 0x55
const PAGE_MARKER: int = 0x56
const PAGE_ONE: int = 0x57
const PAGE_TWO: int = 0x58

## `Pokedex_DrawFootprint`'s four cells, and where they go.
const FOOTPRINT_TOP: int = 0x62
const FOOTPRINT_BOTTOM: int = 0x64
const FOOTPRINT_AT := Vector2i(18, 1)

## `.Number`'s two tiles, and the two the height line's feet and inches use.
const NUMBER_NO: int = 0x5C
const NUMBER_DOT: int = 0x5D
const HEIGHT_FEET: int = 0x5E
const HEIGHT_INCHES: int = 0x5F

## The objects, which come out of `PokedexSlowpokeLZ` rather than the background
## sheet: `Pokedex_PutScrollbarOAM`'s knob, the search screen's Slowpoke and the
## seven tiles the listing cursor's frame is built from.
const SCROLLBAR_TILE: int = 0x0F
## `DoDexSearchSlowpokeFrame.SlowpokeSpriteData`: three by three tiles at
## (9,11), with the frame's own offset added to each tile number.
const SLOWPOKE_AT := Vector2i(9, 11)
const SLOWPOKE_TILES: Array[int] = [
	0x00, 0x01, 0x02, 0x10, 0x11, 0x12, 0x20, 0x21, 0x22,
]
## `AnimateDexSearchSlowpoke.FrameIDs`: five frames, each held seven frames, run
## twenty-five times through and then left on frame 0 for thirty-two more.
const SLOWPOKE_FRAMES: int = 5
const SLOWPOKE_FRAME_HOLD: int = 7
const SLOWPOKE_STEPS: int = 25
const SLOWPOKE_SETTLE: int = 32

## `Pokedex_LoadCursorOAM`'s own rows, as (x tile, y tile, dx, dy, tile, x flip,
## y flip). The y of every row is `wDexListingCursor` * 16 lower, which is what
## `and $7 / swap a` adds.
const CURSOR_NEW_MODE: Array = [
	[9, 3, -1, 3, 0x30, false, false], [9, 2, -1, 3, 0x31, false, false],
	[10, 2, -1, 3, 0x32, false, false], [11, 2, -1, 3, 0x32, false, false],
	[12, 2, -1, 3, 0x33, false, false], [16, 2, 0, 3, 0x33, true, false],
	[17, 2, 0, 3, 0x32, true, false], [18, 2, 0, 3, 0x32, true, false],
	[19, 2, 0, 3, 0x31, true, false], [19, 3, 0, 3, 0x30, true, false],
	[9, 4, -1, 3, 0x30, false, true], [9, 5, -1, 3, 0x31, false, true],
	[10, 5, -1, 3, 0x32, false, true], [11, 5, -1, 3, 0x32, false, true],
	[12, 5, -1, 3, 0x33, false, true], [16, 5, 0, 3, 0x33, true, true],
	[17, 5, 0, 3, 0x32, true, true], [18, 5, 0, 3, 0x32, true, true],
	[19, 5, 0, 3, 0x31, true, true], [19, 4, 0, 3, 0x30, true, true],
]
## `Pokedex_PutOldModeCursorOAM.CursorOAM`, which is two columns wider because
## DEXMODE_OLD's listing has no scroll bar, and sits three pixels higher.
const CURSOR_OLD_MODE: Array = [
	[9, 3, -1, 0, 0x30, false, false], [9, 2, -1, 0, 0x31, false, false],
	[10, 2, -1, 0, 0x32, false, false], [11, 2, -1, 0, 0x32, false, false],
	[12, 2, -1, 0, 0x32, false, false], [13, 2, -1, 0, 0x33, false, false],
	[16, 2, -2, 0, 0x33, true, false], [17, 2, -2, 0, 0x32, true, false],
	[18, 2, -2, 0, 0x32, true, false], [19, 2, -2, 0, 0x32, true, false],
	[20, 2, -2, 0, 0x31, true, false], [20, 3, -2, 0, 0x30, true, false],
	[9, 4, -1, 0, 0x30, false, true], [9, 5, -1, 0, 0x31, false, true],
	[10, 5, -1, 0, 0x32, false, true], [11, 5, -1, 0, 0x32, false, true],
	[12, 5, -1, 0, 0x32, false, true], [13, 5, -1, 0, 0x33, false, true],
	[16, 5, -2, 0, 0x33, true, true], [17, 5, -2, 0, 0x32, true, true],
	[18, 5, -2, 0, 0x32, true, true], [19, 5, -2, 0, 0x32, true, true],
	[20, 5, -2, 0, 0x31, true, true], [20, 4, -2, 0, 0x30, true, true],
]
## `.CursorAtTopOAM`, which DEXMODE_OLD swaps in for a cursor on the top row: the
## frame's own top edge would otherwise be drawn above the listing.
const CURSOR_OLD_MODE_TOP: Array = [
	[9, 3, -1, 0, 0x30, false, false], [9, 2, -1, 0, 0x34, false, false],
	[10, 2, -1, 0, 0x35, false, false], [11, 2, -1, 0, 0x35, false, false],
	[12, 2, -1, 0, 0x35, false, false], [13, 2, -1, 0, 0x36, false, false],
	[16, 2, -2, 0, 0x36, true, false], [17, 2, -2, 0, 0x35, true, false],
	[18, 2, -2, 0, 0x35, true, false], [19, 2, -2, 0, 0x35, true, false],
	[20, 2, -2, 0, 0x34, true, false], [20, 3, -2, 0, 0x30, true, false],
	[9, 4, -1, 0, 0x30, false, true], [9, 5, -1, 0, 0x31, false, true],
	[10, 5, -1, 0, 0x32, false, true], [11, 5, -1, 0, 0x32, false, true],
	[12, 5, -1, 0, 0x32, false, true], [13, 5, -1, 0, 0x33, false, true],
	[16, 5, -2, 0, 0x33, true, true], [17, 5, -2, 0, 0x32, true, true],
	[18, 5, -2, 0, 0x32, true, true], [19, 5, -2, 0, 0x32, true, true],
	[20, 5, -2, 0, 0x31, true, true], [20, 4, -2, 0, 0x30, true, true],
]
## `Pokedex_UpdateSearchResultsCursorOAM.CursorOAM`, the wide frame at the new
## mode's own three-pixel drop.
const CURSOR_RESULTS: Array = [
	[9, 3, -1, 3, 0x30, false, false], [9, 2, -1, 3, 0x31, false, false],
	[10, 2, -1, 3, 0x32, false, false], [11, 2, -1, 3, 0x32, false, false],
	[12, 2, -1, 3, 0x32, false, false], [13, 2, -1, 3, 0x33, false, false],
	[16, 2, -2, 3, 0x33, true, false], [17, 2, -2, 3, 0x32, true, false],
	[18, 2, -2, 3, 0x32, true, false], [19, 2, -2, 3, 0x32, true, false],
	[20, 2, -2, 3, 0x31, true, false], [20, 3, -2, 3, 0x30, true, false],
	[9, 4, -1, 3, 0x30, false, true], [9, 5, -1, 3, 0x31, false, true],
	[10, 5, -1, 3, 0x32, false, true], [11, 5, -1, 3, 0x32, false, true],
	[12, 5, -1, 3, 0x32, false, true], [13, 5, -1, 3, 0x33, false, true],
	[16, 5, -2, 3, 0x33, true, true], [17, 5, -2, 3, 0x32, true, true],
	[18, 5, -2, 3, 0x32, true, true], [19, 5, -2, 3, 0x32, true, true],
	[20, 5, -2, 3, 0x31, true, true], [20, 4, -2, 3, 0x30, true, true],
]
## How much one row of the listing moves the cursor frame, which is
## `Pokedex_LoadCursorOAM`'s `swap a` on the low three bits.
const CURSOR_ROW_HEIGHT: int = 16
## `Pokedex_PutScrollbarOAM`'s own three numbers: the knob's column and the top
## and bottom of the run it slides down.
const SCROLLBAR_X: int = 161
const SCROLLBAR_MIN_Y: int = 20
const SCROLLBAR_RANGE: int = 121
## `dbsprite` writes an object's own bytes with no origin added, and the hardware
## counts them from (8, 16), so a row reaches the screen eight and sixteen less.
const OAM_ORIGIN := Vector2i(8, 16)

## `Pokedex_PlaceCaughtSymbolIfCaught`'s own tile, which is a character.
const CAUGHT_SYMBOL: int = 0x4F
## `Pokedex_BlinkArrowCursor`'s two, which are characters as well.
const CURSOR_CODE: int = 0xED
const CURSOR_BLANK: int = 0x7F

## `POKEDEX_SCX`, the five pixels the main screen's background is scrolled by.
const MAIN_SCX: int = 5
## `hWX` less the hardware's own seven, for the two dex modes: `$47` for a mode
## with a scroll bar and `$4a` for DEXMODE_OLD, which has none. Neither is a tile
## boundary once the background is scrolled, which is why the main screen is
## composed in pixels.
const MAIN_WINDOW_X: int = 0x47 - 7
const MAIN_WINDOW_X_OLD: int = 0x4A - 7
## `DrawPokedexListWindow` writes twelve columns and no more.
const WINDOW_COLUMNS: int = 12

## `String_SELECT_OPTION` and `String_START_SEARCH`, which are tile runs rather
## than text: the two button pictures are drawn out of the dex sheet.
const SELECT_OPTION: Array[int] = [0x3B, 0x48, 0x49, 0x4A, 0x44, 0x45, 0x46, 0x47]
const START_SEARCH: Array[int] = [
	0x3C, 0x3B, 0x41, 0x42, 0x43, 0x4B, 0x4C, 0x4D, 0x4E, 0x3C,
]
## `.TypeLeftRightArrows`' two ends, and the pair the Unown screen puts under its
## own box.
const ARROW_LEFT: int = 0x3D
const ARROW_RIGHT: int = 0x3E

var font: Gen2Font = null
## The dex sheet and the footprint strip, each as the cache's own index buffer.
var _sheet: PackedByteArray = PackedByteArray()
var _footprints: PackedByteArray = PackedByteArray()
var _unown_font: PackedByteArray = PackedByteArray()
var _palette: PackedColorArray = PackedColorArray()
## `PokedexSlowpokeLZ`, which `Pokedex_LoadGFX` decompresses to `vTiles0`: the
## objects, not a background sheet. Its 55 tiles carry the search screen's five
## Slowpoke frames, the scroll bar's knob and the listing cursor's frame.
var _objects: PackedByteArray = PackedByteArray()
var _object_palette: PackedColorArray = PackedColorArray()
## `LoadQuestionMarkPic`'s own 7x7 pic and the palette it is drawn through.
var _question_mark: PackedByteArray = PackedByteArray()
var _question_mark_palette: PackedColorArray = PackedColorArray()


## [param data] supplies the glyphs and the three strips; a cache without them
## answers null rather than drawing a screen of blanks.
static func from_data(data: GameData) -> Gen2PokedexPage:
	if data == null:
		return null
	var glyphs: Gen2Font = Gen2Font.from_data(data)
	if glyphs == null:
		return null
	var out := Gen2PokedexPage.new()
	out.font = glyphs
	out._sheet = data.tile_indices("pokedex")
	out._footprints = data.tile_indices("footprints")
	out._unown_font = data.tile_indices("unown_font")
	out._palette = data.pokedex_palette("interface")
	out._objects = data.tile_indices("pokedex_slowpoke")
	out._object_palette = data.pokedex_palette("cursor")
	out._question_mark = data.tile_indices("pokedex_question_mark")
	out._question_mark_palette = data.pokedex_palette("question_mark")
	return out


func ready() -> bool:
	return font != null and not _sheet.is_empty() and not _footprints.is_empty() \
		and not _objects.is_empty() and not _question_mark.is_empty() \
		and _object_palette.size() == Gen2Palette.COLORS_PER_PIC \
		and _palette.size() == Gen2Palette.COLORS_PER_PIC


## A screen filled the way `Pokedex_FillBackgroundColor2` fills one.
static func blank_map() -> PackedInt32Array:
	var map := PackedInt32Array()
	map.resize(COLUMNS * ROWS)
	map.fill(BACKGROUND_TILE)
	return map


## `Pokedex_DrawMainScreenBG`: the left sidebar, the two boxes and the bottom
## bar. The listing is not in it; that is the window, and [method window_map]
## draws it.
##
## [param seen] and [param caught] are the two counts `CountSetBits` prints.
func main_background(seen: int, caught: int) -> PackedInt32Array:
	_unown_letters = false
	var map: PackedInt32Array = blank_map()
	_place_border(map, 0, 0, 7, 7)
	_place_border(map, 0, 9, 6, 7)
	_text(map, 1, 11, "SEEN")
	_number(map, 5, 12, seen, 3)
	_text(map, 1, 14, "OWN")
	_number(map, 5, 15, caught, 3)
	# `String_SELECT_OPTION` falls through into `String_START_SEARCH`, so the one
	# `Pokedex_PlaceString` at (1,17) writes both runs; the START one on its own
	# is in the window, which is what covers the right-hand half of this row.
	_tiles(map, 1, 17, SELECT_OPTION)
	_tiles(map, 1 + SELECT_OPTION.size(), 17, START_SEARCH)
	_column(map, 8, 1, 7, SIDEBAR)
	_column(map, 8, 10, 6, SIDEBAR)
	_put(map, 8, 0, SIDEBAR_TOP)
	_put(map, 8, 8, SIDEBAR_SPLIT_TOP)
	_put(map, 8, 9, SIDEBAR_SPLIT_BOTTOM)
	_put(map, 8, 16, SIDEBAR_BOTTOM)
	_place_pic_corner(map, 1, 1)
	return map


## `Pokedex_DrawSearchResultsScreenBG`, which is the main screen's sidebar with
## one box instead of two and the result count under it.
func search_results_background(count: int, type_line: String) -> PackedInt32Array:
	_unown_letters = false
	var map: PackedInt32Array = blank_map()
	_place_border(map, 0, 0, 7, 7)
	_place_border(map, 0, 11, 5, 18)
	_text(map, 1, 12, "SEARCH RESULTS")
	_text(map, 1, 13, "  TYPE")
	# `.BottomWindowText`'s third line and `Pokedex_PlaceSearchResultsTypeStrings`
	# are written into two different maps and overlap on screen; laid out as one
	# row here, which is the one thing on this screen the oracle has not settled.
	_text(map, 1, 14, type_line)
	_text(map, 9, 14, "FOUND!")
	_number(map, 1, 16, count, 3)
	_put(map, 8, 0, SIDEBAR_TOP)
	_column(map, 8, 1, 7, SIDEBAR)
	_put(map, 8, 8, SIDEBAR_SPLIT_TOP)
	_put(map, 8, 9, RESULTS_SPLIT_TOP)
	_put(map, 8, 10, RESULTS_SPLIT_BOTTOM)
	_place_pic_corner(map, 1, 1)
	return map


## `DrawPokedexListWindow` and `Pokedex_PrintListing`, as the twelve-column
## window the main screen and the results screen both put their listing in.
##
## [param rows] is [method Gen2Pokedex.rows]' own shape: `number`, `name`,
## `seen` and `caught` per visible entry. [param old_mode] swaps the scroll bar
## for the two tiles that replace it and is what prints a dex number above each
## name.
func window_map(rows: Array, old_mode: bool) -> PackedInt32Array:
	var map := PackedInt32Array()
	map.resize(WINDOW_COLUMNS * ROWS)
	map.fill(CURSOR_BLANK)
	# `DrawPokedexListWindow` fills its own row 17, and `Pokedex_InitMainScreen`
	# writes `String_START_SEARCH` over it: the bar under the listing is the
	# window's, not the background's.
	for column: int in WINDOW_COLUMNS:
		map[17 * WINDOW_COLUMNS + column] = BACKGROUND_TILE
	for index: int in START_SEARCH.size():
		map[17 * WINDOW_COLUMNS + index] = START_SEARCH[index]
	for column: int in 11:
		map[column] = BORDER_TOP
		map[16 * WINDOW_COLUMNS + column] = BORDER_BOTTOM
	map[5] = WINDOW_LEFT_JOINT
	map[16 * WINDOW_COLUMNS + 5] = WINDOW_LEFT_JOINT_BOTTOM
	map[11] = NO_SCROLL_TOP if old_mode else SCROLL_TOP
	for row: int in ROWS - 3:
		map[(row + 1) * WINDOW_COLUMNS + 11] = NO_SCROLL if old_mode else SCROLL
	map[(ROWS - 2) * WINDOW_COLUMNS + 11] = NO_SCROLL_BOTTOM if old_mode else SCROLL_BOTTOM

	_window_rows(map, rows, old_mode)
	return map


## `Pokedex_PrintListing`, which both listing screens share: one entry every two
## rows from row 2, at column 0. `.PrintEntry` reaches the name by one `inc hl`
## from that column and the caught symbol is what it writes into the cell it steps
## over, so a name runs from column 1 to column 10 and the scroll bar's column 11
## is clear of it. DEXMODE_OLD's number is three digits at column 0 of the row
## above. The cursor is not in this map at all: it is the object frame
## `Pokedex_LoadCursorOAM` draws over the whole screen.
func _window_rows(map: PackedInt32Array, rows: Array, old_mode: bool) -> void:
	for index: int in rows.size():
		var entry: Dictionary = rows[index]
		var row: int = 2 + index * 2
		if row >= ROWS:
			break
		if old_mode:
			_window_number(map, 0, row - 1, int(entry.get("number", 0)))
		if not bool(entry.get("seen", false)):
			_window_text(map, 1, row, Gen2Pokedex.NOT_SEEN_NAME)
			continue
		if bool(entry.get("caught", false)):
			map[row * WINDOW_COLUMNS] = CAUGHT_SYMBOL
		_window_text(map, 1, row, String(entry.get("name", "")))


## How much of the results window reaches the screen; see [method
## results_window_map].
const RESULTS_WINDOW_ROWS: int = 11


## `DrawPokedexSearchResultsWindow`: two stacked frames rather than the main
## screen's one, with the four-row listing in the upper.
func results_window_map(rows: Array) -> PackedInt32Array:
	var map := PackedInt32Array()
	map.resize(WINDOW_COLUMNS * ROWS)
	map.fill(CURSOR_BLANK)
	# `DrawPokedexSearchResultsWindow` draws a second frame over rows 11 to 17,
	# which at `hWX` $4a would cut `.BottomWindowText` in the background box in
	# half. Only the listing's own frame is drawn until the oracle says what the
	# hardware puts there.
	for frame: Array in [[0, 10]]:
		var top: int = int(frame[0])
		var bottom: int = int(frame[1])
		for column: int in 11:
			map[top * WINDOW_COLUMNS + column] = BORDER_TOP
			map[bottom * WINDOW_COLUMNS + column] = BORDER_BOTTOM
		map[top * WINDOW_COLUMNS + 11] = NO_SCROLL_TOP
		for row: int in range(top + 1, bottom):
			map[row * WINDOW_COLUMNS + 11] = NO_SCROLL
		map[bottom * WINDOW_COLUMNS + 11] = NO_SCROLL_BOTTOM
	map[5] = WINDOW_LEFT_JOINT
	map[10 * WINDOW_COLUMNS + 5] = WINDOW_LEFT_JOINT_BOTTOM
	_window_rows(map, rows, false)
	return map


## `Pokedex_DrawDexEntryScreenBG` and `DisplayDexEntry`, as one grid.
##
## [param entry] is [method GameData.dex_entry]'s own record. A species that has
## not been caught keeps the placeholder height and weight the background draws,
## which is what the source's early `ret z` leaves on screen.
func entry_map(
	number: int, name: String, entry: Dictionary, caught: bool, page: int, cursor: int
) -> PackedInt32Array:
	_unown_letters = false
	var map: PackedInt32Array = blank_map()
	_place_border(map, 0, 0, 15, 18)
	_put(map, 19, 0, BORDER_TOP)
	_column(map, 19, 1, 15, CURSOR_BLANK)
	_put(map, 19, 16, BORDER_BOTTOM)
	_fill(map, 1, 10, 19, ENTRY_DIVIDER)
	_fill(map, 1, 17, 18, CURSOR_BLANK)
	_text(map, 9, 7, "HT  ?")
	_put(map, 14, 7, HEIGHT_FEET)
	_text(map, 15, 7, "??")
	_put(map, 17, 7, HEIGHT_INCHES)
	_text(map, 9, 9, "WT   ???lb")
	_put(map, 0, 17, SELECT_OPTION[0])
	_text(map, 1, 17, " PAGE AREA CRY PRNT")
	_place_pic_corner(map, 1, 1)

	_text(map, 9, 3, name)
	_text(map, 9, 5, String(entry.get("category", "")))
	_put(map, 2, 8, NUMBER_NO)
	_put(map, 3, 8, NUMBER_DOT)
	_number(map, 4, 8, number, 3, true)
	if caught:
		# `PrintNum` writes the height as four digits with two in front of the
		# point, and the point is then overwritten with the feet symbol; the
		# weight is five digits with four in front of it, which is tenths of a
		# pound. Both are the numbers the cartridge stores, not a conversion.
		var height: int = int(entry.get("height", 0))
		@warning_ignore("integer_division")
		_number(map, 12, 7, height / 100, 2)
		_put(map, 14, 7, HEIGHT_FEET)
		_number(map, 15, 7, height % 100, 2, true)
		_number(map, 11, 9, int(entry.get("weight", 0)), 5, false, 1)
	_put(map, 1, 9, PAGE_MARKER_TOP)
	_put(map, 2, 9, PAGE_MARKER_TOP)
	_put(map, 1, 10, PAGE_MARKER)
	_put(map, 2, 10, PAGE_ONE if page == Gen2Pokedex.PAGE_1 else PAGE_TWO)
	var pages: Array = entry.get("pages", []) as Array
	var body: String = String(pages[page]) if page < pages.size() else ""
	_paragraph(map, 2, 11, body)
	_place_footprint_cells(map)
	if cursor >= 0 and cursor < Gen2PokedexScreen.ENTRY_BUTTONS.size():
		_put(map, ENTRY_CURSOR_COLUMNS[cursor], 17, CURSOR_CODE)
	return map


## `DexEntryScreen_ArrowCursorData`'s four `dwcoord`s, which are all on row 17.
const ENTRY_CURSOR_COLUMNS: Array[int] = [1, 6, 11, 15]
## `.ArrowCursorData` on the OPTION screen and on SEARCH, whose rows are the ones
## the two `dwcoord` lists name.
const OPTION_CURSOR_ROWS: Array[int] = [4, 6, 8, 10]
const SEARCH_CURSOR_ROWS: Array[int] = [4, 6, 13, 15]


## `Pokedex_DrawOptionScreenBG`, whose fourth row is drawn only once
## `wUnlockedUnownMode` is set.
func option_map(
	unown_unlocked: bool, cursor: int, description: String = ""
) -> PackedInt32Array:
	_unown_letters = false
	var map: PackedInt32Array = blank_map()
	_place_border(map, 0, 2, 8, 18)
	_title(map, 1, "OPTION")
	for index: int in Gen2Pokedex.MODE_ROWS.size():
		if index == 3 and not unown_unlocked:
			break
		_text(map, 3, OPTION_CURSOR_ROWS[index], String(
			Gen2Pokedex.MODE_ROWS[index]["label"]
		))
	var rows: int = 4 if unown_unlocked else 3
	if cursor >= 0 and cursor < rows:
		_put(map, 2, OPTION_CURSOR_ROWS[cursor], CURSOR_CODE)
	_bottom_box(map, description)
	return map


## `Pokedex_DisplayModeDescription`, `Pokedex_DisplayChangingModesMessage` and
## `Pokedex_DisplayTypeNotFoundMessage` are the same box redrawn: four rows at
## (0,12) with two lines of words from (1,14).
func _bottom_box(map: PackedInt32Array, text: String) -> void:
	_place_border(map, 0, 12, 4, 18)
	var row: int = 0
	for line: String in text.split("\n"):
		if row >= 2:
			break
		_text(map, 1, 14 + row, line)
		row += 1


## `Pokedex_DrawSearchScreenBG`, with the two chosen type names in place.
func search_map(
	type_1: String, type_2: String, cursor: int, message: String = ""
) -> PackedInt32Array:
	_unown_letters = false
	var map: PackedInt32Array = blank_map()
	_place_border(map, 0, 2, 14, 18)
	_title(map, 1, "SEARCH")
	for row: int in [4, 6]:
		_put(map, 8, row, ARROW_LEFT)
		_put(map, 17, row, ARROW_RIGHT)
	_text(map, 3, 4, "TYPE1")
	_text(map, 3, 6, "TYPE2")
	# `Pokedex_PlaceSearchScreenTypeStrings` clears a four by eight box at (9,3)
	# and places each `PokedexTypeSearchStrings` entry at (9,4) and (9,6). The
	# entries are eight cells wide, so the name is centred by the table itself.
	_text(map, 9, 4, type_1)
	_text(map, 9, 6, type_2)
	_text(map, 3, 13, "BEGIN SEARCH!!")
	_text(map, 3, 15, "CANCEL")
	if cursor >= 0 and cursor < SEARCH_CURSOR_ROWS.size():
		_put(map, 2, SEARCH_CURSOR_ROWS[cursor], CURSOR_CODE)
	if not message.is_empty():
		_bottom_box(map, message)
	return map


## `Pokedex_DrawUnownModeBG` and its own letter walk.
##
## [param forms] is `wUnownDex`, the forms in catching order, and
## [constant UNOWN_COORDS] the table it indexes: the letter's cell and the cell
## the cursor stands in beside it, which are not always the same column.
## [param word] is `PrintUnownWord`'s own, the chamber word for the form the
## cursor is on.
func unown_map(forms: Array, cursor: int, word: String = "") -> PackedInt32Array:
	_unown_letters = true
	var map: PackedInt32Array = blank_map()
	_place_border(map, 2, 1, 10, 13)
	_place_border(map, 2, 14, 1, 13)
	_put(map, 2, 15, ARROW_LEFT)
	_put(map, 16, 15, ARROW_RIGHT)
	_place_pic_corner(map, 6, 5)
	for index: int in mini(forms.size(), UNOWN_COORDS.size()):
		var form: int = int(forms[index])
		if form <= 0:
			break
		var at: Array = UNOWN_COORDS[index]
		_put(map, int(at[0]), int(at[1]), UNOWN_FIRST_CHAR + form - 1)
		if index == cursor:
			# `ld c, FIRST_UNOWN_CHAR + NUM_UNOWN`: the twenty-seventh tile of
			# `UnownFont` is a diamond, not the arrow the other screens blink.
			_put(map, int(at[2]), int(at[3]), UNOWN_CURSOR_CHAR)
	# `PrintUnownWord` clears twelve cells at (4,15) and prints the cursor's own
	# word into them.
	_fill(map, 4, 15, 12, CURSOR_BLANK)
	_text(map, 4, 15, word)
	return map


## `FIRST_UNOWN_CHAR`, which the letter walk adds the form to. The letters are
## `UnownFont` inverted into the dex sheet's own numbering, so a form's cell is a
## sheet tile rather than a character.
const UNOWN_FIRST_CHAR: int = RomLayout.UNOWN_FONT_FIRST_TILE
## `FIRST_UNOWN_CHAR + NUM_UNOWN`, the diamond that follows the alphabet.
const UNOWN_CURSOR_CHAR: int = UNOWN_FIRST_CHAR + RomLayout.UNOWN_FORMS
## `UnownModeLetterAndCursorCoords`, as (letter x, letter y, cursor x, cursor y)
## per form in catching order.
const UNOWN_COORDS: Array = [
	[4, 11, 3, 11], [4, 10, 3, 10], [4, 9, 3, 9], [4, 8, 3, 8],
	[4, 7, 3, 7], [4, 6, 3, 6], [4, 5, 3, 5], [4, 4, 3, 4],
	[4, 3, 3, 2], [5, 3, 5, 2], [6, 3, 6, 2], [7, 3, 7, 2],
	[8, 3, 8, 2], [9, 3, 9, 2], [10, 3, 10, 2], [11, 3, 11, 2],
	[12, 3, 12, 2], [13, 3, 13, 2], [14, 3, 15, 2], [14, 4, 15, 4],
	[14, 5, 15, 5], [14, 6, 15, 6], [14, 7, 15, 7], [14, 8, 15, 8],
	[14, 9, 15, 9], [14, 10, 15, 10],
]


## One grid as pixels. [param pic] is the species picture drawn into the 7x7 box
## the layout left blank, or null for a screen that shows none.
func image(map: PackedInt32Array, pic: Image = null, pic_at: Vector2i = Vector2i(1, 1)) -> Image:
	var indices := PackedByteArray()
	indices.resize(WIDTH * HEIGHT)
	for row: int in ROWS:
		for column: int in COLUMNS:
			_blit_tile(indices, WIDTH, map[row * COLUMNS + column], column * TILE, row * TILE)
	var out: Image = Gen2PicImage.from_indices(indices, WIDTH, HEIGHT, _palette)
	if pic != null:
		out.blit_rect(
			pic, Rect2i(Vector2i.ZERO, pic.get_size()), pic_at * TILE
		)
	return out


## `PadFrontpic`, which is what makes every species fill the same seven by seven
## box: one blank column on the left, the picture sitting on the box's floor, and
## the rest filled with colour 0. A 5x5 species is padded to 7x7 before the copy,
## so the box is never the screen's own background showing through.
static func pad_pic(pic: Image, background: Color) -> Image:
	var side: int = PIC_COLUMNS * TILE
	var out: Image = Image.create_empty(side, side, false, Image.FORMAT_RGBA8)
	out.fill(background)
	if pic == null:
		return out
	out.blit_rect(pic, Rect2i(Vector2i.ZERO, pic.get_size()), Vector2i(
		0 if pic.get_width() >= side else TILE, side - pic.get_height()
	))
	return out


## The search screen and the Slowpoke object `DoDexSearchSlowpokeFrame` puts over
## it, which is the one screen here whose objects are not a cursor.
func search_image(map: PackedInt32Array, frame: int) -> Image:
	var out: Image = image(map)
	_draw_slowpoke(out, frame)
	return out


## The main screen, composed the way the hardware composes it: the background
## scrolled left by [constant MAIN_SCX] and the listing window blitted over it at
## its own `hWX`. Both layers wrap at the background map's 256 pixels, which is
## why the background is drawn wide and sampled rather than blitted.
## [param cursor] is `wDexListingCursor`, which the object frame is drawn around,
## and [param scrollbar] the (position, listing end) pair
## `Pokedex_PutScrollbarOAM` slides its knob by. A cursor below zero draws
## neither, which is what `ClearSprites` leaves on a screen being read.
func image_main(
	background: PackedInt32Array, window: PackedInt32Array, old_mode: bool,
	pic: Image = null, window_rows: int = ROWS, cursor: int = -1,
	scrollbar: Vector2i = Vector2i.ZERO, results: bool = false
) -> Image:
	var out: Image = image(background, pic)
	var scrolled: Image = Image.create(WIDTH, HEIGHT, false, out.get_format())
	for x: int in WIDTH:
		scrolled.blit_rect(
			out, Rect2i((x + MAIN_SCX) % WIDTH, 0, 1, HEIGHT), Vector2i(x, 0)
		)
	var indices := PackedByteArray()
	indices.resize(WINDOW_COLUMNS * TILE * HEIGHT)
	for row: int in ROWS:
		for column: int in WINDOW_COLUMNS:
			_blit_tile(
				indices, WINDOW_COLUMNS * TILE,
				window[row * WINDOW_COLUMNS + column], column * TILE, row * TILE
			)
	var layer: Image = Gen2PicImage.from_indices(
		indices, WINDOW_COLUMNS * TILE, HEIGHT, _palette
	)
	var at: int = MAIN_WINDOW_X_OLD if old_mode else MAIN_WINDOW_X
	scrolled.blit_rect(
		layer,
		Rect2i(0, 0, mini(layer.get_width(), WIDTH - at), window_rows * TILE),
		Vector2i(at, 0)
	)
	_draw_listing_objects(scrolled, old_mode, cursor, scrollbar, results)
	return scrolled


## `Pokedex_UpdateCursorOAM` and `Pokedex_UpdateSearchResultsCursorOAM`: the
## frame around the selected row, and the scroll bar's knob behind it. Both are
## objects rather than tiles, which is why the listing's own names start in
## column 1 of the window with nothing in front of them.
func _draw_listing_objects(
	onto: Image, old_mode: bool, cursor: int, scrollbar: Vector2i, results: bool
) -> void:
	if cursor < 0:
		return
	var buffer := PackedByteArray()
	buffer.resize(WIDTH * HEIGHT)
	var frame: Array = CURSOR_NEW_MODE
	if old_mode:
		frame = CURSOR_OLD_MODE_TOP if cursor == 0 else CURSOR_OLD_MODE
	elif results:
		frame = CURSOR_RESULTS
	_copy_oam(buffer, frame, Vector2i(0, (cursor & 7) * CURSOR_ROW_HEIGHT))
	# `Pokedex_UpdateCursorOAM` puts the scroll bar's knob out only in the two
	# modes that draw a scroll bar, and the results screen draws none either.
	if not old_mode and not results:
		_put_scrollbar(buffer, scrollbar.x, scrollbar.y)
	onto.blend_rect(
		Gen2PicImage.from_indices(buffer, WIDTH, HEIGHT, _object_palette, true),
		Rect2i(0, 0, WIDTH, HEIGHT), Vector2i.ZERO
	)


## `Pokedex_PutScrollbarOAM`: the knob's own y counts the selected position out
## of [param listing_end] over the 121 pixels it can slide, and the last position
## is pinned to the bottom rather than computed.
func _put_scrollbar(into: PackedByteArray, position: int, listing_end: int) -> void:
	if listing_end <= 0:
		return
	var offset: int = SCROLLBAR_RANGE
	if position != listing_end - 1:
		@warning_ignore("integer_division")
		offset = (position * SCROLLBAR_RANGE) / listing_end
	_blit_object(
		into, SCROLLBAR_TILE,
		Vector2i(SCROLLBAR_X - OAM_ORIGIN.x, SCROLLBAR_MIN_Y + offset - OAM_ORIGIN.y),
		false, false
	)


## `DoDexSearchSlowpokeFrame`, whose nine tiles each take the frame number times
## three. Drawn over the search screen, which is where its own OAM sits.
func _draw_slowpoke(onto: Image, frame: int) -> void:
	var buffer := PackedByteArray()
	buffer.resize(WIDTH * HEIGHT)
	for index: int in SLOWPOKE_TILES.size():
		@warning_ignore("integer_division")
		var at := Vector2i(
			(SLOWPOKE_AT.x + index % 3) * TILE - OAM_ORIGIN.x,
			(SLOWPOKE_AT.y + index / 3) * TILE - OAM_ORIGIN.y
		)
		_blit_object(buffer, SLOWPOKE_TILES[index] + frame * 3, at, false, false)
	onto.blend_rect(
		Gen2PicImage.from_indices(buffer, WIDTH, HEIGHT, _object_palette, true),
		Rect2i(0, 0, WIDTH, HEIGHT), Vector2i.ZERO
	)


## `Pokedex_LoadCursorOAM`, which walks a table adding the cursor's own offset to
## every row's y.
func _copy_oam(into: PackedByteArray, objects: Array, offset: Vector2i) -> void:
	for object: Array in objects:
		_blit_object(
			into, int(object[4]),
			Vector2i(
				int(object[0]) * TILE + int(object[2]) + offset.x - OAM_ORIGIN.x,
				int(object[1]) * TILE + int(object[3]) + offset.y - OAM_ORIGIN.y
			),
			bool(object[5]), bool(object[6])
		)


## One eight by eight object out of `PokedexSlowpokeLZ`. Index zero is the
## hardware's transparent colour and is not drawn.
func _blit_object(
	into: PackedByteArray, tile: int, at: Vector2i, flip_x: bool, flip_y: bool
) -> void:
	@warning_ignore("integer_division")
	var slots: int = _objects.size() / TILE / TILE
	if tile < 0 or tile >= slots:
		return
	var width: int = slots * TILE
	for row: int in TILE:
		var y: int = at.y + (TILE - 1 - row if flip_y else row)
		if y < 0 or y >= HEIGHT:
			continue
		for pixel: int in TILE:
			var x: int = at.x + (TILE - 1 - pixel if flip_x else pixel)
			if x < 0 or x >= WIDTH:
				continue
			var index: int = _objects[row * width + tile * TILE + pixel]
			if index == 0:
				continue
			into[y * WIDTH + x] = index


## `Pokedex_LoadSelectedMonTiles`'s `.QuestionMark`, which is what an unseen
## species' box is drawn with: `LoadQuestionMarkPic` decompresses
## `gfx/pokedex/question_mark.2bpp.lz` and copies its 7 * 7 tiles into the pic
## slot, column major like every pic and drawn through the dex's own
## `question_mark` palette. Not `PokedexSlowpokeLZ`, which this used to draw:
## that is a different asset, five Slowpoke reading a book decompressed to
## `vTiles0` for the search screen and the listing's objects.
func unseen_pic() -> Image:
	if _question_mark.is_empty() or _question_mark_palette.size() != Gen2Palette.COLORS_PER_PIC:
		return null
	var side: int = RomLayout.POKEDEX_QUESTION_MARK_COLUMNS * TILE
	var indices := PackedByteArray()
	indices.resize(side * side)
	@warning_ignore("integer_division")
	var width: int = _question_mark.size() / TILE
	for slot: int in RomLayout.POKEDEX_QUESTION_MARK_TILES:
		@warning_ignore("integer_division")
		var column: int = slot / RomLayout.POKEDEX_QUESTION_MARK_COLUMNS
		var row: int = slot % RomLayout.POKEDEX_QUESTION_MARK_COLUMNS
		Gen2Font.blit_slot(
			_question_mark, width, slot, indices, side, column * TILE, row * TILE
		)
	return Gen2PicImage.from_indices(indices, side, side, _question_mark_palette)


## `Pokedex_LoadCurrentFootprint`, as the four tiles the entry screen's grid
## names. Answers false when the cache carries no footprint for the species, in
## which case the four cells keep whatever the sheet has at those numbers.
func load_footprint(data: GameData, species: int) -> bool:
	_footprint = PackedInt32Array()
	if data == null:
		return false
	var tiles: PackedInt32Array = data.footprint_tiles(species)
	if tiles.is_empty():
		return false
	_footprint = tiles
	return true


var _footprint := PackedInt32Array()
## Whether `Pokedex_LoadUnownFont` has run, which only the Unown screen does.
var _unown_letters: bool = false


## `Pokedex_DrawFootprint`'s four cells at (18,1) and (18,2).
func _place_footprint_cells(map: PackedInt32Array) -> void:
	for index: int in 4:
		@warning_ignore("integer_division")
		_put(
			map, FOOTPRINT_AT.x + (index % 2), FOOTPRINT_AT.y + (index / 2),
			FOOTPRINT_TOP + index if index < 2 else FOOTPRINT_BOTTOM + index - 2
		)


## `Pokedex_PlaceBorder`: a box [param height] rows of inside tall and
## [param width] columns of inside wide, from its own top-left corner.
func _place_border(
	map: PackedInt32Array, x: int, y: int, height: int, width: int
) -> void:
	_put(map, x, y, BORDER_TOP_LEFT)
	for column: int in width:
		_put(map, x + 1 + column, y, BORDER_TOP)
	_put(map, x + 1 + width, y, BORDER_TOP_RIGHT)
	for row: int in height:
		_put(map, x, y + 1 + row, BORDER_LEFT)
		for column: int in width:
			_put(map, x + 1 + column, y + 1 + row, BORDER_FILL)
		_put(map, x + 1 + width, y + 1 + row, BORDER_RIGHT)
	_put(map, x, y + 1 + height, BORDER_BOTTOM_LEFT)
	for column: int in width:
		_put(map, x + 1 + column, y + 1 + height, BORDER_BOTTOM)
	_put(map, x + 1 + width, y + 1 + height, BORDER_BOTTOM_RIGHT)


## `Pokedex_PlaceFrontpicAtHL`: the 7x7 run of tile numbers the picture is drawn
## through, counted down each column, which is how a pic is stored.
func _place_pic_corner(map: PackedInt32Array, x: int, y: int) -> void:
	for row: int in 7:
		for column: int in 7:
			_put(map, x + column, y + row, row + column * 7)


## `.Title`'s own three pieces: the SELECT picture, the name, and the START one.
func _title(map: PackedInt32Array, y: int, label: String) -> void:
	# `.Title` is `db $3b, " OPTION ", $3c`: the second picture follows the
	# string's own trailing space rather than replacing it.
	_put(map, 0, y, SELECT_OPTION[0])
	_text(map, 1, y, " %s " % label)
	_put(map, 3 + label.length(), y, START_SEARCH[0])


func _column(map: PackedInt32Array, x: int, y: int, height: int, tile: int) -> void:
	for row: int in height:
		_put(map, x, y + row, tile)


func _fill(map: PackedInt32Array, x: int, y: int, width: int, tile: int) -> void:
	for column: int in width:
		_put(map, x + column, y, tile)


func _tiles(map: PackedInt32Array, x: int, y: int, run: Array[int]) -> void:
	for index: int in run.size():
		_put(map, x + index, y, run[index])


## `PlaceString`, whose `CheckDict` expands the shorthand before a tile is drawn.
## That expansion is [method Gen2Text.encode]'s, which matters here more than
## elsewhere: `$54` is a dex sheet tile on this screen, so a byte placed as
## itself would draw part of the frame.
func _text(map: PackedInt32Array, x: int, y: int, text: String) -> void:
	var codes: PackedByteArray = Gen2Text.encode(text)
	for index: int in codes.size():
		_put(map, x + index, y, codes[index])


## `PrintNum`, as the digits it writes. [param leading_zeros] is its own flag;
## [param decimals] splits the run the way the height and weight lines do.
func _number(
	map: PackedInt32Array, x: int, y: int, value: int, width: int,
	leading_zeros: bool = false, decimals: int = 0
) -> void:
	if leading_zeros:
		_text(map, x, y, String.num_int64(maxi(value, 0)).lpad(width, "0").right(width))
		return
	# `.PrintDigit` latches as `e` runs out, so the digit in front of the point
	# is printed whether or not it is a zero: a weight of 8 reads "   0.8".
	_text(map, x, y, Gen2Pokedex.print_num(value, width, width - decimals))


## One dex entry's page, wrapped into the five rows `ClearBox` cleared for it.
func _paragraph(map: PackedInt32Array, x: int, y: int, text: String) -> void:
	var row: int = 0
	for line: String in text.split("\n"):
		if row >= 5:
			break
		_text(map, x, y + row, line)
		row += 1


func _put(map: PackedInt32Array, x: int, y: int, tile: int) -> void:
	if x < 0 or x >= COLUMNS or y < 0 or y >= ROWS:
		return
	map[y * COLUMNS + x] = tile


func _window_text(map: PackedInt32Array, x: int, y: int, text: String) -> void:
	var codes: PackedByteArray = Gen2Text.encode(text)
	for index: int in codes.size():
		var column: int = x + index
		if column >= WINDOW_COLUMNS or y >= ROWS:
			break
		map[y * WINDOW_COLUMNS + column] = codes[index]


func _window_number(map: PackedInt32Array, x: int, y: int, value: int) -> void:
	var text: String = String.num_int64(maxi(value, 0)).lpad(3, "0")
	_window_text(map, x, y, text)


## One tile of the dex's own VRAM into an index buffer. `$31` to `$6a` is the
## dex sheet, the footprint cells are the four the strip was loaded with, and
## everything else is the font, inverted the way `Pokedex_LoadInvertedFont`
## leaves it.
func _blit_tile(
	into: PackedByteArray, into_width: int, tile: int, at_x: int, at_y: int
) -> void:
	# `Pokedex_LoadUnownFont` lands on top of the sheet, so this run is the
	# alphabet on the Unown screen and the sheet's own tiles everywhere else.
	if _unown_letters and tile >= UNOWN_FIRST_CHAR \
		and tile < UNOWN_FIRST_CHAR + RomLayout.UNOWN_FONT_TILES:
		@warning_ignore("integer_division")
		Gen2Font.blit_slot(
			_unown_font, _unown_font.size() / TILE, tile - UNOWN_FIRST_CHAR,
			into, into_width, at_x, at_y
		)
		_invert(into, into_width, at_x, at_y)
		return
	var footprint: int = _footprint_slot(tile)
	if footprint >= 0:
		@warning_ignore("integer_division")
		Gen2Font.blit_slot(
			_footprints, _footprints.size() / TILE, footprint,
			into, into_width, at_x, at_y
		)
		_invert(into, into_width, at_x, at_y)
		return
	if tile >= SHEET_FIRST_TILE and tile < SHEET_FIRST_TILE + RomLayout.POKEDEX_TILES:
		@warning_ignore("integer_division")
		Gen2Font.blit_slot(
			_sheet, _sheet.size() / TILE, tile - SHEET_FIRST_TILE,
			into, into_width, at_x, at_y
		)
		return
	font.draw_code(tile, into, into_width, at_x, at_y)
	_invert(into, into_width, at_x, at_y)


## Which of the four loaded footprint tiles a cell names, or -1 for a cell that
## is not one. The numbers are `Pokedex_DrawFootprint`'s own.
func _footprint_slot(tile: int) -> int:
	if _footprint.size() != 4:
		return -1
	if tile == FOOTPRINT_TOP:
		return _footprint[0]
	if tile == FOOTPRINT_TOP + 1:
		return _footprint[1]
	if tile == FOOTPRINT_BOTTOM:
		return _footprint[2]
	if tile == FOOTPRINT_BOTTOM + 1:
		return _footprint[3]
	return -1


## `Pokedex_LoadInvertedFont`'s `xor $ff`, which on a 1bpp tile swaps the two
## indices a pixel can be: 3 is lit and 0 is not (`Serve1bppRequest` writes each
## byte into both planes).
func _invert(into: PackedByteArray, into_width: int, at_x: int, at_y: int) -> void:
	@warning_ignore("integer_division")
	var height: int = into.size() / into_width
	for y: int in TILE:
		var row: int = at_y + y
		if row < 0 or row >= height:
			continue
		for x: int in TILE:
			var column: int = at_x + x
			if column < 0 or column >= into_width:
				continue
			var at: int = row * into_width + column
			into[at] = 0 if into[at] == 3 else 3
