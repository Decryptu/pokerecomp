class_name Gen2PartyMenuPage
extends RefCounted

## The party menu as the hardware draws it: `WritePartyMenuTilemap`'s
## `PARTYMENUACTION_SWITCH` quality set plus `PlacePartyMenuText`.
## `SetUpBattlePartyMenu` clears the battle off the screen, so the page is the
## whole 160x144 rather than a box over the field, and each quality steps two rows
## per member because `PartyMenu2DMenuData`'s cursor offset is `dn 2, 0`.
## [Gen2BattleSwitchMenu] owns the rows and the cursor. The one thing this owns is
## `InitPartyMenuGFX`'s icons, whose sprite anim structs are per-frame state. A row
## carrying `egg` is `PartyMenuCheckEgg`'s and only the overworld menu shows one.

const TILE: int = Gen2Font.TILE

## `hlcoord` columns and the first row of each quality, from
## `PlacePartyNicknames`, `PlacePartyHPBar`, `PlacePartyMenuHPDigits`,
## `PlacePartyMonLevel` and `PlacePartyMonStatus`.
const NICKNAME: Vector2i = Vector2i(3, 1)
const HP_BAR: Vector2i = Vector2i(11, 2)
const HP_DIGITS: Vector2i = Vector2i(13, 1)
const LEVEL: Vector2i = Vector2i(8, 2)
const STATUS: Vector2i = Vector2i(5, 2)
## `PlacePartyMonTMHMCompatibility`, `PlacePartyMonEvoStoneCompatibility` and
## `PlacePartyMonGender` all print at `hlcoord 12, 2`, over the HP bar's column.
const QUALITY: Vector2i = Vector2i(12, 2)

## `PlacePartyNicknames.end` steps back two columns from the row below the last
## nickname, which is where CANCEL prints.
const CANCEL_COLUMN: int = NICKNAME.x - 2

## `Place2DMenuCursor`'s column, `PartyMenu2DMenuData`'s `db 1, 0`.
const CURSOR_COLUMN: int = 0

## `charmap.asm`: `"▷"` is $ec, which `SwitchPartyMons` writes at
## `hlcoord 0, 1` over the row of the member being moved.
const HELD_CODE: int = 0xEC

## Rows per member, `dn 2, 0`.
const ROW_STEP: int = 2

## `PlacePartyMenuText`: `hlcoord 0, 14` with `lb bc, 2, 18`, so the frame spans
## the full width and four rows, and the string prints at `hlcoord 1, 16`.
const TEXTBOX: Vector2i = Vector2i(0, 14)
const TEXTBOX_COLUMNS: int = 20
const TEXTBOX_ROWS: int = 4
const PROMPT: Vector2i = Vector2i(1, 16)

## Both HP numbers print through `PrintNum` three digits wide, space padded.
const HP_NUMBER_DIGITS: int = 3

## `.string_able`/`.string_not_able`, shared by the TM/HM and stone columns, and
## `PlacePartyMonGender`'s own three.
const ABLE: String = "ABLE"
const NOT_ABLE: String = "NOT ABLE"
const GENDER_STRINGS: Dictionary = {
	Gen2BattleMon.GENDER_MALE: "♂…MALE",
	Gen2BattleMon.GENDER_FEMALE: "♀…FEMALE",
}
const GENDER_UNKNOWN: String = "…UNKNOWN"

## Shadow OAM's own origin, which every sprite here is placed through.
const OAM_ORIGIN := Vector2i(8, 16)

## `InitPartyMenuIcon`'s spawn: `add $1c` over the slot number shifted four, and
## `ld e, $10`. The icon is the four `.OAMData_RedWalk` tiles at (-8,-8) from
## there, so its top-left corner is the coordinate less a tile and the origin.
const ICON_FIRST_Y: int = 0x1C
const ICON_ROW_STEP: int = 16
const ICON_TILE: int = Gen2Font.TILE

## `SpriteAnimFunc_PartyMon`'s two columns: `8 * 2` for a row the cursor is not
## on and `8 * 3` for the one it is, which is what frees column 0 for the arrow.
const ICON_X: int = 8 * 2
const ICON_SELECTED_X: int = 8 * 3

## `.Frameset_PartyMon`: two OAM sets of eight, which is nine passes each
## (`GetSpriteAnimFrame` returns the entry on the pass that loads the duration
## too), then `oamrestart`. The second set is the same four tiles four on.
const ICON_FRAME_DURATION: int = 8
const ICON_FRAMES: int = 2
const ICON_FRAME_TILES: int = 4

