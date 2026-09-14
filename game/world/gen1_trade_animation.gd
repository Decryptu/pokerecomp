class_name Gen1TradeAnimation
extends Gen1Movie

## `InternalClockTradeAnim` and `ExternalClockTradeAnim` (engine/movie/trade.asm)
## on a [Gen1Lcd]: `TradeFuncPointerTable`'s routines as step lists, the four
## `TRADE_BALL_*_ANIM`s played by [Gen2BattleAnimPlayer] into `wShadowOAM`, and
## `hAutoBGTransferEnabled` toggled the way each routine leaves it.

const INTERNAL_CLOCK: Array[StringName] = [
	&"load_gfx", &"show_player_mon", &"draw_open_end", &"ball_entering", &"left_to_right",
	&"delay_100", &"cleared_window", &"went_to", &"for_sends", &"farewell",
	&"right_to_left", &"cleared_window", &"draw_open_end", &"show_enemy_mon",
	&"delay_100", &"cleanup",
]
const EXTERNAL_CLOCK: Array[StringName] = [
	&"load_gfx", &"cleared_window", &"will_trade", &"farewell", &"swap_names",
	&"left_to_right", &"swap_names", &"cleared_window", &"draw_open_end",
	&"show_enemy_mon", &"slide_off", &"show_player_mon", &"draw_open_end",
	&"ball_entering", &"swap_names", &"right_to_left", &"swap_names", &"delay_100",
	&"cleared_window", &"went_to", &"cleanup",
]

const PLAYER_1: int = Gen2TradeAnimation.PLAYER_1
const PLAYER_2: int = Gen2TradeAnimation.PLAYER_2

## `TradingAnimationGraphics` at `vChars2 tile $31`, `TradingAnimationGraphics2`
## at `vSprites tile $7c`, and the font and `HpBarAndStatusGraphics` the trade
## walks in with.
const GFX_TILE: int = Gen1Lcd.SIGNED_BASE + Gen1Layout.ANIM_BASE_TILE
const BALL_TILE: int = 0x7C
const FONT_TILE: int = Gen1Lcd.BLOCK_TILES
const BATTLE_FONT_TILE: int = Gen1Lcd.SIGNED_BASE + Gen1Layout.BATTLE_FONT_FIRST_CODE
const ANIM_TILE: int = Gen1Layout.ANIM_BASE_TILE
const FRONT_PIC_TILE: int = Gen1Lcd.SIGNED_BASE
const PIC_TILES: int = Gen2PicImage.FRONTPIC_TILES * Gen2PicImage.FRONTPIC_TILES

## `SetAnimationPalette` on the Super Game Boy for a trade id, and the OBP0 the
## cable and transfer scenes write themselves.
const OBP0_NORMAL: int = 0xE4
const OBP1_ICONS: int = 0xD0
## `Trade_Cleanup`'s `LoadGBPal`, which is `FadePal4`.
const CLEANUP_BGP: int = 0xE4
const CLEANUP_OBP0: int = 0xD0
const CLEANUP_OBP1: int = 0xE0

const LCDC_MON: int = Gen1Lcd.LCDC_ON | Gen1Lcd.LCDC_WINDOW | Gen1Lcd.LCDC_BG_MAP \
	| Gen1Lcd.LCDC_OBJS | Gen1Lcd.LCDC_BG
const LCDC_CABLE: int = Gen1Lcd.LCDC_ON | Gen1Lcd.LCDC_BG_MAP | Gen1Lcd.LCDC_OBJS | Gen1Lcd.LCDC_BG

## `Trade_ShowPlayerMon`: the window at $50, both scrolls at $86, and the slide
## from $7e down by two to 2.
const MON_WY: int = 0x50
const MON_SLIDE_START: int = 0x86
const MON_SLIDE_FIRST: int = 0x7E
const MON_SLIDE_STEP: int = 2
const MON_BOX_AT: Vector2i = Vector2i(4, 0)
const ENEMY_BOX_AT: Vector2i = Vector2i(4, 10)
const MON_BOX_INNER: Vector2i = Vector2i(10, 6)
const MON_INFO_AT: Vector2i = Vector2i(5, 0)
const MON_INFO_LINE_STEP: int = 2
const MON_INFO_NUMBER_X: int = 9
const MON_INFO_OT_X: int = 8
const DEX_DIGITS: int = 3
const ID_DIGITS: int = 5
const PIC_AT: Vector2i = Vector2i(7, 2)
const PIC_LOAD_TAIL: int = 10
const DELAY_80: int = 80
const DELAY_100: int = 100
const DELAY_200: int = 200
const DELAY_10: int = 10
const ENEMY_CLEAR_AT: Vector2i = Vector2i(4, 10)
const ENEMY_CLEAR_SIZE: Vector2i = Vector2i(12, 8)

