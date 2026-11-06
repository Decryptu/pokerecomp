class_name Gen3FieldMessage
extends RefCounted # `field_message_box.c` and `RenderText`: the dialogue frame and text printer, BG0 under [method overlay]; a window pixel is a nibble of [member _tiles].

enum State { HANDLE_CHAR, WAIT, CLEAR, SCROLL_START, SCROLL, WAIT_SE, PAUSE }
enum Render { REPEAT, UPDATE, PRINT, FINISH }

const BG_WORDS: int = 32 * 32
const WINDOW_TILE: int = 0x100
const FRAME_TILE: int = 0x200
const FRAME_TILES: int = 20
const STD_TILE: int = 0x214
const STD_TILES: int = 9
const STD_PALETTE: int = 14
const MENU_TILE: int = 0x220
const HELP_TILE: int = 0x300
const HELP_AREA := Rect2i(0, 15, 30, 5) # sHelpMessageWindowTemplate.
const HELP_ROWS: Array[int] = [0, 5, 14] # DrawHelpMessageWindowTilesById's top, middle and bottom tiles of msg_window.
const HELP_COLORS: Array = [10, CLEAR, 2] # sHelpMessageTextColors: a transparent background keeps the bar's tiles.
const HELP_TEXT_AT := Vector2i(2, 5)
const CLEAR: int = -1
const TILE_COUNT: int = 0x480
const PALETTE: int = 15
const SPEED_MID: int = 1
const AUTO_SCROLL_WAIT: int = 49
const ARROW_DELAY: int = 8
const ARROW_FRAMES: Array[int] = [0, 1, 2, 1]
const FONT_NORMAL: int = 0
const FONT_MALE: int = 1
const FONT_FEMALE: int = 2
const TEXT_RED: int = 4
const TEXT_BLUE: int = 8
const ENGINES: Dictionary = { # Cells, line height, colours (text, paper, shadow), first line, speeds, scroll steps, autoscroll delay.
	&"emerald": {"window": Rect2i(2, 15, 27, 4), "line": 16, "colors": [2, 1, 3], "top": 1, "speeds": [8, 4, 1],
		"scroll": [1, 2, 4], "auto_delay": 3},
	&"firered": {"window": Rect2i(2, 15, 26, 4), "line": 15, "colors": [2, 1, 3], "top": 1, "speeds": [8, 4, 1],
		"scroll": [1, 2, 4], "auto_delay": 1},
	&"ruby": {"window": Rect2i(2, 15, 26, 4), "line": 16, "colors": [1, 15, 8], "top": 0, "speeds": [6, 3, 1],
		"scroll": [1, 2, 4], "auto_delay": 1},
}
const RUBY_FRAME: Array = [[1, 3, 4, 4, 5, 6, 9], [11, 9, 9, 9, 9, 0x40B, 9], [7, 9, 9, 9, 9, 10, 9],
	[0x80B, 9, 9, 9, 9, 0xC0B, 9], [0x801, 0x803, 0x804, 0x804, 0x805, 0x806, 9]] # `sDialogueFrameTilemap`.

var visible: bool = false
var printing: bool = false
var signpost: bool = false
var text_speed: int = SPEED_MID
var _config: Dictionary = {}
var _engine: Dictionary = {}
var _engine_name: StringName
var _palette: Gen3Palette
var _window := Rect2i()
var _surface_tile: int = WINDOW_TILE # The window [method _put] draws on: the box, or a menu's while it prints.
var _surface_size := Vector2i.ZERO
var _tiles := PackedByteArray()
var _map := PackedInt32Array()
var _task: int = 0
var _text := PackedByteArray()
var _at: int = 0
var _x: int = 0
var _y: int = 0
var _state: int = State.HANDLE_CHAR
var _delay: int = 0
var _speed: int = 0
var _scroll: int = 0
var _sped_up: bool = false
var _can_speed_up: bool = true
var _auto: bool = false
var _auto_wait: int = 0
var _arrow_delay: int = 0
var _arrow_index: int = 0
var _font: int = FONT_NORMAL
var _colors: Array = []
var _pressed: bool = false
var _held: bool = false
var _requests: Array = []