## `SetPartyMonIconAnimSpeed`'s `.speeds`, added to every frame's duration, and
## the same byte rotated twice into VAR2. A hurt Pokémon's icon steps and bobs
## more slowly; a red one does neither.
const ICON_SPEEDS: Array[int] = [0x00, 0x40, 0x80]
const ICON_BOBS: Array[int] = [-2, -1, 0]

## `.SpawnItemIcon`'s marker over the icon's own bottom-left one, which is
## `HeldItemIcons`' first tile for a held mail ($08 in
## `.OAMData_PartyMonWithMail1`) and its second for anything else ($09).
const ICON_ITEM_TILE: int = Gen2Layout.HELD_ITEM_ICON_ITEM
const ICON_MAIL_TILE: int = Gen2Layout.HELD_ITEM_ICON_MAIL
const ICON_ITEM_QUADRANT: int = 2

## Generation 1's own columns and first rows, from `DrawPartyMenu_`: the
## nickname at `hlcoord 3, 0`, `PrintLevel` ten columns on and
## `PrintStatusCondition` fourteen, with `DrawHPBar` a row below at
## `hlcoord 4, 1` and `DrawHP2`'s fraction nine columns past the bar's own left
## end. `ErasePartyMenuCursors` walks `hlcoord 0, 1` two rows at a time, so the
## arrow stands beside the bar rather than the nickname, and there is no CANCEL
## row: `PartyMenuInit` stops the list at `wPartyCount - 1` and B is the way out.
const GEN1_NICKNAME: Vector2i = Vector2i(3, 0)
const GEN1_LEVEL: Vector2i = Vector2i(13, 0)
const GEN1_STATUS: Vector2i = Vector2i(17, 0)
const GEN1_HP_BAR: Vector2i = Vector2i(4, 1)
const GEN1_HP_DIGITS: Vector2i = Vector2i(13, 1)
const GEN1_CURSOR_ROW: int = 1
## `MESSAGE_BOX` in `data/text_boxes.asm` and `PrintText`'s own `bccoord 1, 14`.
const GEN1_TEXTBOX: Vector2i = Vector2i(0, 12)
const GEN1_TEXTBOX_ROWS: int = 6
const GEN1_PROMPT: Vector2i = Vector2i(1, 14)
## `WriteMonPartySpriteOAM`: X is `$10` flat and Y the slot shifted four with
## `$10` added, and both name the block's top-left rather than a centre.
const GEN1_ICON_AT: Vector2i = Vector2i(0x10, 0x10)
## `PartyMonSpeeds` with `wOnSGB` set, the V-blanks one frame lasts on a green,
## yellow and red bar. Crystal's row is added to a duration; this one is it.
const GEN1_ICON_SPEEDS: Array[int] = [5, 16, 32]

## `PlaceStatusString`'s three-letter strings, in the order
## `PlaceNonFaintStatus` tests them. FNT comes first because
## `PlaceStatusString` checks the health before it ever looks at the byte.
const STATUS_STRINGS: Dictionary = {
	&"poison": "PSN", &"burn": "BRN", &"freeze": "FRZ",
	&"paralysis": "PAR", &"sleep": "SLP",
}
const FAINTED_STRING: String = "FNT"

var font: Gen2Font = null
var hud: Gen2BattleHud = null
var data: GameData = null

## Read through the instance so one drawing routine serves both generations,
## the way [Gen2BattleTiles] carries its own tile numbers.
var gen1: bool = false
var nickname_at: Vector2i = NICKNAME
var hp_bar_at: Vector2i = HP_BAR
var hp_digits_at: Vector2i = HP_DIGITS
var level_at: Vector2i = LEVEL
var status_at: Vector2i = STATUS
var quality_at: Vector2i = QUALITY
var cursor_row: int = NICKNAME.y
var textbox_at: Vector2i = TEXTBOX
var textbox_rows: int = TEXTBOX_ROWS
var prompt_at: Vector2i = PROMPT

## `wAnimCounter` and the `wCurrentMenuItem` its reset is keyed on, which
## Generation 1 keeps for the whole menu rather than one per icon.
var _gen1_counter: int = 0
var _gen1_cursor: int = -1

