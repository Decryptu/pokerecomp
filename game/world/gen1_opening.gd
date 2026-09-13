class_name Gen1Opening
extends RefCounted

## `PlayIntro` and `DisplayTitleScreen` (engine/movie/splash.asm, intro.asm,
## title.asm) a frame at a time against a [Gen1Lcd]: a step list of the
## routines' own `DelayFrames`, `CheckForUserInterruption` and VRAM writes, with
## `wTileMap`, `wShadowOAM` and `hSCX` landing at VBlank and `rBGP` at once. A
## silent copy of the sound driver answers `WaitForSoundToFinish`. Yellow's
## intro is [Gen1YellowIntro].

const PHASE_COPYRIGHT: StringName = &"copyright"
const PHASE_PRESENTS: StringName = &"presents"
const PHASE_INTRO_MOVIE: StringName = &"intro_movie"
const PHASE_TITLE: StringName = &"title"
const PHASE_FINISHED: StringName = &"finished"

## `SFX_Headers_3`'s ids, all in bank $1F, `Init`'s `wAudioROMBank`.
const AUDIO_BANK: int = 0x1F
const SFX_INTRO_LUNGE: int = 184
const SFX_INTRO_HIP: int = 185
const SFX_INTRO_HOP: int = 186
const SFX_INTRO_RAISE: int = 187
const SFX_INTRO_CRASH: int = 188
const SFX_INTRO_WHOOSH: int = 189
const SFX_SHOOTING_STAR: int = 194
const MUSIC_TITLE_SCREEN: int = 195
const MUSIC_INTRO_BATTLE: int = 220
const MUSIC_YELLOW_INTRO: int = 220

## `PAD_*` bits as `hJoyHeld` holds them.
const PAD_A: int = 1 << 0
const PAD_B: int = 1 << 1
const PAD_SELECT: int = 1 << 2
const PAD_START: int = 1 << 3
const PAD_UP: int = 1 << 6
const CHORD_CLEAR_SAVE: int = PAD_UP | PAD_SELECT | PAD_B

const COLUMNS: int = 20
const ROWS: int = 18
const TILEMAP_CELLS: int = COLUMNS * ROWS
const BLANK: int = 0x7F
## `AutoBgMapTransfer`'s rows a VBlank, and its destination as a row of the
## 64 across both maps: `vBGMap0 + $300` is row 24, `vBGMap1` row 32.
const TRANSFER_ROWS: int = 6
const MAP_ROWS: int = 32
const DEST_MAP0: int = 0
const DEST_MAP0_PLUS_300: int = 24
const DEST_MAP1: int = 32
const COPY_TILES_PER_FRAME: int = 8

## `LoadCopyrightAndTextBoxTiles`: both sheets at `vChars2 tile $60`.
const COPYRIGHT_TILE: int = 2 * Gen1Lcd.BLOCK_TILES + 0x60
const COPYRIGHT_AT: Vector2i = Vector2i(2, 7)
const COPYRIGHT_ROW_STEP: int = 2
const COPYRIGHT_FRAMES: int = 180
## `LoadIntroGraphics` under a disabled LCD, measured: four frames of
## `FarCopyData2`, two on Yellow with the logo alone.
const INTRO_GRAPHICS_FRAMES: Dictionary = {RomRegistry.RED: 4, RomRegistry.BLUE: 4, RomRegistry.YELLOW: 2}
## `IntroDrawBlackBars`: four rows top and bottom of the Gengar sheet's tile 1.
const BLACK_BAR_ROWS: int = 4
const BLACK_TILE: int = 1
const LOGO_BG_TILE: int = 2 * Gen1Lcd.BLOCK_TILES + 0x60
const LOGO_OB_TILE: int = Gen1Lcd.BLOCK_TILES
const STAR_TILE: int = Gen1Lcd.BLOCK_TILES + 0x20
## `MoveAnimationTiles1 tile 3` and `19`, the sheet the pointer table lists second.
const BIG_STAR_SHEET: int = 1
const BIG_STAR_SOURCE_TILES: Array[int] = [3, 19]
const SHOOTING_STAR_DELAY: int = 64
const SHOOTING_STAR_OBP0: int = 0xF9
const SHOOTING_STAR_OBP1: int = 0xA4
const BIG_STAR_STEP: int = 4
const BIG_STAR_END_Y: int = 0xA0
const OFF_SCREEN_Y: int = Gen1Lcd.HEIGHT + Gen1Lcd.OAM_Y_OFFSET
const LOGO_FLASHES: int = 3
const LOGO_FLASH_FRAMES: int = 10
const SMALL_STARS: int = 24
const SMALL_STAR_WAVES: int = 6
const SMALL_STAR_FIRST_SLOT: int = 20
const SMALL_STAR_LAST_SLOT: int = 23
const SMALL_STAR_COUNT_STEP: int = 6
const SMALL_STAR_FALL_STEPS: int = 8
const SMALL_STAR_FALL_FRAMES: int = 3
const SMALL_STAR_OBP1_TOGGLE: int = 0xA0
const LOGO_OAM_FIRST_SLOT: int = 24
const AFTER_STARS_DELAY: int = 40
const DELAY3: int = 3

## `PlayIntroScene`'s own numbers.
const INTRO_PALETTE: int = 0xE4
const INTRO_TILEMAP_AT: Vector2i = Vector2i(13, 7)
const NIDORINO_BASE_Y: int = 80
const NIDORINO_SIDE: int = 6
const NIDORINO_SPRITES: int = NIDORINO_SIDE * NIDORINO_SIDE
const NIDORINO_WALK: int = 80 / 2
const GENGAR_RAISE: int = 8 / 2
const GENGAR_SLASH: int = 16 / 2
const MOVE_FRAMES: int = 2
const MOVE_PIXELS: int = 2
const HOP_FRAMES: int = 5
const POSE_TILES: int = Gen1Layout.INTRO_FRONT_MON_POSE_TILES

## `GBFadeOutToWhite`: `FadePal6`, `7` and `8`, eight frames each.
const FADE_TO_WHITE: Array[int] = [5, 6, 7]
const FADE_STEP_FRAMES: int = 8
## `Init`'s tail with the LCD off, measured: frames before `GBPalNormal`, then
## before `LCDC_DEFAULT`. `DisplayTitleScreen`'s own LCD-off loads spend six on
## Red, five on Blue (two `Version_GFX` tiles fewer) and Yellow.
const CLEAR_VRAM_FRAMES: Dictionary = {
	RomRegistry.RED: [5, 0], RomRegistry.BLUE: [5, 0], RomRegistry.YELLOW: [3, 1],
}
const TITLE_LOAD_FRAMES: Dictionary = {RomRegistry.RED: 6, RomRegistry.BLUE: 5, RomRegistry.YELLOW: 5}
const GB_PAL_NORMAL_BGP: int = 0xE4
const GB_PAL_NORMAL_OBP0: int = 0xD0

## `DisplayTitleScreen`.
const TITLE_SCY: int = 0x40
const WINDOW_OFF: int = 0x90
const WINDOW_HALF: int = 0x40
const TITLE_LOGO_AT: Vector2i = Vector2i(2, 1)
const TITLE_LOGO_COLUMNS: int = 16
const TITLE_LOGO_ROWS: int = 7
const TITLE_LOGO_FIRST_TILE: int = 0x80
const TITLE_LOGO_LAST_ROW_TILE: int = 0x31
const TITLE_LOGO_VRAM: int = Gen1Lcd.BLOCK_TILES
const TITLE_LOGO_FIRST_CHUNK: int = 0x60
const TITLE_LOGO2_VRAM: int = 2 * Gen1Lcd.BLOCK_TILES + Gen2PicImage.FRONTPIC_TILES \
	* Gen2PicImage.FRONTPIC_TILES
