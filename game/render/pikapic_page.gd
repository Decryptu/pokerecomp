class_name Gen1PikaPicPage
extends RefCounted

## `StarterPikachuEmotionCommand_pikapic` (`engine/pikachu/pikachu_pic_animation.asm`).
## `PlacePikapicTextBoxBorder` puts a `TextBoxBorder` at `hlcoord 6, 5` sized
## `5, 5`; `ExecutePikaPicAnimScript` loops a setup script and up to four
## tilemap objects at one `Delay3` a turn until the duration runs out or A or
## B is pressed. `pikapic_cry` is a PCM clip nothing here plays yet.

const TILE: int = Gen2Font.TILE
## `hlcoord 6, 5` and `lb bc, 5, 5`: the border's corner and the interior.
const BOX_AT: Vector2i = Vector2i(6, 5)
const INTERIOR: int = 5
const BORDER: int = INTERIOR + 2
## Measured on the cartridge: `PlacePikapicTextBoxBorder` and the palettes
## take eight frames going in, with the border on screen from the third; a
## compressed picture's decompression and 49-tile copy take 24; a raw run takes
## `CopyVideoData`'s frame per eight tiles; the closing border takes six, and
## `RunDefaultPaletteCommand` five more before `CloseTextDisplay` takes the box
## down. Sprites stay hidden twelve frames past that.
const OPEN_FRAMES: int = 8
const BORDER_SHOWN_AFTER: int = 3
const LOOP_FRAMES: int = 3
const COPY_TILES_PER_FRAME: int = 8
const PIC_LOAD_FRAMES: int = 24
const CLOSE_FRAMES: int = 6
const PALETTE_FRAMES: int = 5
const HIDDEN_AFTER_FRAMES: int = 12
## `ResetPikaPicAnimBuffer`'s timer, `wPikaPicUsedGFX`'s first tile and the
## room `CheckIfThereIsRoomForPikaPicAnimGFX` counts to.
const DEFAULT_TIMER: int = 100
const FIRST_TILE: int = 0x80
const TILE_ROOM: int = 0x80
const OBJECTS: int = 4
## `.FlashScreen`'s BGP %11000000 against the ordinary %11100100.
const FLASH_SHADES: Array[int] = [0, 0, 0, 3]
const NORMAL_SHADES: Array[int] = [0, 1, 2, 3]

var font: Gen2Font = null
var palette: PackedColorArray = PackedColorArray()
var frame_style: int = 0

var _data: GameData = null
var _tables: Dictionary = {}
var _script: Array = []
var _at: int = 0
var _delay: int = 0
var _timer: int = DEFAULT_TIMER
var _objects: Array = []
var _used: Array = []
var _used_count: int = 0
var _grid: PackedInt32Array = PackedInt32Array()
## Frames still to spend before the next loop step: the border's, a copy's or
## the flash's, which paints [member _shades] while it runs.
var _wait: int = 0
var _loop_frame: int = 0
var _setup_done: bool = false
var _shades: Array[int] = NORMAL_SHADES
var _flash: Array = []
var _phase: StringName = &"open"
## The waits in order: the border in, the loop, the blank border out, then the
## frames the map is back with its sprites still hidden.
const NEXT_PHASE: Dictionary = {&"open": &"run", &"close": &"gone", &"gone": &"done"}


static func from_data(data: GameData, map: Gen2WorldMap, time_of_day: int) -> Gen1PikaPicPage:
	if data == null:
		return null
	var tables: Dictionary = data.gen1_pikachu().get("pikapic", {})
	var glyphs: Gen2Font = Gen2Font.from_data(data)
	if tables.is_empty() or glyphs == null:
		return null
	var page := Gen1PikaPicPage.new()
	page._data = data
	page._tables = tables
	page.font = glyphs
	page.frame_style = Gen2OptionsStore.current().textbox_frame
	var slots: Array = Gen2WorldPalette.palette_slots(map.environment, time_of_day) \
		if map != null else []
	page.palette = data.world_palette(int(slots[0])) if not slots.is_empty() \
		else PackedColorArray()
	if page.palette.size() < 4:
		page.palette = PokePalette.pic_palette(PackedColorArray([Color.WHITE, Color.BLACK]))
	return page


