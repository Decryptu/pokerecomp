class_name Gen1SurfingMinigame
extends Gen1Movie

## Yellow's `SurfingPikachuMinigame` (engine/minigame/surfing_pikachu.asm) on a
## [Gen1Lcd], one VBlank an [method advance_frame].

const FLAT_WATER_Y: int = 0x74
const CENTER_X: int = Gen1Lcd.WIDTH / 2 + Gen1Lcd.OAM_X_OFFSET

const OBJECT_PIKACHU: int = 1
const OBJECT_START: int = 2
const OBJECT_PLUS_50: int = 4
const OBJECT_PLUS_180: int = 8
const OBJECT_PLUS_500: int = 9
const OBJECT_SPRAY: int = 0xA
const OBJECT_OH_NO: int = 0xB
const OBJECT_INTRO: int = 0xC
const CALLBACK_PIKACHU: int = 1
const CALLBACK_BANNER: int = 2
const CALLBACK_FLIPPING: int = 3
const CALLBACK_INTRO: int = 4
const FRAMESET_FLAT: int = 4
const FRAMESET_CRASH: int = 0x10
const FRAMESET_RESULTS: int = 0xF
const FRAMESET_FIRST_ANGLE: int = 1
const FRAMESET_LAST_ANGLE: int = 0xE
const FRAMESET_RISING: int = 6
const FRAMESET_FALLING: int = 2

enum Routine {
	START, RUN, WAIT_RESULTS, SCROLL_RESULTS, DRAW_RESULTS, HP_LEFT, RADNESS, TOTAL,
	ADD_HP, ADD_RADNESS, WAIT_LAST, EXIT, GAME_OVER,
}
const ROUTINE_DONE: int = 0x80
enum PikachuState { RIDING, JUMPING, LANDING, CRASHED, GAME_END, INIT_RESULTS, RESULTS }

const TILE_WATER: int = 0x0B
const TILE_RISING: int = 0x06
const TILE_FALLING: int = 0x07
const TILE_FACE: int = 0x12
const TILE_CREST: int = 0x14
const LANDING_WIPEOUT: int = 0
const LANDING_HARD: int = 1
const LANDING_ROUGH: int = 2
const LANDING_CLEAN: int = 3
const LANDINGS: Dictionary = {
	-1: {1: LANDING_WIPEOUT, 2: LANDING_HARD, 3: LANDING_ROUGH, 4: LANDING_CLEAN,
		5: LANDING_ROUGH, 6: LANDING_HARD, 7: LANDING_WIPEOUT},
	TILE_RISING: {1: LANDING_WIPEOUT, 2: LANDING_WIPEOUT, 3: LANDING_WIPEOUT, 4: LANDING_HARD,
		5: LANDING_ROUGH, 6: LANDING_CLEAN, 7: LANDING_ROUGH},
	TILE_FALLING: {1: LANDING_ROUGH, 2: LANDING_CLEAN, 3: LANDING_ROUGH, 4: LANDING_HARD,
		5: LANDING_WIPEOUT, 6: LANDING_WIPEOUT, 7: LANDING_WIPEOUT},
	TILE_CREST: {1: LANDING_WIPEOUT, 2: LANDING_HARD, 3: LANDING_ROUGH, 4: LANDING_CLEAN,
		5: LANDING_CLEAN, 6: LANDING_ROUGH, 7: LANDING_HARD},
}

const SPEED_START: int = 0x0040
const SPEED_GAIN: int = 0x0002
const SPEED_CAP_HIGH: int = 2
const SPEED_ROUGH_LOSS: int = 0x0040
const SPEED_HARD_LOSS: int = 0x0080
const JUMP_STEP: int = 0x0080
const SCROLL_STEP: int = 0x0180
const COAST_STEP: int = 0x0900
const RESULTS_SCROLL_STEP: int = 4
const RESULTS_SCX: int = 0x90
const JUMP_MIN_SPEED: int = 10
const TRICK_LEFT_FRAMES: int = 0xB
const TRICK_RIGHT_FRAMES: int = 0xD
const TRICK_LEFT: int = 1
const TRICK_RIGHT: int = 2
const RADNESS_CAP: int = 3
const RADNESS_STEP: int = 0x50
const RADNESS_MIXED_STEPS: int = 10
const RADNESS_PAIR: Array[int] = [0x50, 0x50, 0x50, 0x30]
const RADNESS_MAX: int = 0x99
const COURSE_SECTIONS: int = 0x18
const BIG_KAHUNA_SECTION: int = 0x16
const BIG_KAHUNA_WAVE: int = 0x6A
const RESULTS_WAVE: int = 0x72
const HP_START: int = 0x60
const HP_DIGIT_TILE: int = 0xD0
const CRASH_FRAMES: int = 0x60
const LANDING_FRAMES: int = 0x20
const LANDING_STEP: int = 4
const LANDING_AMPLITUDE: int = 4
const RESULTS_BOB_MASK: int = 0x3F
const RESULTS_BOB_HALF: int = 0x20
const RESULTS_BOB_AMPLITUDE: int = 0x10
const RESULTS_BOB_STEP: int = 2
const OH_NO_Y: int = 0x88
const OH_NO_BOUNCE: int = 0x80
const OH_NO_COUNTER: int = 0x30
const OH_NO_DECAY: int = 2
const BANNER_Y: int = 0x48
const BANNER_X: int = 0xE0
const BANNER_STEP: int = 4
const INTRO_END_X: int = 0xC0
const COAST_FRAMES: int = 192
const GAME_OVER_FRAMES: int = 0x80
const RESULTS_DRAW_FRAMES: int = 32
const RESULTS_LINE_FRAMES: int = 64
const RESULTS_LAST_FRAMES: int = 128
const DRAIN_PER_FRAME: int = 99
const SPRAY_EVERY: int = 4
const SCORE_SPAWN_ABOVE: int = 0x10
const BOARD_ANGLE_EVERY: int = 8
const BOARD_ANGLE_MAX: int = 2
const JUMP_PIXELS: Array[int] = [3, 4]
const READ_AHEAD_PIXELS: int = 9 * Gen1Lcd.TILE
const GENERATE_AHEAD: int = 0xA0
const GENERATE_BEHIND: int = Gen1Lcd.MAP_SIDE * Gen1Lcd.TILE - 32
const SLICE_MASK: int = 0xF0
const WAVE_HEIGHT_MID: int = 7
const SPRAY_HEIGHT_MID: int = 8
const OVERRIDE_FIRST_LINE: int = 2 * Gen1Lcd.TILE
const OVERRIDE_LINES: int = Gen1Lcd.HEIGHT - 2 * Gen1Lcd.TILE
const LY_LINES: int = 256
const REDRAW_BYTES: int = 2 * Gen1Layout.SCREEN_WIDTH_TILES
const BUFFER_TILES: int = PokeTiles.TILE_BYTES

