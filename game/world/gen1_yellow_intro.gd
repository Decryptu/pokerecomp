class_name Gen1YellowIntro
extends RefCounted

## Yellow's `PlayIntroScene` (engine/movie/intro_yellow.asm): eighteen scenes
## over `RunObjectAnimations` (engine/gfx/animated_objects.asm), ten object
## structs each walking a frameset of OAM sets into `wShadowOAM` once a frame.
## [Gen1Opening] owns the frame loop and the LCD.

## `wAnimatedObjectDataStructs`: ten of them, and the offsets read here.
const OBJECTS: int = 10
const STRUCT_LIVE: int = 0
const STRUCT_FRAMESET: int = 1
const STRUCT_CALLBACK: int = 2
const STRUCT_VTILE: int = 3
const STRUCT_X: int = 4
const STRUCT_Y: int = 5
const STRUCT_XOFF: int = 6
const STRUCT_YOFF: int = 7
const STRUCT_TIMER: int = 8
const STRUCT_DURATION_OFFSET: int = 9
const STRUCT_FRAME: int = 10
const STRUCT_VAR1: int = 11
const STRUCT_VAR2: int = 12
const STRUCT_SIZE: int = 16
const OAM_END: int = Gen1Lcd.OAM_SLOTS * Gen1Lcd.OAM_BYTES

## `SetCurrentAnimatedObjectOAMAttributes`.
const OAM_HIGH_PALS: int = 1 << 3
const FLIP_MASK: int = Gen1Lcd.OAM_XFLIP | Gen1Lcd.OAM_YFLIP | Gen1Lcd.OAM_PRIO
const FRAME_FLIP_SHIFT: int = 1
const FRAME_FLIP_MASK: int = 0xC0

## The two `wShadowOAM` attribute passes `.loop` runs on scenes 7 and 11.
const SCENE_SURF: int = 7
const SCENE_FLY: int = 11
const SCENE_DONE: int = 0x80
const SCENE_7_SLOTS: Array[int] = [8, 14, 16, 18, 19]
const SCENE_11_SLOTS: Array[int] = [18, 19, 20, 25, 26, 28]
const CGB_PALETTE_BIT: int = 1

const OBJECT_AT: int = 0x58
const RUN_TIMER: int = 130
const SCENE_TIMER: int = 128
const SURF_TIMER: int = 88
const FLASH_TIMER: int = 0x28
const END_FRAMES: int = 64
const TRANSFER_FRAMES: int = 3
## Frames between `InitYellowIntroGFXAndMusic`'s last copy and `PlayMusic`, measured.
const INIT_TAIL_FRAMES: int = 0
## The surf's passes overrun `DelayFrame` and spend two frames, measured.
const PASS_FRAMES: Dictionary = {7: [2]}
## `YellowIntro_BlankPalsDelay2AndDisableLCD`, then `YellowIntroPaletteAction`'s
## packet sent with the LCD off whether or not a Super Game Boy listens: five
## frames, six on the beach scenes, measured.
const BLANK_FRAMES: int = 2
const LCD_OFF_FRAMES: Dictionary = {2: 6, 4: 5, 6: 6, 8: 5, 10: 6, 12: 5}
const PALETTE_FRAMES: int = 1
const FLY_SCROLL_END: int = 0x68
const FLY_SCROLL_STEP: int = 4
const SURF_SCROLL_STEP: int = 2
const PALETTE_NORMAL: int = 0xE4
const PALETTE_OBP1_RUN: int = 0xC4
const PALETTE_OBP1_SCENE: int = 0xE0
const PALETTE_END: int = 0xFF
const FLASH_MASK: int = 3
const FLASH_OBP0: int = 0xFF
const FLASH_BGP: int = 3
const LCDC_SCENE: int = 0xE3
## `Func_fa079`'s amplitude and the surf's bob table.
const BOB_AMPLITUDE: int = 8
const SINE_MASK: int = 0x3F
const SINE_HALF: int = 0x20
const SINE_QUARTER_MASK: int = 0x1F