## `LoadCurrentPikaPicAnimScriptPointer`: a number past the table plays script 0.
func start(index: int) -> void:
	var scripts: Array = _tables.get("scripts", [])
	_script = scripts[index] if index >= 0 and index < scripts.size() else scripts[0]
	_at = 0
	_delay = 0
	_timer = DEFAULT_TIMER
	_objects = []
	_used = []
	_used_count = 0
	_grid = PackedInt32Array()
	_grid.resize(BORDER * BORDER)
	_grid.fill(-1)
	_wait = OPEN_FRAMES
	_loop_frame = 0
	_setup_done = false
	_shades = NORMAL_SHADES
	_flash = []
	_phase = &"open"


func running() -> bool:
	return _phase != &"done"


## One hardware frame. [param pressed] is A or B down, which
## `PikaPicAnimTimerAndJoypad` reads after the timer.
func advance_frame(pressed: bool) -> void:
	if _phase == &"done":
		return
	if not _flash.is_empty():
		_advance_flash()
		return
	if _wait > 0:
		_wait -= 1
		if _wait > 0:
			return
		_phase = String(NEXT_PHASE.get(_phase, _phase))
		if _phase == &"gone":
			_wait = HIDDEN_AFTER_FRAMES
		return
	if _phase != &"run":
		return
	if _loop_frame == 0:
		if not _setup_done:
			_setup_done = true
			_run_setup()
			if _wait > 0:
				return
		_animate_objects()
	_loop_frame += 1
	if _loop_frame < LOOP_FRAMES:
		return
	_loop_frame = 0
	_setup_done = false
	if _tick_timer() or pressed:
		_phase = &"close"
		_wait = CLOSE_FRAMES + PALETTE_FRAMES


## `CheckPikaPicAnimTimer`: a sixteen-bit count run down a loop at a time.
func _tick_timer() -> bool:
	_timer -= 1
	return _timer <= 0


## `RunPikaPicAnimSetupScript`: `writebyte` holds the script for that many loops.
func _run_setup() -> void:
	if _delay > 0:
		_delay -= 1
		return
	while _at < _script.size():
		var row: Dictionary = _script[_at]
		_at += 1
		match String(row["cmd"]):
			"delay":
				_delay = int(row["value"])
			"loadgfx":
				_load_gfx(int(row["value"]))
			"object":
				_add_object(row)
			"delete":
				_delete_object(int(row["value"]))
			"jump":
				_at = int(row["to"])
			"duration":
				_timer = int(row["value"])
			"thunderbolt":
				_flash = (_tables.get("thunderbolt", []) as Array).duplicate()
			"run":
				return
			"ret":
				_timer = 1
				return


## `CheckIfThereIsRoomForPikaPicAnimGFX` and the copy behind it: a graphic
## already loaded costs nothing, a new one takes the next tiles and the frames
## `CopyVideoData` spends on them.
func _load_gfx(index: int) -> void:
	for entry: Array in _used:
		if int(entry[0]) == index:
			return
	var sizes: Array = _tables.get("gfx", [])
	var size: int = int(sizes[index]) if index < sizes.size() else 0
	if _used.size() >= 8 or _used_count + size > TILE_ROOM:
		return
	_used.append([index, FIRST_TILE + _used_count, size])
	_used_count += size
	var compressed: bool = int(_data.tile_sheet("pikapic_%02d" % index).get("tiles", 0)) \
		== Gen1Layout.PIKAPIC_PIC_TILES
	_wait += PIC_LOAD_FRAMES if compressed else size / COPY_TILES_PER_FRAME + 1


func _add_object(row: Dictionary) -> void:
	if _objects.size() >= OBJECTS:
		return
	_objects.append({
		"id": _objects.size() + 1, "frameset": int(row["frameset"]), "frame": 0,
		"timer": 0, "tile": int(row["tile"]), "x": int(row["x"]), "y": int(row["y"]),
	})


