class_name Gen2HallOfFamePage
extends RefCounted

## One Hall of Fame induction panel, on the tile grid the hardware uses.
## Positions are `engine/events/halloffame.asm`'s own: `DisplayHOFMon`'s two text
## boxes, its frontpic at (6,5) and every field row, plus
## `HOF_AnimatePlayerPic`'s name box. `LoadFontsBattleExtra` runs first, so the
## panel prints with the battle-extra strip over $60 to $78. Node-free: the pic
## has its own palette and is composed over the page by the screen.

const TILE: int = Gen2Font.TILE
const COLUMNS: int = 20
const ROWS: int = 18

## DisplayHOFMon: `Textbox` takes the interior, so 18x3 at (0,0) draws 20x5.
const MON_TOP_BOX: Rect2i = Rect2i(0, 0, 20, 5)
const MON_BOTTOM_BOX: Rect2i = Rect2i(0, 12, 20, 6)
const CAPTION: Vector2i = Vector2i(1, 2)
const CAPTION_TEXT: String = "New Hall of Famer!"
## `_HallOfFamePC.DisplayMonAndStrings` draws this instead: `lb bc, 1, 3` over
## `hlcoord 2, 2`, so the words start at column 5. `.HOFMaster` is unreachable,
## needing 201 where `wHallOfFameCount` stops at 200.
const FAMER_TEXT: String = "-Time Famer"
const FAMER_COUNT: Vector2i = Vector2i(2, 2)
const FAMER_DIGITS: int = 3

## `hlcoord 6, 5`, and the pic is seven tiles square.
const PIC_AT: Vector2i = Vector2i(6, 5)
const PIC_TILES: int = 7

## `ld a, '№' / ld [hli], a / ld [hl], '<DOT>'` at `hlcoord 1, 13`, then
## `hlcoord 3, 13` for three digits, leaving column 6 blank before the name.
const DEX_LABEL: Vector2i = Vector2i(1, 13)
const DEX_NUMBER: Vector2i = Vector2i(3, 13)
const DEX_DIGITS: int = 3
const SPECIES_NAME: Vector2i = Vector2i(7, 13)
const GENDER: Vector2i = Vector2i(18, 13)
const NICKNAME_SLASH: Vector2i = Vector2i(8, 14)
## `PrintLevel` writes `<LV>` and the number left-aligned beside it, its
## three-digit branch backing over the `<LV>`.
const LEVEL: Vector2i = Vector2i(1, 16)
## `<ID>`, `№`, `/` at `hlcoord 7, 16`, then five digits at `hlcoord 10, 16`.
const OT_LABEL: Vector2i = Vector2i(7, 16)
const OT_NUMBER: Vector2i = Vector2i(10, 16)
const OT_DIGITS: int = 5

## The codes the panel places directly: `ld [hl], '№'` puts a byte down, and a
## bracketed marker is not something [method Gen2Text.encode] will produce.
const CODE_NUMERO: int = 0x74
const CODE_DOT: int = 0xF2
const CODE_ID: int = 0x73
const CODE_LEVEL: int = 0x6E
const CODE_SLASH: int = 0xF3
## `HALLOFFAME_COLON` copies `FontExtra + 13 tiles`, which is `<COLON>` at $6d,
## over tile $63. Drawn through the main font: the battle-extra strip owns $63.
const CODE_COLON: int = 0x6D

## Everything on a panel is printed with the battle-extra strip loaded.
const FONT: StringName = Gen2Text.FONT_BATTLE_EXTRA

