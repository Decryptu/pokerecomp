class_name Gen2MagnetTrain
extends RefCounted

## `MagnetTrain` (engine/events/magnet_train.asm), the ride between Goldenrod and
## Saffron: byte counters and a jumptable, node-free so a frame of it can be
## asserted headless. [Gen2MagnetTrainPage] turns one into pixels.

const HEIGHT: int = 144
const TILE: int = 8

const MUSIC: int = 0x05
const SFX_ARRIVED: int = 0xB9

## `MagnetTrain`'s two `lb` pairs: direction, init, hold, final, player x.
const RIDES: Array[Array] = [
	[1, 12 * TILE, 8 * TILE, -12 * TILE, -4],
	[-1, -12 * TILE, -8 * TILE, 12 * TILE, (11 * TILE) + (11 * TILE + 4)],
]

const BAND_LINES: Array[int] = [6 * TILE - 1, 6 * TILE, 6 * TILE + 1]

const PLAYER_Y: int = (8 + 2) * TILE + 5
const WAIT_FRAMES: int = 128
## `oamframe ..., 8` four times: `Facings`' own down row, the last mirrored.
const SPRITE_FRAME_LENGTH: int = 8
const SPRITE_FRAMES: Array[int] = [0, 1, 0, 3]

const EXIT: int = 0x80

var _direction: int = 1
var _hold: int = 0
var _final: int = 0
var _position: int = 0
var _offset: int = 0
var _wait: int = 0
var _index: int = 0
var _global_x: int = 0
var _player_x: int = 0
var _frame: int = 0
var _sprite_tick: int = -1
var _lines := PackedInt32Array()
var _events: Array[Dictionary] = []


static func create(to_goldenrod: bool) -> Gen2MagnetTrain:
	var out := Gen2MagnetTrain.new()
	var row: Array = RIDES[1 if to_goldenrod else 0]
	out._direction = int(row[0])
	out._hold = int(row[2]) & 0xFF
	out._final = int(row[3]) & 0xFF
	out._position = int(row[1]) & 0xFF
	out._offset = out._position
	out._wait = out._position
	out._player_x = int(row[4]) & 0xFF
	## `MagnetTrain_LoadGFX_PlayMusic`'s `PlayMusic2`, before the loop.
	out._events.append({"type": &"play_music", "music": MUSIC})
	out._update_line_offsets()
	return out


func finished() -> bool:
	return (_index & EXIT) != 0


func frame() -> int:
	return _frame


func advance_frame() -> Array[Dictionary]:
	if finished():
		return drain_events()
	_sprite_tick += 1
	_step_jumptable()
	_update_line_offsets()
	_frame += 1
	return drain_events()


func drain_events() -> Array[Dictionary]:
	var out: Array[Dictionary] = _events
	_events = []
	return out


## `wLYOverrides`, one entry per scanline, sampled a line late so lines 0 and 1
## share the first.
func line_offsets() -> PackedInt32Array:
	return _lines


func player_at() -> Vector2i:
	return Vector2i((_player_x + _global_x) & 0xFF, PLAYER_Y)


func player_frame() -> int:
	if _sprite_tick < 0:
		return -1
	@warning_ignore("integer_division")
	var step: int = (_sprite_tick / SPRITE_FRAME_LENGTH) % SPRITE_FRAMES.size()
	return SPRITE_FRAMES[step]


func _update_line_offsets() -> void:
	var band: Array[int] = [(_offset * 2) & 0xFF, _position, (_offset * 2) & 0xFF]
	var buffer := PackedInt32Array()
	for index: int in BAND_LINES.size():
		for _line: int in BAND_LINES[index]:
			buffer.append(band[index])
	_lines = PackedInt32Array([buffer[0]])
	_lines.append_array(buffer.slice(0, HEIGHT - 1))
	_offset = (_offset + _direction * 2) & 0xFF


## `MagnetTrain_Jumptable`: two moves and the waits around them.
func _step_jumptable() -> void:
	match _index:
		0:
			_sprite_tick = 0
			_index += 1
			_wait = WAIT_FRAMES
		1, 3, 5:
			_wait_scene()
		2:
			_move_train(_hold, 1, WAIT_FRAMES)
		4:
			_move_train(_final, 2, -1)
		_:
			_index = EXIT
			_events.append({"type": &"play_sfx", "sfx": SFX_ARRIVED})


func _wait_scene() -> void:
	if _wait == 0:
		_index += 1
		return
	_wait -= 1


## `.MoveTrain1` and `.MoveTrain2`, which differ in pixels a frame and in the
## [param wait] the step behind each loads.
func _move_train(target: int, pixels: int, wait: int) -> void:
	if _position == target:
		_index += 1
		if wait >= 0:
			_wait = wait
		return
	_position = (_position - _direction * pixels) & 0xFF
	_global_x = (_global_x + _direction * pixels) & 0xFF