const GFX_1_VRAM: int = Gen1Lcd.SIGNED_BASE
const GFX_2_VRAM: int = 0
const GFX_3_VRAM: int = Gen1Lcd.BLOCK_TILES
const WATER_ROW: int = 6
const WATER_ROWS: int = 12
const HUD_WY: int = 0x7E
const LCDC_GAME: int = Gen1Lcd.LCDC_ON | Gen1Lcd.LCDC_WIN_MAP | Gen1Lcd.LCDC_WINDOW \
	| Gen1Lcd.LCDC_OBJS | Gen1Lcd.LCDC_BG
## `SetBGPals`' `.sgb` row: `LoadSGB` sets `wOnSGB` on a Game Boy Color too.
const OBP0: int = 0xE4
const OBP1: int = 0xE0
const BGP: int = 0xE4
const STATIC_SPRITES: Array[Array] = [[4, 0x97, 0x80], [1, 0x96, 0x50], [5, 0x14, 0x20], [4, 0x20, 0x80]]
const SLOT_HP: int = 0
const SLOT_MARKER: int = 4
const SLOT_CLOUDS: int = 5
const CLOUD_SLOTS: int = 9
const SLOT_OBJECTS: int = 15
const MARKER_STEP: int = 2
const STATUS_BAR_AT: Vector2i = Vector2i(1, 1)
const STATUS_CORNERS: Array = [[Vector2i(1, 0), 0x15], [Vector2i(2, 0), 0x16], [Vector2i(12, 1), 0x1B], [Vector2i(13, 1), 0x1C]]
const INTRO_BLANK: int = 0xFF
const INTRO_BEACH_AT: Vector2i = Vector2i(0, 6)
const INTRO_TITLE_AT: Vector2i = Vector2i(4, 0)
const INTRO_CLEAR_AT: Vector2i = Vector2i(3, 7)
const INTRO_CLEAR_SIZE: Vector2i = Vector2i(15, 3)
const INTRO_PAD_AT: Vector2i = Vector2i(3, 7)
const INTRO_RAD_AT: Vector2i = Vector2i(4, 9)
const OUTRO_AT: Vector2i = Vector2i(0, 6)
const RESULTS_BOX_ROWS: Array = [[1, 0x3B, 0x40, 0x3C], [9, 0x3D, 0x40, 0x3E]]
const RESULTS_BOX_SIDE: int = 0x3F
const RESULTS_BOX_FILL: int = 0xFF
const RESULTS_BOX_INNER_ROWS: Array[int] = [2, 3, 4, 5, 6, 7, 8]
const RESULTS_BOX_X: int = 1
const RESULTS_BOX_INNER: int = Gen1Layout.SCREEN_WIDTH_TILES - 4
const HI_SCORE_AT: Vector2i = Vector2i(6, 8)
const LINE_AT: Array[Vector2i] = [Vector2i(2, 2), Vector2i(2, 4), Vector2i(2, 6)]
const NUMBER_X: int = 10
const POINTS_X: int = 15
const POINTS_TILES: Array[int] = [0x21, 0x25, 0x26]

const AUDIO_BANK_SURFING: int = 0x20
const MUSIC_SURFING_PIKACHU: int = 153
const CLIP_NO_HIGH_SCORE: int = 27
const CLIP_HIGH_SCORE: int = 33
const TEMPO_DEFAULT: int = 117
const TEMPO_SPEED_MASK: int = 0x3FF

## Measured on the cartridge under a Color boot: what `BlankPals`, `DisableLCD`,
## the copies, `SetBGPals` and `RunPaletteCommand` each spend, and the frame a
## 99-step drain pass overruns VBlank by.
const BLANK_FRAMES: int = 4
const INTRO_LOAD_FRAMES: int = 3
const INTRO_LCD_FRAMES: int = 3
const INTRO_BGP_FRAMES: int = 2
const DISABLE_LCD_FRAMES: int = 1
const LAYOUT_LCD_OFF_FRAMES: int = 5
const LAYOUT_LCD_ON_FRAMES: int = 1
const TITLE_PALETTE_FRAMES: int = 6
const DRAIN_OVERRUN_FRAMES: int = 1
const OUTRO_FRAMES: int = 1

const PAD_A: int = 1 << 0
const PAD_SELECT: int = 1 << 2
const PAD_RIGHT: int = 1 << 4
const PAD_LEFT: int = 1 << 5
const JOY_BUFFER_FRAMES: int = 2

## The tempo the host's driver takes once every channel is between notes, or -1.
var tempo_request: int = -1

var _tables: Dictionary = {}
var _objects: Gen1AnimatedObjects = Gen1AnimatedObjects.new()
var _rng: RandomNumberGenerator = null
var _wave_picks: Array = []
var _surfing_pikachu: bool = false
var _select_quits: bool = false
var _hi_score: int = 0
var _hi_score_beaten: bool = false

var _held: int = 0
var _held_at_read: int = 0
var _tapped: int = 0
var _joy5: int = 0
var _frame_counter: int = 0

var _routine: int = 0
var _pikachu_state: int = 0
var _wave_function: int = 0
var _wave_random: int = 0
var _hp: int = 0
var _radness_meter: int = 0
var _radness: int = 0
var _total: int = 0
var _board_angle: int = 0
var _board_decreasing: bool = false
var _board_timer: int = 0
var _crash_timer: int = 0
var _speed: int = 0
var _distance: int = 0
var _distance_fraction: int = 0
var _wave_buffer: Array[int] = [0, 0]
var _pikachu_height: int = 0
var _spray_counter: int = 0
var _jump_magnitude: int = 0
var _jump_descending: bool = false
var _jump_fraction: int = 0
var _read_buffer: PackedByteArray = PackedByteArray()
var _read_pending: int = -1
var _scx_fraction: int = 0
var _scx2: int = 0
var _scx_high: int = 0
var _wave_height: PackedByteArray = PackedByteArray()
var _x_offset: int = 0
var _trick_flags: int = 0
var _game_over: bool = false
var _game_over_delay: int = 0
var _routine_delay: int = 0
var _intro_finished: bool = false
var _tempo_enabled: bool = false
var _cloud_fraction: int = 0
var _pikachu: int = -1
var _ly_overrides: PackedByteArray = PackedByteArray()
var _ly_pointer_on: bool = false
var _redraw: PackedByteArray = PackedByteArray()
var _redraw_column: int = -1
var _palette_command: String = "surfing"


## [param hi_score] is `wSurfingMinigameHiScore` in BCD, [param select_quits]
## BIT_PIKACHU_MAP_SURF_SELECT. Null off Yellow.
static func create(
	data: GameData, rng: RandomNumberGenerator, best: int, surfing_pikachu: bool,
	select_quits: bool
) -> Gen1SurfingMinigame:
	if data == null or data.surfing().is_empty():
		return null
	var out := Gen1SurfingMinigame.new()
	out._init_machine(data)
	out._tables = data.surfing()
	out._rng = rng
	out._hi_score = best
	out._surfing_pikachu = surfing_pikachu
	out._select_quits = select_quits
	out._objects.tables = out._tables
	out._objects.shadow = out.shadow_oam_buffer()
	out._objects.callback = out._callback
	out._read_buffer.resize(BUFFER_TILES)
	out._wave_height.resize(Gen1Layout.SCREEN_WIDTH_TILES)
	out._ly_overrides.resize(LY_LINES)
	out._redraw.resize(REDRAW_BYTES)
	out.lcd.cgb = true
	out._build()
	return out