## HOF_AnimatePlayerPic's two `Textbox` calls: a 9x8 interior beside the pic and
## the ordinary bottom box, which it opens empty for `ProfOaksPCRating` to print
## into.
const PLAYER_BOX: Rect2i = Rect2i(0, 2, 11, 10)
const PLAYER_NAME: Vector2i = Vector2i(2, 4)
## `HOF_LoadTrainerFrontpic`, then `PlaceGraphic` at `hlcoord 12, 5`.
const PLAYER_PIC_AT: Vector2i = Vector2i(12, 5)
## `<ID>`, `№`, `/` at `hlcoord 1, 6`, then five digits at `hlcoord 4, 6`.
const PLAYER_ID_LABEL: Vector2i = Vector2i(1, 6)
const PLAYER_ID_NUMBER: Vector2i = Vector2i(4, 6)
const PLAYER_ID_DIGITS: int = 5
## `.PlayTime` at `hlcoord 1, 8`, three hour digits at `hlcoord 3, 9`, the
## `ld [hl], HALLOFFAME_COLON` behind them, and two minute digits.
const PLAY_TIME_LABEL: Vector2i = Vector2i(1, 8)
const PLAY_TIME_TEXT: String = "PLAY TIME"
const PLAY_TIME_HOURS: Vector2i = Vector2i(3, 9)
const PLAY_TIME_HOUR_DIGITS: int = 3
const PLAY_TIME_COLON: Vector2i = Vector2i(6, 9)
const PLAY_TIME_MINUTES: Vector2i = Vector2i(7, 9)
## `PrintText`'s own first line (`hlcoord 1, 14`) and the interior it prints
## into, which is every text box's: one tile of margin each side and two lines
## two rows apart.
const TEXT_AT: Vector2i = Vector2i(1, 14)
const TEXT_COLUMNS: int = MON_BOTTOM_BOX.size.x - 2
const TEXT_ROWS: int = 2
const TEXT_LINE_SPACING: int = 2
## `PrintText`'s own `hlcoord 1, 14` again, over a cleared screen.
const SAVING_AT: Vector2i = Vector2i(1, 14)

## `Textbox` draws with wTextboxFrame, which the in-game OPTION menu's FRAME row
## and the launcher's settings both write, so the panel is drawn in whichever
## frame the player chose rather than always the first.
var frame_style: int = 0

var font: Gen2Font = null


static func from_data(data: GameData) -> Gen2HallOfFamePage:
	var glyphs: Gen2Font = Gen2Font.from_data(data)
	if glyphs == null:
		return null
	var out := Gen2HallOfFamePage.new()
	out.font = glyphs
	out.frame_style = Gen2OptionsStore.current().textbox_frame
	return out


## The whole 160x144 page as palette indices. [param page] is one row of
## [method Gen2HallOfFame.pages].
func draw(page: Dictionary) -> PackedByteArray:
	var indices := PackedByteArray()
	indices.resize(COLUMNS * TILE * ROWS * TILE)
	if font == null:
		return indices
	var kind: StringName = StringName(page.get("kind", &""))
	if kind == Gen2HallOfFame.PAGE_SAVING:
		_draw_saving(page, indices)
	elif kind == Gen2HallOfFame.PAGE_PLAYER:
		_draw_player(page, indices)
	else:
		_draw_mon(page, indices)
	return indices


## Where the screen puts the front pic, in pixels.
static func pic_position() -> Vector2i:
	return PIC_AT * TILE


static func pic_size() -> int:
	return PIC_TILES * TILE


## Where the screen puts the player's own front pic, in pixels.
static func player_pic_position() -> Vector2i:
	return PLAYER_PIC_AT * TILE


func _draw_mon(page: Dictionary, indices: PackedByteArray) -> void:
	var width: int = COLUMNS * TILE
	_box(indices, width, MON_TOP_BOX)
	_box(indices, width, MON_BOTTOM_BOX)
	if page.has("win_count"):
		_text(indices, width, "%*d%s" % [
			FAMER_DIGITS, int(page["win_count"]), FAMER_TEXT,
		], FAMER_COUNT)
	else:
		_text(indices, width, CAPTION_TEXT, CAPTION)

	_code(indices, width, CODE_NUMERO, DEX_LABEL)
	_code(indices, width, CODE_DOT, DEX_LABEL + Vector2i(1, 0))
	## PRINTNUM_LEADINGZEROS, so a two-digit dex number keeps its column.
	_text(indices, width, "%0*d" % [DEX_DIGITS, int(page.get("dex_number", 0))], DEX_NUMBER)
	_text(indices, width, String(page.get("species_name", "")), SPECIES_NAME)
	_text(indices, width, _gender_glyph(StringName(page.get("gender", &""))), GENDER)

	_code(indices, width, CODE_SLASH, NICKNAME_SLASH)
	_text(indices, width, String(page.get("nickname", "")), NICKNAME_SLASH + Vector2i(1, 0))

	## PRINTNUM_LEFTALIGN, so the digits start against the symbol rather than
	## being padded out to the field's width.
	var level: int = int(page.get("level", 0))
	var level_at: Vector2i = LEVEL
	if Gen2Font.level_glyph_shown(level):
		_code(indices, width, CODE_LEVEL, LEVEL)
		level_at += Vector2i(1, 0)
	_text(indices, width, str(level), level_at)

	_code(indices, width, CODE_ID, OT_LABEL)
	_code(indices, width, CODE_NUMERO, OT_LABEL + Vector2i(1, 0))
	_code(indices, width, CODE_SLASH, OT_LABEL + Vector2i(2, 0))
	_text(indices, width, "%0*d" % [OT_DIGITS, int(page.get("ot_id", 0))], OT_NUMBER)