const TITLE_COPYRIGHT_VRAM: int = TITLE_LOGO2_VRAM + 16
const TITLE_COPYRIGHT_NINTENDO_TILES: int = 5
const TITLE_COPYRIGHT_GAMEFREAK_TILES: int = 9
const TITLE_COPYRIGHT_GAMEFREAK_FIRST: int = 19
const TITLE_VERSION_VRAM: int = 2 * Gen1Lcd.BLOCK_TILES + 0x60
const TITLE_VERSION_SLOT_TILES: int = 10
const TITLE_VERSION_AT: Vector2i = Vector2i(7, 8)
const TITLE_COPYRIGHT_AT: Vector2i = Vector2i(2, 17)
## `.tileScreenCopyrightTiles` on Red and Blue and Yellow's own row.
const TITLE_COPYRIGHT_TILES: Array[int] = [
	0x41, 0x42, 0x43, 0x42, 0x44, 0x42, 0x45, 0x46,
	0x47, 0x48, 0x49, 0x4A, 0x4B, 0x4C, 0x4D, 0x4E,
]
const YELLOW_TITLE_COPYRIGHT_TILES: Array[int] = [
	0xE0, 0xE1, 0xE2, 0xE3, 0xE1, 0xE2, 0xEE, 0xE5,
	0xE6, 0xE7, 0xE8, 0xE9, 0xEA, 0xEB, 0xEC, 0xED,
]
const TITLE_PLAYER_AT: Vector2i = Vector2i(0x5A, 0x60)
const TITLE_PLAYER_COLUMNS: int = 5
const TITLE_PLAYER_ROWS: int = 7
## `ld hl, wShadowOAMSprite10 / ld [hl], $74` lands on the slot's Y byte.
const TITLE_BALL_SLOT: int = 10
const TITLE_BALL_Y: int = 0x74
const TITLE_MON_AT: Vector2i = Vector2i(5, 10)
const TITLE_MON_VRAM: int = 2 * Gen1Lcd.BLOCK_TILES
const TITLE_MON_TILES: int = Gen2PicImage.FRONTPIC_TILES * Gen2PicImage.FRONTPIC_TILES
## `LoadTitleMonSprite`, measured from the pick to `hWY` landing: the
## decompressor's CPU time plus seven `CopyVideoData` frames.
const TITLE_MON_LOAD_TAIL: int = 7
## `EnableLCD` sits mid-frame, so what follows lands a frame late.
const TITLE_FIRST_LOAD_EXTRA: int = 1
## Whether `PrepareTitleScreen`'s `hWY` write lands a frame before the title's.
const PREPARE_WINDOW_EARLY: Dictionary = {RomRegistry.RED: true, RomRegistry.BLUE: true, RomRegistry.YELLOW: false}
const TITLE_MON_LOAD_FRAMES: Dictionary = {
	RomRegistry.RED: {
		1: 29, 4: 30, 7: 29, 13: 25, 17: 38, 25: 27, 32: 26, 35: 27,
		63: 30, 77: 35, 92: 51, 95: 43, 112: 51, 123: 46, 129: 40, 132: 28,
	},
	RomRegistry.BLUE: {
		1: 29, 4: 30, 7: 29, 26: 44, 37: 39, 44: 34, 56: 27, 60: 26,
		84: 26, 94: 34, 106: 48, 113: 35, 135: 35, 137: 38, 142: 49, 143: 49,
	},
}
const TITLE_MON_LOAD_DEFAULT: int = 30
## `.TitleScreenPokemonLogoYScrolls`: a scroll and how many frames of it.
const TITLE_BOUNCE: Array[Vector2i] = [
	Vector2i(-4, 16), Vector2i(3, 4), Vector2i(-3, 4), Vector2i(2, 2),
	Vector2i(-2, 2), Vector2i(1, 2), Vector2i(-1, 2),
]
const TITLE_BOUNCE_CRASH: int = -3
const TITLE_OBP0: int = 0xE4
const YELLOW_TITLE_OBP0: int = 0xE0
const TITLE_SETTLE_FRAMES: int = 36
const VERSION_SCROLL_START: int = 144
const VERSION_SCROLL_STEP: int = 4
const VERSION_SCROLL_LINES: Vector2i = Vector2i(64, 80)
const TITLE_MON_LINES: Vector2i = Vector2i(0x48, 0x88)
const TITLE_WAIT_FRAMES: int = 200
## `TitleScroll_In`, `_Out` and `_WaitBall`: speed high, frames low.
const TITLE_SCROLL_IN: Array[int] = [0xA2, 0x94, 0x84, 0x63, 0x52, 0x31, 0x11]
const TITLE_SCROLL_OUT: Array[int] = [0x12, 0x22, 0x32, 0x42, 0x52, 0x62, 0x83, 0x93]
const TITLE_SCROLL_WAIT_BALL: Array[int] = [0x05, 0x05]
const TITLE_SCROLL_IN_START: int = 0x88
## `TitleBallYTable`, entered at index 1.
const TITLE_BALL_YS: Array[int] = [0, 0x71, 0x6F, 0x6E, 0x6D, 0x6C, 0x6D, 0x6E, 0x6F, 0x71, 0x74, 0]
const TITLE_STARTERS: int = 3
const TITLE_MON_PICK_MASK: int = 0xF

## Yellow's title: its loads, boxes, blink and `IncrementResetCounter`'s $C00.
const YELLOW_LOGO_VRAM: int = 2 * Gen1Lcd.BLOCK_TILES
const YELLOW_CORNER_VRAM: int = Gen1Lcd.BLOCK_TILES + 0x7D
const YELLOW_PIKACHU_BG_VRAM: int = Gen1Lcd.BLOCK_TILES
const YELLOW_PIKACHU_OB_VRAM: int = Gen1Lcd.BLOCK_TILES + 0x70
const YELLOW_COPYRIGHT_VRAM: int = Gen1Lcd.BLOCK_TILES + 0x60
const YELLOW_NINE_VRAM: int = Gen1Lcd.BLOCK_TILES + 0x6E
const YELLOW_GAMEFREAK_VRAM: int = Gen1Lcd.BLOCK_TILES + 0x65
const YELLOW_BUBBLE_AT: Vector2i = Vector2i(6, 4)
const YELLOW_BUBBLE_TAIL_AT: Vector2i = Vector2i(9, 8)
const YELLOW_BUBBLE_TAIL: Array[int] = [0x64, 0x65]
const YELLOW_PIKACHU_AT: Vector2i = Vector2i(4, 8)
const YELLOW_PIKACHU_COLUMN: Array[int] = [0x96, 0x9D, 0xA7, 0xB1]
const YELLOW_PIKACHU_COLUMN_AT: Vector2i = Vector2i(16, 10)
## `.Jumptable`: an eye frame, or `.Nop` (-1), `.BlinkWait` (-3), `.GoBackToStart` (-2).
const YELLOW_BLINK_SCENES: Array[int] = [-1, 4, -3, -3, 8, -3, -3, 4, -3, -3, 0, -2]
const YELLOW_BLINK_NOP: int = -1
const YELLOW_BLINK_RESTART: int = -2
const YELLOW_BLINK_WAIT: int = -3
const YELLOW_BLINK_MASK: int = 0xF3
const YELLOW_TIMER_RESTARTS: Array[int] = [0x00, 0x80, 0x90]
const YELLOW_RESET_FRAMES: int = 0xC00
const YELLOW_BUBBLE_DELAY: int = DELAY3
## The two `PlayPikachuSoundClip`s, spent in silence.
const YELLOW_TITLE_CRY: int = 0
const YELLOW_TITLE_CRY_CLOSE: int = 10

## `CheckForUserInterruption`'s two answers.
const INTERRUPT_BUTTONS: int = PAD_START | PAD_A
const YELLOW_INTRO_BUTTONS: int = PAD_A | PAD_B | PAD_START

var lcd: Gen1Lcd = Gen1Lcd.new()

var _profile: StringName = &"red"
var _data: GameData = null
var _opening: Dictionary = {}
var _rng: RandomNumberGenerator = null
var _sound: Gen1SoundEngine = null
var _yellow_intro: Gen1YellowIntro = null

## `wTileMap`, `wShadowOAM`, `hSCX`, `hSCY` and `hWY`, which VBlank copies.
var _tilemap: PackedByteArray = PackedByteArray()
var _shadow_oam: PackedByteArray = PackedByteArray()
var _hscx: int = 0
var _hscy: int = 0
var _hwy: int = 0
var _transfer_enabled: bool = false
var _transfer_dest: int = DEST_MAP1
var _transfer_portion: int = 0
var _pending_copy: Dictionary = {}
## `SaveScreenTilesToBuffer1` and `2`.
var _buffer1: PackedByteArray = PackedByteArray()
var _buffer2: PackedByteArray = PackedByteArray()

var _steps: Array = []
var _labels: Dictionary = {}
var _pc: int = 0
## Steps a `do` handed back, a called routine run to its end first.
var _calls: Array[Dictionary] = []
var _wait: int = 0
var _check_left: int = 0
var _check_skip: StringName = &""
var _sound_wait: bool = false
var _frame: int = 0
var _phase: StringName = PHASE_COPYRIGHT
var _finished: bool = false
var _events: Array[Dictionary] = []

var _held: int = 0
var _held_at_read: int = 0
var _tapped: int = 0

