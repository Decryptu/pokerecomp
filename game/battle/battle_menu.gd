class_name Gen2BattleMenu
extends RefCounted

## `BattleMenu`'s FIGHT/PKMN/PACK/RUN and `MoveSelectionScreen`'s move list
## (`engine/battle/core.asm`, `engine/battle/menu.asm`), scene-free: the rows
## and cursor rules are here, the battle screen owns the presses and drawing.

## `wBattleMenuCursorPosition`, which `BattleMenu.next` compares against: the
## menu's own 1-based position, counted along the rows.
const FIGHT: int = 1
const PKMN: int = 2
const PACK: int = 3
const RUN: int = 4

## `BattleMenuHeader`: `menu_coords 8, 12, SCREEN_WIDTH - 1, SCREEN_HEIGHT - 1`,
## `STATICMENU_CURSOR | STATICMENU_DISABLE_B`, `dn 2, 2` and `db 6`. No
## STATICMENU_WRAP, so neither axis wraps (`_2DMenuInterpretJoypad`).
const MAIN_LEFT: int = 8
const MAIN_TOP: int = 12
const MAIN_RIGHT: int = 19
const MAIN_BOTTOM: int = 17
const MAIN_ROWS: int = 2
const MAIN_COLUMNS: int = 2
const MAIN_SPACING: int = 6
const MAIN_FLAGS: int = Gen2MenuBox.STATICMENU_CURSOR | Gen2MenuBox.STATICMENU_DISABLE_B
## `.Text`, in its own order. `<PKMN>` is charmap's $4a, one byte the printer
## expands to those four letters, so the four tiles are what is written here.
const MAIN_OPTIONS: Array[String] = ["FIGHT", "PKMN", "PACK", "RUN"]
## `BattleMenuText`, the same box in the same order: the bag is spelled ITEM and
## `<PK><MN>` is two narrow tiles where Crystal's one byte spells four letters.
const GEN1_MAIN_OPTIONS: Array[String] = ["FIGHT", "<PKMN>", "ITEM", "RUN"]

## `MoveSelectionScreen`'s own `Textbox` rather than a menu header:
## `hlcoord 4, 17 - NUM_MOVES - 1` with `b, 4` and `c, 14`, its list placed from
## `hlcoord 6, 17 - NUM_MOVES` with `wListMovesLineSpacing` one whole row, and
## its cursor started at `w2DMenuCursorInitX` 5. That is the same box with
## STATICMENU_NO_TOP_SPACING and a row step of one.
const MOVE_LEFT: int = 4
const MOVE_TOP: int = 12
const MOVE_RIGHT: int = 19
const MOVE_BOTTOM: int = 17
const MOVE_FLAGS: int = Gen2MenuBox.STATICMENU_CURSOR \
	| Gen2MenuBox.STATICMENU_NO_TOP_SPACING
## `w2DMenuFlags1` is written `STATICMENU_ENABLE_LEFT_RIGHT | ENABLE_START |
## WRAP` outright, so unlike the menu above this list wraps top to bottom.
const MOVE_WRAPS: bool = true

## `MoveInfoBox`: `hlcoord 0, 8` with `b, 3` and `c, 9`, "TYPE/" at (1,9), the
## type name at (2,10) and the PP pair at (5,11) either side of a '/' at (7,11).
const INFO_LEFT: int = 0
const INFO_TOP: int = 8
const INFO_RIGHT: int = 10
const INFO_BOTTOM: int = 12
const INFO_TYPE_LABEL_AT := Vector2i(1, 9)
const INFO_TYPE_AT := Vector2i(2, 10)
const INFO_PP_AT := Vector2i(5, 11)
const INFO_TYPE_LABEL: String = "TYPE/"
## `MoveInfoBox`' own `.Disabled`, printed at (1,10) in place of the type and PP
## while the cursor is on the disabled slot.
const INFO_DISABLED_AT := Vector2i(1, 10)
const INFO_DISABLED: String = "Disabled!"

