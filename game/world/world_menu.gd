class_name Gen2WorldMenu
extends RefCounted

## Scene-free cursor state for the bounded menu layouts imported from a
## cartridge. The screen owns labels and input; this record owns only the
## source selection rules and the returned option index.

## The two flags that decide selection. [Gen2MenuBox] owns the whole set, since
## it is the layer that reads all of them.
const STATICMENU_ENABLE_LEFT_RIGHT: int = Gen2MenuBox.STATICMENU_ENABLE_LEFT_RIGHT
const STATICMENU_WRAP: int = Gen2MenuBox.STATICMENU_WRAP

## [method Gen2MenuBox.yes_no]'s box. A `choice` pending value carries no
## `loadmenu` header, since `Script_yesorno` never loads one, so this is the
## box every such prompt falls back to.
const YES_NO_LEFT: int = 14
const YES_NO_TOP: int = 7
const YES_NO_RIGHT: int = 19
const YES_NO_BOTTOM: int = 11
## `YesNoMenuHeader.MenuData`'s own flags and its `db "YES@"` / `db "NO@"`. A
## `choice` with no `loadmenu` header is a `Script_yesorno` and inherits these:
## without STATICMENU_CURSOR [Gen2MenuPage] draws no arrow. The runner's own
## keys for the two answers are not what the cartridge prints.
const YES_NO_KEYS: Array = [&"yes", &"no"]
const YES_NO_OPTIONS: Array = ["YES", "NO"]
const YES_NO_FLAGS: int = (
	Gen2MenuBox.STATICMENU_CURSOR | Gen2MenuBox.STATICMENU_NO_TOP_SPACING
)
## `InterpretTwoOptionMenu`'s and `DisplayTwoOptionMenu`'s 15 frames: an answered
## YES/NO stays up, reading no button, before the caller hears it.
const ANSWER_HOLD_FRAMES: int = 15

var kind: StringName = &"vertical"
var options: Array = []
var flags: int = 0
var rows: int = 0
var columns: int = 1
var cursor: int = 0
## `menu_coords x1, y1, x2, y2`, imported off the `LoadMenuHeader` a scripted
## `verticalmenu`/`2dmenu` reads. [const YES_NO_LEFT] and its three siblings
## when there is no such header.
var box_left: int = YES_NO_LEFT
var box_top: int = YES_NO_TOP
var box_right: int = YES_NO_RIGHT
var box_bottom: int = YES_NO_BOTTOM
## `Place2DMenuItemStrings`' own column spacing, a `2d` menu's `db spacing`.
var _spacing: int = 0
## `SCROLLINGMENU_DISPLAY_ARROWS`. No imported `verticalmenu` header carries it:
## every `ScrollingMenu` in the game is opened by a routine rather than by a
## script, and Buena's prize list is the one this runner stages itself.
var scrolling_arrows: bool = false
var _hold: int = 0
var _answered_yes: bool = false


## `YesNoMenuHeader`: YES over NO, opening on YES and wrapping neither way.
static func yes_no() -> Gen2WorldMenu:
	var menu := Gen2WorldMenu.new()
	menu.options = YES_NO_OPTIONS.duplicate()
	menu.flags = YES_NO_FLAGS
	menu.rows = YES_NO_OPTIONS.size()
	return menu


## `_InitVerticalMenuCursor` filters B out under STATICMENU_DISABLE_B.
func takes_b() -> bool:
	return (flags & Gen2MenuBox.STATICMENU_DISABLE_B) == 0


func is_yes_no() -> bool:
	return options == YES_NO_OPTIONS


## One button on a YES/NO, true when it moved or answered: B is NO, and nothing
## is read while the hold runs.
func press_yes_no(button: int) -> bool:
	if _hold > 0:
		return false
	match button:
		PokeButton.UP, PokeButton.DOWN:
			return move(Vector2i(0, 1 if button == PokeButton.DOWN else -1))
		PokeButton.A, PokeButton.B:
			_answered_yes = button == PokeButton.A and cursor == 0
			_hold = ANSWER_HOLD_FRAMES
			return true
	return false


func holding() -> bool:
	return _hold > 0


## True on the answering press, which `MenuClickSound` clicks for.
func just_answered() -> bool:
	return _hold == ANSWER_HOLD_FRAMES


## Spends one frame of the hold, answering true on the frame it ends.
func advance_hold() -> bool:
	if _hold <= 0:
		return false
	_hold -= 1
	return _hold == 0