## One sprite anim struct per member, in party order:
## `{icon, item, speed, frame, duration, var1, x, y_offset}`. Empty until
## [method advance] has been given rows to build it from.
var _icons: Array = []

## `Textbox` draws with wTextboxFrame, so the bottom box wears whichever frame
## the player chose, as every other box here does.
var frame_style: int = 0


## `PlacePartyMonGender`, whose `.unknown` is `GetGender`'s carry.
static func gender_quality(gender: StringName) -> String:
	return String(GENDER_STRINGS.get(gender, GENDER_UNKNOWN))


static func able_quality(able: bool) -> String:
	return ABLE if able else NOT_ABLE


static func from_data(source: GameData) -> Gen2PartyMenuPage:
	var glyphs: Gen2Font = Gen2Font.from_data(source)
	var panels: Gen2BattleHud = Gen2BattleHud.from_data(source)
	if glyphs == null or panels == null:
		return null
	var out := Gen2PartyMenuPage.new()
	out.font = glyphs
	out.hud = panels
	out.data = source
	out.frame_style = Gen2OptionsStore.current().textbox_frame
	if source.generation == RomRegistry.GEN1:
		out._use_gen1_layout()
	return out


func _use_gen1_layout() -> void:
	gen1 = true
	nickname_at = GEN1_NICKNAME
	hp_bar_at = GEN1_HP_BAR
	hp_digits_at = GEN1_HP_DIGITS
	level_at = GEN1_LEVEL
	status_at = GEN1_STATUS
	## `.teachMoveMenu` and `.evolutionStoneMenu` both print at the nickname's
	## own `SCREEN_WIDTH + 9`, which is where `PlacePartyMonTMHMCompatibility`
	## prints too.
	quality_at = GEN1_NICKNAME + QUALITY - NICKNAME
	cursor_row = GEN1_CURSOR_ROW
	textbox_at = GEN1_TEXTBOX
	textbox_rows = GEN1_TEXTBOX_ROWS
	prompt_at = GEN1_PROMPT


## The whole screen, with the arrow on [param cursor] counting CANCEL as the row
## after the last member. [param rows] is [member Gen2BattleSwitchMenu.rows].
## `SwitchPartyMons` opens through `InitPartyMenuNoCancel`, so [param cancel] is
## false while a member is being moved, and [param held] is that member's row,
## which wears `▷` instead of nothing. [param quality] is the four
## `PartyMenuQualityPointers` rows that are not `.Default`: each replaces the HP
## bar and its digits with one string, which the row carries as `quality`.
func render(
	rows: Array, cursor: int, prompt: String, cancel: bool = true, held: int = -1,
	quality: bool = false
) -> Image:
	var width: int = Gen2Screen.WIDTH
	var height: int = Gen2Screen.HEIGHT
	var page: PackedByteArray = PackedByteArray()
	page.resize(width * height)

	for index: int in rows.size():
		_draw_member(page, width, index, rows[index], quality)
	if cancel and not gen1:
		font.draw_text(
			Gen2BattleSwitchMenu.cancel_label(), page, width,
			CANCEL_COLUMN * TILE, (nickname_at.y + rows.size() * ROW_STEP) * TILE
		)
	if held >= 0 and held < rows.size():
		font.draw_code(
			HELD_CODE, page, width,
			CURSOR_COLUMN * TILE, (cursor_row + held * ROW_STEP) * TILE
		)
	_draw_cursor(page, width, cursor)
	_draw_prompt(page, width, prompt)

	var pixels: PackedInt32Array = Gen2PicImage.canvas_from_indices(
		page, width, height, PokePalette.pic_palette(
			PackedColorArray([Color.WHITE, Color.BLACK])
		)
	)
	if not quality:
		for index: int in rows.size():
			_blend_bar(pixels, index, rows[index])
	_blend_icons(pixels, rows.size())
	return Gen2PicImage.canvas_image(pixels, width, height)


## One pass of `PlaySpriteAnimations` over `InitPartyMenuGFX`'s structs: the
## sequence first and then the frameset, which is the order
## `DoNextFrameForAllSprites` calls them in. Called once per hardware frame by
## whoever owns the screen; the structs are rebuilt when the party behind them
## changes, the way a reopened menu respawns them.
func advance(rows: Array, cursor: int) -> void:
	if _icons.size() != rows.size():
		reset(rows)
	if gen1:
		_advance_gen1(cursor)
		return
	for index: int in _icons.size():
		var icon: Dictionary = _icons[index]
		_step_icon_sequence(icon, index == cursor)
		_step_icon_frame(icon)