## Which `SetPal_*` packet the screen is under.
var _palette_command: String = "splash"
var _title_species: int = 0
## Picks to take before `Random` is asked, so a trace can follow a cartridge's.
var _title_picks: Array[int] = []
var _blink_scene: int = 0
var _blink_timer: int = 0
var _reset_counter: int = 0


## Null on a cache with no opening section.
static func create(data: GameData, rng: RandomNumberGenerator = null) -> Gen1Opening:
	if data == null or data.generation != RomRegistry.GEN1 or data.opening().is_empty():
		return null
	var out := Gen1Opening.new()
	out._data = data
	out._profile = data.id
	out._opening = data.opening()
	out._rng = rng if rng != null else RandomNumberGenerator.new()
	out._sound = Gen1SoundEngine.new()
	out._sound.set_assets(data.audio_assets())
	out._sound.yellow = data.id == RomRegistry.YELLOW
	out._sound.audio_rom_bank = AUDIO_BANK
	out._sound.saved_rom_bank = AUDIO_BANK
	out._tilemap.resize(TILEMAP_CELLS)
	out._shadow_oam.resize(Gen1Lcd.OAM_SLOTS * Gen1Lcd.OAM_BYTES)
	# `PrepareOAMData`'s first VBlank runs before `Init` writes
	# `wUpdateSpritesEnabled`, and a zero there is `HideSprites`.
	for slot: int in Gen1Lcd.OAM_SLOTS:
		out._shadow_oam[slot * Gen1Lcd.OAM_BYTES] = OFF_SCREEN_Y
	out._buffer1.resize(TILEMAP_CELLS)
	out._buffer2.resize(TILEMAP_CELLS)
	out._build()
	return out


func phase() -> StringName:
	return _phase


func finished() -> bool:
	return _finished


func frame() -> int:
	return _frame


func profile() -> StringName:
	return _profile


## The `wTitleMonSpecies` on screen, as a dex number.
func title_species() -> int:
	return _title_species


## Dex numbers `TitleScreenPickNewMon` takes in order before it rolls its own.
func set_title_picks(picks: Array[int]) -> void:
	_title_picks = picks.duplicate()


## Which `SetPal_*` packet colours the screen.
func palette_command() -> String:
	return _palette_command


func palettes() -> Array:
	return (_opening.get("palettes", {}) as Dictionary).get(_palette_command, [])


func blocks() -> Array:
	return (_opening.get("blocks", {}) as Dictionary).get(_palette_command, [])


func shadow_oam() -> Array[Dictionary]:
	return lcd.shadow_oam()


func drain_events() -> Array[Dictionary]:
	var out: Array[Dictionary] = _events.duplicate(true)
	_events.clear()
	return out


## `hJoyHeld`: a button held from this frame on, until [method release].
func press(button: int) -> void:
	_held |= button
	_tapped |= button


func release(button: int) -> void:
	_held &= ~button


## One frame: the code before VBlank, VBlank, then the joypad read behind it.
func advance_frame() -> Array[Dictionary]:
	if _finished:
		return drain_events()
	_frame += 1
	# An `rLY` wait scrolls one frame only.
	lcd.line_scx = PackedInt32Array()
	if _sound_wait and not _sound_active():
		_sound_wait = false
	if _wait == 0 and _check_left == 0 and not _sound_wait:
		_run()
	# No LCD, no VBlank, no driver.
	if lcd.lcdc & Gen1Lcd.LCDC_ON:
		_vblank()
		_sound.fade_out_audio()
		_sound.update_music()
	if _wait > 0:
		_wait -= 1
	if _wait == 0 and _check_left > 0:
		_check_left -= 1
		if _interrupted():
			_check_left = 0
			_jump(_check_skip)
		elif _check_left > 0:
			_wait = 1
	_tapped = 0
	return drain_events()


## `WaitForSoundToFinish`: channels 5, 6 and 8 of `wChannelSoundIDs`.
func _sound_active() -> bool:
	for channel: int in [4, 5, 7]:
		if _sound.channel_sound_id(channel) != 0:
			return true
	return false


## `CheckForUserInterruption`'s read: Up+Select+B held, or START or A newly down.
func _interrupted() -> bool:
	return _held == CHORD_CLEAR_SAVE or _read_pressed() & INTERRUPT_BUTTONS != 0


## `hJoy5`: down now and not at the last read, plus any tap between.
func _read_pressed() -> int:
	var pressed: int = (_held & ~_held_at_read) | _tapped
	_held_at_read = _held
	return pressed


func _run() -> void:
	while _wait == 0 and _check_left == 0 and not _sound_wait and not _finished:
		var step: Dictionary = _next_step()
		if step.is_empty():
			return
		if step.has("do"):
			var more: Variant = (step["do"] as Callable).call()
			if more is Array and not (more as Array).is_empty():
				_calls.append({"steps": more, "pc": 0})
		elif step.has("delay"):
			_wait = int(step["delay"])
		elif step.has("check"):
			_wait = 1
			_check_left = int(step["check"])
			_check_skip = step["skip"]
		elif step.has("jump"):
			_jump(step["jump"])
		elif step.has("wait_sound"):
			_sound_wait = _sound_active()
		elif step.has("phase"):
			_phase = step["phase"]
			_emit(&"phase", {"phase": _phase})
		elif step.has("finish"):
			_finished = true
			_phase = PHASE_FINISHED
			_emit(step["finish"], {})


## The step to run: the innermost called routine's next, or the program's own.
func _next_step() -> Dictionary:
	while not _calls.is_empty():
		var routine: Dictionary = _calls[_calls.size() - 1]
		var steps: Array = routine["steps"]
		if int(routine["pc"]) < steps.size():
			routine["pc"] = int(routine["pc"]) + 1
			return steps[int(routine["pc"]) - 1]
		_calls.pop_back()
	if _pc >= _steps.size():
		return {}
	_pc += 1
	return _steps[_pc - 1]


## A `ret c` chain: the program continues at a label, the called routine dropped.
func _jump(label: StringName) -> void:
	_pc = int(_labels[label])
	_calls.clear()


func _index_labels() -> void:
	_labels.clear()
	for index: int in _steps.size():
		var step: Dictionary = _steps[index]
		if step.has("label"):
			_labels[step["label"]] = index


func _emit(type: StringName, values: Dictionary) -> void:
	var event: Dictionary = {"type": type, "frame": _frame, "phase": _phase}
	event.merge(values, true)
	_events.append(event)


## The VBlank handler: the scroll registers, `AutoBgMapTransfer`'s third,
## `VBlankCopy`'s eight tiles and `hDMARoutine`'s OAM.
func _vblank() -> void:
	lcd.scx = _hscx
	lcd.scy = _hscy
	lcd.wy = _hwy
	if _transfer_enabled and _pending_copy.is_empty():
		_transfer_third()
	_land_copy()
	for index: int in _shadow_oam.size():
		lcd.oam[index] = _shadow_oam[index]
	if _yellow_intro != null:
		_yellow_intro.vblank()


func _transfer_third() -> void:
	var first_row: int = _transfer_portion * TRANSFER_ROWS
	for row: int in TRANSFER_ROWS:
		var source: int = first_row + row
		var dest: int = (_transfer_dest + source) % (2 * MAP_ROWS)
		var map: PackedByteArray = lcd.maps[dest / MAP_ROWS]
		var at: int = (dest % MAP_ROWS) * Gen1Lcd.MAP_SIDE
		for column: int in COLUMNS:
			map[at + column] = _tilemap[source * COLUMNS + column]
	_transfer_portion = (_transfer_portion + 1) % 3


func _land_copy() -> void:
	if _pending_copy.is_empty():
		return
	var count: int = mini(COPY_TILES_PER_FRAME, int(_pending_copy["left"]))
	lcd.load_tiles(
		int(_pending_copy["at"]), _pending_copy["strip"], int(_pending_copy["strip_tiles"]),
		int(_pending_copy["first"]), count
	)
	_pending_copy["at"] = int(_pending_copy["at"]) + count
	_pending_copy["first"] = int(_pending_copy["first"]) + count
	_pending_copy["left"] = int(_pending_copy["left"]) - count
	if int(_pending_copy["left"]) <= 0:
		_pending_copy = {}


## `CopyVideoData`: `c / 8 + 1` VBlanks with the auto transfer held off.
func copy_video_steps(sheet: String, at: int, first: int, count: int) -> Array:
	var strip: PackedByteArray = _data.tile_indices(sheet)
	var strip_tiles: int = int(_data.tile_sheet(sheet).get("tiles", 0))
	return [
		{"do": func() -> void:
			_pending_copy = {
				"strip": strip, "strip_tiles": strip_tiles,
				"at": at, "first": first, "left": count,
			}},
		{"delay": count / COPY_TILES_PER_FRAME + 1},
	]