## `YellowIntroGraphics2` at `vChars0`, `1` at `vChars2`, the clouds at $60.
const GFX_2_VRAM: int = 0
const GFX_1_VRAM: int = 2 * Gen1Lcd.BLOCK_TILES
const CLOUD_VRAM: int = 2 * Gen1Lcd.BLOCK_TILES + 0x60
const CLOUD_TILES: int = 4
const CLOUD_FRAME_MASK: int = 7
const CLOUD_SET_MASK: int = 8
## The scenes' `vBGMap0` addresses as (column, row).
const FLY_PIC_AT: Vector2i = Vector2i(20, 6)
const FLY_PIC_SIDE: int = 6
const FLY_PIC_FIRST_TILE: int = 0x90
const FLY_PIC_ROW_STEP: int = 0x10
const SEA_TOP_ROWS: int = 3
const SEA_LINE_ROW: int = 3
const SEA_LINE_TILES: Array[int] = [0x20, 0x21]
const SEA_ROWS: int = 24
const SEA_TILE: int = 0x10
const SKY_ROWS: int = 8
const SKY_TILE: int = 2
const CLOSE_UP_AT: Vector2i = Vector2i(5, 6)
const CLOSE_UP_SIZE: Vector2i = Vector2i(12, 8)
const CLOSE_UP_FIRST_TILE: int = 4
const CLOSE_UP_ROW_STEP: int = 16
const CLOSE_UP_EXTRA: Array = [[Vector2i(4, 6), 3], [Vector2i(4, 7), 0x74], [Vector2i(5, 13), 0]]
const BAR_ROWS: int = 4
const BAR_TILE: int = 1
const FLY_BOX_AT: Array[Vector2i] = [Vector2i(0, 8), Vector2i(12, 4), Vector2i(3, 7)]
const SURF_OBJECT_AT: Vector2i = Vector2i(0xF8, 0x40)
const FLY_OBJECT_AT: Vector2i = Vector2i(0x58, 0x98)
const CLOSE_OBJECT_AT: Vector2i = Vector2i(0x58, 0x60)
const BOLT_OBJECT_AT: Vector2i = Vector2i(0x58, 0x68)
## `wLYOverrides`, its buffer, and the surf's seven-tile copy from line $10.
const LY_LINES: int = 256
const LY_COPY_FROM: int = 0x10
const LY_COPY_BYTES: int = 7 * PokeTiles.TILE_BYTES

var _host: Gen1Opening = null
var _data: GameData = null
var _yellow: Dictionary = {}
var _structs: Array[PackedByteArray] = []
var _scene: int = 0
var _timer: int = 0
var _pass: int = 0
var _current: int = -1
var _loaded: int = 0
var _oam_offset: int = 0
var _ly_pointer_on: bool = false
var _ly_overrides: PackedByteArray = PackedByteArray()
var _ly_buffer: PackedByteArray = PackedByteArray()
var _ly_copy_pending: bool = false
var _cloud_pending: int = -1


static func create(host: Gen1Opening, data: GameData) -> Gen1YellowIntro:
	var out := Gen1YellowIntro.new()
	out._host = host
	out._data = data
	out._yellow = data.opening().get("yellow", {})
	out._ly_overrides.resize(LY_LINES)
	out._ly_buffer.resize(LY_LINES)
	out._clear_objects()
	return out


## Frames one of `PikachuCriesPointerTable`'s clips holds the game.
static func pikachu_clip_frames(data: GameData, index: int) -> int:
	var cries: Array = data.gen1_pikachu().get("cries", []) if data != null else []
	if index < 0 or index >= cries.size():
		return 0
	return Gen1Layout.pikachu_cry_frames(int(cries[index]))


func finished() -> bool:
	return _scene & SCENE_DONE != 0


func scene() -> int:
	return _scene


## `InitYellowIntroGFXAndMusic` as steps.
func init_steps() -> Array:
	var steps: Array = [
		_host.do_step(func() -> void:
			_host.set_transfer(false, Gen1Opening.DEST_MAP0)
			_host.set_scroll(0, 0)
			_host.fill_tilemap(BAR_TILE)
			_host.fill_tilemap_rows(BAR_ROWS, Gen1Opening.ROWS - 2 * BAR_ROWS, 0)
			_host.set_transfer(true, Gen1Opening.DEST_MAP0)),
		_host.delay_step(TRANSFER_FRAMES),
		_host.do_step(func() -> void: _host.set_transfer(false, Gen1Opening.DEST_MAP0)),
	]
	steps.append_array(_host.copy_video_steps(
		"yellow_intro_gfx_2", GFX_2_VRAM, 0, Gen1Layout.YELLOW_INTRO_GFX_2_TILES
	))
	steps.append_array(_host.copy_video_steps(
		"yellow_intro_gfx_1", GFX_1_VRAM, 0, Gen1Layout.YELLOW_INTRO_GFX_1_TILES
	))
	steps.append(_host.delay_step(INIT_TAIL_FRAMES))
	steps.append(_host.do_step(func() -> void:
		_clear_objects()
		_host.set_palette_command("generic")
		_scene = 0
		_timer = 0
		_host.play_music(Gen1Opening.MUSIC_YELLOW_INTRO)))
	steps.append(_host.delay_step(1))
	return steps