## The level-up stats box `.skip_exp_bar_animation` draws over the upper screen:
## `hlcoord 9, 0` with `ld b, 10` and `ld c, 9`, then `PrintTempMonStats` at
## `hlcoord 11, 1` with a spacing of four. No options and no cursor; the ten
## strings are [method Gen2StatsScreenPage.stats_placements].
const LEVEL_UP_LEFT: int = 9
const LEVEL_UP_TOP: int = 0
const LEVEL_UP_RIGHT: int = 19
const LEVEL_UP_BOTTOM: int = 11
const LEVEL_UP_STATS_AT := Vector2i(11, 1)
const LEVEL_UP_STATS_SPACING: int = 4
## `PrintStatsBox`'s LEVEL_UP_STATS_BOX: `hlcoord 9, 2`, `lb bc, 8, 9`, names at 11, 3.
const GEN1_LEVEL_UP_TOP: int = 2
const GEN1_LEVEL_UP_STATS_AT := Vector2i(11, 3)
const GEN1_LEVEL_UP_STAT_NAMES: Array[String] = ["ATTACK", "DEFENSE", "SPEED", "SPECIAL"]
const GEN1_LEVEL_UP_STAT_KEYS: Array[String] = ["attack", "defense", "speed", "sp_attack"]

## `.use_move`'s two refusals, which it prints over the list and then reopens
## it behind: `BattleText_TheresNoPPLeftForThisMove` and `..._TheMoveIsDisabled`.
const NO_PP: StringName = &"BattleText_TheresNoPPLeftForThisMove"
const DISABLED: StringName = &"BattleText_TheMoveIsDisabled"


## `ContestBattleMenuHeader`: the same two-by-two four columns further left, with
## twelve of spacing, and PARKBALL where PACK is. Its ball count is printed by
## the header's own `.PrintParkBallsRemaining` at (13,16) rather than as part of
## the row.
const CONTEST_LEFT: int = 2
const CONTEST_SPACING: int = 12
const CONTEST_OPTIONS: Array[String] = ["FIGHT", "PKMN", "PARKBALL×", "RUN"]
const CONTEST_BALLS_AT := Vector2i(13, 16)

## `text_box_text SAFARI_BATTLE_MENU_TEMPLATE, 0, 12, 19, 17, ..., 2, 14`, with
## `.safariLeftColumn`'s own count beside the first row.
const SAFARI_LEFT: int = 0
const SAFARI_BALLS_AT := Vector2i(7, 14)


static func safari_box() -> Gen2MenuBox:
	var box: Gen2MenuBox = Gen2MenuBox.from_coords(
		SAFARI_LEFT, MAIN_TOP, MAIN_RIGHT, MAIN_BOTTOM, MAIN_FLAGS
	)
	box.columns = MAIN_COLUMNS
	box.column_spacing = Gen1Layout.SAFARI_MENU_COLUMN
	return box


## `SafariZoneBattleMenuText`'s two rows split at the second word's own column.
static func safari_options(top: String, bottom: String) -> Array[String]:
	var out: Array[String] = []
	for row: String in [top, bottom]:
		for column: int in MAIN_COLUMNS:
			out.append(row.substr(
				column * Gen1Layout.SAFARI_MENU_COLUMN, Gen1Layout.SAFARI_MENU_COLUMN
			).rstrip(" "))
	return out


static func main_box(contest: bool = false) -> Gen2MenuBox:
	var box: Gen2MenuBox = Gen2MenuBox.from_coords(
		CONTEST_LEFT if contest else MAIN_LEFT,
		MAIN_TOP, MAIN_RIGHT, MAIN_BOTTOM, MAIN_FLAGS
	)
	box.columns = MAIN_COLUMNS
	box.column_spacing = CONTEST_SPACING if contest else MAIN_SPACING
	return box