## The cartridge's own `Random` bytes for a trace.
func set_wave_picks(picks: Array) -> void:
	_wave_picks = picks.duplicate()


func press(button: int) -> void:
	_held |= button
	_tapped |= button


func release(button: int) -> void:
	_held &= ~button


func routine() -> int:
	return _routine


func pikachu_state() -> int:
	return _pikachu_state


func total_score() -> int:
	return _total


func hi_score() -> int:
	return _hi_score


func hi_score_beaten() -> bool:
	return _hi_score_beaten


func distance() -> int:
	return _distance


func hp() -> int:
	return _hp


func speed() -> int:
	return _speed


func pikachu_height() -> int:
	return _pikachu_height


func wave_function() -> int:
	return _wave_function


func wave_random() -> int:
	return _wave_random


func palettes() -> Array[PackedColorArray]:
	var out: Array[PackedColorArray] = []
	for palette: Variant in (_data.opening().get("palettes", {}) as Dictionary).get(_palette_command, []):
		var colors := PackedColorArray()
		for packed: Variant in palette as Array:
			colors.append(PokePalette.from_packed(int(packed)))
		out.append(colors)
	return out


func blocks() -> Array:
	return (_data.opening().get("blocks", {}) as Dictionary).get(_palette_command, [])


func _end_frame() -> void:
	_tapped = 0


func _read_pressed() -> int:
	var pressed: int = (_held & ~_held_at_read) | _tapped
	_held_at_read = _held
	return pressed


func _set_palette_command(name: String) -> void:
	_palette_command = name
	if lcd.cgb:
		lcd.load_attributes(RomCache.packed_bytes(
			(_data.opening().get("attributes", {}) as Dictionary).get(name, [])
		))


func _build() -> void:
	_steps = [
		do_step(func() -> void: set_palettes(0, 0, 0)),
		delay_step(BLANK_FRAMES),
		do_step(func() -> void: _transfer_dest = DEST_MAP0),
	]
	_steps.append_array(_intro_steps())
	_steps.append_array(_loop_steps())
	_steps.append_array([
		do_step(_leave),
		delay_step(OUTRO_FRAMES),
		{"finish": &"surfing_finished"},
	])
	_index_labels()


## `SurfingPikachuMinigameIntro`.
func _intro_steps() -> Array:
	return [
		do_step(func() -> void: lcd.lcdc &= ~Gen1Lcd.LCDC_ON),
		delay_step(DISABLE_LCD_FRAMES),
		do_step(func() -> void:
			_fill_tilemap(0)
			_clear_sprites()
			lcd.clear_oam()
			_transfer_enabled = false
			_objects.clear()
			_load_sheet("surfing_gfx_3", GFX_3_VRAM)
			_objects.spawn(OBJECT_INTRO, CENTER_X, FLAT_WATER_Y)
			_draw_intro_background()
			set_scroll(0, 0)
			set_window(WINDOW_OFF)
			_set_palette_command("surfing")),
		delay_step(INTRO_LOAD_FRAMES),
		do_step(func() -> void:
			lcd.lcdc = LCDC_GAME
			_transfer_enabled = true),
		delay_step(INTRO_LCD_FRAMES),
		do_step(func() -> void: set_palettes(BGP, OBP0, OBP1)),
		delay_step(INTRO_BGP_FRAMES),
		do_step(func() -> void:
			_play_music(MUSIC_SURFING_PIKACHU, AUDIO_BANK_SURFING)
			_intro_finished = false),
		until_step(func() -> bool:
			if _intro_finished:
				return true
			_objects.run(0)
			return false),
	]


func _draw_intro_background() -> void:
	var tilemaps: Dictionary = _tables.get("tilemaps", {})
	_fill_tilemap(INTRO_BLANK)
	_write_tilemap(INTRO_BEACH_AT, Gen1Layout.SURFING_BEACH_INTRO.x, Gen1Layout.SURFING_BEACH_INTRO.y, tilemaps.get("beach_intro", []))
	_write_tilemap(INTRO_TITLE_AT, Gen1Layout.SURFING_TITLE_TILEMAP.x, Gen1Layout.SURFING_TITLE_TILEMAP.y, tilemaps.get("title", []))
	for row: int in INTRO_CLEAR_SIZE.y:
		for column: int in INTRO_CLEAR_SIZE.x:
			_tilemap[(INTRO_CLEAR_AT.y + row) * COLUMNS + INTRO_CLEAR_AT.x + column] = INTRO_BLANK
	var pad: Array = tilemaps.get("use_control_pad", [])
	_write_tilemap(INTRO_PAD_AT, pad.size(), 1, pad)
	var rad: Array = tilemaps.get("to_surf_rad", [])
	_write_tilemap(INTRO_RAD_AT, rad.size(), 1, rad)


## `SurfingPikachuLoop`.
func _loop_steps() -> Array:
	return [
		do_step(func() -> void: lcd.lcdc &= ~Gen1Lcd.LCDC_ON),
		delay_step(DISABLE_LCD_FRAMES),
		do_step(_load_layout),
		delay_step(LAYOUT_LCD_OFF_FRAMES),
		do_step(func() -> void:
			lcd.lcdc = LCDC_GAME
			set_palettes(BGP, OBP0, OBP1)),
		delay_step(LAYOUT_LCD_ON_FRAMES),
		do_step(func() -> void: _set_palette_command("surfing_title")),
		delay_step(TITLE_PALETTE_FRAMES),
		until_step(func() -> Variant:
			if _routine & ROUTINE_DONE:
				return true
			_read_joypad()
			if _select_quits and _read_pressed() & PAD_SELECT:
				return true
			var more: Array = _run_routine()
			if more.is_empty():
				_loop_tail()
				return false
			more.append(do_step(_loop_tail))
			more.append(delay_step(1))
			return more),
	]


func _loop_tail() -> void:
	_objects.run(SLOT_OBJECTS * Gen1Lcd.OAM_BYTES)
	_move_clouds()
	_update_music_tempo()