## One pass of `.loop` as steps: the scene, `RunObjectAnimations`, `DelayFrame`.
func loop_steps() -> Array:
	var opened: int = _scene
	var index: int = _pass
	_pass += 1
	var steps: Array = _scene_steps()
	steps.append(_host.do_step(func() -> Array:
		_run_object_animations()
		if _scene == SCENE_SURF:
			_or_attributes(SCENE_7_SLOTS)
		elif _scene == SCENE_FLY:
			_or_attributes(SCENE_11_SLOTS)
		return [_host.delay_step(_pass_frames(opened, index))]))
	return steps


func _pass_frames(opened: int, index: int) -> int:
	if _scene != opened or not PASS_FRAMES.has(opened):
		return 1
	var cycle: Array = PASS_FRAMES[opened]
	return int(cycle[index % cycle.size()])


## `.go_to_title_screen`'s first frame.
func leave() -> void:
	_host.set_palettes(0, 0, 0)
	_ly_pointer_on = false
	_scene |= SCENE_DONE


## The VBlank's `VBlankCopy` and the `LCD` interrupt's lines for the frame.
func vblank() -> void:
	if _ly_copy_pending:
		for line: int in range(LY_COPY_FROM, LY_COPY_FROM + LY_COPY_BYTES):
			_ly_overrides[line] = _ly_buffer[line]
		_ly_copy_pending = false
	if _cloud_pending >= 0:
		_host.lcd.load_tiles(
			CLOUD_VRAM, _data.tile_indices("yellow_intro_clouds"),
			Gen1Layout.YELLOW_INTRO_CLOUD_TILES, _cloud_pending, CLOUD_TILES
		)
		_cloud_pending = -1
	if _ly_pointer_on:
		var lines := PackedInt32Array()
		lines.resize(Gen1Lcd.HEIGHT)
		for line: int in Gen1Lcd.HEIGHT:
			lines[line] = _ly_overrides[line]
		_host.lcd.line_scy = lines
		_host.lcd.line_lag = 1
	else:
		_host.lcd.line_scy = PackedInt32Array()


func _scene_steps() -> Array:
	match _scene:
		0:
			return [_host.do_step(_scene_0)]
		1, 5, 9:
			return [_host.do_step(_scene_wait_and_mask)]
		2:
			return _blank_then(_scene_2, "beach")
		3:
			return [_host.do_step(_scene_3)]
		4:
			return _blank_then(_scene_4, "generic")
		6:
			return _blank_then(_scene_6, "beach")
		7:
			return [_host.do_step(_scene_7)]
		8:
			return _blank_then(_scene_8, "generic")
		10:
			return _blank_then(_scene_10, "beach")
		11:
			return [_host.do_step(_scene_11)]
		12:
			return _blank_then(_scene_12, "generic")
		13:
			return [_host.do_step(_scene_13)]
		14:
			return [_host.do_step(_scene_14)]
		15:
			return [_host.do_step(_scene_15)]
		16:
			return [_host.do_step(_scene_16)]
		17:
			return [_host.delay_step(END_FRAMES), _host.do_step(func() -> void: _scene |= SCENE_DONE)]
	return []


