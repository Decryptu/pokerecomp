class_name Gen1Credits
extends Gen2Credits

## `HallOfFamePC`'s credits (`engine/movie/credits.asm`), one straight loop: a
## screen's strings are placed, then its command fades the text in, waits, and
## slides the next `CreditsMons` entry across as a silhouette. `ShiftFontColorIndex`
## drops the font's ink to colour 2, so a fade is `HoFGBPalettes` walking `rBGP`;
## the black bands are tile $7e on colour 3 throughout.

## `ClearScreen` then `ld c, 100` before the bands, `ld c, 128` behind
## `PlayMusic MUSIC_CREDITS`, and `FadeInCredits`' four palettes at five frames.
const OPEN_FRAMES: int = 100
const LEAD_FRAMES: int = 128
const FADE_STEP_FRAMES: int = 5
const FADE_PALETTES: Array[int] = [0xC0, 0xD0, 0xE0, 0xF0]
## The palette every mon leaves behind, the one that makes the mon and the text
## one silhouette, and `GBFadeOutToWhite`'s last step, which the induction ends on.
const BGP_HIDDEN: int = 0xC0
const BGP_SILHOUETTE: int = 0xFC
const BGP_WHITE: int = 0x00
## The waits behind each command; Yellow's are twelve longer each.
const WAITS: Dictionary = {
	Gen1Layout.CREDITS_TEXT_FADE_MON: 90,
	Gen1Layout.CREDITS_TEXT_MON: 110,
	Gen1Layout.CREDITS_TEXT_FADE: 120,
	Gen1Layout.CREDITS_TEXT: 140,
}
const WAIT_EXTRA_YELLOW: int = 12
## `.showTheEnd`'s `ld c, 16`, 24 on Yellow; `DisplayCreditsMon`'s three
## `CreditsCopyTileMapToVRAM` before its `.scrollLoop1` and `.scrollLoop2`,
## 7 and 20 frames, Yellow's 10, 10 and 8.
const THE_END_FRAMES: int = 16
const THE_END_FRAMES_YELLOW: int = 24
const SLIDE_SETUP_FRAMES: int = 9
const SLIDE_FRAMES: int = 27
const SLIDE_FRAMES_YELLOW: int = 28
const SLIDE_STEP: int = 8
## `HallOfFameResetEventsAndSaveScript`'s five `ld c, 600 / 5` behind the
## credits, which no press shortens, and `WaitForTextScrollButtonPress` after.
const END_HOLD_FRAMES: int = 600

const BLACK_TILE: int = 0x7E
## `FillFourRowsWithBlack` at rows 0 and 14, `FillMiddleOfScreenWithWhite`
## between them.
const BAND_ROWS: int = 4
const BAND_BOTTOM_ROW: int = 14
const MIDDLE_FIRST_ROW: int = 4
const MIDDLE_ROWS: int = 10
## `hlcoord 8, 6`, copied to `vBGMap0 + 12`: the mon's left edge is BG column
## 20, off the right of the screen until the scroll brings it on.
const MON_ROW: int = 6
const MON_SOURCE_X: int = (12 + 8) * Gen2Font.TILE
## `TheEndTextString`'s two rows at `hlcoord 4, 8`.
const THE_END_AT_GEN1: Vector2i = Vector2i(4, 8)
const THE_END_ROWS: Array = [
	[0x60, 0x7F, 0x62, 0x7F, 0x64, 0x7F, 0x7F, 0x64, 0x7F, 0x66, 0x7F, 0x68],
	[0x61, 0x7F, 0x63, 0x7F, 0x65, 0x7F, 0x7F, 0x65, 0x7F, 0x67, 0x7F, 0x69],
]
const COPYRIGHT_AT_GEN1: Vector2i = Vector2i(2, 7)

const SHEET_NONE: StringName = &""
const SHEET_COPYRIGHT: StringName = &"copyright"
const SHEET_THE_END: StringName = &"credits_the_end"