## `FarCopyData` under a disabled LCD, which lands at once.
func _load_sheet(sheet: String, at: int, first: int = 0, count: int = -1) -> void:
	var strip_tiles: int = int(_data.tile_sheet(sheet).get("tiles", 0))
	lcd.load_tiles(
		at, _data.tile_indices(sheet), strip_tiles,
		first, count if count >= 0 else strip_tiles - first
	)


## What [Gen1YellowIntro] writes through.
func set_transfer(enabled: bool, dest: int) -> void:
	_transfer_enabled = enabled
	_transfer_dest = dest


func set_scroll(x: int, y: int) -> void:
	_hscx = x & 0xFF
	_hscy = y & 0xFF


func scroll_x() -> int:
	return _hscx


func set_window(y: int) -> void:
	_hwy = y & 0xFF


func set_palettes(bgp: int, obp0: int, obp1: int) -> void:
	lcd.bgp = bgp & 0xFF
	lcd.obp0 = obp0 & 0xFF
	lcd.obp1 = obp1 & 0xFF


func set_palette_command(name: String) -> void:
	_palette_command = name


func play_music(id: int) -> void:
	_play_music(id)


func fill_tilemap(id: int) -> void:
	_fill_tilemap(id)


func fill_tilemap_rows(first: int, count: int, id: int) -> void:
	_fill_tilemap_rows(first, count, id)


func write_map(which: int, at: Vector2i, columns: int, rows: int, ids: Array) -> void:
	var bytes := PackedByteArray()
	for id: Variant in ids:
		bytes.append(int(id) & 0xFF)
	lcd.write_map(which, at, columns, rows, bytes)


func clear_sprites() -> void:
	_clear_sprites()


func shadow_byte(at: int) -> int:
	return _shadow_oam[at]


func set_shadow_byte(at: int, value: int) -> void:
	_shadow_oam[at] = value & 0xFF


func _set_sprite(slot: int, y: int, x: int, tile: int, attributes: int) -> void:
	var at: int = slot * Gen1Lcd.OAM_BYTES
	_shadow_oam[at] = y & 0xFF
	_shadow_oam[at + 1] = x & 0xFF
	_shadow_oam[at + 2] = tile & 0xFF
	_shadow_oam[at + 3] = attributes & 0xFF


func _sprite_byte(slot: int, byte: int) -> int:
	return _shadow_oam[slot * Gen1Lcd.OAM_BYTES + byte]


func _set_sprite_byte(slot: int, byte: int, value: int) -> void:
	_shadow_oam[slot * Gen1Lcd.OAM_BYTES + byte] = value & 0xFF


func _clear_sprites() -> void:
	_shadow_oam.fill(0)


func _fill_tilemap(id: int) -> void:
	_tilemap.fill(id)


func _write_tilemap(at: Vector2i, columns: int, rows: int, ids: Array) -> void:
	for row: int in rows:
		for column: int in columns:
			var x: int = at.x + column
			var y: int = at.y + row
			var source: int = row * columns + column
			if x < 0 or x >= COLUMNS or y < 0 or y >= ROWS or source >= ids.size():
				continue
			_tilemap[y * COLUMNS + x] = int(ids[source]) & 0xFF


func _fill_tilemap_rows(first: int, count: int, id: int) -> void:
	for cell: int in range(first * COLUMNS, (first + count) * COLUMNS):
		_tilemap[cell] = id


func _play_sfx(id: int) -> void:
	_sound.play_sound(id)
	_emit(&"play_sfx", {"sfx": id, "bank": AUDIO_BANK})


func _play_music(id: int) -> void:
	_sound.play_music(AUDIO_BANK, id)
	_emit(&"play_music", {"music": id, "bank": AUDIO_BANK})


func _stop_music() -> void:
	_sound.play_sound(Gen1SoundEngine.SFX_STOP_ALL_MUSIC)
	_emit(&"stop_music", {})


## `PlayCry` through the same driver, so the wait behind it ends with the cry.
func _play_cry(species: int) -> void:
	var record: Dictionary = _data.species_cry(species)
	if not record.is_empty():
		_sound.frequency_modifier = int(record.get("cry_pitch", 0)) & 0xFF
		_sound.tempo_modifier = int(record.get("cry_length", 0x80)) & 0xFF
		_sound.play_sound(int(record.get("sound_id", 0)))
	_emit(&"play_cry", {"species": species})


func wait_sound_step() -> Dictionary:
	return {"wait_sound": true}


func delay_step(frames: int) -> Dictionary:
	return {"delay": frames}


func check_step(frames: int, skip: StringName) -> Dictionary:
	return {"check": frames, "skip": skip}


func do_step(callable: Callable) -> Dictionary:
	return {"do": callable}


func label_step(name: StringName) -> Dictionary:
	return {"label": name}


func _build() -> void:
	_steps = []
	_steps.append_array(_splash_steps())
	if _profile == RomRegistry.YELLOW:
		_steps.append_array(_yellow_intro_steps())
	else:
		_steps.append_array(_intro_steps())
	_steps.append_array(_init_tail_steps())
	if _profile == RomRegistry.YELLOW:
		_steps.append_array(_yellow_title_steps())
	else:
		_steps.append_array(_title_steps())
	_index_labels()


## `PlayShootingStar` up to its `Delay3`.
func _splash_steps() -> Array:
	var steps: Array = [
		{"phase": PHASE_COPYRIGHT},
		do_step(func() -> void:
			_palette_command = "splash"
			_hwy = 0
			_fill_tilemap(BLANK)
			_transfer_enabled = true
			_transfer_dest = DEST_MAP1),
		delay_step(DELAY3),
	]
	# `LoadTextBoxTilePatterns` with the LCD on, then `LoadCopyrightTiles`.
	steps.append_array(copy_video_steps("font_extra", COPYRIGHT_TILE, 0, Gen1Layout.FONT_EXTRA_TILES))
	steps.append_array(copy_video_steps(
		"copyright", COPYRIGHT_TILE, 0, Gen1Layout.copyright_tiles(_profile)
	))
	steps.append_array([
		do_step(func() -> void:
			_place_copyright()
			lcd.bgp = INTRO_PALETTE),
		delay_step(COPYRIGHT_FRAMES),
		do_step(func() -> void: _fill_tilemap(BLANK)),
		delay_step(DELAY3),
		do_step(func() -> void:
			lcd.lcdc &= ~Gen1Lcd.LCDC_ON
			_draw_black_bars()
			_load_intro_graphics()),
		delay_step(int(INTRO_GRAPHICS_FRAMES[_profile])),
		do_step(func() -> void:
			lcd.lcdc |= Gen1Lcd.LCDC_ON),
		delay_step(1),
		{"phase": PHASE_PRESENTS},
		do_step(func() -> void:
			lcd.lcdc = (lcd.lcdc & ~Gen1Lcd.LCDC_WINDOW) | Gen1Lcd.LCDC_BG_MAP),
		delay_step(SHOOTING_STAR_DELAY),
	])
	steps.append_array(_shooting_star_steps())
	steps.append_array([
		delay_step(AFTER_STARS_DELAY),
		label_step(&"presents_end"),
		do_step(func() -> void:
			if _profile != RomRegistry.YELLOW:
				_play_music(MUSIC_INTRO_BATTLE)
			_fill_tilemap_rows(BLACK_BAR_ROWS, ROWS - 2 * BLACK_BAR_ROWS, 0)
			_clear_sprites()),
		delay_step(DELAY3),
	])
	return steps


## `CopyrightTextString` at `hlcoord 2, 7`, `next` moving two rows.
func _place_copyright() -> void:
	var rows: Array = _data.credits_copyright_rows()
	for index: int in rows.size():
		var row: Array = rows[index]
		_write_tilemap(COPYRIGHT_AT + Vector2i(0, index * COPYRIGHT_ROW_STEP), row.size(), 1, row)


func _draw_black_bars() -> void:
	for row: int in ROWS:
		for column: int in Gen1Lcd.MAP_SIDE:
			lcd.maps[1][row * Gen1Lcd.MAP_SIDE + column] = 0
	_fill_tilemap(0)
	_fill_tilemap_rows(0, BLACK_BAR_ROWS, BLACK_TILE)
	_fill_tilemap_rows(ROWS - BLACK_BAR_ROWS, BLACK_BAR_ROWS, BLACK_TILE)
	for y: int in ROWS:
		if y >= BLACK_BAR_ROWS and y < ROWS - BLACK_BAR_ROWS:
			continue
		for column: int in Gen1Lcd.MAP_SIDE:
			lcd.maps[1][y * Gen1Lcd.MAP_SIDE + column] = BLACK_TILE