## `Trade_DrawOpenEndOfLinkCable`: the cable at (6,2), `hSCX` $a0 and twenty
## adds of four, and `Trade_CopyCableTilesOffScreen`'s destinations as cells of
## `vBGMap1`.
const OPEN_END_SCX: int = 0xA0
const OPEN_END_STEPS: int = 20
const OPEN_END_STEP: int = 4
const CABLE_AT: Vector2i = Vector2i(6, 2)
const OFF_SCREEN_CABLE_LEFT: int = 0x8C
const OFF_SCREEN_CABLE_RIGHT: int = 0x94
const CABLE_ROW: int = 4
const CABLE_TILE: int = 0x5E
const CABLE_PLUG: int = 0x5D
const CABLE_CORNER_DOWN: int = 0x5F
const CABLE_CORNER_UP: int = 0x60
const CABLE_VERTICAL: int = 0x61
const LEFT_CABLE_AT: Vector2i = Vector2i(11, 4)
const LEFT_CABLE_TILES: int = 8
const RIGHT_CABLE_TILES: int = 14
const RIGHT_CABLE_COLUMN: int = 14
const RIGHT_CABLE_ROWS: int = 4
const LEFT_GAME_BOY_AT: Vector2i = Vector2i(5, 3)
const RIGHT_GAME_BOY_AT: Vector2i = Vector2i(7, 8)
const LEFT_NAME_BOX_AT: Vector2i = Vector2i(4, 12)
const RIGHT_NAME_BOX_AT: Vector2i = Vector2i(6, 0)
const NAME_BOX_INNER: Vector2i = Vector2i(7, 2)

## `Trade_AnimateBallEnteringLinkCable`: `lb bc, $20, $60`, four a step to $a0,
## `Delay3` each, and `Trade_BallInsideLinkCableOAMBlock`'s two tiles.
const BALL_Y: int = 0x20
const BALL_FIRST_X: int = 0x60
const BALL_STEP: int = 4
const BALL_END_X: int = 0xA0
const BULGE_TILE: int = 0x7E
const BULGE_ATTRIBUTES: Array[int] = [0, Gen1Lcd.OAM_XFLIP, Gen1Lcd.OAM_YFLIP, Gen1Lcd.OAM_XFLIP | Gen1Lcd.OAM_YFLIP]

## `Trade_AnimLeftToRight` and `..RightToLeft`: the OAM base, the icon block at
## $10,$10, `Trade_CircleOAMBlocks`, and `Trade_AnimMonMoveHorizontal`'s eight
## frames of two pixels per sixteen-pixel unit.
const LEFT_BASE: Vector2i = Vector2i(0x54, 0x1C)
const RIGHT_BASE: Vector2i = Vector2i(0x64, 0x44)
const ICON_AT: Vector2i = Vector2i(0x10, 0x10)
const ICON_SLOTS: int = 4
const CIRCLE_SLOTS: int = 16
const CIRCLE_BLOCKS: Array[Vector2i] = [Vector2i(8, 8), Vector2i(24, 8), Vector2i(8, 24), Vector2i(24, 24)]
const CIRCLE_FLIPS: Array[int] = [0, Gen1Lcd.OAM_XFLIP, Gen1Lcd.OAM_YFLIP, Gen1Lcd.OAM_XFLIP | Gen1Lcd.OAM_YFLIP]
const CIRCLE_TILE_ORDER: Array[Array] = [[0, 1, 2, 3], [1, 0, 3, 2], [2, 3, 0, 1], [3, 2, 1, 0]]
const ICON_TRADEBUBBLE: int = 14
const ICON_HELIX: int = Gen1Layout.MON_ICON_HELIX
const ICON_FRAME_TILES: int = Gen1Layout.MON_ICON_FRAME_TILES
const ICON_OFFSET: int = Gen1Layout.MON_ICON_FRAME_OFFSET
const HORIZONTAL_UNITS: Array[int] = [6, 4, 6]
const HORIZONTAL_FRAMES: int = 8
const HORIZONTAL_STEP: int = 2
const VERTICAL_STEPS: int = 4
const VERTICAL_FRAMES: int = 8
const VERTICAL_RIGHT: Array[Vector2i] = [Vector2i(4, 0), Vector2i(0, 10)]
const VERTICAL_LEFT: Array[Vector2i] = [Vector2i(0, -10), Vector2i(-4, 0)]
const CABLE_FLASH: int = 0x3C
## `LoadMonPartySpriteGfx`'s `CopyVideoData` per header: one frame each for a
## header under eight tiles and two for `PokeBallSprite`'s eight, over 28
## headers on Red and Blue and 30 on Yellow.
const ICON_LOAD_FRAMES: Dictionary = {RomRegistry.RED: 30, RomRegistry.BLUE: 30, RomRegistry.YELLOW: 32}
const ICON_COUNT: int = Gen1Layout.MON_ICON_NYBBLES
## Yellow on a Game Boy Color: `RunPaletteCommand` spends five frames converting
## and transferring the palettes, and `Trade_AnimCircledMon`'s
## `UpdateCGBPal_BGP` holds for the next VBlank. Red and Blue spend nothing.
const CGB_PALETTE_COMMAND_FRAMES: Dictionary = {RomRegistry.YELLOW: 5}
const CGB_BGP_WRITE_FRAMES: Dictionary = {RomRegistry.YELLOW: 1}

## `Trade_ShowClearedWindow`'s `hSCX` and `Trade_SlideTextBoxOffScreen`'s waits.
const CLEARED_SCX: int = 0x90
const SLIDE_OFF_WAIT: int = 50
const SLIDE_OFF_STEP: int = 2
const SLIDE_OFF_END: int = 0xA1
const SLIDE_OFF_TAIL: int = 10