func _init(config: Dictionary, engine: StringName, palette: Gen3Palette) -> void:
	_config = config
	_engine_name = engine
	_engine = ENGINES[engine]
	_palette = palette
	_window = _engine["window"]
	_surface_size = _window.size
	_tiles.resize(TILE_COUNT * GbaTiles.TILE_BYTES)
	_map.resize(BG_WORDS)


func show(text: PackedByteArray, mode: String, color: int, sign_frame: bool = false) -> void: # `ShowFieldMessage` and kin, once [param text] is expanded; [param color] is FRLG's `ContextNpcGetTextColor`.
	signpost = sign_frame
	_auto = mode == "messageautoscroll"
	_can_speed_up = not _auto
	_text = text
	_at = 0
	_x = 0
	_y = int(_engine["top"])
	_state = State.HANDLE_CHAR
	_delay = 0
	_scroll = 0
	_sped_up = false
	_auto_wait = 0
	_arrow_delay = 0
	_arrow_index = 0
	_colors = (_engine["colors"] as Array).duplicate()
	_font = FONT_NORMAL
	if _engine_name == &"firered" and color in [FONT_MALE - 1, FONT_FEMALE - 1]:
		_font = color + 1
		_colors[0] = TEXT_BLUE if color == 0 else TEXT_RED
	var delay: int = int(_engine["speeds"][text_speed])
	_speed = maxi(delay - 1, 0)
	printing = true
	_task = 0
	if mode == "messageinstant":
		_load_frame()
		_draw_frame()
		_run_all()


func hide() -> void: # HideFieldMessageBox, which clears only the box's rows.
	visible = false
	printing = false
	var frame_top: int = _window.position.y - 1
	for y: int in range(frame_top, 20):
		for x: int in 32:
			_map[y * 32 + x] = 0


func step(held: bool, pressed: bool, requests: Array) -> bool: # Task_DrawFieldMessage for one frame; requests a sound when a press answers a prompt. True on the frame the text ends.
	if not printing:
		return false
	_held = held
	_pressed = pressed
	_requests = requests
	match _task:
		0:
			_load_frame()
			_task = 1
		1:
			_draw_frame()
			_task = 2
		_:
			return _run()
	return false


func overlay() -> Dictionary:
	return {"bg0_map": _map, "bg0_tiles": _tiles, "bg0_scroll": Vector2i.ZERO} if visible or _map.count(0) != BG_WORDS else {}


func text_width(text: PackedByteArray) -> int: # The width [method Gen3Text] [param text] prints in, as `GetStringWidth` measures it.
	var width: int = 0
	var widths: PackedByteArray = _config["fonts"][FONT_NORMAL]["widths"]
	for code: int in text:
		if code != Gen3Text.EOS and code < widths.size():
			width += widths[code]
	return width


func draw_window(area: Rect2i, tile: int) -> void: # `AddTextPrinterParameterized` at once on a window: [param area] is its cells and [param tile] its first.
	_load_frame() # LoadMessageBoxAndBorderGfx: the window's text palette is the box's, and no box need have shown first.
	_load_std_frame()
	var at: Vector2i = area.position
	var size: Vector2i = area.size
	_std_word(at.x - 1, at.y - 1, 0)
	_std_word(at.x + size.x, at.y - 1, 2)
	_std_word(at.x - 1, at.y + size.y, 6)
	_std_word(at.x + size.x, at.y + size.y, 8)
	for x: int in size.x:
		_std_word(at.x + x, at.y - 1, 1)
		_std_word(at.x + x, at.y + size.y, 7)
	for y: int in size.y:
		_std_word(at.x - 1, at.y + y, 3)
		_std_word(at.x + size.x, at.y + y, 5)
		for x: int in size.x:
			_word(at.x + x, at.y + y, tile + y * size.x + x)
	_on_surface(tile, size, _fill)


func print_on(tile: int, size: Vector2i, at: Vector2i, text: PackedByteArray) -> void:
	_on_surface(tile, size, _print_all.bind(at, text))


func clear_rect_on(tile: int, size: Vector2i, area: Rect2i) -> void:
	_on_surface(tile, size, _clear_rect.bind(area))


func outline_on(tile: int, size: Vector2i, area: Rect2i) -> void: # R/S's box cursor, drawn in the text's colour.
	_on_surface(tile, size, _outline.bind(area))