## `LoadIntroGraphics`; Yellow writes a white and a black tile in the Gengar's place.
func _load_intro_graphics() -> void:
	if _profile == RomRegistry.YELLOW:
		lcd.fill_tile(2 * Gen1Lcd.BLOCK_TILES, 0)
		lcd.fill_tile(2 * Gen1Lcd.BLOCK_TILES + BLACK_TILE, 3)
	else:
		_load_sheet("intro_back_mon", 2 * Gen1Lcd.BLOCK_TILES)
		_load_sheet("intro_front_mon", 0)
	_load_sheet("splash_logo", LOGO_BG_TILE)
	_load_sheet("splash_logo", LOGO_OB_TILE)


## `AnimateShootingStar`.
func _shooting_star_steps() -> Array:
	var steps: Array = [
		do_step(func() -> void:
			lcd.obp0 = SHOOTING_STAR_OBP0
			lcd.obp1 = SHOOTING_STAR_OBP1),
	]
	for index: int in BIG_STAR_SOURCE_TILES.size():
		steps.append_array(_copy_anim_tile(BIG_STAR_SOURCE_TILES[index], STAR_TILE + index))
	steps.append_array(copy_video_steps("splash_star", STAR_TILE + 2, 0, Gen1Layout.SPLASH_STAR_TILES))
	steps.append(do_step(func() -> void:
		var logo: Array = _opening.get("logo_oam", [])
		for slot: int in logo.size():
			_set_sprite_row(LOGO_OAM_FIRST_SLOT + slot, logo[slot])
		var star: Array = _opening.get("shooting_star_oam", [])
		for slot: int in star.size():
			_set_sprite_row(slot, star[slot])
		_play_sfx(SFX_SHOOTING_STAR)))
	# `.bigStarLoop` runs until slot 0's Y reaches $a0, four pixels a frame.
	var star_rows: Array = _opening.get("shooting_star_oam", [])
	var start_y: int = int(star_rows[0][0]) if not star_rows.is_empty() else 0
	var moves: int = ((BIG_STAR_END_Y - start_y) & 0xFF) / BIG_STAR_STEP
	for _move: int in moves:
		steps.append(do_step(func() -> void:
			for slot: int in Gen1Layout.SPLASH_SHOOTING_STAR_SPRITES:
				_set_sprite_byte(slot, 0, _sprite_byte(slot, 0) + BIG_STAR_STEP)
				_set_sprite_byte(slot, 1, _sprite_byte(slot, 1) - BIG_STAR_STEP)))
		steps.append(check_step(1, &"presents_end"))
	steps.append(do_step(func() -> void:
		for slot: int in Gen1Layout.SPLASH_SHOOTING_STAR_SPRITES:
			_set_sprite_byte(slot, 0, OFF_SCREEN_Y)))
	for _flash: int in LOGO_FLASHES:
		steps.append(do_step(func() -> void:
			lcd.obp0 = _rotate_right_twice(lcd.obp0)))
		steps.append(check_step(LOGO_FLASH_FRAMES, &"presents_end"))
	steps.append(do_step(func() -> void:
		var row: Array = _opening.get("small_star_oam", [0, 0, 0, 0])
		for slot: int in SMALL_STARS:
			_set_sprite_row(slot, row)))
	steps.append_array(_small_star_steps())
	return steps


## `.smallStarsLoop`: six waves, four with stars, eight three-frame steps each
## with `rOBP1` toggled, the buffer shifted four slots between waves.
func _small_star_steps() -> Array:
	var steps: Array = []
	var waves: Array = _opening.get("small_star_waves", [])
	var count: int = 0
	for wave: int in SMALL_STAR_WAVES:
		var rows: Array = waves[wave] if wave < waves.size() else []
		if not rows.is_empty():
			steps.append(do_step(func() -> void:
				for index: int in rows.size():
					_set_sprite_byte(SMALL_STAR_FIRST_SLOT + index, 0, int(rows[index][0]))
					_set_sprite_byte(SMALL_STAR_FIRST_SLOT + index, 1, int(rows[index][1]))))
			if count != SMALL_STARS:
				count += SMALL_STAR_COUNT_STEP
		var moving: int = count
		for _step: int in SMALL_STAR_FALL_STEPS:
			steps.append(do_step(func() -> void:
				for index: int in moving:
					var slot: int = SMALL_STAR_LAST_SLOT - index
					_set_sprite_byte(slot, 0, _sprite_byte(slot, 0) + 1)
				lcd.obp1 ^= SMALL_STAR_OBP1_TOGGLE))
			steps.append(check_step(SMALL_STAR_FALL_FRAMES, &"presents_end"))
		steps.append(do_step(func() -> void:
			for byte: int in (SMALL_STAR_FIRST_SLOT) * Gen1Lcd.OAM_BYTES:
				_shadow_oam[byte] = _shadow_oam[byte + Gen1Lcd.OAM_BYTES * Gen1Lcd.OAM_BYTES]))
	return steps


func _copy_anim_tile(source: int, at: int) -> Array:
	var strip: PackedByteArray = _data.battle_anim_gfx_indices(BIG_STAR_SHEET)
	var strip_tiles: int = int(_data.battle_anim_gfx(BIG_STAR_SHEET).get("tiles", 0))
	return [
		do_step(func() -> void:
			_pending_copy = {
				"strip": strip, "strip_tiles": strip_tiles,
				"at": at, "first": source, "left": 1,
			}),
		delay_step(1),
	]


func _set_sprite_row(slot: int, row: Array) -> void:
	_set_sprite(slot, int(row[0]), int(row[1]), int(row[2]), int(row[3]))


static func _rotate_right_twice(byte: int) -> int:
	var out: int = byte & 0xFF
	for _turn: int in 2:
		out = ((out >> 1) | ((out & 1) << 7)) & 0xFF
	return out


## `PlayIntroScene`, every `ret c` landing on `GBFadeOutToWhite`.
func _intro_steps() -> Array:
	var anims: Array = _opening.get("nidorino_anims", [])
	var steps: Array = [
		{"phase": PHASE_INTRO_MOVIE},
		do_step(func() -> void:
			_palette_command = "intro"
			lcd.bgp = INTRO_PALETTE
			lcd.obp0 = INTRO_PALETTE
			lcd.obp1 = INTRO_PALETTE
			_hscx = 0
			_copy_gengar_tiles(0)
			_init_nidorino_oam()),
	]
	steps.append_array(_move_mon_steps(NIDORINO_WALK, 1, true))
	steps.append_array(_hop_steps(SFX_INTRO_HIP, 0, anims, 0))
	steps.append_array(_hop_steps(SFX_INTRO_HOP, 0, anims, 1))
	steps.append(check_step(10, &"intro_end"))
	steps.append_array(_hop_steps(SFX_INTRO_HIP, 0, anims, 0))
	steps.append_array(_hop_steps(SFX_INTRO_HOP, 0, anims, 1))
	steps.append(check_step(30, &"intro_end"))
	steps.append(do_step(func() -> void:
		_copy_gengar_tiles(1)
		_play_sfx(SFX_INTRO_RAISE)))
	steps.append_array(_move_mon_steps(GENGAR_RAISE, 1, false))
	steps.append(check_step(30, &"intro_end"))
	steps.append(do_step(func() -> void:
		_copy_gengar_tiles(2)
		_play_sfx(SFX_INTRO_CRASH)))
	steps.append_array(_move_mon_steps(GENGAR_SLASH, -1, false))
	steps.append_array(_hop_steps(SFX_INTRO_HIP, POSE_TILES, anims, 2))
	steps.append(check_step(30, &"intro_end"))
	steps.append_array(_move_mon_steps(GENGAR_RAISE, 1, false))
	steps.append(do_step(func() -> void: _copy_gengar_tiles(0)))
	steps.append(check_step(60, &"intro_end"))
	steps.append_array(_hop_steps(SFX_INTRO_HIP, 0, anims, 3))
	steps.append_array(_hop_steps(SFX_INTRO_HOP, 0, anims, 4))
	steps.append(check_step(20, &"intro_end"))
	steps.append_array(_hop_steps(-1, POSE_TILES, anims, 5))
	steps.append(check_step(30, &"intro_end"))
	steps.append_array(_hop_steps(SFX_INTRO_LUNGE, 2 * POSE_TILES, anims, 6))
	steps.append(label_step(&"intro_end"))
	for row: int in FADE_TO_WHITE:
		steps.append(do_step(func() -> void: _fade_palette(row)))
		steps.append(delay_step(FADE_STEP_FRAMES))
	steps.append(do_step(func() -> void:
		_hscx = 0
		_transfer_enabled = false
		_clear_sprites()))
	steps.append(delay_step(1))
	return steps


