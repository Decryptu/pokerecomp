class_name Gen3FieldDoor
extends RefCounted # `field_door.c`: frames copied over the last BG tiles and drawn as covered metatiles, kept in [member Gen3FieldVram.door_cells] until the closed frame.

const ROW_BYTES: int = 12
const PALETTE_BYTES: int = 8
const FRAME_COUNT: int = 3
const FRAME_TIME: int = 4
const FRAME_TILES: Array[int] = [8, 4] # Hoenn's and FRLG's small door.
const TILES_TOTAL: int = 1024
const CLOSED: int = -1
const SOUNDS: Array[String] = ["door", "sliding_door", "repel"] # `DOOR_SOUND_*`; Ruby and FRLG have the first two.
const MULTI_CORRIDOR := Vector2i(26, 16) # Emerald's Battle Tower corridor, whose doors open in pairs.
const FLAG_MULTI_CORRIDOR_DOOR: int = 0x4002

var running: bool = false
var _camera: Gen3FieldCamera
var _vram: Gen3FieldVram
var _input: Gen3FieldInput
var _events: Gen3EventData
var _row: Dictionary = {}
var _frames: Array[int] = []
var _frame: int = 0
var _counter: int = 0
var _cell := Vector2i.ZERO


func _init(camera: Gen3FieldCamera, vram: Gen3FieldVram, input: Gen3FieldInput, events: Gen3EventData) -> void:
	_camera = camera
	_vram = vram
	_input = input
	_events = events


func sound(cell: Vector2i) -> String: # GetDoorSoundEffect, which is SE_DOOR off a door.
	var row: Dictionary = _door_at(cell)
	return SOUNDS[int(row["sound"])] if not row.is_empty() and int(row["sound"]) < SOUNDS.size() else SOUNDS[0]


func open(cell: Vector2i) -> bool: # FieldAnimateDoorOpen; false when no task started, which callers treat as finished.
	return _start(cell, true)


func close(cell: Vector2i) -> bool: # FieldAnimateDoorClose.
	return _start(cell, false)


func set_opened(cell: Vector2i) -> void: # FieldSetDoorOpened.
	var row: Dictionary = _door_at(cell)
	if not row.is_empty():
		_draw(row, _offsets(row, true)[-1], cell)


func set_closed(cell: Vector2i) -> void: # FieldSetDoorClosed.
	var row: Dictionary = _door_at(cell)
	if not row.is_empty():
		_draw(row, CLOSED, cell)


func step() -> void: # Task_AnimateDoor.
	if not running:
		return
	if _counter == 0:
		_draw(_row, _frames[_frame], _cell)
	if _counter == FRAME_TIME:
		_counter = 0
		_frame += 1
		running = _frame < _frames.size()
	else:
		_counter += 1


func _start(cell: Vector2i, opening: bool) -> bool:
	var row: Dictionary = _door_at(cell)
	if row.is_empty() or running:
		return false
	_row = row
	_frames = _offsets(row, opening)
	_frame = 0
	_counter = 0
	_cell = cell
	running = true
	return true


func _door_at(cell: Vector2i) -> Dictionary:
	if not _input.is_door(_camera.grid.behavior_at(cell.x, cell.y) & 0xFF):
		return {}
	return _camera.data.world_door(_camera.grid.metatile_id_at(cell.x, cell.y))


func _offsets(row: Dictionary, opening: bool) -> Array[int]: # Emerald closes a big door with the small frames: `sBigDoorCloseAnimFrames` has no caller. FRLG's has one.
	var frlg: bool = _input.engine == &"firered"
	var big: bool = row["big"] and (opening or frlg)
	var step_bytes: int = FRAME_TILES[int(frlg)] * (2 if big else 1) * GbaTiles.TILE_BYTES
	var open_frames: Array[int] = [CLOSED, 0, step_bytes, step_bytes * 2]
	if opening:
		return open_frames
	open_frames.reverse()
	return open_frames


func _draw(row: Dictionary, offset: int, cell: Vector2i) -> void:
	_draw_at(row, offset, cell)
	if _input.engine == &"emerald" and _events.flag_get(FLAG_MULTI_CORRIDOR_DOOR) \
			and Vector2i(_camera.group, _camera.number) == MULTI_CORRIDOR:
		_draw_at(row, offset, Vector2i(_events.var_get(0x8004), _events.var_get(0x8005)) + Vector2i.ONE * Gen3MapGrid.MAP_OFFSET)


func _draw_at(row: Dictionary, offset: int, cell: Vector2i) -> void:
	var cells: Array[Vector2i] = _cells(row, cell)
	if offset == CLOSED:
		for at: Vector2i in cells:
			_vram.door_cells.erase(at)
		return
	var frlg: bool = _input.engine == &"firered"
	var count: int = TILES_TOTAL - (16 if row["big"] and not frlg else 8)
	var bytes: PackedByteArray = row["bytes"]
	var size: int = (TILES_TOTAL - count) * GbaTiles.TILE_BYTES
	_vram.write_tiles(count, bytes.slice(offset, offset + size))
	var palettes: Array = row["palettes"]
	for index: int in cells.size():
		var words := PackedInt32Array()
		for slot: int in 4:
			words.append((int(palettes[_palette_slot(index, cells.size()) + slot]) << 12) | (count + index * 4 + slot))
		_vram.door_cells[cells[index]] = words


func _cells(row: Dictionary, cell: Vector2i) -> Array[Vector2i]: # FRLG's 1x1 door is one cell; the rest run top then bottom, a big door's right column last.
	var top: Vector2i = cell - Vector2i(0, 1)
	if _input.engine == &"firered" and not row["big"]:
		return [cell]
	if _input.engine != &"firered" and row["big"]:
		return [top, cell, top + Vector2i.RIGHT, cell + Vector2i.RIGHT]
	return [top, cell]


static func _palette_slot(index: int, count: int) -> int: # Each column's bottom cell starts at `paletteNums[4]`.
	return 4 if count > 1 and index % 2 == 1 else 0