const TEXT_BOX_AT: Vector2i = Vector2i(0, 12)
const TEXT_BOX_INNER: Vector2i = Vector2i(18, 4)
const TEXT_AT: Vector2i = Vector2i(1, 14)
const TEXT_LINE_STEP: int = 2

const SFX_HEAL_HP: int = 141
const SFX_TINK: int = Gen1Layout.SFX_TINK

const TRADE_TEXT_RUN: String = "trade_anim"

var _player: Dictionary = {}
var _ot: Dictionary = {}
## `wLeftGBMonSpecies` and `wRightGBMonSpecies`.
var _left_species: int = 0
var _right_species: int = 0
## `wPlayerName` and `wLinkEnemyTrainerName`, which `Trade_SwapNames` swaps.
var _player_name: String = ""
var _enemy_name: String = ""
var _palette_species: int = 0
var _anim: Gen2BattleAnimPlayer = null
var _anim_data: Gen2BattleAnimData = null
var _anim_gfx: int = -1
var _bulge: int = 0


## [param context] is what [method Gen2TradeAnimationScreen.set_context] takes.
## Null on a cache without the trade art.
static func create(data: GameData, context: Dictionary, half: int = PLAYER_1) -> Gen1TradeAnimation:
	if data == null or data.generation != RomRegistry.GEN1 or not data.has_trade_anim():
		return null
	var out := Gen1TradeAnimation.new()
	out._init_machine(data)
	out._player = (context.get("player", {}) as Dictionary).duplicate(true)
	out._ot = (context.get("ot", {}) as Dictionary).duplicate(true)
	out._anim_data = Gen2BattleAnimData.from_game_data(data)
	out._build(half)
	return out


## `SetPal_PokemonWholeScreen`'s species, or zero under `SetPal_Generic`.
func palette_species() -> int:
	return _palette_species


## The `PAL_SET` row every cell wears: the species' own, or `PalPacket_Generic`.
func palettes() -> Array[PackedColorArray]:
	if _palette_species > 0:
		return [_data.palette(_palette_species)]
	var out: Array[PackedColorArray] = []
	for palette: Variant in (_data.opening().get("palettes", {}) as Dictionary).get("generic", []):
		var colors := PackedColorArray()
		for packed: Variant in palette as Array:
			colors.append(PokePalette.from_packed(int(packed)))
		out.append(colors)
	return out


func _build(half: int) -> void:
	var external: bool = half == PLAYER_2
	## `wTradedPlayerMonSpecies` goes on the left of an internal clock.
	_left_species = int((_ot if external else _player).get("species", 0))
	_right_species = int((_player if external else _ot).get("species", 0))
	_player_name = String(_player.get("sender_name", ""))
	_enemy_name = String(_ot.get("sender_name", ""))
	lcd.lcdc = Gen1Lcd.LCDC_DEFAULT
	lcd.bgp = CLEANUP_BGP
	lcd.wx = Gen1Lcd.WINDOW_X_OFFSET
	_load_sheet("font", FONT_TILE)
	_load_sheet("font_extra", Gen1Lcd.SIGNED_BASE + Gen1Layout.FONT_EXTRA_FIRST_CODE)
	_load_sheet("battle_font", BATTLE_FONT_TILE)
	_steps = []
	for name: StringName in EXTERNAL_CLOCK if external else INTERNAL_CLOCK:
		if name != &"cleared_window":
			_steps.append(do_step(func() -> void: _emit(&"routine", {"name": name})))
		_steps.append_array(call("_%s_steps" % name))
	_steps.append({"finish": &"finished"})
	_index_labels()


## `LoadTradingGFXAndMonNames`: `DisableLCD` polls `rLY` for the rest of a frame,
## and everything else lands under the disabled LCD.
func _load_gfx_steps() -> Array:
	return [
		do_step(func() -> void: _fill_tilemap(BLANK)),
		delay_step(1),
		do_step(func() -> void:
			_load_sheet("trade_gfx", GFX_TILE)
			_load_sheet("trade_ball", BALL_TILE)
			lcd.fill_map(0, BLANK)
			lcd.fill_map(1, BLANK)
			_clear_sprites()
			lcd.obp0 = Gen1Layout.ANIM_OBP0
			_transfer_enabled = false),
	]


func _swap_names_steps() -> Array:
	return [do_step(func() -> void:
		var name: String = _player_name
		_player_name = _enemy_name
		_enemy_name = name)]


func _delay_100_steps() -> Array:
	return [delay_step(DELAY_100)]


## `Trade_ShowPlayerMon`: the box in `vBGMap0` behind the window and the picture
## in the tilemap, the window slid in from the right and the map from the left,
## then the two ball animations. Both halves show `wTradedPlayerMonSpecies`.
func _show_player_mon_steps() -> Array:
	var species: int = int(_player.get("species", 0))
	var steps: Array = [do_step(func() -> void:
		lcd.lcdc = LCDC_MON
		_hwy = MON_WY
		lcd.wx = MON_SLIDE_START
		_hscx = MON_SLIDE_START
		_transfer_enabled = false
		_draw_box(MON_BOX_AT, MON_BOX_INNER)
		_print_info(MON_INFO_AT, species, _player))]
	steps.append_array(_copy_tilemap_to_map_steps(0))
	steps.append_array(_clear_screen_steps())
	steps.append_array(_load_mon_sprite_steps(species))
	for value: int in range(MON_SLIDE_FIRST, 0, -MON_SLIDE_STEP):
		steps.append(delay_step(1))
		steps.append(do_step(func() -> void:
			lcd.wx = value
			_hscx = value))
	steps.append(delay_step(DELAY_80))
	steps.append_array(_animation_steps(Gen1Layout.ANIM_ID_TRADE_POOF))
	steps.append_array(_animation_steps(Gen1Layout.ANIM_ID_TRADE_DROP))
	steps.append_array(_cry_steps(species))
	steps.append(do_step(func() -> void: _transfer_enabled = false))
	return steps