## `IntroCopyTiles`: a Gengar row at `hlcoord 13, 7`, auto transfer on.
func _copy_gengar_tiles(index: int) -> void:
	var tilemaps: Array = _opening.get("gengar_tilemaps", [])
	if index < tilemaps.size():
		_write_tilemap(
			INTRO_TILEMAP_AT, Gen2PicImage.FRONTPIC_TILES, Gen2PicImage.FRONTPIC_TILES,
			tilemaps[index]
		)
	_transfer_enabled = true


## `InitIntroNidorinoOAM`: six columns of six, behind the background.
func _init_nidorino_oam() -> void:
	var tile: int = 0
	for column: int in NIDORINO_SIDE:
		for row: int in NIDORINO_SIDE:
			_set_sprite(
				tile, NIDORINO_BASE_Y + (row + 1) * Gen1Lcd.TILE, column * Gen1Lcd.TILE,
				tile, Gen1Lcd.OAM_PRIO
			)
			tile += 1


## `UpdateIntroNidorinoOAM`: one offset for all, tiles renumbered from a base.
func _update_nidorino_oam(dy: int, dx: int, base_tile: int) -> void:
	for slot: int in NIDORINO_SPRITES:
		_set_sprite_byte(slot, 0, _sprite_byte(slot, 0) + dy)
		_set_sprite_byte(slot, 1, _sprite_byte(slot, 1) + dx)
		_set_sprite_byte(slot, 2, base_tile + slot)


## `IntroMoveMon`: two-pixel steps of `hSCX`, the Nidorino along when [param mon].
func _move_mon_steps(moves: int, direction: int, mon: bool) -> Array:
	var steps: Array = []
	for _move: int in moves:
		steps.append(do_step(func() -> void:
			if mon:
				_update_nidorino_oam(0, MOVE_PIXELS, 0)
			_hscx = (_hscx + direction * MOVE_PIXELS) & 0xFF))
		steps.append(check_step(MOVE_FRAMES, &"intro_end"))
	return steps


## `AnimateIntroNidorino` behind its sound, a row every five frames.
func _hop_steps(sfx: int, base_tile: int, anims: Array, index: int) -> Array:
	var steps: Array = []
	if sfx >= 0:
		steps.append(do_step(func() -> void: _play_sfx(sfx)))
	var rows: Array = anims[index] if index < anims.size() else []
	for row: Array in rows:
		steps.append(do_step(func() -> void:
			_update_nidorino_oam(int(row[0]), int(row[1]), base_tile)))
		steps.append(delay_step(HOP_FRAMES))
	return steps


## One `FadePal*` row into the three registers.
func _fade_palette(row: int) -> void:
	var at: int = row * 3
	lcd.bgp = Gen1Layout.FADE_PALS[at]
	lcd.obp0 = Gen1Layout.FADE_PALS[at + 1]
	lcd.obp1 = Gen1Layout.FADE_PALS[at + 2]


## What `Init` does between `PlayIntro` and `PrepareTitleScreen`.
func _init_tail_steps() -> Array:
	var frames: Array = CLEAR_VRAM_FRAMES[_profile]
	return [
		do_step(func() -> void:
			lcd.lcdc &= ~Gen1Lcd.LCDC_ON
			lcd.clear_vram()),
		delay_step(int(frames[0])),
		do_step(func() -> void:
			lcd.bgp = GB_PAL_NORMAL_BGP
			lcd.obp0 = GB_PAL_NORMAL_OBP0
			_clear_sprites()),
		delay_step(int(frames[1])),
		do_step(func() -> void:
			lcd.lcdc = Gen1Lcd.LCDC_DEFAULT
			if PREPARE_WINDOW_EARLY[_profile]:
				_hwy = 0),
		# `DisplayTitleScreen`'s white-out is the frame after the LCD returns.
		delay_step(1),
	]


## `DisplayTitleScreen` on Red and Blue.
func _title_steps() -> Array:
	var steps: Array = [
		{"phase": PHASE_TITLE},
		do_step(func() -> void:
			lcd.bgp = 0
			lcd.obp0 = 0
			lcd.obp1 = 0
			_transfer_enabled = true
			_hscx = 0
			_hscy = TITLE_SCY
			_hwy = WINDOW_OFF
			_fill_tilemap(BLANK)),
		delay_step(DELAY3),
		do_step(func() -> void:
			lcd.lcdc &= ~Gen1Lcd.LCDC_ON
			_load_title_graphics()
			lcd.fill_map(0, BLANK)
			lcd.fill_map(1, BLANK)
			_place_title_logo()
			_draw_player_character()
			_write_tilemap(TITLE_COPYRIGHT_AT, TITLE_COPYRIGHT_TILES.size(), 1, TITLE_COPYRIGHT_TILES)
			_buffer2 = _tilemap.duplicate()),
		delay_step(int(TITLE_LOAD_FRAMES.get(_profile, 6))),
		do_step(func() -> void:
			lcd.lcdc |= Gen1Lcd.LCDC_ON
			_title_species = int(_opening.get("title_mons", [0])[0])),
		delay_step(TITLE_FIRST_LOAD_EXTRA),
		do_step(func() -> Array: return _load_title_mon_steps()),
		do_step(func() -> void: _transfer_dest = DEST_MAP0_PLUS_300),
		delay_step(DELAY3),
		do_step(func() -> void:
			_buffer1 = _tilemap.duplicate()
			_hwy = WINDOW_HALF
			_tilemap = _buffer2.duplicate()
			_transfer_dest = DEST_MAP0),
		delay_step(DELAY3),
		do_step(func() -> void:
			_palette_command = "title"
			lcd.bgp = GB_PAL_NORMAL_BGP
			lcd.obp0 = TITLE_OBP0),
	]
	steps.append_array(_bounce_steps())
	steps.append_array([
		do_step(func() -> void: _tilemap = _buffer1.duplicate()),
		delay_step(TITLE_SETTLE_FRAMES),
		do_step(func() -> void:
			_play_sfx(SFX_INTRO_WHOOSH)
			_place_version()
			_hwy = Gen1Lcd.HEIGHT),
	])
	steps.append_array(_version_scroll_steps())
	steps.append_array([
		do_step(func() -> void: _transfer_dest = DEST_MAP1),
		delay_step(DELAY3),
		do_step(func() -> void:
			_tilemap = _buffer2.duplicate()
			_place_version()),
		delay_step(DELAY3),
		wait_sound_step(),
		do_step(func() -> void: _play_music(MUSIC_TITLE_SCREEN)),
		label_step(&"title_loop"),
		check_step(TITLE_WAIT_FRAMES, &"title_end"),
		do_step(func() -> Array:
			return _title_scroll_steps(TITLE_SCROLL_OUT, 0, false, func() -> void: _hwy = 0)),
		check_step(1, &"title_end"),
		do_step(func() -> Array:
			var starters: Array[int] = []
			for mon: Variant in (_opening.get("title_mons", []) as Array).slice(0, TITLE_STARTERS):
				starters.append(int(mon))
			if _title_species not in starters:
				return []
			return _title_scroll_steps(TITLE_SCROLL_WAIT_BALL, 0, true)),
		do_step(func() -> void: _transfer_dest = DEST_MAP0),
		delay_step(DELAY3),
		do_step(func() -> Array:
			_title_species = _pick_title_mon()
			return _load_title_mon_steps()),
		do_step(func() -> Array:
			_hwy = WINDOW_OFF
			return _title_scroll_steps(TITLE_SCROLL_IN, TITLE_SCROLL_IN_START, false)),
		{"jump": &"title_loop"},
		label_step(&"title_end"),
		do_step(func() -> void: _play_cry(_title_species)),
		wait_sound_step(),
	])
	steps.append_array(_leave_title_steps())
	return steps