func draw_help(text: PackedByteArray) -> void: # DrawHelpMessageWindowWithText, or PrintTextOnHelpMessageWindow over a bar already up.
	_palette.load(_config.get("help_palette", PackedByteArray()), PALETTE * 16)
	var bytes: PackedByteArray = _config.get("help", PackedByteArray())
	var size: Vector2i = HELP_AREA.size
	for y: int in size.y:
		var row: int = HELP_ROWS[0 if y == 0 else (2 if y == size.y - 1 else 1)] * GbaTiles.TILE_BYTES
		for x: int in size.x:
			var at: int = (HELP_TILE + y * size.x + x) * GbaTiles.TILE_BYTES
			for offset: int in GbaTiles.TILE_BYTES:
				_tiles[at + offset] = bytes[row + offset]
			_word(x, HELP_AREA.position.y + y, HELP_TILE + y * size.x + x)
	_on_surface(HELP_TILE, size, _print_help.bind(text))


func erase_help() -> void: # DestroyHelpMessageWindow.
	for y: int in HELP_AREA.size.y:
		for x: int in HELP_AREA.size.x:
			_map[(HELP_AREA.position.y + y) * 32 + x] = 0


func erase_window(area: Rect2i) -> void: # ClearToTransparentAndRemoveWindow, frame included.
	for y: int in range(area.position.y - 1, area.end.y + 1):
		for x: int in range(area.position.x - 1, area.end.x + 1):
			_map[y * 32 + x] = 0


func _on_surface(tile: int, size: Vector2i, body: Callable) -> void:
	var saved: Array = [_surface_tile, _surface_size, _x, _y, _font, _colors]
	_surface_tile = tile
	_surface_size = size
	_colors = (_engine["colors"] as Array).duplicate()
	_font = FONT_NORMAL
	body.call()
	_surface_tile = saved[0]
	_surface_size = saved[1]
	_x = saved[2]
	_y = saved[3]
	_font = saved[4]
	_colors = saved[5]


func _print_all(at: Vector2i, text: PackedByteArray) -> void:
	_x = at.x
	_y = at.y
	for code: int in text:
		if code == Gen3Text.EOS:
			return
		_draw_glyph(code)


func _print_help(text: PackedByteArray) -> void: # PrintHelpMessageText: one pixel between letters, and the box's line height.
	_colors = HELP_COLORS
	_x = HELP_TEXT_AT.x
	_y = HELP_TEXT_AT.y
	for code: int in text:
		if code == Gen3Text.EOS:
			return
		if code == Gen3Text.NEWLINE:
			_x = HELP_TEXT_AT.x
			_y += int(_engine["line"])
		else:
			_draw_glyph(code)
			_x += 1


func _outline(area: Rect2i) -> void:
	for x: int in range(area.position.x, area.end.x):
		_put(x, area.position.y, _colors[0])
		_put(x, area.end.y - 1, _colors[0])
	for y: int in range(area.position.y, area.end.y):
		_put(area.position.x, y, _colors[0])
		_put(area.end.x - 1, y, _colors[0])


func _clear_rect(area: Rect2i) -> void:
	for y: int in range(area.position.y, area.end.y):
		for x: int in range(area.position.x, area.end.x):
			_put(x, y, _colors[1])


func _load_std_frame() -> void: # LoadUserWindowBorderGfx, frame type 1.
	var bytes: PackedByteArray = _config.get("std_frame", PackedByteArray())
	for at: int in mini(bytes.size(), STD_TILES * GbaTiles.TILE_BYTES):
		_tiles[STD_TILE * GbaTiles.TILE_BYTES + at] = bytes[at]
	_palette.load(_config.get("std_frame_palette", PackedByteArray()), STD_PALETTE * 16)


func _std_word(x: int, y: int, tile: int) -> void:
	_map[y * 32 + x] = (STD_PALETTE << 12) | (STD_TILE + tile)


func _run() -> bool:
	var render: int = Render.REPEAT
	while render == Render.REPEAT:
		render = _render()
	if render == Render.FINISH:
		printing = false
		return true
	return false


func _run_all() -> void:
	_speed = 0
	for iteration: int in 0x400:
		var render: int = _render()
		if render == Render.FINISH or _state != State.HANDLE_CHAR:
			break
	printing = false