## `Trade_DrawOpenEndOfLinkCable`: a blank `vBGMap0`, the generic palette, the
## pointless off-screen copy and its ten frames, then the cable slid in.
func _draw_open_end_steps() -> Array:
	var steps: Array = [do_step(func() -> void: _fill_tilemap(BLANK))]
	steps.append_array(_copy_tilemap_to_map_steps(0))
	steps.append_array(_palette_command_steps(0))
	steps.append_array(_copy_cable_off_screen_steps(OFF_SCREEN_CABLE_LEFT))
	steps.append_array([
		do_step(func() -> void: _hscx = OPEN_END_SCX),
		delay_step(1),
		do_step(func() -> void:
			lcd.lcdc = LCDC_CABLE
			_write_trade_tilemap("link_cable", CABLE_AT)),
	])
	steps.append_array(_copy_tilemap_steps())
	steps.append(do_step(func() -> void:
		_play_sfx(SFX_HEAL_HP)
		_hscx = (_hscx + OPEN_END_STEPS * OPEN_END_STEP) & 0xFF))
	return steps


## `Trade_AnimateBallEnteringLinkCable`.
func _ball_entering_steps() -> Array:
	var steps: Array = _animation_steps(Gen1Layout.ANIM_ID_TRADE_SHAKE)
	steps.append(delay_step(DELAY_10))
	steps.append(do_step(func() -> void:
		lcd.obp0 = OBP0_NORMAL
		_bulge = 0))
	for x: int in range(BALL_FIRST_X, BALL_END_X, BALL_STEP):
		steps.append(do_step(func() -> void: _write_bulge(x)))
		steps.append(delay_step(DELAY3))
		if x + BALL_STEP < BALL_END_X:
			steps.append(do_step(func() -> void: _play_sfx(SFX_TINK)))
	steps.append(do_step(func() -> void:
		_clear_sprites()
		_transfer_enabled = true))
	steps.append_array(_clear_screen_steps())
	steps.append_array(_copy_tilemap_to_map_steps(0))
	steps.append(delay_step(DELAY3))
	steps.append(do_step(func() -> void: _transfer_enabled = false))
	return steps


## `Trade_BallInsideLinkCableOAMBlock` at (y, x), every tile the bulge's own.
func _write_bulge(x: int) -> void:
	_bulge ^= 1
	for index: int in BULGE_ATTRIBUTES.size():
		_set_sprite(
			index, BALL_Y + (index / 2) * Gen1Lcd.TILE, x + (index % 2) * Gen1Lcd.TILE,
			BULGE_TILE + _bulge, BULGE_ATTRIBUTES[index]
		)


## `Trade_AnimLeftToRight`.
func _left_to_right_steps() -> Array:
	var steps: Array = _init_transfer_steps()
	steps.append(do_step(func() -> void:
		lcd.obp0 = OBP0_NORMAL
		_write_circled_mon(_left_species, LEFT_BASE)
		_draw_left_game_boy()))
	steps.append(delay_step(1))
	steps.append_array(_copy_tilemap_steps())
	steps.append(do_step(func() -> void: _draw_cable_across()))
	steps.append_array(_copy_cable_off_screen_steps(OFF_SCREEN_CABLE_LEFT))
	steps.append_array(_horizontal_steps(HORIZONTAL_UNITS[0], true))
	steps.append(do_step(func() -> void:
		_transfer_enabled = true
		_draw_cable_across()))
	steps.append_array(_horizontal_steps(HORIZONTAL_UNITS[1], true))
	steps.append(do_step(func() -> void: _draw_right_game_boy()))
	steps.append(delay_step(1))
	steps.append_array(_horizontal_steps(HORIZONTAL_UNITS[2], true))
	steps.append(do_step(func() -> void: _transfer_enabled = false))
	steps.append_array(_vertical_steps(VERTICAL_RIGHT))
	steps.append(do_step(func() -> void: _clear_sprites()))
	return steps


## `Trade_AnimRightToLeft`.
func _right_to_left_steps() -> Array:
	var steps: Array = _init_transfer_steps()
	steps.append(do_step(func() -> void:
		lcd.obp0 = OBP0_NORMAL
		_write_circled_mon(_right_species, RIGHT_BASE)
		_draw_right_game_boy()))
	steps.append(delay_step(1))
	steps.append_array(_copy_tilemap_steps())
	steps.append(do_step(func() -> void: _draw_cable_across()))
	steps.append_array(_copy_cable_off_screen_steps(OFF_SCREEN_CABLE_RIGHT))
	steps.append_array(_vertical_steps(VERTICAL_LEFT))
	steps.append_array(_horizontal_steps(HORIZONTAL_UNITS[0], false))
	steps.append(do_step(func() -> void:
		_transfer_enabled = true
		_draw_cable_across()))
	steps.append_array(_horizontal_steps(HORIZONTAL_UNITS[1], false))
	steps.append(do_step(func() -> void: _draw_left_game_boy()))
	steps.append(delay_step(1))
	steps.append_array(_horizontal_steps(HORIZONTAL_UNITS[2], false))
	steps.append(do_step(func() -> void:
		_transfer_enabled = false
		_clear_sprites()))
	return steps