static func main_options(
	contest: bool = false, generation: int = RomRegistry.GEN2
) -> Array[String]:
	if contest:
		return CONTEST_OPTIONS.duplicate()
	return GEN1_MAIN_OPTIONS.duplicate() if generation == RomRegistry.GEN1 \
		else MAIN_OPTIONS.duplicate()


## `MoveSelectionMenu`, whose `.regularmenu` box is `hlcoord 4, 12` fourteen
## wide and so is Crystal's. [param relearn] is `wMoveMenuType` 2, the one
## `ItemUsePPRestore` opens six rows higher with no PP beside the names.
static func move_box(relearn: bool = false) -> Gen2MenuBox:
	var box: Gen2MenuBox = Gen2MenuBox.from_coords(
		MOVE_LEFT, MOVE_TOP - (RELEARN_RISE if relearn else 0),
		MOVE_RIGHT, MOVE_BOTTOM - (RELEARN_RISE if relearn else 0), MOVE_FLAGS
	)
	box.row_step = 1
	return box


static func info_box() -> Gen2MenuBox:
	return Gen2MenuBox.from_coords(
		INFO_LEFT, INFO_TOP, INFO_RIGHT, INFO_BOTTOM, 0
	)


static func level_up_box(gen1: bool = false) -> Gen2MenuBox:
	return Gen2MenuBox.from_coords(
		LEVEL_UP_LEFT, GEN1_LEVEL_UP_TOP if gen1 else LEVEL_UP_TOP,
		LEVEL_UP_RIGHT, LEVEL_UP_BOTTOM, 0
	)


static func level_up_placements(stats: Dictionary, gen1: bool = false) -> Array:
	if not gen1:
		return Gen2StatsScreenPage.stats_placements(
			LEVEL_UP_STATS_AT, stats, LEVEL_UP_STATS_SPACING
		)
	var out: Array = []
	for index: int in GEN1_LEVEL_UP_STAT_NAMES.size():
		var at: Vector2i = GEN1_LEVEL_UP_STATS_AT \
			+ Vector2i(0, index * Gen2StatsScreenPage.STAT_ROW_STEP)
		out.append({"text": GEN1_LEVEL_UP_STAT_NAMES[index], "at": at})
		out.append({
			"text": str(int(stats.get(GEN1_LEVEL_UP_STAT_KEYS[index], 0))).lpad(
				Gen2StatsScreenPage.STAT_DIGITS
			),
			"at": at + Vector2i(LEVEL_UP_STATS_SPACING, 1),
		})
	return out


## `ForgetMove`'s own list, drawn over the field while `MoveAskForgetText` stands
## in the text box below it: `hlcoord 5, 2` with `b, NUM_MOVES * 2` and
## `c, MOVE_NAME_LENGTH`, its rows placed from `hlcoord 5 + 2, 2 + 2` a whole two
## rows apart, and `w2DMenuFlags1` $20, which is STATICMENU_WRAP alone.
const FORGET_LEFT: int = 5
const FORGET_TOP: int = 2
const FORGET_RIGHT: int = 19
const FORGET_BOTTOM: int = 11
const FORGET_FLAGS: int = Gen2MenuBox.STATICMENU_CURSOR | Gen2MenuBox.STATICMENU_WRAP

## The pack, the balls and the move an Ether goes on. `BattleMenu_Pack` opens
## `Pack`'s four pockets; the battle here is handed the flat list, drawn full
## width with `ScrollingMenu`'s arrows and `UpdateItemDescription`'s box below.
const LIST_LEFT: int = 0
const LIST_TOP: int = 2
const LIST_RIGHT: int = 19
const LIST_BOTTOM: int = 11
const LIST_ROWS: int = 4
const LIST_FLAGS: int = FORGET_FLAGS
## How far `.relearnmenu` sits above `.regularmenu`: `hlcoord 4, 7` against
## `hlcoord 4, 12`.
const RELEARN_RISE: int = 5
## How many columns a row has, from [method Gen2MenuBox.text_start] to the frame
## on the right.
const LIST_TEXT_WIDTH: int = LIST_RIGHT - LIST_LEFT - 2