func _render() -> int:
	match _state:
		State.HANDLE_CHAR: return _handle_char()
		State.WAIT:
			if _prompt_answered():
				_state = State.HANDLE_CHAR
		State.CLEAR:
			_draw_arrow()
			if _prompt_answered():
				_fill()
				_x = 0
				_y = int(_engine["top"])
				_state = State.HANDLE_CHAR
		State.SCROLL_START:
			_draw_arrow()
			if _prompt_answered():
				_clear_arrow()
				_scroll = int(_engine["line"])
				_x = 0
				_state = State.SCROLL
		State.SCROLL: _scroll_step()
		State.WAIT_SE: _state = State.HANDLE_CHAR
		State.PAUSE:
			if _delay != 0:
				_delay -= 1
			else:
				_state = State.HANDLE_CHAR
	return Render.UPDATE


func _prompt_answered() -> bool: # TextPrinterWait and TextPrinterWaitWithDownArrow.
	if _auto:
		_auto_wait += 1
		return _auto_wait > AUTO_SCROLL_WAIT
	if _pressed:
		_requests.append({"kind": "sound", "name": "select"})
	return _pressed


func _scroll_step() -> void:
	if _scroll == 0:
		_state = State.HANDLE_CHAR
		return
	var step_size: int = mini(int(_engine["scroll"][text_speed]), _scroll)
	var size: Vector2i = _window.size * 8
	for y: int in size.y:
		for x: int in size.x:
			_put(x, y, _pixel(x, y + step_size) if y + step_size < size.y else _colors[1])
	_scroll -= step_size


func _handle_char() -> int:
	if _held and _sped_up:
		_delay = 0
	if _delay != 0 and _speed != 0:
		_delay -= 1
		if _can_speed_up and _pressed:
			_sped_up = true
			_delay = 0
		return Render.UPDATE
	_delay = int(_engine["auto_delay"]) if _auto else _speed
	if _at >= _text.size():
		return Render.FINISH
	var code: int = _next()
	match code:
		Gen3Text.NEWLINE:
			_x = 0
			_y += int(_engine["line"])
			return Render.REPEAT
		Gen3Text.PLACEHOLDER:
			_at += 1
			return Render.REPEAT
		Gen3Text.EXT_CTRL_CODE: return _control()
		0xFB:
			_start_prompt(State.CLEAR)
			return Render.UPDATE
		0xFA:
			_start_prompt(State.SCROLL_START)
			return Render.UPDATE
		0xF9:
			code = _next() | 0x100
		Gen3Text.EOS: return Render.FINISH
	_draw_glyph(code)
	return Render.PRINT


func _start_prompt(state: int) -> void: # TextPrinterInitDownArrowCounters.
	_state = state
	_arrow_delay = 0
	_arrow_index = 0
	_auto_wait = 0


func _next() -> int:
	var code: int = _text[_at] if _at < _text.size() else Gen3Text.EOS
	_at += 1
	return code


func _control() -> int:
	var code: int = _next()
	match code:
		1, 2, 3:
			_colors[[0, 1, 2][code - 1]] = _next()
		4:
			_colors = [_next(), _next(), _next()]
		5, 6, 20:
			_at += 1
		8:
			_delay = _next()
			_state = State.PAUSE
		9:
			_start_prompt(State.WAIT)
			return Render.UPDATE
		10:
			_state = State.WAIT_SE
			return Render.UPDATE
		11, 16:
			_at += 2
		12:
			_draw_glyph(_next() | 0x100)
			return Render.PRINT
		13, 18:
			_x = _next()
		14:
			_y = int(_engine["top"]) + _next()
		15:
			_fill()
			_x = 0
			_y = int(_engine["top"])
		17:
			_clear_span(_next())
			return Render.PRINT
		19:
			_clear_span(_next() - _x)
			return Render.PRINT
	return Render.REPEAT


func _clear_span(width: int) -> void:
	for x: int in maxi(width, 0):
		for y: int in int(_engine["line"]):
			_put(_x + x, _y + y, _colors[1])
	_x += maxi(width, 0)


func _draw_glyph(code: int) -> void: # CopyGlyphToWindow, in the font's own format.
	var font: Dictionary = _config["fonts"][_font]
	var widths: PackedByteArray = font["widths"]
	var width: int = widths[code] if code < widths.size() else 0
	var glyphs: PackedByteArray = font["glyphs"]
	if _engine_name == &"ruby":
		_draw_ruby_glyph(glyphs, code, width)
	else:
		_draw_wide_glyph(glyphs, code, width)
	_x += width