enum Phase { OPEN, LEAD, FADE, WAIT, SLIDE_SETUP, SLIDE, THE_END, DONE }

var _yellow: bool = false
var _phase: Phase = Phase.OPEN
var _left: int = 0
var _slide_at: int = 0
## `rBGP`, which sheet `vChars2 tile $60` holds, and the command being spent.
var _bgp: int = BGP_WHITE
var _sheet: StringName = SHEET_NONE
var _command: int = 0
var _mons_shown: int = 0
var _mon: int = 0
## `rSCX` inside the middle rows during a slide.
var _slide_scroll: int = 0
var _mons: PackedInt32Array = PackedInt32Array()
var _end_hold: int = 0


static func create_gen1(data: GameData) -> Gen1Credits:
	if data == null or data.credits_script().is_empty():
		return null
	var out := Gen1Credits.new()
	out._data = data
	out._script = data.credits_script()
	out._mons = data.credits_mons()
	out._yellow = data.id == RomRegistry.YELLOW
	out._tilemap.resize(COLUMNS * ROWS)
	out._tilemap.fill(BLANK_TILE)
	out._left = OPEN_FRAMES
	return out


func finished() -> bool:
	return _phase == Phase.DONE


func may_finish(held: Array = []) -> bool:
	return _phase == Phase.DONE and _end_hold <= 0 \
		and (PokeButton.A in held or PokeButton.B in held)


func skippable() -> bool:
	return false


func music_outlasts() -> bool:
	return true


func bg_map() -> PackedInt32Array:
	return _tilemap.duplicate()


func bgp() -> int:
	return _bgp


func sheet() -> StringName:
	return _sheet


func sliding_mon() -> int:
	return _mon


func slide_scroll() -> int:
	return _slide_scroll


func frame_state() -> Dictionary:
	return {
		"gen1": true,
		"map": bg_map(),
		"bgp": _bgp,
		"sheet": _sheet,
		"mon": _mon,
		"scroll": _slide_scroll,
	}


## The only event is `PlayMusic MUSIC_CREDITS`, on the frame the bands go up.
func advance_frame(_held: Array = []) -> Array:
	var events: Array = []
	match _phase:
		Phase.OPEN:
			if _spend():
				_open_bands()
				events.append({"type": &"music_requested", "music": MUSIC_CREDITS})
		Phase.LEAD:
			if _spend():
				_next_screen()
		Phase.FADE:
			_fade_step()
			if _spend():
				_after_fade()
		Phase.WAIT:
			if _spend():
				_after_wait()
		Phase.SLIDE_SETUP:
			if _spend():
				_start_slide()
		Phase.SLIDE:
			_slide_step()
		Phase.THE_END:
			if _spend():
				_show_the_end()
		Phase.DONE:
			_end_hold = maxi(_end_hold - 1, 0)
	return events


func _spend() -> bool:
	_left -= 1
	return _left <= 0


func _open_bands() -> void:
	for row: int in BAND_ROWS:
		_fill_row(row, BLACK_TILE)
		_fill_row(BAND_BOTTOM_ROW + row, BLACK_TILE)
	_bgp = BGP_HIDDEN
	_phase = Phase.LEAD
	_left = LEAD_FRAMES


## `.nextCreditsScreen`: the middle cleared, then strings placed until a command.
func _next_screen() -> void:
	_clear_middle()
	var line: int = 0
	while true:
		var command: int = _next()
		if command == Gen1Layout.CREDITS_COPYRIGHT:
			_place_copyright()
		elif command == Gen1Layout.CREDITS_THE_END:
			_phase = Phase.THE_END
			_left = THE_END_FRAMES_YELLOW if _yellow else THE_END_FRAMES
			return
		elif command >= Gen1Layout.CREDITS_TEXT:
			_command = command
			_begin_command()
			return
		else:
			_place_string(command, line)
			line += 1