## `HOF_AnimatePlayerPic`'s two boxes. The picture is the screen's, as a mon
## panel's is.
func _draw_player(page: Dictionary, indices: PackedByteArray) -> void:
	var width: int = COLUMNS * TILE
	_box(indices, width, PLAYER_BOX)
	_box(indices, width, MON_BOTTOM_BOX)
	_text(indices, width, String(page.get("player_name", "")), PLAYER_NAME)
	_code(indices, width, CODE_ID, PLAYER_ID_LABEL)
	_code(indices, width, CODE_NUMERO, PLAYER_ID_LABEL + Vector2i(1, 0))
	_code(indices, width, CODE_SLASH, PLAYER_ID_LABEL + Vector2i(2, 0))
	_text(indices, width, "%0*d" % [
		PLAYER_ID_DIGITS, int(page.get("player_id", 0)),
	], PLAYER_ID_NUMBER)
	_text(indices, width, PLAY_TIME_TEXT, PLAY_TIME_LABEL)
	_text(indices, width, "%*d" % [
		PLAY_TIME_HOUR_DIGITS, int(page.get("hours", 0)),
	], PLAY_TIME_HOURS)
	font.draw_code(
		CODE_COLON, indices, width,
		PLAY_TIME_COLON.x * TILE, PLAY_TIME_COLON.y * TILE, Gen2Text.FONT_MAIN
	)
	_text(indices, width, String(page.get("minutes", "")), PLAY_TIME_MINUTES)
	var lines: Array = page.get("lines", [])
	for index: int in lines.size():
		_text(
			indices, width, String(lines[index]),
			TEXT_AT + Vector2i(0, index * TEXT_LINE_SPACING)
		)


## `InitDisplayForHallOfFame`: no box, since it prints into a cleared tilemap.
func _draw_saving(page: Dictionary, indices: PackedByteArray) -> void:
	var lines: Array = page.get("lines", [])
	for index: int in lines.size():
		_text(
			indices, COLUMNS * TILE, String(lines[index]),
			SAVING_AT + Vector2i(0, index * TEXT_LINE_SPACING)
		)


## GetGender answers one of three, and the source prints a space for a
## genderless Pokémon rather than a symbol.
func _gender_glyph(gender: StringName) -> String:
	if gender == Gen2BattleMon.GENDER_MALE:
		return "♂"
	if gender == Gen2BattleMon.GENDER_FEMALE:
		return "♀"
	return " "


func _box(indices: PackedByteArray, width: int, box: Rect2i) -> void:
	font.draw_box(
		frame_style, indices, width,
		box.position.x * TILE, box.position.y * TILE, box.size.x, box.size.y
	)


func _text(indices: PackedByteArray, width: int, text: String, at: Vector2i) -> void:
	font.draw_text(text, indices, width, at.x * TILE, at.y * TILE, FONT)


## One glyph placed by its code, which is what `ld [hl], '№'` does.
func _code(indices: PackedByteArray, width: int, code: int, at: Vector2i) -> void:
	font.draw_code(code, indices, width, at.x * TILE, at.y * TILE, FONT)