## `Trade_InitGameboyTransferGfx`: a cleared screen, the icon strips and the
## window parked, with the BG on `vBGMap1`.
func _init_transfer_steps() -> Array:
	var steps: Array = [do_step(func() -> void: _transfer_enabled = true)]
	steps.append_array(_clear_screen_steps())
	steps.append(do_step(func() -> void: _transfer_enabled = false))
	## Yellow's `Trade_InitGameboyTransferGfx` alone runs `SET_PAL_GENERIC` here.
	if _profile == RomRegistry.YELLOW:
		steps.append_array(_palette_command_steps(0))
	steps.append(do_step(func() -> void:
		lcd.obp1 = OBP1_ICONS
		_load_icons()))
	steps.append(delay_step(int(ICON_LOAD_FRAMES.get(_profile, 0))))
	steps.append(delay_step(1))
	steps.append(do_step(func() -> void:
		lcd.lcdc = LCDC_MON
		_hscx = 0
		_hwy = WINDOW_OFF))
	return steps


## `LoadMonPartySpriteGfx`: every icon's first frame at `ICON << 2` and its
## second `ICONOFFSET` above.
func _load_icons() -> void:
	for icon: int in ICON_COUNT:
		var strip: PackedByteArray = _data.overworld_icon_indices(icon + 1)
		if strip.is_empty():
			continue
		lcd.load_tiles(icon * ICON_FRAME_TILES, strip, 2 * ICON_FRAME_TILES, 0, ICON_FRAME_TILES)
		lcd.load_tiles(
			ICON_OFFSET + icon * ICON_FRAME_TILES, strip, 2 * ICON_FRAME_TILES,
			ICON_FRAME_TILES, ICON_FRAME_TILES
		)


## `Trade_WriteCircledMonOAM`: `WriteMonPartySpriteOAMBySpecies` in the first
## four slots, `Trade_CircleOAMBlocks` in the sixteen after, and
## `Trade_AddOffsetsToOAMCoords` over all twenty.
func _write_circled_mon(species: int, base: Vector2i) -> void:
	var icon: int = _data.mon_menu_icon(species) - 1
	var tile: int = maxi(icon, 0) * ICON_FRAME_TILES
	var helix: bool = icon == ICON_HELIX
	for index: int in ICON_SLOTS:
		var flip: int = 0 if helix or index % 2 == 0 else Gen1Lcd.OAM_XFLIP
		var part: int = index if helix else (index / 2) * 2
		_set_sprite(
			index, base.y + ICON_AT.y + (index / 2) * Gen1Lcd.TILE,
			base.x + ICON_AT.x + (index % 2) * Gen1Lcd.TILE, tile + part, flip
		)
	for block: int in CIRCLE_BLOCKS.size():
		var at: Vector2i = CIRCLE_BLOCKS[block]
		var order: Array = CIRCLE_TILE_ORDER[block]
		for index: int in ICON_SLOTS:
			_set_sprite(
				ICON_SLOTS + block * ICON_SLOTS + index,
				base.y + at.y + (index / 2) * Gen1Lcd.TILE,
				base.x + at.x + (index % 2) * Gen1Lcd.TILE,
				ICON_TRADEBUBBLE * ICON_FRAME_TILES + int(order[index]),
				Gen1Lcd.OAM_PAL1 | CIRCLE_FLIPS[block]
			)


## `Trade_AnimMonMoveHorizontal` for [param units] sixteen-pixel units.
func _horizontal_steps(units: int, right: bool) -> Array:
	var steps: Array = []
	for _unit: int in units:
		for _tick: int in HORIZONTAL_FRAMES:
			steps.append(do_step(func() -> void:
				_hscx = (_hscx + (HORIZONTAL_STEP if right else -HORIZONTAL_STEP)) & 0xFF))
			steps.append(delay_step(1))
		steps.append(do_step(_anim_circled_mon))
		steps.append_array(_bgp_write_steps())
	return steps


## `Trade_AnimMonMoveVertical`: two legs of four moves, eight frames each.
func _vertical_steps(legs: Array[Vector2i]) -> Array:
	var steps: Array = []
	for leg: Vector2i in legs:
		for _step: int in VERTICAL_STEPS:
			steps.append(do_step(func() -> void:
				_add_oam_offsets(leg)
				_anim_circled_mon()))
			steps.append_array(_bgp_write_steps())
			steps.append(delay_step(VERTICAL_FRAMES))
	return steps


## `RunPaletteCommand` with [param species]' palette over the whole screen, or
## `SET_PAL_GENERIC` for zero.
func _palette_command_steps(species: int) -> Array:
	var steps: Array = [do_step(func() -> void: _palette_species = species)]
	var frames: int = int(CGB_PALETTE_COMMAND_FRAMES.get(_profile, 0))
	if frames > 0:
		steps.append(delay_step(frames))
	return steps