## `AnimatePartyMon` behind `GetAnimationSpeed`: one counter for the whole menu,
## which `HandleMenuInput_` zeroes every time it redraws the cursor, and only
## the chosen row moved. `.resetSprites` puts every icon back on its first frame
## at zero and `.animateSprite` swaps the chosen one at the speed its bar colour
## names, so the counter runs to twice that. A ball or a helix takes
## `.editCoords` and shakes a pixel down where the rest change tile.
func _advance_gen1(cursor: int) -> void:
	if cursor != _gen1_cursor:
		_gen1_cursor = cursor
		_gen1_counter = 0
	for icon: Dictionary in _icons:
		icon["frame"] = 0
		icon["y_offset"] = 0
	if cursor < 0 or cursor >= _icons.size():
		return
	var chosen: Dictionary = _icons[cursor]
	var speed: int = GEN1_ICON_SPEEDS[int(chosen["speed"])]
	var shown: int = _gen1_counter
	_gen1_counter = 0 if shown + 1 >= speed * 2 else shown + 1
	if shown < speed:
		return
	if bool(chosen["shakes"]):
		chosen["y_offset"] = 1
	else:
		chosen["frame"] = 1


## `InitPartyMenuGFX`: one struct per member, spawned in party order. FRAME
## opens at -1 and DURATION at zero, so the first pass shows the first entry.
func reset(rows: Array) -> void:
	_icons = []
	for row: Variant in rows:
		var member: Dictionary = row as Dictionary
		var speed: int = GameData.hp_bar_palette_index(Gen2BattleHud.bar_pixels(
			int(member.get("hp", 0)), int(member.get("max_hp", 0)),
			Gen2BattleHud.HP_BAR_TILES * TILE
		))
		## `PlacePartyMenuHPBar` never runs for an egg, so the speed byte behind
		## its icon is whatever the last party left in `wHPPals`. Zero here, the
		## green one, rather than a stale byte no save can reproduce.
		if bool(member.get("egg", false)):
			speed = 0
		var icon: int = data.mon_menu_icon(
			int(member.get("species", 0)), bool(member.get("egg", false))
		) if data != null else 0
		_icons.append({
			## The strip is asked for by species rather than by icon number, so a
			## mod species drawing indices of its own animates with the rest.
			"strip": data.species_icon_indices(
				int(member.get("species", 0)), bool(member.get("egg", false))
			) if data != null else PackedByteArray(),
			"item": int(member.get("item", 0)) != 0,
			"mail": Gen2HeldItem.is_mail(int(member.get("item", 0))),
			"speed": speed,
			"shakes": gen1 and Gen1Layout.MON_ICON_SHAKING.has(icon - 1),
			"symmetric": gen1 and icon - 1 != Gen1Layout.MON_ICON_HELIX,
			"frame": -1 if not gen1 else 0,
			"duration": 0,
			"var1": 0,
			"x": ICON_X,
			"y_offset": 0,
		})
	_gen1_counter = 0
	_gen1_cursor = -1


## What the icons would draw right now, so a host caching its layer knows when
## the picture behind that cache has moved.
func animation_signature() -> String:
	var parts: PackedStringArray = []
	for icon: Dictionary in _icons:
		parts.append("%d:%d:%d" % [int(icon["frame"]), int(icon["x"]), int(icon["y_offset"])])
	return ",".join(parts)


## `SpriteAnimFunc_PartyMon`, which hands the cursor's own row to
## `SpriteAnimFunc_PartyMonSwitch`. VAR1 counts only while a row is the chosen
## one, and the offset it picks changes every sixteenth pass.
func _step_icon_sequence(icon: Dictionary, selected: bool) -> void:
	if not selected:
		icon["x"] = ICON_X
		icon["y_offset"] = 0
		return
	icon["x"] = ICON_SELECTED_X
	var counter: int = int(icon["var1"])
	icon["var1"] = (counter + 1) & 0xFF
	if counter & 0x0F != 0:
		return
	icon["y_offset"] = ICON_BOBS[int(icon["speed"])] if counter & 0x10 != 0 else 0