func _load_layout() -> void:
	_fill_tilemap(0)
	_clear_sprites()
	lcd.clear_oam()
	_reset_data()
	_ly_overrides.fill(0)
	_transfer_enabled = false
	_objects.clear()
	_load_sheet("surfing_gfx_1", GFX_1_VRAM)
	_load_sheet("surfing_gfx_2", GFX_2_VRAM)
	lcd.fill_map(0, 0)
	lcd.fill_map(1, 0)
	var water := PackedByteArray()
	water.resize(WATER_ROWS * Gen1Lcd.MAP_SIDE)
	water.fill(TILE_WATER)
	lcd.write_map(0, Vector2i(0, WATER_ROW), Gen1Lcd.MAP_SIDE, WATER_ROWS, water)
	_pikachu = _objects.spawn(OBJECT_PIKACHU, CENTER_X, FLAT_WATER_Y)
	_pikachu_height = FLAT_WATER_Y
	_init_scanline_overrides()
	set_scroll(0, 0)
	set_window(HUD_WY)
	_ly_pointer_on = true
	_speed = SPEED_START
	_hp = HP_START << 8
	_wave_height.fill(FLAT_WATER_Y)
	_init_static_sprites()
	_draw_status_bar()


func _reset_data() -> void:
	_routine = 0
	_pikachu_state = 0
	_wave_function = 0
	_wave_random = 0
	_hp = 0
	_radness_meter = 0
	_radness = 0
	_total = 0
	_board_angle = 0
	_board_decreasing = false
	_board_timer = 0
	_crash_timer = 0
	_speed = 0
	_distance = 0
	_distance_fraction = 0
	_wave_buffer = [0, 0]
	_pikachu_height = 0
	_spray_counter = 0
	_jump_magnitude = 0
	_jump_descending = false
	_jump_fraction = 0
	_read_buffer.fill(0)
	_read_pending = -1
	_scx_fraction = 0
	_scx2 = 0
	_scx_high = 0
	_wave_height.fill(0)
	_x_offset = 0
	_trick_flags = 0
	_game_over = false
	_game_over_delay = 0
	_routine_delay = 0
	_intro_finished = false
	_tempo_enabled = false
	_cloud_fraction = 0
	_redraw.fill(0)
	_redraw_column = -1


func _init_scanline_overrides() -> void:
	var sine: Array = _tables.get("ly_sine", [])
	for line: int in LY_LINES:
		_ly_overrides[line] = int(sine[line % sine.size()]) & 0xFF if not sine.is_empty() else 0


func _init_static_sprites() -> void:
	var tiles: Array = _tables.get("static_tiles", [])
	var order: Array[int] = [1, 0, 5, 10]
	var slot: int = SLOT_HP
	for index: int in STATIC_SPRITES.size():
		var row: Array = STATIC_SPRITES[index]
		var x: int = int(row[2])
		for count: int in int(row[0]):
			var tile: int = int(tiles[order[index] + count]) if order[index] + count < tiles.size() else 0
			_set_sprite(slot, int(row[1]), x, tile, 0)
			slot += 1
			x += Gen1Lcd.TILE


func _draw_status_bar() -> void:
	var bar: Array = _tables.get("status_bar", [])
	write_map(1, STATUS_BAR_AT, bar.size(), 1, bar)
	for corner: Array in STATUS_CORNERS:
		write_map(1, corner[0], 1, 1, [int(corner[1])])


## `SurfingPikachu_GetJoypad_3FrameBuffer`: `hFrameCounter` is set to 2, so the
## pad is sampled every other frame.
func _read_joypad() -> void:
	if _frame_counter != 0:
		_joy5 = 0
		return
	_joy5 = _held
	_frame_counter = JOY_BUFFER_FRAMES


## `RunSurfingMinigameRoutine`; the steps a state spends outside the loop come back.
func _run_routine() -> Array:
	match _routine:
		Routine.START:
			_objects.spawn(OBJECT_START, BANNER_X, BANNER_Y)
			_routine += 1
			_tempo_enabled = true
		Routine.RUN:
			_run_game()
		Routine.WAIT_RESULTS:
			_wait_to_show_results()
		Routine.SCROLL_RESULTS:
			_scroll_to_results()
		Routine.DRAW_RESULTS:
			_draw_results_screen()
			_routine_delay = RESULTS_DRAW_FRAMES
			_routine += 1
		Routine.HP_LEFT, Routine.RADNESS, Routine.TOTAL:
			if _delay_ran_out():
				_write_results_line(_routine - Routine.HP_LEFT)
				_routine_delay = RESULTS_LINE_FRAMES
				_routine += 1
		Routine.ADD_HP:
			if _delay_ran_out():
				if _drain_hp():
					_routine_delay = RESULTS_LINE_FRAMES
					_routine += 1
				return [delay_step(DRAIN_OVERRUN_FRAMES)]
		Routine.ADD_RADNESS:
			if _delay_ran_out():
				var spent: bool = _drain_radness()
				if spent:
					_routine_delay = RESULTS_LAST_FRAMES
					_routine += 1
				return [delay_step(DRAIN_OVERRUN_FRAMES)] + (_high_score_steps() if spent else [])
		Routine.WAIT_LAST:
			if _delay_ran_out():
				_routine += 1
		Routine.EXIT:
			_update_ly_overrides()
			if _read_pressed() & PAD_A:
				_routine |= ROUTINE_DONE
		Routine.GAME_OVER:
			_game_over_routine()
	return []


func _run_game() -> void:
	if _distance >= COURSE_SECTIONS:
		_routine += 1
		_tempo_enabled = false
		_routine_delay = COAST_FRAMES
		return
	if _hp == 0:
		_game_over = true
		_routine = Routine.GAME_OVER
		_game_over_delay = GAME_OVER_FRAMES
		var index: int = _objects.spawn(OBJECT_OH_NO, CENTER_X, OH_NO_Y)
		if index >= 0:
			var struct: PackedByteArray = _objects.object(index)
			struct[Gen1AnimatedObjects.STRUCT_YOFF] = OH_NO_BOUNCE
			struct[Gen1AnimatedObjects.STRUCT_VAR1] = OH_NO_BOUNCE
			struct[Gen1AnimatedObjects.STRUCT_VAR2] = OH_NO_COUNTER
		_tempo_enabled = false
		return
	_wave_random = _roll()
	_update_ly_overrides()
	_set_pikachu_height()
	_read_bg_map()
	_scroll_and_generate()
	_update_distance()
	_hp = _bcd_deduct_word(_hp)
	_draw_hp()


func _roll() -> int:
	if not _wave_picks.is_empty():
		return int(_wave_picks.pop_front()) & 0xFF
	return _rng.randi() & 0xFF if _rng != null else 0


func _wait_to_show_results() -> void:
	if not _delay_ran_out():
		_wave_random = 0
		_update_ly_overrides()
		_set_pikachu_height()
		_read_bg_map()
		_x_offset = GENERATE_AHEAD
		_scroll_by(COAST_STEP)
		_generate_bg_map()
		_reset_music_tempo()
		return
	_routine += 1
	set_scroll(RESULTS_SCX, 0)
	_wave_function = RESULTS_WAVE
	_pikachu_state = PikachuState.GAME_END
	_ly_pointer_on = false
	_scx_fraction = 0
	_scx2 = 0
	_scx_high = 0