func _bgp_write_steps() -> Array:
	var frames: int = int(CGB_BGP_WRITE_FRAMES.get(_profile, 0))
	return [delay_step(frames)] if frames > 0 else []


## `Trade_AnimCircledMon`: the cable flashes and the twenty sprites swap frame.
func _anim_circled_mon() -> void:
	lcd.bgp ^= CABLE_FLASH
	for slot: int in ICON_SLOTS + CIRCLE_SLOTS:
		_set_sprite_byte(slot, 2, _sprite_byte(slot, 2) ^ ICON_OFFSET)


func _add_oam_offsets(offset: Vector2i) -> void:
	for slot: int in ICON_SLOTS + CIRCLE_SLOTS:
		_set_sprite_byte(slot, 0, _sprite_byte(slot, 0) + offset.y)
		_set_sprite_byte(slot, 1, _sprite_byte(slot, 1) + offset.x)


## `Trade_DrawLeftGameboy`.
func _draw_left_game_boy() -> void:
	_fill_tilemap(BLANK)
	var cable: Array = [CABLE_PLUG]
	for _tile: int in LEFT_CABLE_TILES:
		cable.append(CABLE_TILE)
	_write_tilemap(LEFT_CABLE_AT, cable.size(), 1, cable)
	_write_trade_tilemap("game_boy", LEFT_GAME_BOY_AT)
	_draw_box(LEFT_NAME_BOX_AT, NAME_BOX_INNER)
	_place_string(LEFT_NAME_BOX_AT + Vector2i(1, 2), _player_name)


## `Trade_DrawRightGameboy`.
func _draw_right_game_boy() -> void:
	_fill_tilemap(BLANK)
	var cable: Array = []
	for _tile: int in RIGHT_CABLE_TILES:
		cable.append(CABLE_TILE)
	cable.append(CABLE_CORNER_DOWN)
	_write_tilemap(Vector2i(0, CABLE_ROW), cable.size(), 1, cable)
	for row: int in RIGHT_CABLE_ROWS:
		_write_tilemap(Vector2i(RIGHT_CABLE_COLUMN, CABLE_ROW + 1 + row), 1, 1, [CABLE_VERTICAL])
	_write_tilemap(
		Vector2i(RIGHT_CABLE_COLUMN - 1, CABLE_ROW + 1 + RIGHT_CABLE_ROWS), 2, 1,
		[CABLE_PLUG, CABLE_CORNER_UP]
	)
	_write_trade_tilemap("game_boy", RIGHT_GAME_BOY_AT)
	_draw_box(RIGHT_NAME_BOX_AT, NAME_BOX_INNER)
	_place_string(RIGHT_NAME_BOX_AT + Vector2i(1, 2), _enemy_name)


## `Trade_DrawCableAcrossScreen`.
func _draw_cable_across() -> void:
	_fill_tilemap(BLANK)
	_fill_tilemap_rows(CABLE_ROW, 1, CABLE_TILE)


## `Trade_CopyCableTilesOffScreen`: the tilemap's cable row onto twenty cells of
## `vBGMap1` from [param cell], then ten frames.
func _copy_cable_off_screen_steps(cell: int) -> Array:
	return [
		do_step(func() -> void:
			for column: int in COLUMNS:
				lcd.maps[1][(cell + column) % Gen1Lcd.MAP_BYTES] = _tilemap[CABLE_ROW * COLUMNS + column]),
		delay_step(DELAY_10),
	]


## `Trade_ShowClearedWindow`.
func _cleared_window_steps() -> Array:
	var steps: Array = [do_step(func() -> void:
		_emit(&"routine", {"name": &"cleared_window"})
		_transfer_enabled = true)]
	steps.append_array(_clear_screen_steps())
	steps.append(do_step(func() -> void:
		lcd.lcdc = Gen1Lcd.LCDC_DEFAULT
		lcd.wx = Gen1Lcd.WINDOW_X_OFFSET
		_hwy = 0
		_hscx = CLEARED_SCX))
	return steps


## `Trade_SlideTextBoxOffScreen`.
func _slide_off_steps() -> Array:
	var steps: Array = [delay_step(SLIDE_OFF_WAIT)]
	for value: int in range(Gen1Lcd.WINDOW_X_OFFSET + SLIDE_OFF_STEP, SLIDE_OFF_END + 1, SLIDE_OFF_STEP):
		steps.append(delay_step(1))
		steps.append(do_step(func() -> void: lcd.wx = value))
	steps.append(do_step(func() -> void: _fill_tilemap(BLANK)))
	steps.append(delay_step(SLIDE_OFF_TAIL))
	steps.append(do_step(func() -> void: lcd.wx = Gen1Lcd.WINDOW_X_OFFSET))
	return steps


func _went_to_steps() -> Array:
	var steps: Array = _print_text_steps("went_to")
	steps.append(delay_step(DELAY_200))
	steps.append_array(_slide_off_steps())
	return steps


func _for_sends_steps() -> Array:
	var steps: Array = _print_text_steps("for")
	steps.append(delay_step(DELAY_80))
	steps.append_array(_print_text_steps("sends"))
	steps.append(delay_step(DELAY_80))
	return steps