## `GetSpriteAnimFrame` over `.Frameset_PartyMon`: count the duration down, and
## on the pass it runs out step to the next entry and load its own.
func _step_icon_frame(icon: Dictionary) -> void:
	if int(icon["duration"]) > 0:
		icon["duration"] = int(icon["duration"]) - 1
		return
	icon["frame"] = (int(icon["frame"]) + 1) % ICON_FRAMES
	icon["duration"] = (ICON_FRAME_DURATION + ICON_SPEEDS[int(icon["speed"])]) & 0xFF


## The icons over the page, in the one palette `InitPartyMenuOBPals` gives them.
## They are objects rather than tiles, so colour 0 is transparent and they are
## blended on top rather than written into the index buffer.
func _blend_icons(pixels: PackedInt32Array, count: int) -> void:
	if data == null or _icons.is_empty():
		return
	var colors: PackedColorArray = _icon_palette()
	if colors.size() != PokePalette.COLORS_PER_PIC:
		return
	var held: PackedByteArray = data.held_item_icon_indices()
	for index: int in mini(count, _icons.size()):
		var icon: Dictionary = _icons[index]
		## Shadow OAM holds nothing for a struct `UpdateAnimFrame` has not
		## reached yet, which is why FRAME opens at -1 rather than at zero.
		if int(icon["frame"]) < 0:
			continue
		var strip: PackedByteArray = icon["strip"]
		if strip.is_empty():
			continue
		var at: Vector2i = _icon_corner(icon, index)
		var first: int = int(icon["frame"]) * ICON_FRAME_TILES
		for quadrant: int in ICON_FRAME_TILES:
			var source: PackedByteArray = strip
			var tile: int = first + quadrant
			var flip: bool = false
			if gen1:
				## `WriteSymmetricMonPartySpriteOAM` writes each row's one tile
				## twice, the second time X-flipped; the helix's own writer walks
				## all four in raster order.
				flip = bool(icon["symmetric"]) and quadrant % 2 == 1
				tile = first + (quadrant & 2) if bool(icon["symmetric"]) else tile
			elif quadrant == ICON_ITEM_QUADRANT and bool(icon["item"]) and not held.is_empty():
				source = held
				tile = ICON_MAIL_TILE if bool(icon["mail"]) else ICON_ITEM_TILE
			blend_tile(
				pixels, source, tile, colors,
				at + Vector2i((quadrant & 1) * ICON_TILE, (quadrant >> 1) * ICON_TILE), flip
			)


## `PartyMenuOBPals` on Crystal. Generation 1 has no object palette table: the
## icons stand in the two columns `BlkPacket_PartyMenu` gives PAL_MEWMON, read
## through `GBPalNormal`'s own `rOBP0`.
func _icon_palette() -> PackedColorArray:
	if not gen1:
		return data.party_menu_icon_palette()
	return Gen2WorldPalette.gen1_object_colors(
		data.world_palette(Gen1Layout.PAL_MEWMON)
	)


## The block's top-left on screen. Generation 1's OAM coordinates are the
## corner itself; Crystal's name the middle of `.OAMData_RedWalk`'s four tiles,
## which sit a tile up and left of it.
func _icon_corner(icon: Dictionary, index: int) -> Vector2i:
	if gen1:
		return Vector2i(
			GEN1_ICON_AT.x, GEN1_ICON_AT.y + index * ICON_ROW_STEP + int(icon["y_offset"])
		) - OAM_ORIGIN
	return Vector2i(
		int(icon["x"]) - ICON_TILE - OAM_ORIGIN.x,
		ICON_FIRST_Y + index * ICON_ROW_STEP + int(icon["y_offset"])
			- ICON_TILE - OAM_ORIGIN.y
	)


## One 8x8 tile of an index strip, clipped to the screen. Static and public
## because the move screen composes the same icon over its own page.
static func blend_tile(
	pixels: PackedInt32Array, strip: PackedByteArray, tile: int,
	colors: PackedColorArray, at: Vector2i, flip_x: bool = false
) -> void:
	@warning_ignore("integer_division")
	var tiles: int = strip.size() / PokeTiles.TILE_PIXELS
	Gen2PicImage.blit_tile(
		pixels, Gen2Screen.WIDTH, Gen2Screen.HEIGHT, strip, tiles, tile,
		at.x, at.y, Gen2PicImage.lookup(colors), flip_x, false, 0
	)