func _scroll_to_results() -> void:
	if scroll_x() == 0:
		_speed = 0
		_routine += 1
		_pikachu_state = PikachuState.INIT_RESULTS
		return
	_update_ly_overrides()
	_set_pikachu_height()
	_read_bg_map()
	set_scroll((scroll_x() - RESULTS_SCROLL_STEP) & 0xFF, 0)
	_x_offset = GENERATE_BEHIND
	_generate_bg_map()


func _game_over_routine() -> void:
	_update_ly_overrides()
	_set_pikachu_height()
	_read_bg_map()
	_scroll_and_generate()
	_reset_music_tempo()
	if _game_over_delay != 0:
		_game_over_delay -= 1
		return
	if _read_pressed() & PAD_A:
		_routine |= ROUTINE_DONE


func _delay_ran_out() -> bool:
	if _routine_delay == 0:
		return true
	_routine_delay -= 1
	return false


## `UpdatePikachuDistance`: a section is a carry out of the 16-bit fraction.
func _update_distance() -> void:
	_distance_fraction += _speed
	if _distance_fraction >= 0x10000:
		_distance_fraction &= 0xFFFF
		_distance = (_distance + 1) & 0xFF
		_set_sprite_byte(SLOT_MARKER, 1, _sprite_byte(SLOT_MARKER, 1) - MARKER_STEP)


func _update_ly_overrides() -> void:
	var first: int = _ly_overrides[OVERRIDE_FIRST_LINE]
	for line: int in OVERRIDE_LINES:
		_ly_overrides[OVERRIDE_FIRST_LINE + line] = _ly_overrides[OVERRIDE_FIRST_LINE + line + 1]
	_ly_overrides[OVERRIDE_FIRST_LINE + OVERRIDE_LINES] = first


## `SetPikachuHeight`: a slope tile slides the sample by `hSCX`'s pixel in the tile.
func _height_at(mid: int, tile: int) -> int:
	var sample: int = _wave_height[mid + (1 if scroll_x() & Gen1Lcd.TILE else 0)]
	var pixel: int = scroll_x() & 7
	if tile == TILE_RISING or tile == TILE_CREST:
		return (sample - pixel) & 0xFF
	if tile == TILE_FALLING:
		return (sample + pixel) & 0xFF
	return sample


func _set_pikachu_height() -> void:
	_pikachu_height = _height_at(WAVE_HEIGHT_MID, _read_buffer[0])


## `ReadBGMapBuffer`: `VBlankCopy` reads the tile at the next VBlank.
func _read_bg_map() -> void:
	var column: int = ((scroll_x() + READ_AHEAD_PIXELS) & 0xFF) >> 3
	var row: int = _pikachu_height >> 3
	_read_pending = (row * Gen1Lcd.MAP_SIDE + column) & (Gen1Lcd.MAP_BYTES - 1)


func _scroll_by(step: int) -> void:
	var scrolled: int = (scroll_x() << 8 | _scx_fraction) + step
	_scx_fraction = scrolled & 0xFF
	set_scroll((scrolled >> 8) & 0xFF, 0)


func _scroll_and_generate() -> void:
	_x_offset = GENERATE_AHEAD
	_scroll_by(SCROLL_STEP)
	_generate_bg_map()


## `GenerateBGMap`: a slice a sixteen-pixel boundary, a column at the next VBlank.
func _generate_bg_map() -> void:
	if scroll_x() == _scx2:
		return
	_scx2 = scroll_x()
	var high: int = scroll_x() & SLICE_MASK
	if high == _scx_high:
		return
	_scx_high = high
	var slice: Dictionary = _wave_data()
	_wave_buffer = [int(slice["left"]), int(slice["right"])]
	for index: int in Gen1Layout.SCREEN_WIDTH_TILES - 2:
		_wave_height[index] = _wave_height[index + 2]
	_wave_height[Gen1Layout.SCREEN_WIDTH_TILES - 2] = _wave_buffer[0]
	_wave_height[Gen1Layout.SCREEN_WIDTH_TILES - 1] = _wave_buffer[1]
	var metatiles: Array = _tables.get("metatiles", [])
	var pattern: Array = (_tables.get("wave_patterns", []) as Array)[int(slice["pattern"])]
	for index: int in pattern.size():
		var metatile: Array = metatiles[int(pattern[index])]
		for byte: int in Gen1Layout.SURFING_METATILE_TILES:
			_redraw[index * Gen1Layout.SURFING_METATILE_TILES + byte] = int(metatile[byte])
	_redraw_column = (((scroll_x() + _x_offset) & 0xFF) & SLICE_MASK) >> 3


func _wave_data() -> Dictionary:
	var functions: Array = _tables.get("wave_functions", [])
	var row: Dictionary = functions[_wave_function] if _wave_function < functions.size() else {"kind": "choose"}
	if String(row["kind"]) == "choose":
		_choose_next_wave()
		return {"left": FLAT_WATER_Y, "right": FLAT_WATER_Y, "pattern": 0}
	match String(row["kind"]):
		"advance":
			_wave_function = (_wave_function + 1) & 0xFF
		"reset":
			_wave_function = 0
	return row


## `ChooseNextWaveSequence`: the Big Kahuna at section 22, flat water past it.
func _choose_next_wave() -> void:
	if _distance == BIG_KAHUNA_SECTION:
		_wave_function = BIG_KAHUNA_WAVE
		return
	if _distance > BIG_KAHUNA_SECTION or _wave_random == 0:
		return
	var starts: Array = _tables.get("wave_starts", [])
	_wave_function = int(starts[(_wave_random - 1) & 7])


func _bcd_deduct_word(word: int) -> int:
	var low: int = word & 0xFF
	var high: int = word >> 8
	if low != 0:
		return high << 8 | _bcd_decrement(low)
	low = 0x99
	high = 0x99 if high == 0 else _bcd_decrement(high)
	return high << 8 | low


static func _bcd_decrement(byte: int) -> int:
	if byte & 0xF == 0:
		return ((byte - 0x10) & 0xF0) | 9
	return byte - 1


static func _bcd_increment(byte: int) -> int:
	if byte & 0xF == 9:
		return (byte + 0x10) & 0xF0
	return byte + 1


## `AddPointsToTotal`: 9999 on a carry out of the second byte.
static func _bcd_add_word(word: int, amount: int) -> int:
	var low: int = _bcd_add_byte(word & 0xFF, amount)
	var high: int = word >> 8
	if low >= 0x100:
		low &= 0xFF
		high = _bcd_add_byte(high, 1)
		if high >= 0x100:
			return 0x9999
	return high << 8 | low


static func _bcd_add_byte(byte: int, amount: int) -> int:
	var sum: int = (byte & 0xF) + (amount & 0xF)
	var carry: int = 0
	if sum > 9:
		sum += 6
	var high: int = (byte >> 4) + (amount >> 4) + (sum >> 4)
	sum &= 0xF
	if high > 9:
		high += 6
		carry = 1
	return carry << 8 | (high & 0xF) << 4 | sum


func _draw_hp() -> void:
	for digit: int in 4:
		var nybble: int = (_hp >> ((3 - digit) * 4)) & 0xF
		_set_sprite_byte(SLOT_HP + digit, 2, HP_DIGIT_TILE + nybble)