## `DisplayTitleScreen`'s LCD-off loads; a shorter `Version_GFX` sits a tile along.
func _load_title_graphics() -> void:
	_load_sheet("copyright", TITLE_COPYRIGHT_VRAM, 0, TITLE_COPYRIGHT_NINTENDO_TILES)
	_load_sheet(
		"copyright", TITLE_COPYRIGHT_VRAM + TITLE_COPYRIGHT_NINTENDO_TILES,
		TITLE_COPYRIGHT_GAMEFREAK_FIRST, TITLE_COPYRIGHT_GAMEFREAK_TILES
	)
	_load_sheet("title_logo", TITLE_LOGO_VRAM, 0, TITLE_LOGO_FIRST_CHUNK)
	_load_sheet("title_logo", TITLE_LOGO2_VRAM, TITLE_LOGO_FIRST_CHUNK, 16)
	var version: int = int(_data.tile_sheet("title_version").get("tiles", 0))
	_load_sheet("title_version", TITLE_VERSION_VRAM + (TITLE_VERSION_SLOT_TILES - version) / 2)
	_load_sheet("title_player", 0)


func _place_title_logo() -> void:
	for row: int in TITLE_LOGO_ROWS - 1:
		var ids: Array = []
		for column: int in TITLE_LOGO_COLUMNS:
			ids.append(TITLE_LOGO_FIRST_TILE + row * TITLE_LOGO_COLUMNS + column)
		_write_tilemap(TITLE_LOGO_AT + Vector2i(0, row), TITLE_LOGO_COLUMNS, 1, ids)
	var last: Array = []
	for column: int in TITLE_LOGO_COLUMNS:
		last.append(TITLE_LOGO_LAST_ROW_TILE + column)
	_write_tilemap(TITLE_LOGO_AT + Vector2i(0, TITLE_LOGO_ROWS - 1), TITLE_LOGO_COLUMNS, 1, last)


## `DrawPlayerCharacter`: seven rows of five, slot 10 dropped four pixels.
func _draw_player_character() -> void:
	_clear_sprites()
	var tile: int = 0
	for row: int in TITLE_PLAYER_ROWS:
		for column: int in TITLE_PLAYER_COLUMNS:
			_set_sprite(
				tile, TITLE_PLAYER_AT.y + row * Gen1Lcd.TILE,
				TITLE_PLAYER_AT.x + column * Gen1Lcd.TILE, tile, 0
			)
			tile += 1
	_set_sprite_byte(TITLE_BALL_SLOT, 0, TITLE_BALL_Y)


## `LoadTitleMonSprite`: the decompressor's frames, 49 tiles, `MonTiles` at (5, 10).
func _load_title_mon_steps() -> Array:
	var frames: int = int((TITLE_MON_LOAD_FRAMES.get(_profile, {}) as Dictionary).get(
		_title_species, TITLE_MON_LOAD_DEFAULT
	)) - TITLE_MON_LOAD_TAIL
	var steps: Array = [delay_step(frames)]
	var cell: Dictionary = _front_pic_box(_title_species)
	steps.append(do_step(func() -> void:
		_pending_copy = {
			"strip": cell["strip"], "strip_tiles": TITLE_MON_TILES,
			"at": TITLE_MON_VRAM, "first": 0, "left": TITLE_MON_TILES,
		}))
	steps.append(delay_step(TITLE_MON_TILES / COPY_TILES_PER_FRAME + 1))
	steps.append(do_step(func() -> void:
		var ids: Array = []
		for row: int in Gen2PicImage.FRONTPIC_TILES:
			for column: int in Gen2PicImage.FRONTPIC_TILES:
				ids.append(column * Gen2PicImage.FRONTPIC_TILES + row)
		_write_tilemap(TITLE_MON_AT, Gen2PicImage.FRONTPIC_TILES, Gen2PicImage.FRONTPIC_TILES, ids)))
	return steps


## A front pic as `vFrontPic`'s 49 column-major tiles, padded.
func _front_pic_box(species: int) -> Dictionary:
	var strip := PackedByteArray()
	strip.resize(TITLE_MON_TILES * Gen1Lcd.TILE_PIXELS)
	var pic: Dictionary = _data.species_pic(species)
	var cell: Dictionary = Gen2PicImage.atlas_cell(
		_data.atlas_indices(String(pic.get("atlas", ""))), _data.atlas(String(pic.get("atlas", ""))), pic
	) if not pic.is_empty() else {}
	if cell.is_empty():
		return {"strip": strip}
	var width: int = int(cell["width"])
	var height: int = int(cell["height"])
	var box: int = Gen2PicImage.FRONTPIC_TILES * Gen1Lcd.TILE
	var left: int = Gen2PicImage.frontpic_pad_columns(width / Gen1Lcd.TILE, false, RomRegistry.GEN1) \
		* Gen1Lcd.TILE
	var top: int = box - height
	var indices: PackedByteArray = cell["indices"]
	var stride: int = TITLE_MON_TILES * Gen1Lcd.TILE
	for y: int in height:
		for x: int in width:
			var bx: int = left + x
			var by: int = top + y
			var tile: int = (bx / Gen1Lcd.TILE) * Gen2PicImage.FRONTPIC_TILES + by / Gen1Lcd.TILE
			strip[(by % Gen1Lcd.TILE) * stride + tile * Gen1Lcd.TILE + bx % Gen1Lcd.TILE] = \
				indices[y * width + x]
	return {"strip": strip}


## `.bouncePokemonLogoLoop`, the crash sound on the first -3.
func _bounce_steps() -> Array:
	var steps: Array = []
	for scroll: Vector2i in TITLE_BOUNCE:
		if scroll.x == TITLE_BOUNCE_CRASH:
			steps.append(do_step(func() -> void: _play_sfx(SFX_INTRO_CRASH)))
		for _time: int in scroll.y:
			steps.append(delay_step(1))
			steps.append(do_step(func() -> void: _hscy = (_hscy + scroll.x) & 0xFF))
	return steps


func _place_version() -> void:
	var text: Array = _opening.get("version_text", [])
	_write_tilemap(TITLE_VERSION_AT, text.size(), 1, text)


## `.scrollTitleScreenGameVersionLoop`: lines 64 to 79 under d, four more a frame.
func _version_scroll_steps() -> Array:
	var steps: Array = []
	var d: int = VERSION_SCROLL_START
	while d != 0:
		var shift: int = d
		if not steps.is_empty():
			steps.append(delay_step(1))
		steps.append(do_step(func() -> void:
			_set_line_scroll(VERSION_SCROLL_LINES, shift)))
		d = (d + VERSION_SCROLL_STEP) & 0xFF
	return steps


## `_TitleScroll`: `rSCX` d between `rLY` $48 and $88, the ball's Y walked
## along `TitleBallYTable` when [param ball].
func _title_scroll_steps(table: Array[int], start: int, ball: bool, after: Callable = Callable()) -> Array:
	var frames: Array = []
	var d: int = start
	var ball_index: int = 1 if ball else 0
	for entry: int in table:
		var speed: int = entry >> 4
		for _time: int in entry & 0xF:
			frames.append([d, ball_index])
			d = (d + speed) & 0xFF
			if ball_index > 0 and ball_index < TITLE_BALL_YS.size() and TITLE_BALL_YS[ball_index] != 0:
				ball_index += 1
	# The code behind the loop runs in its last frame: no VBlank of its own.
	var steps: Array = []
	for index: int in frames.size():
		var shift: int = int(frames[index][0])
		var ball_at: int = int(frames[index][1])
		var last: bool = index == frames.size() - 1
		steps.append(do_step(func() -> void:
			_set_line_scroll(TITLE_MON_LINES, shift)
			if ball_at > 0 and ball_at < TITLE_BALL_YS.size() and TITLE_BALL_YS[ball_at] != 0:
				_set_sprite_byte(TITLE_BALL_SLOT, 0, TITLE_BALL_YS[ball_at])
			if last and after.is_valid():
				after.call()))
		if not last:
			steps.append(delay_step(1))
	return steps


func _set_line_scroll(lines: Vector2i, value: int) -> void:
	var overrides := PackedInt32Array()
	overrides.resize(Gen1Lcd.HEIGHT)
	overrides.fill(-1)
	for line: int in range(lines.x, lines.y):
		overrides[line] = value
	lcd.line_scx = overrides
	lcd.line_lag = 0


## `TitleScreenPickNewMon`'s `.loop`: `Random & $f` until it differs.
func _pick_title_mon() -> int:
	var mons: Array = _opening.get("title_mons", [])
	if not _title_picks.is_empty():
		return _title_picks.pop_front()
	if mons.size() < 2:
		return _title_species
	while true:
		var pick: int = int(mons[_rng.randi() & TITLE_MON_PICK_MASK])
		if pick != _title_species:
			return pick
	return _title_species