func _draw_wide_glyph(glyphs: PackedByteArray, code: int, width: int) -> void: # Two bits a pixel, big-endian by byte pair, in 16x16 cells of four 8x8 tiles: 1 is text, 2 shadow, and 0 and 3 paper.
	var cell: int = code * 64
	if cell + 64 > glyphs.size():
		return
	for y: int in 16:
		for x: int in mini(width, 16):
			var tile: int = cell + (32 if y >= 8 else 0) + (16 if x >= 8 else 0)
			var row: int = tile + (y & 7) * 2
			var byte: int = glyphs[row + ((x & 7) >> 2 ^ 1)]
			var value: int = (byte >> (6 - (x & 3) * 2)) & 3
			_put(_x + x, _y + y, _colors[0] if value == 1 else (_colors[2] if value == 2 else _colors[1]))


func _draw_ruby_glyph(glyphs: PackedByteArray, code: int, width: int) -> void: # Ruby's fonts are 4bpp 8x16 cells: 15 text, 14 shadow (`ApplyColors_ShadowedFont`).
	var cell: int = code * 64
	if cell + 64 > glyphs.size():
		return
	for y: int in 16:
		for x: int in mini(width, 8):
			var value: int = (glyphs[cell + y * 4 + x / 2] >> ((x & 1) * 4)) & 15
			_put(_x + x, _y + y, _colors[0] if value == 15 else (_colors[2] if value == 14 else _colors[1]))


func _draw_arrow() -> void: # TextPrinterDrawDownArrow.
	if _auto:
		return
	if _arrow_delay != 0:
		_arrow_delay -= 1
		return
	_clear_arrow()
	var frlg: bool = _engine_name == &"firered"
	var size := Vector2i(10, 12) if frlg else Vector2i(8, 16)
	var frame: int = ARROW_FRAMES[_arrow_index]
	var from := Vector2i(frame * 16, 0) if frlg else Vector2i(0, frame * (16 if _engine_name == &"ruby" else 1))
	_blit(_config["arrow"], 128 if frlg else 8, from, size)
	_arrow_delay = ARROW_DELAY
	_arrow_index = (_arrow_index + 1) & 3


func _clear_arrow() -> void:
	var size := Vector2i(10, 12) if _engine_name == &"firered" else Vector2i(8, 16)
	for y: int in size.y:
		for x: int in size.x:
			_put(_x + x, _y + y, _colors[1])


func _blit(source: PackedByteArray, width: int, from: Vector2i, size: Vector2i) -> void: # BlitBitmapRectToWindow from tiles [param width] pixels across, colour 0 transparent.
	for y: int in size.y:
		for x: int in size.x:
			var at := Vector2i(from.x + x, from.y + y)
			var offset: int = ((at.y >> 3) * (width >> 3) + (at.x >> 3)) * GbaTiles.TILE_BYTES + (at.y & 7) * 4 + ((at.x & 7) >> 1)
			if offset >= source.size():
				continue
			var color: int = (source[offset] >> ((at.x & 1) * 4)) & 15
			if _engine_name == &"ruby":
				color = _colors[0] if color == 15 else (_colors[2] if color == 14 else 0)
			if color != 0:
				_put(_x + x, _y + y, color)


func _load_frame() -> void: # LoadMessageBoxAndBorderGfx, or FRLG's signpost frame.
	var key: String = "signpost" if signpost else "frame"
	var frame: PackedByteArray = _config.get(key, _config["frame"])
	var bytes: PackedByteArray = frame.slice(0, FRAME_TILES * GbaTiles.TILE_BYTES)
	for at: int in bytes.size():
		_tiles[FRAME_TILE * GbaTiles.TILE_BYTES + at] = bytes[at]
	_palette.load(_config.get(key + "_palette", _config["frame_palette"]), PALETTE * 16)