func _draw_results_screen() -> void:
	_fill_tilemap(0)
	_write_tilemap(OUTRO_AT, Gen1Layout.SURFING_BEACH_OUTRO.x, Gen1Layout.SURFING_BEACH_OUTRO.y,
		(_tables.get("tilemaps", {}) as Dictionary).get("beach_outro", []))
	for row: Array in RESULTS_BOX_ROWS:
		_place_box_row(int(row[0]), int(row[1]), int(row[2]), int(row[3]))
	for row: int in RESULTS_BOX_INNER_ROWS:
		_place_box_row(row, RESULTS_BOX_SIDE, RESULTS_BOX_FILL, RESULTS_BOX_SIDE)
	for byte: int in range(SLOT_CLOUDS * Gen1Lcd.OAM_BYTES + 1,
			SLOT_CLOUDS * Gen1Lcd.OAM_BYTES + 1 + CLOUD_SLOTS * Gen1Lcd.OAM_BYTES):
		set_shadow_byte(byte, 0)
	_transfer_enabled = true


func _place_box_row(row: int, left: int, fill: int, right: int) -> void:
	var ids: Array = [left]
	for _column: int in RESULTS_BOX_INNER:
		ids.append(fill)
	ids.append(right)
	_write_tilemap(Vector2i(RESULTS_BOX_X, row), ids.size(), 1, ids)


func _write_results_line(line: int) -> void:
	var texts: Dictionary = _tables.get("texts", {})
	var names: Array[String] = ["hp_left", "radness", "total"]
	var label: Array = texts.get(names[line], [])
	_write_tilemap(LINE_AT[line], label.size(), 1, label)
	match line:
		0:
			_print_number(LINE_AT[0].y, _hp)
		1:
			_print_number(LINE_AT[1].y, _radness)
		2:
			_print_number(LINE_AT[1].y, _radness)
			_print_number(LINE_AT[2].y, _total)


func _print_number(row: int, word: int) -> void:
	var ids: Array = []
	for digit: int in 4:
		ids.append(HP_DIGIT_TILE + ((word >> ((3 - digit) * 4)) & 0xF))
	_write_tilemap(Vector2i(NUMBER_X, row), ids.size(), 1, ids)
	_write_tilemap(Vector2i(POINTS_X, row), POINTS_TILES.size(), 1, POINTS_TILES)


## `AddRemainingHPToTotal`: 99 a frame under `SFX_PRESS_AB`, true once spent.
func _drain_hp() -> bool:
	for _step: int in DRAIN_PER_FRAME:
		if _hp == 0:
			_print_number(LINE_AT[2].y, _total)
			return true
		_hp = _bcd_deduct_word(_hp)
		_total = _bcd_add_word(_total, 1)
	_play_sfx(Gen1Sfx.SFX_PRESS_AB)
	_print_number(LINE_AT[2].y, _total)
	return false


func _drain_radness() -> bool:
	for _step: int in DRAIN_PER_FRAME:
		if _radness == 0:
			_print_number(LINE_AT[2].y, _total)
			return true
		_radness = _bcd_deduct_word(_radness)
		_total = _bcd_add_word(_total, 1)
	_play_sfx(Gen1Sfx.SFX_PRESS_AB)
	_print_number(LINE_AT[2].y, _total)
	return false


## `DidPlayerGetAHighScore`: the cry is the surfing starter's alone.
func _high_score_steps() -> Array:
	_hi_score_beaten = _total > _hi_score
	if _hi_score_beaten:
		_hi_score = _total
	var steps: Array = [wait_sound_step()]
	if _surfing_pikachu:
		steps.append_array(pikachu_clip_steps(CLIP_HIGH_SCORE if _hi_score_beaten else CLIP_NO_HIGH_SCORE))
	if _hi_score_beaten:
		steps.append(do_step(func() -> void:
			_play_sfx(Gen1Sfx.SFX_GET_ITEM2_4_2)
			var text: Array = (_tables.get("texts", {}) as Dictionary).get("hi_score", [])
			_write_tilemap(HI_SCORE_AT, text.size(), 1, text)
			_pikachu_state = PikachuState.RESULTS))
	return steps


func _move_clouds() -> void:
	var moved: int = _speed + _cloud_fraction
	_cloud_fraction = moved & 0xFF
	var pixels: int = (moved >> 8) & 0xFF
	for slot: int in range(SLOT_CLOUDS, SLOT_CLOUDS + CLOUD_SLOTS):
		_set_sprite_byte(slot, 1, _sprite_byte(slot, 1) + pixels)


## `UpdateMusicTempo`: the live driver answers its note gate, so the tempo rides
## [member tempo_request].
func _update_music_tempo() -> void:
	tempo_request = -1
	if not _tempo_enabled:
		return
	var tempos: Array = _tables.get("tempos", [])
	var index: int = ((_speed & TEMPO_SPEED_MASK) * 2) >> 8
	if index < tempos.size():
		tempo_request = int(tempos[index])


func _reset_music_tempo() -> void:
	tempo_request = TEMPO_DEFAULT


func _callback(struct: PackedByteArray, _index: int) -> void:
	match struct[Gen1AnimatedObjects.STRUCT_CALLBACK]:
		CALLBACK_PIKACHU:
			_pikachu_callback(struct)
		CALLBACK_BANNER:
			if struct[Gen1AnimatedObjects.STRUCT_X] != CENTER_X:
				struct[Gen1AnimatedObjects.STRUCT_X] = (struct[Gen1AnimatedObjects.STRUCT_X] + BANNER_STEP) & 0xFF
		CALLBACK_FLIPPING:
			_flipping_callback(struct)
		CALLBACK_INTRO:
			var count: int = struct[Gen1AnimatedObjects.STRUCT_VAR1]
			struct[Gen1AnimatedObjects.STRUCT_VAR1] = (count + 1) & 0xFF
			if count & 1 == 0:
				return
			if struct[Gen1AnimatedObjects.STRUCT_X] == INTRO_END_X:
				_intro_finished = true
				struct[Gen1AnimatedObjects.STRUCT_LIVE] = 0
				return
			struct[Gen1AnimatedObjects.STRUCT_X] += 1


## `Oh no..` on a sine whose amplitude decays two a frame.
func _flipping_callback(struct: PackedByteArray) -> void:
	var amplitude: int = struct[Gen1AnimatedObjects.STRUCT_VAR1]
	if amplitude == 0:
		return
	struct[Gen1AnimatedObjects.STRUCT_VAR1] = (amplitude - OH_NO_DECAY) & 0xFF
	var angle: int = struct[Gen1AnimatedObjects.STRUCT_VAR2]
	struct[Gen1AnimatedObjects.STRUCT_VAR2] = (angle + 1) & 0xFF
	var offset: int = _sine(angle, amplitude) & 0xFF
	if offset >= 0x80:
		offset = (-offset) & 0xFF
	struct[Gen1AnimatedObjects.STRUCT_YOFF] = offset


