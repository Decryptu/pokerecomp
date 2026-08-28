class_name Gen2BattleAnimBackground
extends RefCounted

## The video state a battle animation's background effects write, and the
## primitives they write it with (engine/battle_anims/bg_effects.asm). A bg effect
## does not draw: it edits the scanline tables, the screen scroll, the DMG palette
## bytes and the tilemap the battler's picture sits in. All four are held here, so
## an effect stays arithmetic the way a motion callback does.

const SCREEN_WIDTH: int = 20
const SCREEN_HEIGHT: int = 18
## `SCREEN_HEIGHT_PX`, the scanlines a table entry can be read for.
const SCREEN_LINES: int = 144

## `wLYOverrides` and `wLYOverridesBackup` are each `align 8`, and every routine
## that indexes one loads only the low byte (`ld h, HIGH(...)` then `ld l, a`),
## so the addressable table is the whole 256-byte page. Only the first
## [constant SCREEN_LINES] entries are ever read as scanlines.
const LY_PAGE: int = 256

## `BattleBGEffects_SetLYOverrides` writes `$99` bytes to a 144-byte table and
## `$91` to another. Both overruns are the cartridge's and land in padding, so
## they are kept rather than clamped to the table.
const LY_CLEAR_LIVE: int = 0x99
const LY_CLEAR_BACKUP: int = 0x91

## `' '`, which is what `ClearBox` fills with.
const BLANK_TILE: int = 0x7F

## What `hLCDCPointer` names: the register the scanline table is written into.
## Zero is the table switched off, which is what `PushLYOverrides` checks.
const LCDC_OFF: int = 0x00
const LCDC_SCY: int = 0x42
const LCDC_SCX: int = 0x43
const LCDC_BGP: int = 0x47

## `%11100100`, the DMG palette that maps every colour to itself.
const PALETTE_IDENTITY: int = 0xE4

## `NUM_PALS`: eight background and eight object palettes.
const PALETTE_COUNT: int = 8
## `PAL_BATTLE_BG_*` and `PAL_BATTLE_OB_*` slots the effects name.
const PAL_BG_PLAYER: int = 0
const PAL_BG_ENEMY: int = 1
const PAL_OB_ENEMY: int = 0
const PAL_OB_PLAYER: int = 1
const PAL_OB_GRAY: int = 2
## `LoadTrainerHudOAM` draws the party balls on this one.
const PAL_OB_YELLOW: int = 3

## `wSurfWaveBGEffect`, the 64-entry wave `BattleBGEffect_Surf` rotates.
const SURF_WAVE_LENGTH: int = 0x40

## `wLYOverrides`, what the hardware reads, and `wLYOverridesBackup`, what an
## effect writes. `PushLYOverrides` is the copy between them.
var ly_overrides: PackedByteArray = PackedByteArray()
var ly_overrides_backup: PackedByteArray = PackedByteArray()

var lcdc_pointer: int = LCDC_OFF
var ly_override_start: int = 0
var ly_override_end: int = 0

## `hSCX` and `hSCY`, the whole-screen scroll three effects shake.
var scx: int = 0
var scy: int = 0

## `wBGP`, `wOBP0` and `wOBP1`, plus the `rBGP`/`rOBP0` they are compared
## against. On the Color hardware these registers draw nothing themselves;
## `BattleAnimRequestPals` is what turns a change into a CGB palette remap.
var bgp: int = PALETTE_IDENTITY
var obp0: int = PALETTE_IDENTITY
var obp1: int = PALETTE_IDENTITY
var r_bgp: int = PALETTE_IDENTITY
var r_obp0: int = PALETTE_IDENTITY

## Which permutation of its own four colours each palette is drawn with, as the
## DMG palette byte `CopyPals` was handed.
##
## `CopyPals` always reads the pristine `wBGPals2`/`wOBPals2`, never the live
## copy, so a remap is never compounded and the byte is the whole state. A
## renderer applies it to whatever colours the battle actually loaded.
var bg_palette_maps: PackedByteArray = PackedByteArray()
var ob_palette_maps: PackedByteArray = PackedByteArray()

## `hCGBPalUpdate`.
var palettes_dirty: bool = false

## `wTilemap`, the 20x18 screen the battler pictures are drawn into. Effects
## clear boxes in it, shift its rows and stamp resized pictures over it.
var bg_map: PackedByteArray = PackedByteArray()
## `hBGMapMode` and `hBGMapThird`: whether the tilemap is being pushed to VRAM,
## and which third of it.
var bg_map_mode: int = 0
var bg_map_third: int = 0

## `wSurfWaveBGEffect`.
var surf_wave: PackedByteArray = PackedByteArray()