## `YellowIntro_BlankPalsDelay2AndDisableLCD`, the body, `Func_f9e9a`.
func _blank_then(body: Callable, palette: String) -> Array:
	var opened: int = _scene
	return [
		_host.do_step(func() -> void: _host.set_palettes(0, 0, 0)),
		_host.delay_step(BLANK_FRAMES),
		_host.do_step(func() -> void:
			_host.lcd.lcdc &= ~Gen1Lcd.LCDC_ON
			body.call()),
		_host.delay_step(int(LCD_OFF_FRAMES.get(opened, 1))),
		_host.do_step(func() -> void:
			_host.set_palette_command(palette)
			_host.lcd.lcdc = LCDC_SCENE),
		_host.delay_step(PALETTE_FRAMES),
		_host.do_step(func() -> void:
			_host.set_scroll(0, 0)
			_host.set_window(Gen1Opening.WINDOW_OFF)
			_host.set_palettes(PALETTE_NORMAL, PALETTE_NORMAL, PALETTE_OBP1_SCENE)),
	]


func _next_scene() -> void:
	_scene += 1
	_pass = 0


## `YellowIntro_CheckFrameTimerDecrement`: true once the timer has run out.
func _timer_expired() -> bool:
	if _timer == 0:
		return true
	_timer -= 1
	return false


func _scene_0() -> void:
	_ly_pointer_on = false
	_current = _spawn(1, OBJECT_AT, OBJECT_AT)
	_host.set_scroll(0, 0)
	_host.set_window(Gen1Opening.WINDOW_OFF)
	_host.set_palettes(PALETTE_NORMAL, PALETTE_NORMAL, PALETTE_OBP1_RUN)
	_timer = RUN_TIMER
	_next_scene()


func _scene_wait_and_mask() -> void:
	if not _timer_expired():
		return
	_mask(_current)
	_next_scene()


## The flight: the picture past the screen's edge and eight speed bars.
func _scene_2() -> void:
	_ly_pointer_on = false
	_host.lcd.fill_map(0, 0)
	for row: int in FLY_PIC_SIDE:
		var ids: Array = []
		for column: int in FLY_PIC_SIDE:
			ids.append(FLY_PIC_FIRST_TILE + row * FLY_PIC_ROW_STEP + column)
		_host.write_map(0, FLY_PIC_AT + Vector2i(0, row), FLY_PIC_SIDE, 1, ids)
	# `ld e, [hl]`: the row's first byte is the X `SpawnAnimatedObject` takes in `e`.
	for bar: Array in _yellow.get("speed_bars", []):
		var index: int = _spawn(8, int(bar[0]), int(bar[1]))
		if index >= 0:
			_structs[index][STRUCT_VAR1] = int(bar[2])
	_timer = SCENE_TIMER
	_next_scene()


func _scene_3() -> void:
	if _timer_expired():
		_mask_all()
		_next_scene()
		return
	if _host.scroll_x() != FLY_SCROLL_END:
		_host.set_scroll((_host.scroll_x() + FLY_SCROLL_STEP) & 0xFF, 0)


func _scene_4() -> void:
	_ly_pointer_on = false
	_draw_bars()
	_current = _spawn(2, OBJECT_AT, OBJECT_AT)
	_timer = SCENE_TIMER
	_next_scene()


## `Func_f9e5f`: black bars on `vBGMap0`, four rows top and bottom.
func _draw_bars() -> void:
	_fill_rows(0, BAR_ROWS, BAR_TILE)
	_fill_rows(BAR_ROWS, Gen1Opening.ROWS - 2 * BAR_ROWS, 0)
	_fill_rows(Gen1Opening.ROWS - BAR_ROWS, BAR_ROWS, BAR_TILE)


func _fill_rows(first: int, count: int, id: int) -> void:
	var map: PackedByteArray = _host.lcd.maps[0]
	for cell: int in range(first * Gen1Lcd.MAP_SIDE, (first + count) * Gen1Lcd.MAP_SIDE):
		map[cell] = id


## The surf: the sine eight times over, the sea, `rSCY` handed to the interrupt.
func _scene_6() -> void:
	_ly_pointer_on = true
	var sine: Array = _yellow.get("sine", [])
	for line: int in LY_LINES:
		_ly_buffer[line] = int(sine[line % sine.size()]) & 0xFF if not sine.is_empty() else 0
	_fill_rows(0, SEA_TOP_ROWS, 0)
	var line_ids: Array = []
	for _pair: int in Gen1Lcd.MAP_SIDE / 2:
		line_ids.append_array(SEA_LINE_TILES)
	_host.write_map(0, Vector2i(0, SEA_LINE_ROW), Gen1Lcd.MAP_SIDE, 1, line_ids)
	_fill_rows(SEA_LINE_ROW + 1, SEA_ROWS, SEA_TILE)
	_current = _spawn(5, SURF_OBJECT_AT.x, SURF_OBJECT_AT.y)
	_timer = SURF_TIMER
	_next_scene()