func _farewell_steps() -> Array:
	var steps: Array = _print_text_steps("waves_farewell")
	steps.append(delay_step(DELAY_80))
	steps.append_array(_print_text_steps("transferred"))
	steps.append(delay_step(DELAY_80))
	steps.append_array(_slide_off_steps())
	return steps


func _will_trade_steps() -> Array:
	var steps: Array = _print_text_steps("will_trade")
	steps.append(delay_step(DELAY_80))
	steps.append_array(_print_text_steps("trade_for"))
	steps.append(delay_step(DELAY_80))
	return steps


## `Trade_ShowEnemyMon`.
func _show_enemy_mon_steps() -> Array:
	var species: int = int(_ot.get("species", 0))
	var steps: Array = _animation_steps(Gen1Layout.ANIM_ID_TRADE_TILT)
	steps.append_array(_cleared_window_steps())
	steps.append(do_step(func() -> void:
		_draw_box(ENEMY_BOX_AT, MON_BOX_INNER)
		_print_info(ENEMY_BOX_AT + Vector2i(1, 0), species, _ot)))
	steps.append_array(_copy_tilemap_steps())
	steps.append(do_step(func() -> void: _transfer_enabled = true))
	steps.append_array(_load_mon_sprite_steps(species))
	steps.append_array(_animation_steps(Gen1Layout.ANIM_ID_TRADE_POOF))
	steps.append(do_step(func() -> void: _transfer_enabled = true))
	steps.append_array(_cry_steps(species))
	steps.append(delay_step(DELAY_100))
	steps.append(do_step(func() -> void: _clear_area(ENEMY_CLEAR_AT, ENEMY_CLEAR_SIZE)))
	steps.append_array(_print_text_steps("take_care"))
	steps.append(delay_step(DELAY_80))
	return steps


## `Trade_Cleanup`: `LoadGBPal` and the text delay back.
func _cleanup_steps() -> Array:
	return [do_step(func() -> void:
		lcd.bgp = CLEANUP_BGP
		lcd.obp0 = CLEANUP_OBP0
		lcd.obp1 = CLEANUP_OBP1)]


## `Trade_LoadMonSprite`: the species' palette over the whole screen, the auto
## transfer toggled, `LoadFlippedFrontSpriteByMonIndex` and ten frames.
func _load_mon_sprite_steps(species: int) -> Array:
	var restore: Array = [false]
	var steps: Array = [do_step(func() -> void: _emit(&"routine", {"name": &"load_mon_sprite"}))]
	steps.append_array(_palette_command_steps(species))
	steps.append_array([
		do_step(func() -> void:
			restore[0] = not _transfer_enabled
			_transfer_enabled = false),
		delay_step(_data.gen1_pic_load_frames(species)),
		do_step(func() -> void:
			lcd.load_tiles(
				FRONT_PIC_TILE, Gen2PicImage.gen1_front_strip(_data, species, true),
				PIC_TILES, 0, PIC_TILES
			)
			var ids: Array = []
			for row: int in Gen2PicImage.FRONTPIC_TILES:
				for column: int in Gen2PicImage.FRONTPIC_TILES:
					ids.append(column * Gen2PicImage.FRONTPIC_TILES + row)
			_write_tilemap(PIC_AT, Gen2PicImage.FRONTPIC_TILES, Gen2PicImage.FRONTPIC_TILES, ids)
			_transfer_enabled = bool(restore[0])),
		delay_step(PIC_LOAD_TAIL),
	])
	return steps


## `PlayCry`, which is `WaitForSoundToFinish` behind the cry.
func _cry_steps(species: int) -> Array:
	return [do_step(func() -> void: _play_cry(species)), wait_sound_step()]


## `Trade_ShowAnimation`, which is `MoveAnimation` with `wAnimationType` zero:
## a sound wait either side and `SetAnimationPalette`'s trade bytes.
func _animation_steps(id: int) -> Array:
	return [
		wait_sound_step(),
		do_step(func() -> void:
			lcd.obp0 = Gen1Layout.ANIM_OBP0
			lcd.obp1 = Gen1Layout.ANIM_OBP1
			_anim = Gen2BattleAnimPlayer.create_gen1(_anim_data, id - 1)
			_anim_gfx = -1
			_emit(&"animation", {"id": id})),
		until_step(_advance_animation),
		wait_sound_step(),
	]


## One `PlayAnimation` frame: the tileset `LoadMoveAnimationTiles` copied, the
## frame block into `wShadowOAM`, and the block's own routine's writes.
func _advance_animation() -> bool:
	if _anim == null or _anim.finished():
		_anim = null
		return true
	_anim.advance_frame()
	for command: Dictionary in _anim.frame_commands():
		_apply_anim_command(command)
	var tiles: Array = _anim.tiles()
	if not tiles.is_empty() and int((tiles[0] as Dictionary).get("gfx", -1)) != _anim_gfx:
		_anim_gfx = int((tiles[0] as Dictionary)["gfx"])
		var strip: PackedByteArray = _data.battle_anim_gfx_indices(_anim_gfx)
		lcd.load_tiles(ANIM_TILE, strip, tiles.size(), 0, tiles.size())
	_hscx = _anim.background().scx
	var sprites: Array = _anim.sprites()
	_clear_sprites()
	for index: int in mini(sprites.size(), Gen1Lcd.OAM_SLOTS):
		var sprite: Dictionary = sprites[index]
		_set_sprite(
			index, int(sprite["y"]), int(sprite["x"]), int(sprite["tile"]), int(sprite["attributes"])
		)
	if _anim.finished():
		_anim = null
		return true
	return false