func _draw_member(
	page: PackedByteArray, width: int, index: int, row: Dictionary,
	quality: bool = false
) -> void:
	var step: int = index * ROW_STEP
	var hp: int = int(row.get("hp", 0))
	var max_hp: int = int(row.get("max_hp", 0))

	font.draw_text(
		String(row.get("name", "")), page, width,
		nickname_at.x * TILE, (nickname_at.y + step) * TILE
	)
	## Every quality below `PlacePartyNicknames` opens its loop with
	## `PartyMenuCheckEgg` and steps past the row, so an egg is a nickname and
	## an icon and nothing else. Reachable from the overworld menu only: a battle
	## party cannot hold one.
	if bool(row.get("egg", false)):
		return
	if quality:
		font.draw_text(
			String(row.get("quality", "")), page, width,
			quality_at.x * TILE, (quality_at.y + step) * TILE
		)
	else:
		font.draw_text(
			"%s/%s" % [
				str(hp).lpad(HP_NUMBER_DIGITS), str(max_hp).lpad(HP_NUMBER_DIGITS),
			],
			page, width, hp_digits_at.x * TILE, (hp_digits_at.y + step) * TILE
		)
		hud.draw_bar_frame(
			page, width, Vector2i(hp_bar_at.x, hp_bar_at.y + step), hud.tiles.hp_bar_end
		)
	hud.draw_level(page, width, Vector2i(level_at.x, level_at.y + step), int(row.get("level", 0)))
	font.draw_text(
		_status_string(row), page, width, status_at.x * TILE, (status_at.y + step) * TILE
	)


## The fill of one bar, blended over the page in its own colour: the hardware
## gives every tile its own palette, and one index buffer carries one.
##
## A bar is one tile row of the screen, so it is drawn into a strip that tall:
## six party rows used to cost six 160x144 buffers and six whole images a frame
## for six 48x8 rectangles.
func _blend_bar(pixels: PackedInt32Array, index: int, row: Dictionary) -> void:
	var width: int = Gen2Screen.WIDTH
	if bool(row.get("egg", false)):
		return
	var buffer: PackedByteArray = PackedByteArray()
	buffer.resize(width * TILE)
	var hp: int = int(row.get("hp", 0))
	var max_hp: int = int(row.get("max_hp", 0))
	var top: int = hp_bar_at.y + index * ROW_STEP
	hud.draw_hp_bar(buffer, width, Vector2i(hp_bar_at.x, 0), hp, max_hp)

	var lit: int = Gen2BattleHud.bar_pixels(
		hp, max_hp, Gen2BattleHud.HP_BAR_TILES * TILE
	)
	var table: PackedInt32Array = Gen2PicImage.lookup(
		data.bar_palette(GameData.hp_bar_palette_name(lit)), true
	)
	var left: int = (hp_bar_at.x + 2) * TILE
	for y: int in TILE:
		var from: int = y * width
		var to: int = (top * TILE + y) * width
		for x: int in range(left, left + Gen2BattleHud.HP_BAR_TILES * TILE):
			var value: int = buffer[from + x]
			# `blend_rect` over a transparent index 0 left the pixel alone.
			if value == 0:
				continue
			pixels[to + x] = table[value]


## `PlaceStatusString`: FNT for no health left, otherwise the first flag on the
## byte, or nothing at all for a Pokémon with none.
func _status_string(row: Dictionary) -> String:
	if bool(row.get("fainted", false)):
		return FAINTED_STRING
	var name: StringName = Gen2Status.name_of(int(row.get("status", 0)))
	return String(STATUS_STRINGS.get(name, ""))


func _draw_cursor(page: PackedByteArray, width: int, cursor: int) -> void:
	if cursor < 0:
		return
	font.draw_code(
		Gen2MenuPage.CURSOR_CODE, page, width,
		CURSOR_COLUMN * TILE, (cursor_row + cursor * ROW_STEP) * TILE
	)


func _draw_prompt(page: PackedByteArray, width: int, prompt: String) -> void:
	font.draw_box(
		frame_style, page, width, textbox_at.x * TILE, textbox_at.y * TILE,
		TEXTBOX_COLUMNS, textbox_rows
	)
	## `PlacePartyMenuText`'s string is one line and every `PartyMenuMessagePointers`
	## box is two, so a break is a row two down, which is where `<LINE>` lands.
	var line: int = 0
	for row: String in prompt.split("\n", false):
		font.draw_text(
			row, page, width, prompt_at.x * TILE, (prompt_at.y + line * ROW_STEP) * TILE
		)
		line += 1