func _scene_7() -> void:
	if _timer_expired():
		_mask(_current)
		_next_scene()
		return
	_host.set_scroll((_host.scroll_x() + SURF_SCROLL_STEP) & 0xFF, 0)
	var first: int = _ly_buffer[0]
	for line: int in LY_LINES - 1:
		_ly_buffer[line] = _ly_buffer[line + 1]
	_ly_buffer[LY_LINES - 1] = first
	_ly_copy_pending = true


func _scene_8() -> void:
	_ly_pointer_on = false
	_draw_bars()
	_current = _spawn(3, OBJECT_AT, OBJECT_AT)
	_timer = SCENE_TIMER
	_next_scene()


## The flight over the clouds: the sky, then the three tilemaps.
func _scene_10() -> void:
	_ly_pointer_on = false
	_host.lcd.fill_map(0, 0)
	_fill_rows(0, SKY_ROWS, SKY_TILE)
	var tilemaps: Array = _yellow.get("tilemaps", [])
	for index: int in mini(tilemaps.size(), FLY_BOX_AT.size()):
		var tilemap: Dictionary = tilemaps[index]
		_host.write_map(
			0, FLY_BOX_AT[index], int(tilemap["columns"]), int(tilemap["rows"]), tilemap["ids"]
		)
	_current = _spawn(6, FLY_OBJECT_AT.x, FLY_OBJECT_AT.y)
	_timer = SCENE_TIMER
	_next_scene()


func _scene_11() -> void:
	if _timer_expired():
		_mask(_current)
		_next_scene()
		return
	if _timer & CLOUD_FRAME_MASK != 0:
		return
	_cloud_pending = CLOUD_TILES if _timer & CLOUD_SET_MASK else 0


## The close-up: the 12x8 face from tile 4, four tiles skipped a row.
func _scene_12() -> void:
	_ly_pointer_on = false
	_draw_bars()
	for row: int in CLOSE_UP_SIZE.y:
		var ids: Array = []
		for column: int in CLOSE_UP_SIZE.x:
			ids.append(CLOSE_UP_FIRST_TILE + row * CLOSE_UP_ROW_STEP + column)
		_host.write_map(0, CLOSE_UP_AT + Vector2i(0, row), CLOSE_UP_SIZE.x, 1, ids)
	for extra: Array in CLOSE_UP_EXTRA:
		_host.write_map(0, extra[0], 1, 1, [int(extra[1])])
	_current = _spawn(9, CLOSE_OBJECT_AT.x, CLOSE_OBJECT_AT.y)
	_timer = SCENE_TIMER
	_next_scene()


func _scene_13() -> void:
	if not _timer_expired():
		return
	_spawn(10, BOLT_OBJECT_AT.x, BOLT_OBJECT_AT.y)
	_next_scene()


## `YellowIntroPalSequence_f9dd6`, then the bars through the screen buffer.
func _scene_14() -> Array:
	var value: int = _palette_step(_yellow.get("pal_flash", []))
	if value >= 0:
		_host.set_palettes(value, value, value & 0xF0)
		return []
	_mask_all()
	_host.clear_sprites()
	_host.fill_tilemap(BAR_TILE)
	_host.fill_tilemap_rows(BAR_ROWS, Gen1Opening.ROWS - 2 * BAR_ROWS, 0)
	_host.set_transfer(true, Gen1Opening.DEST_MAP0)
	return [
		_host.delay_step(TRANSFER_FRAMES),
		_host.do_step(func() -> void:
			_host.set_transfer(false, Gen1Opening.DEST_MAP0)
			_host.set_palettes(PALETTE_NORMAL, PALETTE_NORMAL, _host.lcd.obp1)
			_current = _spawn(7, OBJECT_AT, OBJECT_AT)
			_next_scene()
			_timer = FLASH_TIMER),
	]


## `YellowIntro_LoadDMGPalAndIncrementCounter`, -1 at the end.
func _palette_step(sequence: Array) -> int:
	var index: int = _timer
	_timer = (_timer + 1) & 0xFF
	if index >= sequence.size():
		return -1
	var value: int = int(sequence[index])
	return -1 if value == PALETTE_END else value