## What the tilemap effects did to each battler's picture, keyed by `player_side`.
## `BattleBGEffect_HideMon`, `..._RemoveMon` and `..._RunPicResizeScript` all say
## it by editing `wTilemap`, and a renderer with no background plane cannot read a
## shrink or a removal back out of a grid of tile ids. `visible` is whether a
## picture is on the square at all, `shift` how far `RemoveMon` has pushed it off
## in pixels, and `scale` the side of the square the resize script last placed
## over the side of the whole picture.
var battler_visible: Dictionary = {true: true, false: true}
var battler_shift: Dictionary = {true: Vector2.ZERO, false: Vector2.ZERO}
var battler_scale: Dictionary = {true: 1.0, false: 1.0}

## `.BGSquares`' seven and six: the whole picture on each side, which every other
## square of the resize scripts is a subsampling of.
const BATTLER_SQUARE: Dictionary = {true: 6, false: 7}


## `BGEffect_DisplaceLYOverridesBackup`'s own `$90`, a scanline scrolled to a row
## the picture is not on. Those lines carry no displacement to average.
const LY_OFF_SCREEN: int = 0x90
## `SetLCDStatCustoms` opens the player's window at `$2d` or `$2f` and the
## opponent's at `$00`, so where a window starts is what says whose it is.
const PLAYER_WINDOW_TOP: int = 0x2D


## How far the open scanline window has moved one side's picture, in pixels.
## Tackle, Withdraw, Dig, Psychic, DoubleTeam, AcidArmor, Wobble, Flail,
## WaveDeformMon, BounceDown and Vibrate all move a battler by writing scroll
## values into it. The mean of the window on the axis `hLCDCPointer` names, less
## the whole-screen scroll `raster_scx`/`raster_scy` already carry. A scroll of n
## draws n pixels further left or up, so the offset is its negation, and a row
## pushed off with `$90` is not part of the mean. WaveDeformMon and Psychic
## stretch rather than move, where the mean is a summary rather than an answer.
func battler_window_offset(player_side: bool) -> Vector2:
	if lcdc_pointer != LCDC_SCX and lcdc_pointer != LCDC_SCY:
		return Vector2.ZERO
	var first: int = ly_override_start & 0xFF
	var count: int = (ly_override_end - ly_override_start) & 0xFF
	var mine: bool = first >= PLAYER_WINDOW_TOP if player_side \
		else first < PLAYER_WINDOW_TOP
	if count == 0 or not mine:
		return Vector2.ZERO
	var base: int = scx if lcdc_pointer == LCDC_SCX else scy
	var total: float = 0.0
	var lines: int = 0
	for step: int in count:
		var line: int = (first + step) & (LY_PAGE - 1)
		if line >= SCREEN_LINES:
			continue
		var value: int = int(ly_overrides[line])
		if value == LY_OFF_SCREEN:
			continue
		total += float(value - 256 if value > 127 else value) - float(base)
		lines += 1
	if lines == 0:
		return Vector2.ZERO
	var offset: float = -total / float(lines)
	return Vector2(offset, 0.0) if lcdc_pointer == LCDC_SCX \
		else Vector2(0.0, offset)


## One tilemap effect's report. [param player_side] is the effect's own side.
func report_battler(
	player_side: bool, visible: bool, scale: float = -1.0,
	shift: Vector2 = Vector2.INF
) -> void:
	battler_visible[player_side] = visible
	if scale >= 0.0:
		battler_scale[player_side] = scale
	if shift != Vector2.INF:
		battler_shift[player_side] = shift


func _init() -> void:
	ly_overrides.resize(LY_PAGE)
	ly_overrides_backup.resize(LY_PAGE)
	surf_wave.resize(SURF_WAVE_LENGTH)
	bg_map.resize(SCREEN_WIDTH * SCREEN_HEIGHT)
	bg_map.fill(BLANK_TILE)
	bg_palette_maps.resize(PALETTE_COUNT)
	bg_palette_maps.fill(PALETTE_IDENTITY)
	ob_palette_maps.resize(PALETTE_COUNT)
	ob_palette_maps.fill(PALETTE_IDENTITY)


## Seeds the tilemap a battle is already showing, so the effects that clear and
## resize a picture edit the real screen rather than a blank one.
func set_bg_map(tiles: PackedByteArray) -> void:
	if tiles.size() != bg_map.size():
		return
	bg_map = tiles.duplicate()


## `BattleBGEffects_ClearLYOverrides` and `..._SetLYOverrides`.
func set_ly_overrides(value: int) -> void:
	for index: int in LY_CLEAR_LIVE:
		ly_overrides[index & (LY_PAGE - 1)] = value & 0xFF
	for index: int in LY_CLEAR_BACKUP:
		ly_overrides_backup[index & (LY_PAGE - 1)] = value & 0xFF