func _pikachu_callback(struct: PackedByteArray) -> void:
	match _pikachu_state:
		PikachuState.RIDING:
			_riding(struct)
		PikachuState.JUMPING:
			_jumping(struct)
		PikachuState.LANDING:
			_landing(struct)
		PikachuState.CRASHED:
			if _crash_timer == 0:
				_pikachu_state = PikachuState.RIDING
				Gen1AnimatedObjects.set_frameset(struct, FRAMESET_FLAT)
				return
			_crash_timer -= 1
			struct[Gen1AnimatedObjects.STRUCT_Y] = _pikachu_height
		PikachuState.GAME_END:
			struct[Gen1AnimatedObjects.STRUCT_Y] = _pikachu_height
			_update_surfing_frame(struct)
		PikachuState.INIT_RESULTS:
			Gen1AnimatedObjects.set_frameset(struct, FRAMESET_RESULTS)
			struct[Gen1AnimatedObjects.STRUCT_VAR2] = 0
		PikachuState.RESULTS:
			var angle: int = struct[Gen1AnimatedObjects.STRUCT_VAR2]
			struct[Gen1AnimatedObjects.STRUCT_VAR2] = (angle + RESULTS_BOB_STEP) & 0xFF
			angle &= RESULTS_BOB_MASK
			struct[Gen1AnimatedObjects.STRUCT_YOFF] = _sine(angle, RESULTS_BOB_AMPLITUDE) & 0xFF \
				if angle >= RESULTS_BOB_HALF else 0


func _riding(struct: PackedByteArray) -> void:
	if _game_over:
		_speed = 0
		_pikachu_state = PikachuState.GAME_END
		_update_surfing_frame(struct)
		return
	_spawn_water_spray(struct)
	struct[Gen1AnimatedObjects.STRUCT_Y] = _pikachu_height
	if _try_start_jump():
		_update_surfing_frame(struct)
		_pikachu_state = PikachuState.JUMPING
		struct[Gen1AnimatedObjects.STRUCT_VAR2] = 0
		struct[Gen1AnimatedObjects.STRUCT_VAR3] = 0
		struct[Gen1AnimatedObjects.STRUCT_VAR4] = 0
		_radness_meter = 0
		_trick_flags = 0
		_play_sfx(Gen1Sfx.SFX_SURFING_JUMP)
		return
	_update_surfing_frame(struct)
	if _speed >> 8 < SPEED_CAP_HIGH:
		_speed = (_speed + SPEED_GAIN) & 0xFFFF


func _jumping(struct: PackedByteArray) -> void:
	_dpad_action(struct)
	if not _update_jump_height(struct):
		return
	var landing: int = _tile_interaction(struct[Gen1AnimatedObjects.STRUCT_FRAMESET])
	if landing == LANDING_WIPEOUT:
		_speed = SPEED_START
		_pikachu_state = PikachuState.CRASHED
		_crash_timer = CRASH_FRAMES
		Gen1AnimatedObjects.set_frameset(struct, FRAMESET_CRASH)
		_play_sfx(Gen1Sfx.SFX_SURFING_CRASH)
		return
	if landing == LANDING_HARD:
		_reduce_speed(SPEED_HARD_LOSS)
	elif landing == LANDING_ROUGH:
		_reduce_speed(SPEED_ROUGH_LOSS)
	_play_sfx(Gen1Sfx.SFX_SURFING_LAND)
	_add_stunt_radness(struct)
	struct[Gen1AnimatedObjects.STRUCT_VAR2] = 0
	_pikachu_state = PikachuState.LANDING


func _landing(struct: PackedByteArray) -> void:
	var counter: int = struct[Gen1AnimatedObjects.STRUCT_VAR2]
	if counter >= LANDING_FRAMES:
		struct[Gen1AnimatedObjects.STRUCT_YOFF] = 0
		_pikachu_state = PikachuState.RIDING
		return
	struct[Gen1AnimatedObjects.STRUCT_VAR2] = (counter + LANDING_STEP) & 0xFF
	struct[Gen1AnimatedObjects.STRUCT_YOFF] = _sine(counter, LANDING_AMPLITUDE) & 0xFF
	_spawn_water_spray(struct)
	struct[Gen1AnimatedObjects.STRUCT_Y] = _pikachu_height


## `DPadAction` on `hJoy5`: enough polls one way are a trick.
func _dpad_action(struct: PackedByteArray) -> void:
	if _joy5 & PAD_LEFT:
		struct[Gen1AnimatedObjects.STRUCT_VAR4] = 0
		var held: int = struct[Gen1AnimatedObjects.STRUCT_VAR3]
		struct[Gen1AnimatedObjects.STRUCT_VAR3] = (held + 1) & 0xFF
		if held >= TRICK_LEFT_FRAMES:
			_start_trick(struct)
			_trick_flags |= TRICK_LEFT
		var frameset: int = struct[Gen1AnimatedObjects.STRUCT_FRAMESET]
		struct[Gen1AnimatedObjects.STRUCT_FRAMESET] = FRAMESET_FIRST_ANGLE \
			if frameset >= FRAMESET_LAST_ANGLE else frameset + 1
	elif _joy5 & PAD_RIGHT:
		struct[Gen1AnimatedObjects.STRUCT_VAR3] = 0
		var held: int = struct[Gen1AnimatedObjects.STRUCT_VAR4]
		struct[Gen1AnimatedObjects.STRUCT_VAR4] = (held + 1) & 0xFF
		if held >= TRICK_RIGHT_FRAMES:
			_start_trick(struct)
			_trick_flags |= TRICK_RIGHT
		var frameset: int = struct[Gen1AnimatedObjects.STRUCT_FRAMESET]
		struct[Gen1AnimatedObjects.STRUCT_FRAMESET] = FRAMESET_LAST_ANGLE \
			if frameset == FRAMESET_FIRST_ANGLE else frameset - 1


func _start_trick(struct: PackedByteArray) -> void:
	_radness_meter = mini(_radness_meter + 1, RADNESS_CAP)
	struct[Gen1AnimatedObjects.STRUCT_VAR3] = 0
	struct[Gen1AnimatedObjects.STRUCT_VAR4] = 0
	_play_sfx(Gen1Sfx.SFX_SURFING_FLIP)


func _tile_interaction(frameset: int) -> int:
	var tile: int = _read_buffer[0]
	var key: int = tile if LANDINGS.has(tile) else (TILE_CREST if tile == TILE_FACE else -1)
	return int((LANDINGS[key] as Dictionary).get(frameset, LANDING_WIPEOUT))


func _reduce_speed(loss: int) -> void:
	if _speed >> 8 == 0 and (_speed & 0xFF) < loss:
		_speed = 0
		return
	_speed = (_speed - loss) & 0xFFFF