func _begin_command() -> void:
	if _command == Gen1Layout.CREDITS_TEXT_FADE_MON \
		or _command == Gen1Layout.CREDITS_TEXT_FADE:
		_phase = Phase.FADE
		_left = FADE_PALETTES.size() * FADE_STEP_FRAMES
		return
	_start_wait()


func _fade_step() -> void:
	var spent: int = FADE_PALETTES.size() * FADE_STEP_FRAMES - _left
	@warning_ignore("integer_division")
	_bgp = FADE_PALETTES[mini(spent / FADE_STEP_FRAMES, FADE_PALETTES.size() - 1)]


func _after_fade() -> void:
	if _command == Gen1Layout.CREDITS_THE_END:
		_after_the_end_fade()
		return
	_start_wait()


func _start_wait() -> void:
	_phase = Phase.WAIT
	_left = int(WAITS[_command]) + (WAIT_EXTRA_YELLOW if _yellow else 0)


func _after_wait() -> void:
	if _command == Gen1Layout.CREDITS_TEXT_FADE_MON \
		or _command == Gen1Layout.CREDITS_TEXT_MON:
		_phase = Phase.SLIDE_SETUP
		_left = SLIDE_SETUP_FRAMES
		return
	_next_screen()


## `DisplayCreditsMon`: the first scroll frame shows everything still in place.
func _start_slide() -> void:
	_mon = _mons[_mons_shown] if _mons_shown < _mons.size() else 0
	_mons_shown += 1
	_bgp = BGP_SILHOUETTE
	_phase = Phase.SLIDE
	_slide_at = 0
	_slide_scroll = 0


func _slide_step() -> void:
	_slide_at += 1
	if _slide_at >= (SLIDE_FRAMES_YELLOW if _yellow else SLIDE_FRAMES):
		_mon = 0
		_slide_scroll = 0
		_bgp = BGP_HIDDEN
		_next_screen()
		return
	_slide_scroll = _slide_at * SLIDE_STEP


func _show_the_end() -> void:
	_clear_middle()
	_sheet = SHEET_THE_END
	for row: int in THE_END_ROWS.size():
		var codes: Array = THE_END_ROWS[row]
		for column: int in codes.size():
			_put(THE_END_AT_GEN1 + Vector2i(column, row), int(codes[column]))
	_phase = Phase.FADE
	_left = FADE_PALETTES.size() * FADE_STEP_FRAMES
	_command = Gen1Layout.CREDITS_THE_END


## `.showTheEnd`'s `FadeInCredits` runs into `ret`.
func _after_the_end_fade() -> void:
	_phase = Phase.DONE
	_end_hold = END_HOLD_FRAMES


func _next() -> int:
	if _position >= _script.size():
		return Gen1Layout.CREDITS_THE_END
	var byte: int = _script[_position]
	_position += 1
	return byte


func _place_string(index: int, line: int) -> void:
	var column: int = _data.credits_string_column(index)
	var at := Vector2i(column, TEXT_TOP_ROW + line * TEXT_LINE_SPACING)
	for code: int in _data.credits_string(index):
		if code == CODE_NEXT_LINE:
			at = Vector2i(column, at.y + TEXT_LINE_SPACING)
			continue
		if code == CODE_POKE:
			for glyph: int in Gen1Text.encode(POKE_TEXT):
				_put(at, glyph)
				at.x += 1
			continue
		_put(at, code)
		at.x += 1


func _place_copyright() -> void:
	_sheet = SHEET_COPYRIGHT
	var rows: Array = _data.credits_copyright_rows()
	for row: int in rows.size():
		var codes: PackedByteArray = rows[row]
		for column: int in codes.size():
			_put(COPYRIGHT_AT_GEN1 + Vector2i(column, row * TEXT_LINE_SPACING), codes[column])


func _clear_middle() -> void:
	for row: int in MIDDLE_ROWS:
		_fill_row(MIDDLE_FIRST_ROW + row, BLANK_TILE)


func _fill_row(row: int, tile: int) -> void:
	for column: int in COLUMNS:
		_put(Vector2i(column, row), tile)