func _scene_15() -> void:
	if not _timer_expired():
		if _timer & FLASH_MASK == 0:
			_host.set_palettes(
				_host.lcd.bgp ^ FLASH_BGP, _host.lcd.obp0 ^ FLASH_OBP0, _host.lcd.obp1
			)
		return
	_ly_pointer_on = false
	_host.set_palettes(PALETTE_NORMAL, PALETTE_NORMAL, _host.lcd.obp1)
	_next_scene()
	# `.expired` runs on into `YellowIntroScene16` with no `ret` between them.
	_scene_16()


func _scene_16() -> void:
	var value: int = _palette_step(_yellow.get("pal_fade", []))
	if value >= 0:
		_host.set_palettes(value, value, _host.lcd.obp1)
		return
	_next_scene()


func _clear_objects() -> void:
	_structs = []
	for _index: int in OBJECTS:
		var object := PackedByteArray()
		object.resize(STRUCT_SIZE)
		_structs.append(object)
	_loaded = 0
	_oam_offset = 0


## `SpawnAnimatedObject`: the first free struct, or -1 with none left.
func _spawn(kind: int, x: int, y: int) -> int:
	var spawns: Array = _yellow.get("spawn_states", [])
	if kind >= spawns.size():
		return -1
	for index: int in OBJECTS:
		var object: PackedByteArray = _structs[index]
		if object[STRUCT_LIVE] != 0:
			continue
		_loaded += 1
		object.fill(0)
		object[STRUCT_LIVE] = _loaded & 0xFF
		object[STRUCT_FRAMESET] = int(spawns[kind][0])
		object[STRUCT_CALLBACK] = int(spawns[kind][1])
		object[STRUCT_X] = x & 0xFF
		object[STRUCT_Y] = y & 0xFF
		object[STRUCT_FRAME] = 0xFF
		return index
	return -1


func _mask(index: int) -> void:
	if index >= 0 and index < OBJECTS:
		_structs[index][STRUCT_LIVE] = 0


func _mask_all() -> void:
	for object: PackedByteArray in _structs:
		object[STRUCT_LIVE] = 0


## `RunObjectAnimations`, the rest of the buffer zeroed.
func _run_object_animations() -> void:
	_oam_offset = 0
	for index: int in OBJECTS:
		var object: PackedByteArray = _structs[index]
		if object[STRUCT_LIVE] == 0:
			continue
		_callback(object)
		if not _update_frame(object):
			return
	while _oam_offset < OAM_END:
		_host.set_shadow_byte(_oam_offset, 0)
		_oam_offset += 1


## `YellowIntro_AnimatedObjectJumptable`.
func _callback(object: PackedByteArray) -> void:
	match object[STRUCT_CALLBACK]:
		2:
			# `Func_fa008`: left four a frame to $58.
			if object[STRUCT_X] != OBJECT_AT:
				object[STRUCT_X] = (object[STRUCT_X] - 4) & 0xFF
		3:
			# `Func_fa014`: right four a frame to $58, Y from the X still in `a`.
			var a: int = object[STRUCT_X]
			if a != OBJECT_AT:
				a = (a + 4) & 0xFF
				object[STRUCT_X] = a
			if a != OBJECT_AT:
				object[STRUCT_Y] = (a + 1) & 0xFF
		4:
			# `Func_fa02b`: up two a frame to $58, then a bob off the sine.
			if object[STRUCT_VAR1] == 0:
				if object[STRUCT_Y] != OBJECT_AT:
					object[STRUCT_Y] = (object[STRUCT_Y] - 2) & 0xFF
					return
				object[STRUCT_VAR1] += 1
			var angle: int = object[STRUCT_VAR2]
			object[STRUCT_VAR2] = (angle + 1) & 0xFF
			object[STRUCT_YOFF] = _sine(angle, BOB_AMPLITUDE) & 0xFF
		5:
			# `Func_fa062`: X by the speed the spawn wrote.
			object[STRUCT_X] = (object[STRUCT_X] + object[STRUCT_VAR1]) & 0xFF