## `BGEffect_FillLYOverridesBackup`: one value across the whole window.
##
## The loop is a `dec`/`jr nz`, so a window of no height writes the whole page
## rather than nothing.
func fill_ly_backup(value: int) -> void:
	var at: int = ly_override_start & 0xFF
	var count: int = (ly_override_end - ly_override_start) & 0xFF
	for _step: int in (count if count != 0 else LY_PAGE):
		ly_overrides_backup[at] = value & 0xFF
		at = (at + 1) & (LY_PAGE - 1)


## `BGEffect_DisplaceLYOverridesBackup`: [param value] scanlines pushed off the
## screen with `$90`, then the rest holding the negated displacement.
func displace_ly_backup(value: int) -> void:
	var at: int = ly_override_start & 0xFF
	var pushed: int = value & 0xFF
	var rest: int = (ly_override_end - ly_override_start - pushed) & 0xFF
	for _step: int in (pushed if pushed != 0 else LY_PAGE):
		ly_overrides_backup[at] = 0x90
		at = (at + 1) & (LY_PAGE - 1)
	var held: int = (~pushed) & 0xFF
	for _step: int in (rest if rest != 0 else LY_PAGE):
		ly_overrides_backup[at] = held
		at = (at + 1) & (LY_PAGE - 1)


## `PushLYOverrides`, which only runs while a register is named.
func push_ly_overrides() -> void:
	if lcdc_pointer == LCDC_OFF:
		return
	for line: int in SCREEN_LINES:
		ly_overrides[line] = ly_overrides_backup[line]


## `BattleAnimRequestPals`: a changed DMG palette byte is what asks for the CGB
## palettes to be remapped, which is how the effects that only write `wBGP` show
## on the Color hardware at all.
func request_pals() -> void:
	if bgp != r_bgp:
		set_bg_pals(bgp)
	if obp0 != r_obp0:
		set_ob_pals(obp0)


## `BattleAnim_SetBGPals`: seven background palettes and the two battler object
## ones.
func set_bg_pals(value: int) -> void:
	r_bgp = value & 0xFF
	for slot: int in 7:
		bg_palette_maps[slot] = value & 0xFF
	for slot: int in 2:
		ob_palette_maps[slot] = value & 0xFF
	palettes_dirty = true


## `BattleAnim_SetOBPals`: the two object palettes from `PAL_BATTLE_OB_GRAY` on.
func set_ob_pals(value: int) -> void:
	r_obp0 = value & 0xFF
	for slot: int in 2:
		ob_palette_maps[PAL_OB_GRAY + slot] = value & 0xFF
	palettes_dirty = true


## `BGEffects_LoadPlayerPals` and `..._LoadEnemyPals`: one background palette and
## one object palette each, which is how a fade reaches one side of the field.
func load_player_pals(value: int) -> void:
	bg_palette_maps[PAL_BG_PLAYER] = value & 0xFF
	ob_palette_maps[PAL_OB_PLAYER] = value & 0xFF
	palettes_dirty = true


func load_enemy_pals(value: int) -> void:
	bg_palette_maps[PAL_BG_ENEMY] = value & 0xFF
	ob_palette_maps[PAL_OB_ENEMY] = value & 0xFF
	palettes_dirty = true


## `BattleAnim_ResetLCDStatCustom` without its `EndBattleBGEffect`, which the
## caller owns.
func reset_lcd_stat_custom() -> void:
	ly_override_start = 0
	ly_override_end = 0
	set_ly_overrides(0)
	lcdc_pointer = LCDC_OFF


## `BattleBGEffects_ResetVideoHRAM`.
func reset_video_hram() -> void:
	lcdc_pointer = LCDC_OFF
	r_bgp = PALETTE_IDENTITY
	bgp = PALETTE_IDENTITY
	obp1 = PALETTE_IDENTITY
	ly_override_start = 0
	ly_override_end = 0
	set_ly_overrides(0)


## `ClearBox`: a [param rows] by [param columns] box of blanks at a tile coord.
func clear_box(x: int, y: int, rows: int, columns: int) -> void:
	for row: int in rows:
		var line: int = y + row
		if line < 0 or line >= SCREEN_HEIGHT:
			continue
		for column: int in columns:
			var at: int = x + column
			if at < 0 or at >= SCREEN_WIDTH:
				continue
			bg_map[line * SCREEN_WIDTH + at] = BLANK_TILE


func tile_at(x: int, y: int) -> int:
	if x < 0 or x >= SCREEN_WIDTH or y < 0 or y >= SCREEN_HEIGHT:
		return BLANK_TILE
	return bg_map[y * SCREEN_WIDTH + x]


func set_tile(x: int, y: int, tile: int) -> void:
	if x < 0 or x >= SCREEN_WIDTH or y < 0 or y >= SCREEN_HEIGHT:
		return
	bg_map[y * SCREEN_WIDTH + x] = tile & 0xFF