func _try_start_jump() -> bool:
	if (scroll_x() & 7) not in JUMP_PIXELS or _read_buffer[0] != TILE_CREST:
		return false
	var magnitude: int = (_speed >> 5) & 0xFF
	if magnitude < JUMP_MIN_SPEED:
		return false
	_jump_magnitude = magnitude
	_jump_descending = false
	_jump_fraction = 0
	return true


func _update_surfing_frame(struct: PackedByteArray) -> void:
	if (scroll_x() & 7) not in JUMP_PIXELS:
		return
	var tile: int = _read_buffer[0]
	if tile == TILE_RISING or tile == TILE_CREST:
		struct[Gen1AnimatedObjects.STRUCT_FRAMESET] = (FRAMESET_RISING + _board_angle - 1) & 0xFF
	elif tile == TILE_FALLING:
		struct[Gen1AnimatedObjects.STRUCT_FRAMESET] = (FRAMESET_FALLING + _board_angle - 1) & 0xFF
	else:
		_update_board_angle()
		struct[Gen1AnimatedObjects.STRUCT_FRAMESET] = FRAMESET_FLAT


func _update_board_angle() -> void:
	var timer: int = _board_timer
	_board_timer = (timer + 1) & 0xFF
	if timer & (BOARD_ANGLE_EVERY - 1) != 0:
		return
	if _board_decreasing:
		if _board_angle == 0:
			_board_decreasing = false
		else:
			_board_angle -= 1
		return
	if _board_angle == BOARD_ANGLE_MAX:
		_board_decreasing = true
	else:
		_board_angle += 1


func _spawn_water_spray(struct: PackedByteArray) -> void:
	var counter: int = _spray_counter
	_spray_counter = (counter + 1) & 0xFF
	if counter & (SPRAY_EVERY - 1) != 0:
		return
	_objects.spawn(OBJECT_SPRAY, struct[Gen1AnimatedObjects.STRUCT_X],
		_height_at(SPRAY_HEIGHT_MID, _read_buffer[1]))


## `UpdatePikachuHeight`: the arc moves by four times its velocity squared over
## 256; true on the frame the water is reached.
func _update_jump_height(struct: PackedByteArray) -> bool:
	if not _jump_descending:
		if _jump_magnitude == 0 and _jump_fraction == 0:
			_jump_descending = true
			return false
		_step_jump_velocity(-JUMP_STEP)
		## `.notDescending` negates `4 * a ** 2` a byte at a time and drops the carry.
		var rise: int = 4 * _jump_magnitude * _jump_magnitude
		_move_by_arc(struct, ((~rise) & 0xFF00) | (((~rise) & 0xFF) + 1) & 0xFF)
		return false
	var y: int = struct[Gen1AnimatedObjects.STRUCT_Y]
	if y < Gen1Lcd.HEIGHT and y >= _pikachu_height:
		struct[Gen1AnimatedObjects.STRUCT_Y] = _pikachu_height
		struct[Gen1AnimatedObjects.STRUCT_VAR2] = 0
		return true
	_step_jump_velocity(JUMP_STEP)
	_move_by_arc(struct, 4 * _jump_magnitude * _jump_magnitude)
	return false


func _step_jump_velocity(step: int) -> void:
	var velocity: int = ((_jump_magnitude << 8 | _jump_fraction) + step) & 0xFFFF
	_jump_fraction = velocity & 0xFF
	_jump_magnitude = velocity >> 8


func _move_by_arc(struct: PackedByteArray, delta: int) -> void:
	var position: int = ((struct[Gen1AnimatedObjects.STRUCT_Y] << 8
		| struct[Gen1AnimatedObjects.STRUCT_VAR2]) + delta) & 0xFFFF
	struct[Gen1AnimatedObjects.STRUCT_Y] = (position >> 8) & 0xFF
	struct[Gen1AnimatedObjects.STRUCT_VAR2] = position & 0xFF


## `CalculateAndAddRadnessFromStunt`: 50, 150 or 350 one way, 180 or 500 both.
func _add_stunt_radness(struct: PackedByteArray) -> void:
	if _radness_meter == 0:
		return
	var y: int = (struct[Gen1AnimatedObjects.STRUCT_Y] - SCORE_SPAWN_ABOVE) & 0xFF
	var x: int = struct[Gen1AnimatedObjects.STRUCT_X]
	if _trick_flags & (TRICK_LEFT | TRICK_RIGHT) != TRICK_LEFT | TRICK_RIGHT:
		var steps: int = (1 << _radness_meter) - 1
		for _step: int in steps:
			_radness = _bcd_add_word(_radness, RADNESS_STEP)
		_objects.spawn(OBJECT_PLUS_50 - 1 + _radness_meter, x, y)
		return
	if _radness_meter >= RADNESS_CAP:
		for _step: int in RADNESS_MIXED_STEPS:
			_radness = _bcd_add_word(_radness, RADNESS_STEP)
		_objects.spawn(OBJECT_PLUS_500, x, y)
		return
	for amount: int in RADNESS_PAIR:
		_radness = _bcd_add_word(_radness, amount)
	_objects.spawn(OBJECT_PLUS_180, x, y)


func _sine(angle: int, amplitude: int) -> int:
	var words: Array = _tables.get("sine_words", [])
	var index: int = angle & RESULTS_BOB_MASK
	var negative: bool = index >= RESULTS_BOB_HALF
	index &= RESULTS_BOB_HALF - 1
	if index >= words.size():
		return 0
	var value: int = ((int(words[index]) * amplitude) >> 8) & 0xFF
	return (-value) & 0xFF if negative else value


## `RedrawRowOrColumn`, `VBlankCopy` and the `LCD` interrupt's lines.
func _after_vblank() -> void:
	if _redraw_column >= 0:
		var map: PackedByteArray = lcd.maps[0]
		for row: int in ROWS:
			var at: int = (row * Gen1Lcd.MAP_SIDE + _redraw_column) & (Gen1Lcd.MAP_BYTES - 1)
			map[at] = _redraw[row * 2]
			map[(at + 1) & (Gen1Lcd.MAP_BYTES - 1)] = _redraw[row * 2 + 1]
		_redraw_column = -1
	if _read_pending >= 0:
		for byte: int in BUFFER_TILES:
			_read_buffer[byte] = lcd.maps[0][(_read_pending + byte) & (Gen1Lcd.MAP_BYTES - 1)]
		_read_pending = -1
	if _frame_counter > 0:
		_frame_counter -= 1
	if _ly_pointer_on:
		var lines := PackedInt32Array()
		lines.resize(Gen1Lcd.HEIGHT)
		for line: int in Gen1Lcd.HEIGHT:
			lines[line] = _ly_overrides[line]
		lcd.line_scy = lines
		lcd.line_lag = 1
	else:
		lcd.line_scy = PackedInt32Array()


## `ReloadMapAfterSurfingMinigame` and `PlayDefaultMusic` are the host's.
func _leave() -> void:
	set_palettes(0, 0, 0)
	_objects.clear()
	_clear_sprites()
	_ly_pointer_on = false
	set_scroll(0, 0)
	set_window(WINDOW_OFF)
	tempo_request = -1