func _delete_object(id: int) -> void:
	for index: int in _objects.size():
		if int((_objects[index] as Dictionary)["id"]) == id:
			_objects.remove_at(index)
			return


## `AnimateCurrentPikaPicAnimFrame` and `LoadPikaPicAnimObjectData`: the frame
## set's row is drawn every loop, its count steps the timer, and a zero count
## holds the row for good.
func _animate_objects() -> void:
	var framesets: Array = _tables.get("framesets", [])
	for object: Dictionary in _objects:
		var rows: Array = framesets[int(object["frameset"])] \
			if int(object["frameset"]) < framesets.size() else []
		if rows.is_empty():
			continue
		if int(object["frame"]) >= rows.size():
			object["frame"] = 0
			object["timer"] = 0
		var row: Array = rows[int(object["frame"])]
		_draw_tilemap(int(row[0]), object)
		if int(row[1]) == 0:
			continue
		object["timer"] = int(object["timer"]) + 1
		if int(object["timer"]) == int(row[1]):
			object["timer"] = 0
			object["frame"] = int(object["frame"]) + 1


## `LoadCurPikaPicObjectTilemap`: tile ids under the object's offset, `$ff`
## leaving the cell as it was, from one tile inside the border.
func _draw_tilemap(index: int, object: Dictionary) -> void:
	var tilemaps: Array = _tables.get("tilemaps", [])
	if index <= 0 or index >= tilemaps.size():
		return
	var tilemap: Dictionary = tilemaps[index]
	var columns: int = int(tilemap["columns"])
	var tiles: Array = tilemap["tiles"]
	for cell: int in tiles.size():
		if int(tiles[cell]) == Gen1Layout.PIKAPIC_TILE_KEEP:
			continue
		var x: int = 1 + int(object["x"]) + cell % columns
		var y: int = 1 + int(object["y"]) + cell / columns
		if x < 0 or y < 0 or x >= BORDER or y >= BORDER:
			continue
		_grid[y * BORDER + x] = (int(object["tile"]) + int(tiles[cell])) & 0xFF


## `.FlashScreen`: each row holds its BGP for its frames.
func _advance_flash() -> void:
	var row: Array = _flash[0]
	_shades = FLASH_SHADES if int(row[1]) == 0xC0 else NORMAL_SHADES
	row[0] = int(row[0]) - 1
	if int(row[0]) <= 0:
		_flash.pop_front()
	if _flash.is_empty():
		_shades = NORMAL_SHADES


## Whether the box is on screen: not before its first `Delay3` and not once
## `CloseTextDisplay` has run.
func box_shown() -> bool:
	if _phase == &"open":
		return _wait <= OPEN_FRAMES - BORDER_SHOWN_AFTER
	return _phase in [&"run", &"close"]


## The interior goes blank with the closing border: `TextBoxBorder` clears it.
func render() -> Image:
	var width: int = BORDER * TILE
	var indices := PackedByteArray()
	indices.resize(width * width)
	font.draw_box(frame_style, indices, width, 0, 0, BORDER, BORDER)
	for cell: int in _grid.size():
		var tile: int = _grid[cell]
		if tile < 0 or _phase == &"close":
			continue
		var found: Array = _tile_source(tile)
		if found.is_empty():
			continue
		var name: String = "pikapic_%02d" % int(found[0])
		Gen2Font.blit_slot(
			_data.tile_indices(name), int(_data.tile_sheet(name).get("width", 0)),
			int(found[1]), indices, width, (cell % BORDER) * TILE, (cell / BORDER) * TILE
		)
	var colors := PackedColorArray()
	for shade: int in _shades:
		colors.append(palette[shade])
	return Gen2PicImage.from_indices(indices, width, width, colors)


func _tile_source(tile: int) -> Array:
	for entry: Array in _used:
		var base: int = int(entry[1])
		if tile >= base and tile < base + int(entry[2]):
			return [int(entry[0]), tile - base]
	return []


func position() -> Vector2i:
	return BOX_AT * TILE