## `.finishedWaiting`'s tail: white out, both maps cleared, `MainMenu`.
func _leave_title_steps() -> Array:
	return [
		do_step(func() -> void:
			lcd.bgp = 0
			lcd.obp0 = 0
			lcd.obp1 = 0),
		delay_step(DELAY3),
		do_step(func() -> void:
			_clear_sprites()
			_hwy = 0
			_transfer_enabled = true
			_fill_tilemap(BLANK)),
		delay_step(DELAY3),
		do_step(func() -> void: _transfer_dest = DEST_MAP0),
		delay_step(DELAY3),
		do_step(func() -> void: _transfer_dest = DEST_MAP1),
		delay_step(DELAY3),
		delay_step(DELAY3),
		{"finish": &"title_menu"},
	]


## `PlayIntroScene` on Yellow: `.loop` until the done bit or A, B or START.
func _yellow_intro_steps() -> Array:
	return [
		{"phase": PHASE_INTRO_MOVIE},
		do_step(func() -> Array:
			_yellow_intro = Gen1YellowIntro.create(self, _data)
			return _yellow_intro.init_steps()),
		label_step(&"yellow_loop"),
		do_step(func() -> Array:
			if _yellow_intro.finished() or _read_pressed() & YELLOW_INTRO_BUTTONS != 0:
				_yellow_intro.leave()
				_jump(&"yellow_end")
				return []
			return _yellow_intro.loop_steps()),
		{"jump": &"yellow_loop"},
		label_step(&"yellow_end"),
		delay_step(1),
		do_step(func() -> void:
			_hwy = WINDOW_OFF
			_fill_tilemap(0)
			_clear_sprites()
			_transfer_enabled = true),
		delay_step(DELAY3),
		do_step(func() -> void:
			_transfer_enabled = false
			_hscx = 0
			_clear_sprites()
			lcd.line_scy = PackedInt32Array()
			_yellow_intro = null),
		delay_step(1),
	]


## `DisplayTitleScreen` on Yellow.
func _yellow_title_steps() -> Array:
	var yellow: Dictionary = _opening.get("yellow", {})
	var steps: Array = [
		{"phase": PHASE_TITLE},
		do_step(func() -> void:
			lcd.bgp = 0
			lcd.obp0 = 0
			lcd.obp1 = 0
			_transfer_enabled = true
			_hscx = 0
			_hscy = TITLE_SCY
			_hwy = WINDOW_OFF
			_fill_tilemap(BLANK)),
		delay_step(DELAY3),
		do_step(func() -> void:
			lcd.lcdc &= ~Gen1Lcd.LCDC_ON
			_load_yellow_title_graphics()
			lcd.fill_map(0, BLANK)
			lcd.fill_map(1, BLANK)
			_write_tilemap(
				TITLE_LOGO_AT, Gen1Layout.TITLE_LOGO_TILEMAP.x, Gen1Layout.TITLE_LOGO_TILEMAP.y,
				yellow.get("title_logo_tilemap", [])
			)
			_write_tilemap(
				TITLE_COPYRIGHT_AT, YELLOW_TITLE_COPYRIGHT_TILES.size(), 1,
				YELLOW_TITLE_COPYRIGHT_TILES
			)
			_buffer2 = _tilemap.duplicate()),
		delay_step(int(TITLE_LOAD_FRAMES.get(_profile, 6))),
		do_step(func() -> void: lcd.lcdc |= Gen1Lcd.LCDC_ON),
		delay_step(TITLE_FIRST_LOAD_EXTRA),
		do_step(func() -> void:
			_place_yellow_pikachu()
			_transfer_dest = DEST_MAP0_PLUS_300),
		delay_step(DELAY3),
		do_step(func() -> void:
			_buffer1 = _tilemap.duplicate()
			_hwy = WINDOW_HALF
			_tilemap = _buffer2.duplicate()
			_transfer_dest = DEST_MAP0),
		delay_step(DELAY3),
		do_step(func() -> void:
			_palette_command = "title"
			lcd.bgp = GB_PAL_NORMAL_BGP
			lcd.obp0 = YELLOW_TITLE_OBP0),
	]
	steps.append_array(_bounce_steps())
	steps.append_array([
		do_step(func() -> void: _tilemap = _buffer1.duplicate()),
		delay_step(TITLE_SETTLE_FRAMES),
		do_step(func() -> void:
			_play_sfx(SFX_INTRO_WHOOSH)
			_place_yellow_bubble()
			_hwy = Gen1Lcd.HEIGHT),
		delay_step(YELLOW_BUBBLE_DELAY),
		delay_step(Gen1YellowIntro.pikachu_clip_frames(_data, YELLOW_TITLE_CRY)),
		wait_sound_step(),
		do_step(func() -> void:
			_stop_music()
			_play_music(MUSIC_TITLE_SCREEN)
			_blink_scene = 0
			_blink_timer = 0
			_reset_counter = 0),
		label_step(&"yellow_title_loop"),
		delay_step(1),
		do_step(func() -> void:
			_reset_counter += 1
			if _reset_counter == YELLOW_RESET_FRAMES:
				_jump(&"yellow_title_reset")
				return
			if _interrupted():
				_jump(&"yellow_title_end")
				return
			_yellow_title_function()),
		{"jump": &"yellow_title_loop"},
		label_step(&"yellow_title_reset"),
		do_step(func() -> void: _stop_music()),
		{"finish": &"restart_opening"},
		label_step(&"yellow_title_end"),
		delay_step(Gen1YellowIntro.pikachu_clip_frames(_data, YELLOW_TITLE_CRY_CLOSE)),
	])
	steps.append_array(_leave_title_steps())
	return steps


## `LoadYellowTitleScreenGFX` and the copyright loads around it.
func _load_yellow_title_graphics() -> void:
	_load_sheet("copyright", YELLOW_COPYRIGHT_VRAM, 0, TITLE_COPYRIGHT_NINTENDO_TILES)
	_load_sheet("title_nine", YELLOW_NINE_VRAM)
	_load_sheet(
		"copyright", YELLOW_GAMEFREAK_VRAM,
		TITLE_COPYRIGHT_GAMEFREAK_FIRST, TITLE_COPYRIGHT_GAMEFREAK_TILES
	)
	_load_sheet("title_logo", YELLOW_LOGO_VRAM)
	_load_sheet("title_logo_corner", YELLOW_CORNER_VRAM)
	_load_sheet("title_pikachu_bg", YELLOW_PIKACHU_BG_VRAM)
	_load_sheet("title_pikachu_ob", YELLOW_PIKACHU_OB_VRAM)


## `TitleScreen_PlacePikachu`: the box, four tiles beside it, the eyes.
func _place_yellow_pikachu() -> void:
	var yellow: Dictionary = _opening.get("yellow", {})
	_write_tilemap(
		YELLOW_PIKACHU_AT, Gen1Layout.TITLE_PIKACHU_TILEMAP.x, Gen1Layout.TITLE_PIKACHU_TILEMAP.y,
		yellow.get("title_pikachu_tilemap", [])
	)
	for index: int in YELLOW_PIKACHU_COLUMN.size():
		_write_tilemap(YELLOW_PIKACHU_COLUMN_AT + Vector2i(0, index), 1, 1, [YELLOW_PIKACHU_COLUMN[index]])
	var eyes: Array = yellow.get("title_eyes_oam", [])
	for slot: int in eyes.size():
		_set_sprite_row(slot, eyes[slot])


func _place_yellow_bubble() -> void:
	var yellow: Dictionary = _opening.get("yellow", {})
	_write_tilemap(
		YELLOW_BUBBLE_AT, Gen1Layout.TITLE_BUBBLE_TILEMAP.x, Gen1Layout.TITLE_BUBBLE_TILEMAP.y,
		yellow.get("title_bubble_tilemap", [])
	)
	_write_tilemap(YELLOW_BUBBLE_TAIL_AT, YELLOW_BUBBLE_TAIL.size(), 1, YELLOW_BUBBLE_TAIL)


## `DoTitleScreenFunction`: `.CheckTimer` restarts the blink at $00, $80, $90.
func _yellow_title_function() -> void:
	if _blink_timer in YELLOW_TIMER_RESTARTS:
		_blink_scene = 1
	_blink_timer = (_blink_timer + 1) & 0xFF
	var action: int = YELLOW_BLINK_SCENES[_blink_scene]
	if action == YELLOW_BLINK_RESTART:
		_blink_scene = 0
		return
	if action == YELLOW_BLINK_NOP:
		return
	if action != YELLOW_BLINK_WAIT:
		for slot: int in Gen1Layout.TITLE_EYES_SPRITES:
			_set_sprite_byte(slot, 2, (_sprite_byte(slot, 2) & YELLOW_BLINK_MASK) | action)
	_blink_scene += 1
