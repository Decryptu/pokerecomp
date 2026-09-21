class_name Gen1Movie
extends RefCounted

## A Generation 1 screen routine a frame at a time against a [Gen1Lcd]: a step
## list of the routine's own `DelayFrames`, `WaitForSoundToFinish` and VRAM
## writes, with `wTileMap`, `wShadowOAM` and `hSCX` landing at VBlank and `rBGP`
## at once. A silent copy of the sound driver answers `WaitForSoundToFinish`.
## [Gen1Opening] and [Gen1TradeAnimation] are its programs.

const PHASE_FINISHED: StringName = &"finished"

## `BANK(SFX_Shooting_Star)`, which `Init` puts in `wAudioROMBank` and
## every field routine plays out of.
const AUDIO_BANK: int = 0x1F

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
const WINDOW_OFF: int = 0x90  ## `hWY` parked below the screen.
const DELAY3: int = 3
const OFF_SCREEN_Y: int = Gen1Lcd.HEIGHT + Gen1Lcd.OAM_Y_OFFSET

var lcd: Gen1Lcd = Gen1Lcd.new()

var _profile: StringName = &"red"
var _data: GameData = null
var _sound: Gen1SoundEngine = null

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
## `PlayPikachuSoundClip`'s three `DelayFrame`s and its `di` to `ei`.
var _clip_lead: int = 0
var _clip_hold: int = 0
var _clip_frames: int = 0
var _clip: PackedByteArray = PackedByteArray()
var _frame: int = 0
var _phase: StringName = &""
var _finished: bool = false
var _events: Array[Dictionary] = []


## The driver, buffers and OAM every program starts from.
func _init_machine(data: GameData) -> void:
	_data = data
	_profile = data.id
	_sound = Gen1SoundEngine.new()
	_sound.set_assets(data.audio_assets())
	_sound.yellow = data.id == RomRegistry.YELLOW
	_sound.audio_rom_bank = AUDIO_BANK
	_sound.saved_rom_bank = AUDIO_BANK
	_tilemap.resize(TILEMAP_CELLS)
	_shadow_oam.resize(Gen1Lcd.OAM_SLOTS * Gen1Lcd.OAM_BYTES)
	# `PrepareOAMData`'s first VBlank runs before `Init` writes
	# `wUpdateSpritesEnabled`, and a zero there is `HideSprites`.
	for slot: int in Gen1Lcd.OAM_SLOTS:
		_shadow_oam[slot * Gen1Lcd.OAM_BYTES] = OFF_SCREEN_Y
	_buffer1.resize(TILEMAP_CELLS)
	_buffer2.resize(TILEMAP_CELLS)


func phase() -> StringName:
	return _phase


func finished() -> bool:
	return _finished


func frame() -> int:
	return _frame


func profile() -> StringName:
	return _profile


func shadow_oam() -> Array[Dictionary]:
	return lcd.shadow_oam()


func drain_events() -> Array[Dictionary]:
	var out: Array[Dictionary] = _events.duplicate(true)
	_events.clear()
	return out


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
		if not _clip_frame():
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
	_end_frame()
	return drain_events()


## `WaitForSoundToFinish`: channels 5, 6 and 8 of `wChannelSoundIDs`.
func _sound_active() -> bool:
	for channel: int in [4, 5, 7]:
		if _sound.channel_sound_id(channel) != 0:
			return true
	return false


## `CheckForUserInterruption`, which only the opening reads.
func _interrupted() -> bool:
	return false


## Whether this frame is inside a `check` step, the only frames a press reaches.
func reads_joypad() -> bool:
	return _check_left > 0


## The joypad's own end of frame.
func _end_frame() -> void:
	pass


## What runs after the VBlank copies, for a program with a second machine.
func _after_vblank() -> void:
	pass


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
		elif step.has("until"):
			var answer: Variant = (step["until"] as Callable).call()
			if answer is Array:
				_rewind()
				_calls.append({"steps": answer, "pc": 0})
			elif not bool(answer):
				_wait = 1
				_rewind()
		elif step.has("phase"):
			_phase = step["phase"]
			_emit(&"phase", {"phase": _phase})
		elif step.has("finish"):
			_finished = true
			_phase = PHASE_FINISHED
			_emit(step["finish"], {})


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


## The step just taken, to be taken again next frame.
func _rewind() -> void:
	if _calls.is_empty():
		_pc -= 1
		return
	var routine: Dictionary = _calls[_calls.size() - 1]
	routine["pc"] = int(routine["pc"]) - 1


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

	_after_vblank()


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


func shadow_oam_buffer() -> PackedByteArray:
	return _shadow_oam


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


func _play_music(id: int, bank: int = AUDIO_BANK) -> void:
	_sound.play_music(bank, id)
	_emit(&"play_music", {"music": id, "bank": bank})


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


## Yellow's `PlayPikachuSoundClip`, handed to whoever renders the audio.
func _play_pikachu_clip(index: int) -> void:
	_clip = _data.gen1_pikachu_cry(index)
	_clip_lead = Gen1Layout.PIKACHU_CRY_LEAD_FRAMES
	_clip_frames = Gen1Layout.pikachu_cry_frames(_clip.size()) - _clip_lead
	_clip_hold = _clip_frames
	_emit(&"play_pikachu_clip", {"index": index})


## A `PlayPikachuSoundClip` step: the clip started, and its frames spent.
func pikachu_clip_steps(index: int) -> Array:
	return [
		do_step(func() -> void: _play_pikachu_clip(index)),
		delay_step(Gen1Layout.pikachu_cry_frames(_data.gen1_pikachu_cry(index).size())),
	]


## True on a frame the clip holds the driver.
func _clip_frame() -> bool:
	if _clip_lead > 0:
		_clip_lead -= 1
		if _clip_lead == 0:
			_sound.begin_pikachu_clip(_clip)
		return false
	if _clip_hold <= 0:
		return false
	if _clip_hold < _clip_frames:
		_sound.apu.advance_pcm_frame()
	_clip_hold -= 1
	if _clip_hold == 0:
		_sound.end_pikachu_clip()
	return true


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


## A routine that spends frames of its own: [param each] runs once a frame and
## answers true on the frame it is done, which spends nothing more, or a list of
## steps to run before it is asked again.
func until_step(each: Callable) -> Dictionary:
	return {"until": each}