func answered_yes() -> bool:
	return _answered_yes


static func from_input(input: Dictionary) -> Gen2WorldMenu:
	var menu := Gen2WorldMenu.new()
	var header: Dictionary = input.get("header", {})
	menu.kind = StringName(input.get("menu_kind", header.get("kind", &"vertical")))
	menu.options = input.get(
		"options", input.get("choices", header.get("options", []))
	).duplicate(true)
	if menu.options == YES_NO_KEYS:
		menu.options = YES_NO_OPTIONS.duplicate()
	menu.flags = int(header.get("data_flags", YES_NO_FLAGS))
	menu.rows = maxi(1, int(header.get("rows", menu.options.size())))
	menu.columns = maxi(1, int(header.get("columns", 1)))
	if menu.kind == &"2d":
		menu.rows = maxi(1, int(header.get("rows", menu.rows)))
		menu.columns = maxi(1, int(header.get("columns", menu.columns)))
		menu._spacing = int(header.get("spacing", 0))
	var default_position: int = int(header.get("default", 1)) - 1
	menu.cursor = menu._clamp_position(default_position)
	menu.box_left = int(header.get("left", YES_NO_LEFT))
	menu.box_top = int(header.get("top", YES_NO_TOP))
	menu.box_right = int(header.get("right", YES_NO_RIGHT))
	menu.box_bottom = int(header.get("bottom", YES_NO_BOTTOM))
	menu.scrolling_arrows = bool(header.get("arrows", false))
	return menu


## The box the source's own `menu_coords` puts this menu in, for a renderer
## that draws it over the map the way `MenuBox` does. `Place2DMenuItemStrings`'
## own column count and spacing carry over for a `2d` menu; every list menu
## here is one column with no spacing.
func box() -> Gen2MenuBox:
	var out := Gen2MenuBox.from_coords(box_left, box_top, box_right, box_bottom, flags)
	out.scrolling_arrows = scrolling_arrows
	out.pick_arrows = kind == &"room"
	if kind == &"2d":
		out.columns = maxi(1, columns)
		out.column_spacing = _spacing
	return out


func move(direction: Vector2i) -> bool:
	if options.is_empty():
		return false
	if kind == &"2d":
		return _move_2d(direction)
	if direction.x != 0:
		return false
	if kind == &"room":
		return _move_room(direction.y)
	return _move_vertical(direction.y)


func selected_index() -> int:
	return cursor


func selected_value() -> Variant:
	if cursor < 0 or cursor >= options.size():
		return null
	return options[cursor]


func row() -> int:
	return cursor / columns if columns > 0 else 0


func column() -> int:
	return cursor % columns if columns > 0 else 0


func horizontal_enabled() -> bool:
	return kind == &"2d" or (flags & STATICMENU_ENABLE_LEFT_RIGHT) != 0


## `BattleTowerRoomMenu_UpdatePickLevelMenu`'s `.d_up` and `.d_down`, which run
## the other way round from every other menu here: the index is one-based, `up`
## increments it and restarts at 1 past the last room, and `down` decrements it
## and restarts at the last room past 1. So UP walks L:10 towards CANCEL. Both
## wrap whatever the flags say, since neither branch consults them.
func _move_room(delta: int) -> bool:
	if delta == 0:
		return false
	cursor = posmod(cursor - signi(delta), options.size())
	return true


func _move_vertical(delta: int) -> bool:
	if delta == 0:
		return false
	var next: int = cursor + signi(delta)
	if next < 0 or next >= options.size():
		if (flags & STATICMENU_WRAP) != 0:
			next = options.size() - 1 if next < 0 else 0
		else:
			return false
	cursor = next
	return true


func _move_2d(direction: Vector2i) -> bool:
	var next_row: int = row() + signi(direction.y)
	var next_column: int = column() + signi(direction.x)
	var wraps: bool = (flags & STATICMENU_WRAP) != 0
	if next_row < 0 or next_row >= rows:
		if not wraps:
			return false
		next_row = rows - 1 if next_row < 0 else 0
	if next_column < 0 or next_column >= columns:
		if not wraps:
			return false
		next_column = columns - 1 if next_column < 0 else 0
	var next: int = next_row * columns + next_column
	if next < 0 or next >= options.size():
		return false
	cursor = next
	return true


func _clamp_position(position: int) -> int:
	if options.is_empty():
		return 0
	return clampi(position, 0, options.size() - 1)
