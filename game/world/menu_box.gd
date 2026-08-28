class_name Gen2MenuBox
extends RefCounted

## Every cartridge menu's geometry: `menu_coords`' four corners,
## `GetMenuBoxDims`, `GetMenuTextStartCoord` and the cursor position
## `_InitVerticalMenuCursor` derives from them. Scene-free arithmetic on the tile
## grid, so a layout can be checked without drawing it. [Gen2MenuPage] draws what
## this places and [Gen2WorldMenu] owns the selection rules.

## constants/menu_constants.asm, owned here because this layer reads all of them.
const STATICMENU_DISABLE_B: int = 1 << 0
const STATICMENU_ENABLE_SELECT: int = 1 << 1
const STATICMENU_ENABLE_LEFT_RIGHT: int = 1 << 2
const STATICMENU_ENABLE_START: int = 1 << 3
const STATICMENU_PLACE_TITLE: int = 1 << 4
const STATICMENU_WRAP: int = 1 << 5
## `ScrollingMenu_UpdateDisplay` reaches its first row with `ld bc, SCREEN_WIDTH
## + 1` where `_InitVerticalMenuCursor` spends a second row: every scrolling menu
## carries this flag and no vertical one does.
const STATICMENU_NO_TOP_SPACING: int = 1 << 6
const STATICMENU_CURSOR: int = 1 << 7

## `_InitVerticalMenuCursor`'s `ln a, 2, 0`: two rows per item and no columns,
## which is why `PlaceVerticalMenuItems` advances by `2 * SCREEN_WIDTH`.
const ROW_STEP: int = 2

## `menu_coords x1, y1, x2, y2`, which stores `db y1, x1` then `db y2, x2`.
var left: int = 0
var top: int = 0
var right: int = 0
var bottom: int = 0
var flags: int = 0
## `dn rows, columns` and its `db spacing` (`Place2DMenuItemStrings`). One column
## and no spacing is `PlaceVerticalMenuItems`, which is every list menu here.
var columns: int = 1
var column_spacing: int = 0
## `w2DMenuCursorOffsets`' high nybble, which is `ROW_STEP` for every menu built
## from a header and one for `MoveSelectionScreen`'s own hand-built list.
var row_step: int = ROW_STEP
## `SCROLLINGMENU_DISPLAY_ARROWS` and `wMenuScrollPosition`, which
## `ScrollingMenu_UpdateDisplay` reads together: `▼` at the box's bottom-right
## whenever the flag is set, and `▲` at its top-right only past the first row.
## A field of its own rather than a bit in [member flags], because the source's
## one flags byte is read as `STATICMENU_*` by `VerticalMenu` and as
## `SCROLLINGMENU_*` by `ScrollingMenu`, and the two sets overlap.
var scrolling_arrows: bool = false
var scroll: int = 0
## The frame a caller drew before the menu, `ScrollingMenu` drawing none. Empty
## is every other menu, whose frame is its own corners.
var frame: Rect2i = Rect2i()
## `BattleTowerRoomMenu_UpdatePickLevelMenu`, the one menu in the game that
## shows a single row between two arrows instead of a list under a cursor. Both
## are the `▼` of `String_119d07`, placed at `hlcoord 13, 8` and `hlcoord 13,
## 10`; the upper one is the same tile with the attrmap's own $40, which is the
## BG map's vertical flip.
var pick_arrows: bool = false



## `YesNoBox`'s own `lb bc, SCREEN_WIDTH - 6, 7`, which `_YesNoBox` turns into
## the five-wide, four-tall box at (14, 7). Every YES/NO in the game is this one.
static func yes_no() -> Gen2MenuBox:
	return from_coords(
		14, 7, 19, 11, STATICMENU_CURSOR | STATICMENU_NO_TOP_SPACING
	)


static func from_coords(x1: int, y1: int, x2: int, y2: int, menu_flags: int) -> Gen2MenuBox:
	var box := Gen2MenuBox.new()
	box.left = x1
	box.top = y1
	box.right = x2
	box.bottom = y2
	box.flags = menu_flags
	return box


func has_flag(flag: int) -> bool:
	return (flags & flag) != 0


## `GetMenuBoxDims`, the span between the corners. `MenuBox` decrements both
## before `Textbox`, so this is the interior plus one on each axis.
func dims() -> Vector2i:
	return Vector2i(right - left, bottom - top)


## What `Textbox` is asked for: the interior, in tiles.
func interior() -> Vector2i:
	return dims() - Vector2i.ONE


## The drawn frame, or [member frame] where the caller drew one of its own.
func border_size() -> Vector2i:
	return frame.size if frame.size.x > 0 else interior() + Vector2i(2, 2)


func border_position() -> Vector2i:
	return frame.position if frame.size.x > 0 else Vector2i(left, top)


## `GetMenuTextStartCoord`: one in from the top-left corner, one row further
## down unless STATICMENU_NO_TOP_SPACING, and one column further right when
## there is a cursor to leave room for.
func text_start() -> Vector2i:
	var at := Vector2i(left + 1, top + 1)
	if not has_flag(STATICMENU_NO_TOP_SPACING):
		at.y += 1
	if has_flag(STATICMENU_CURSOR):
		at.x += 1
	return at


## `_InitVerticalMenuCursor`'s init coords, one column left of the text. The
## source writes `wMenuBorderLeftCoord + 1` outright rather than subtracting, so
## a menu without STATICMENU_CURSOR has a position here and never draws one.
func cursor_start() -> Vector2i:
	return Vector2i(left + 1, text_start().y)


## Zero-based. `Place2DMenuItemStrings` walks a row's columns before moving on.
func item_position(index: int) -> Vector2i:
	return text_start() + _item_offset(index)


## Where the cursor sits for item [param index], zero-based.
func cursor_position(index: int) -> Vector2i:
	return cursor_start() + _item_offset(index)


func _item_offset(index: int) -> Vector2i:
	var per_row: int = maxi(1, columns)
	return Vector2i(
		(index % per_row) * column_spacing, (index / per_row) * row_step
	)


## `PlaceMenuStrings`' title: the top row, indented by the byte after the items.
func title_position(indent: int) -> Vector2i:
	return Vector2i(left + indent, top)