func _draw_frame() -> void: # DrawDialogueFrame, FillWindowPixelBuffer and PutWindowTilemap.
	visible = true
	match _engine_name:
		&"emerald": _frame_emerald()
		&"firered": _frame_firered()
		&"ruby": _frame_ruby()
	_fill()
	for y: int in _window.size.y:
		for x: int in _window.size.x:
			_word(_window.position.x + x, _window.position.y + y, WINDOW_TILE + y * _window.size.x + x)


func _frame_emerald() -> void:
	var at: Vector2i = _window.position
	var width: int = _window.size.x
	for flip: int in [0, 0x800]:
		var y: int = at.y - 1 if flip == 0 else at.y + _window.size.y
		_frame_tile(at.x - 2, y, 1, flip)
		_frame_tile(at.x - 1, y, 3, flip)
		for x: int in width - 1:
			_frame_tile(at.x + x, y, 4, flip)
		_frame_tile(at.x + width - 1, y, 5, flip)
		_frame_tile(at.x + width, y, 6, flip)
	for y: int in _window.size.y:
		_frame_tile(at.x - 2, at.y + y, 7, 0)
		for x: int in width + 1:
			_frame_tile(at.x - 1 + x, at.y + y, 9, 0)
		_frame_tile(at.x + width, at.y + y, 10, 0)


func _frame_firered() -> void: # WindowFunc_DrawDialogueFrame: the signpost swaps its two middle rows' sides.
	var at: Vector2i = _window.position
	var width: int = _window.size.x
	var rows: Array = [[5, 6, 8, 9], [10, 11, 12, 13]]
	var lower: Array = [rows[0], rows[1]] if signpost else [rows[1], rows[0]]
	for flip: int in [0, 0x800]:
		var y: int = at.y - 1 if flip == 0 else at.y + 4
		for row: Array in [[-2, 0], [-1, 1], [width, 3], [width + 1, 4]]:
			_frame_tile(at.x + int(row[0]), y, row[1], flip)
		for x: int in width:
			_frame_tile(at.x + x, y, 2, flip)
	for index: int in 4:
		var row: Array = rows[index] if index < 2 else lower[index - 2]
		var flip: int = 0 if index < 2 else 0x800
		_frame_tile(at.x - 2, at.y + index, row[0], flip)
		_frame_tile(at.x - 1, at.y + index, row[1], flip)
		_frame_tile(at.x + width, at.y + index, row[2], flip)
		_frame_tile(at.x + width + 1, at.y + index, row[3], flip)


func _frame_ruby() -> void: # DrawDialogueFrame's GetDialogueFrameTilemapEntry at (0, 14), 26x4.
	var width: int = _window.size.x
	for y: int in _window.size.y + 2:
		for x: int in width + 6:
			var row: int = y - 4 + 3 if y >= 4 else mini(y, 2)
			var column: int = x - (width + 2) + 4 if x >= width + 2 else mini(x, 3)
			var entry: int = RUBY_FRAME[row][column] if column < 7 and row < 5 else 9
			_map[(14 + y) * 32 + x] = (PALETTE << 12) | (FRAME_TILE + entry)


func _frame_tile(x: int, y: int, tile: int, flip: int) -> void:
	_map[y * 32 + x] = (PALETTE << 12) | flip | (FRAME_TILE + tile)


func _word(x: int, y: int, tile: int) -> void:
	_map[y * 32 + x] = (PALETTE << 12) | tile


func _fill() -> void:
	var size: Vector2i = _surface_size * 8
	for y: int in size.y:
		for x: int in size.x:
			_put(x, y, _colors[1] if not _colors.is_empty() else 1)


func _put(x: int, y: int, color: int) -> void:
	var size: Vector2i = _surface_size * 8
	if x < 0 or y < 0 or x >= size.x or y >= size.y or color == CLEAR:
		return
	var at: int = (_surface_tile + (y >> 3) * _surface_size.x + (x >> 3)) * GbaTiles.TILE_BYTES + (y & 7) * 4 + ((x & 7) >> 1)
	var shift: int = (x & 1) * 4
	_tiles[at] = (_tiles[at] & (0xF0 >> shift)) | (color << shift)


func _pixel(x: int, y: int) -> int:
	var at: int = (_surface_tile + (y >> 3) * _surface_size.x + (x >> 3)) * GbaTiles.TILE_BYTES + (y & 7) * 4 + ((x & 7) >> 1)
	return (_tiles[at] >> ((x & 1) * 4)) & 15