func _apply_anim_command(command: Dictionary) -> void:
	match StringName(command["name"]):
		Gen2BattleAnimPlayer.GEN1_SOUND:
			_play_sfx(int((command["operands"] as Array)[0]))
		Gen2BattleAnimPlayer.GEN1_HIDE_PIC:
			_clear_area(PIC_AT, Vector2i(Gen2PicImage.FRONTPIC_TILES, Gen2PicImage.FRONTPIC_TILES))
		Gen2BattleAnimPlayer.GEN1_CLEAR_SCREEN:
			_fill_tilemap(BLANK)


## `PrintText` with `BIT_NO_TEXT_DELAY` set: the box, three frames, the text.
func _print_text_steps(name: String) -> Array:
	return [
		do_step(func() -> void: _draw_box(TEXT_BOX_AT, TEXT_BOX_INNER)),
		delay_step(DELAY3),
		do_step(func() -> void:
			_emit(&"text", {"name": name})
			var lines: PackedStringArray = _text(name).split("\n")
			for line: int in lines.size():
				_place_string(TEXT_AT + Vector2i(0, line * TEXT_LINE_STEP), lines[line])),
	]


## One `_Trade*Text` with its `text_ram`s and `<PLAYER>` filled.
func _text(name: String) -> String:
	var text: String = _data.special_text(TRADE_TEXT_RUN, name)
	text = Gen2TextStream.fill_names(text, {"player": _player_name})
	for pair: Array in [
		["string", String(_player.get("species_name", ""))],
		["name", String(_ot.get("species_name", ""))],
		["enemy_trainer", _enemy_name],
	]:
		text = Gen2TextStream.fill_all_markers(
			text, "%s%04X>" % [Gen2TextStream.RAM_MARKER, _data.gen1_trade_buffer(String(pair[0]))],
			String(pair[1])
		)
	return text


## `Trade_PrintPlayerMonInfoText` and its enemy twin: `Trade_MonInfoText`'s
## lines two rows apart, the dex number, the name, the OT and the id.
func _print_info(at: Vector2i, species: int, half: Dictionary) -> void:
	var lines: Array = _data.gen1_trade_info_lines()
	for line: int in lines.size():
		var codes: Array = lines[line]
		_write_tilemap(at + Vector2i(0, line * MON_INFO_LINE_STEP), codes.size(), 1, codes)
	_place_string(Vector2i(MON_INFO_NUMBER_X, at.y), "%0*d" % [DEX_DIGITS, species])
	_place_string(at + Vector2i(0, MON_INFO_LINE_STEP), String(_data.species(species).get("name", "")))
	_place_string(Vector2i(MON_INFO_OT_X, at.y + 2 * MON_INFO_LINE_STEP), String(half.get("ot_name", "")))
	_place_string(
		Vector2i(MON_INFO_OT_X, at.y + 3 * MON_INFO_LINE_STEP),
		"%0*d" % [ID_DIGITS, int(half.get("ot_id", 0))]
	)


## `CopyScreenTileBufferToVRAM`: six rows a frame into map [param which].
func _copy_tilemap_to_map_steps(which: int) -> Array:
	var steps: Array = []
	for third: int in ROWS / TRANSFER_ROWS:
		steps.append(do_step(func() -> void:
			for row: int in TRANSFER_ROWS:
				var source: int = third * TRANSFER_ROWS + row
				for column: int in COLUMNS:
					lcd.maps[which][source * Gen1Lcd.MAP_SIDE + column] = _tilemap[source * COLUMNS + column]))
		steps.append(delay_step(1))
	return steps


## `Trade_CopyTileMapToVRAM`: the auto transfer on for `Delay3`.
func _copy_tilemap_steps() -> Array:
	return [
		do_step(func() -> void: _transfer_enabled = true),
		delay_step(DELAY3),
		do_step(func() -> void: _transfer_enabled = false),
	]


## `ClearScreen`.
func _clear_screen_steps() -> Array:
	return [do_step(func() -> void: _fill_tilemap(BLANK)), delay_step(DELAY3)]


## `ClearScreenArea`.
func _clear_area(at: Vector2i, size: Vector2i) -> void:
	for row: int in size.y:
		for column: int in size.x:
			_write_tilemap(at + Vector2i(column, row), 1, 1, [BLANK])


## `TextBoxBorder` at [param at] with a [param inner] interior.
func _draw_box(at: Vector2i, inner: Vector2i) -> void:
	var rows: Array = Gen1Text.text_box_rows(inner)
	for row: int in rows.size():
		_write_tilemap(at + Vector2i(0, row), inner.x + 2, 1, rows[row])


func _place_string(at: Vector2i, text: String) -> void:
	_write_tilemap(at, Gen1Text.encoded_length(text), 1, Array(Gen1Text.encode(text)))


func _write_trade_tilemap(name: String, at: Vector2i) -> void:
	var shape: Array = _data.gen1_trade_tilemap_shape(name)
	_write_tilemap(at, int(shape[0]), int(shape[1]), Array(_data.trade_anim_tilemap(name)))