## Generation 1's `LearnMove` frames its list at `hlcoord 4, 7`, single-spaced,
## which is `.relearnmenu`'s box.
static func forget_box(gen1: bool = false) -> Gen2MenuBox:
	if gen1:
		return move_box(true)
	return Gen2MenuBox.from_coords(
		FORGET_LEFT, FORGET_TOP, FORGET_RIGHT, FORGET_BOTTOM, FORGET_FLAGS
	)


## [param scroll] is `wMenuScrollPosition` over [param count] rows, none of
## them a CANCEL row.
static func list_box(scroll: int = 0, count: int = 0) -> Gen2MenuBox:
	var box: Gen2MenuBox = Gen2MenuBox.from_coords(
		LIST_LEFT, LIST_TOP, LIST_RIGHT, LIST_BOTTOM, LIST_FLAGS
	)
	if count > LIST_ROWS:
		box.show_scroll(scroll, count - 1, LIST_ROWS)
	return box


## `wMenuScrollPosition` after a cursor move: the window travels the least that
## keeps the cursor inside it, which is what `ScrollingMenu`'s own clamp does.
static func list_scrolled(
	scroll: int, cursor: int, count: int, rows: int = LIST_ROWS
) -> int:
	var last: int = maxi(count - rows, 0)
	return clampi(clampi(scroll, cursor - rows + 1, cursor), 0, last)


## `_2DMenuInterpretJoypad` over the main menu's own two-by-two: a press that
## would leave the grid is ignored, since it sets no wrap flag and no exit one.
## [param position] and the answer are `wBattleMenuCursorPosition`.
static func main_moved(position: int, button: int) -> int:
	var index: int = clampi(position, FIGHT, RUN) - 1
	var column: int = index % MAIN_COLUMNS
	var row: int = index / MAIN_COLUMNS
	match button:
		PokeButton.LEFT:
			column = maxi(0, column - 1)
		PokeButton.RIGHT:
			column = mini(MAIN_COLUMNS - 1, column + 1)
		PokeButton.UP:
			row = maxi(0, row - 1)
		PokeButton.DOWN:
			row = mini(MAIN_ROWS - 1, row + 1)
	return row * MAIN_COLUMNS + column + 1


## `ListMoves`' rows for the Pokemon that is out: the move name, its own PP pair
## and whether the slot can be chosen at all. `wNumMoves` is the row count, so a
## Pokemon with two moves has a two-row list rather than four with dashes: the
## dashes are the party summary's, which lists a fixed four.
static func move_rows(mon: Gen2BattleMon, data: GameData) -> Array:
	var out: Array = []
	if mon == null or data == null:
		return out
	for slot: int in mon.moves.size():
		var number: int = int(mon.moves[slot])
		if number <= 0:
			continue
		var record: Dictionary = data.move(number)
		out.append({
			"slot": slot,
			"move": number,
			"name": String(record.get("name", "")),
			"type": int(record.get("type", 0)),
			"pp": mon.pp_left(slot),
			"max_pp": mon.max_pp(slot),
			"disabled": slot == mon.disabled_slot,
		})
	return out


## The cursor after [param button], zero-based over [param rows]. Wraps both
## ways, which is the flag `MoveSelectionScreen` writes.
static func move_cursor_moved(cursor: int, button: int, rows: int) -> int:
	if rows <= 0:
		return 0
	match button:
		PokeButton.UP:
			return (cursor + rows - 1) % rows
		PokeButton.DOWN:
			return (cursor + 1) % rows
	return clampi(cursor, 0, rows - 1)


## `.use_move`'s refusals in its order, no PP first; empty for a row that may
## be chosen.
static func refusal_for(row: Dictionary) -> StringName:
	if int(row.get("pp", 0)) <= 0:
		return NO_PP
	if bool(row.get("disabled", false)):
		return DISABLED
	return &""