## `Func_fa079`: the sine's high byte times [param amplitude], negated past half.
func _sine(angle: int, amplitude: int) -> int:
	var words: Array = _yellow.get("sine_words", [])
	var index: int = angle & SINE_MASK
	var negative: bool = index >= SINE_HALF
	index &= SINE_QUARTER_MASK
	if index >= words.size():
		return 0
	var value: int = (int(words[index]) * amplitude) >> 8
	return -value if negative else value


## `UpdateCurrentAnimatedObjectFrame`; false once the buffer is full.
func _update_frame(object: PackedByteArray) -> bool:
	var frame: Dictionary = _advance_duration(object)
	var set_id: int = int(frame["set"])
	if set_id < 0:
		return true
	var sets: Array = _yellow.get("oam_sets", [])
	if set_id >= sets.size():
		return true
	var oam_set: Dictionary = sets[set_id]
	var vtile: int = (object[STRUCT_VTILE] + int(oam_set["tile"])) & 0xFF
	var flips: int = int(frame["flips"])
	for sprite: Array in oam_set["sprites"]:
		if _oam_offset >= OAM_END:
			return false
		var y: int = (object[STRUCT_Y] + object[STRUCT_YOFF]
			+ _flipped(int(sprite[0]), flips & Gen1Lcd.OAM_YFLIP)) & 0xFF
		var x: int = (object[STRUCT_X] + object[STRUCT_XOFF]
			+ _flipped(int(sprite[1]), flips & Gen1Lcd.OAM_XFLIP)) & 0xFF
		var attributes: int = ((int(sprite[3]) ^ flips) & FLIP_MASK) \
			| (int(sprite[3]) & Gen1Lcd.OAM_PAL1)
		if attributes & Gen1Lcd.OAM_PAL1:
			attributes |= OAM_HIGH_PALS
		_host.set_shadow_byte(_oam_offset, y)
		_host.set_shadow_byte(_oam_offset + 1, x)
		_host.set_shadow_byte(_oam_offset + 2, (vtile + int(sprite[2])) & 0xFF)
		if _scene != SCENE_SURF:
			_host.set_shadow_byte(_oam_offset + 3, attributes)
		_oam_offset += Gen1Lcd.OAM_BYTES
	return true


## `GetCurrentAnimatedObjectTileYCoordinate` and its X twin.
static func _flipped(offset: int, flipped: int) -> int:
	if flipped == 0:
		return offset
	return (-(offset + Gen1Lcd.TILE)) & 0xFF


## `UpdateDurationTimerAndFrameStateForCurrentAnimatedObject`.
func _advance_duration(object: PackedByteArray) -> Dictionary:
	var framesets: Array = _yellow.get("frames", [])
	var rows: Array = framesets[object[STRUCT_FRAMESET]] \
		if object[STRUCT_FRAMESET] < framesets.size() else []
	for _guard: int in 8:
		if object[STRUCT_TIMER] != 0:
			object[STRUCT_TIMER] -= 1
			var row: Array = _row(rows, object[STRUCT_FRAME])
			return {"set": int(row[0]), "flips": (int(row[1]) & FRAME_FLIP_MASK) >> FRAME_FLIP_SHIFT}
		object[STRUCT_FRAME] = (object[STRUCT_FRAME] + 1) & 0xFF
		var next: Array = _row(rows, object[STRUCT_FRAME])
		var command: int = int(next[0])
		if command == -2:
			object[STRUCT_TIMER] = 0
			object[STRUCT_FRAME] = 0xFF
			continue
		if command == -1:
			object[STRUCT_TIMER] = 0
			object[STRUCT_FRAME] = (object[STRUCT_FRAME] - 2) & 0xFF
			continue
		object[STRUCT_TIMER] = ((int(next[1]) & Gen1Layout.ANIM_FRAME_DURATION_MASK)
			+ object[STRUCT_DURATION_OFFSET]) & 0xFF
		return {"set": command, "flips": (int(next[1]) & FRAME_FLIP_MASK) >> FRAME_FLIP_SHIFT}
	return {"set": -1, "flips": 0}


static func _row(rows: Array, index: int) -> Array:
	if index < 0 or index >= rows.size():
		return [-1, 0]
	return rows[index]


func _or_attributes(slots: Array[int]) -> void:
	for slot: int in slots:
		var at: int = slot * Gen1Lcd.OAM_BYTES + 3
		_host.set_shadow_byte(at, _host.shadow_byte(at) | CGB_PALETTE_BIT)
