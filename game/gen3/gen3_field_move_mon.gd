class_name Gen3FieldMoveMon
extends RefCounted

## `FldEff_FieldMoveShowMon`'s banner task ([method run_task], in `RunTasks`, then its VBlank's register writes)
## and mon sprite ([method animate], in `AnimateSprites`), outdoors or indoors.

enum Slide { DUMMY, ON, WAIT, OFF }
## The `CpuCopy16` lengths of `FieldMoveShowMon*Effect_LoadGfx`, indoors then outdoors.
const TILE_BYTES: Array[int] = [0x80, 0x200]
const TILEMAP_WORDS: int = 320
const BANNER_WORD: int = 160
const PIC_SIZE: Vector2i = Vector2i(64, 64)
const SHINY_ODDS: int = 8
const SHINY_TAG_OFFSET: int = 500
const SPINDA_SPOT_BYTES: int = 36
## `InitOverworldGraphicsRegisters`: WIN0 over the whole screen with every layer, WIN1 empty.
const FIELD_WINDOWS: Dictionary = {"win0h": 0x00FF, "win0v": 0x00FF, "win1h": 0xFFFF, "win1v": 0xFFFF,
	"winin": 0x1F1F, "winout": 0x0101}

var active: bool = false
var outdoors: bool = true
var state: int = 0
var registers: Dictionary = FIELD_WINDOWS.duplicate()
var bg0_scroll: Vector2i = Vector2i.ZERO
var bg0_tiles := PackedByteArray()
var bg0_map := PackedInt32Array()
## In [member Gen3ObjectSprites.pics], with its callback and `sOnscreenTimer`.
var sprite: Dictionary = {}

var _sprites: Gen3ObjectSprites
var _frlg: bool = false
var _tilemap := PackedInt32Array()
var _palette := PackedByteArray()
var _data := PackedInt32Array()
var _tag: int = 0


func _init(sprites: Gen3ObjectSprites) -> void:
	_sprites = sprites
	_frlg = sprites.data.id in [RomRegistry.FIRERED, RomRegistry.LEAFGREEN]
	_data.resize(16)


## False when the banner's graphics are not imported.
func start(number: int, personality: int, ot_id: int, outdoors_map: bool, no_ducking: bool = false) -> bool:
	var run: PackedByteArray = _sprites.data.world_field_move_streaks(outdoors_map)
	var size: int = TILE_BYTES[int(outdoors_map)]
	if run.size() != size + Gen3Layout.PALETTE_BYTES + TILEMAP_WORDS * 2:
		return false
	outdoors = outdoors_map
	bg0_tiles = run.slice(0, size)
	_tilemap.resize(TILEMAP_WORDS)
	for word: int in TILEMAP_WORDS:
		_tilemap[word] = run.decode_u16(size + Gen3Layout.PALETTE_BYTES + word * 2)
	_palette = run.slice(size, size + Gen3Layout.PALETTE_BYTES)
	bg0_map.resize(1024)
	bg0_map.fill(0)
	_data.fill(0)
	state = 0
	active = true
	_start_sprite(number, personality, ot_id, no_ducking)
	return true


func run_task() -> void:
	if not active:
		return
	if outdoors:
		_run_outdoors()
	else:
		_run_indoors()
	if not active:
		return
	if outdoors:
		registers.merge({"win0h": _data[1] & 0xFFFF, "win0v": _data[2] & 0xFFFF, "winin": _data[3] & 0xFFFF,
			"winout": _data[4] & 0xFFFF}, true)
		bg0_scroll = Vector2i(_data[5], _data[6])
	else:
		bg0_scroll = Vector2i(_data[1], _data[2])


## The `SpriteCB_FieldMoveMon*` callbacks; the cry is the request on reaching the centre.
func animate() -> Array:
	var requests: Array = []
	if not active:
		return requests
	var x: int = sprite["position"].x
	match int(sprite["slide"]):
		Slide.ON:
			x = _s16(x - 20)
			if x <= 120:
				x = 120
				sprite["timer"] = 30
				sprite["slide"] = Slide.WAIT
				requests.append({"kind": "cry", "species": sprite["species"], "no_ducking": sprite["no_ducking"]})
		Slide.WAIT:
			sprite["timer"] = int(sprite["timer"]) - 1
			if int(sprite["timer"]) == 0:
				sprite["slide"] = Slide.OFF
		Slide.OFF:
			if x < -64:
				sprite["slid_offscreen"] = true
			else:
				x = _s16(x - 20)
	sprite["position"] = Vector2i(x, sprite["position"].y)
	return requests


## BG0 and the window registers for [method Gen3FieldVram.draw_screen], empty once the effect ends.
func screen() -> Dictionary:
	if not active:
		return {}
	var out: Dictionary = registers.duplicate()
	out.merge({"bg0_tiles": bg0_tiles, "bg0_map": bg0_map, "bg0_scroll": bg0_scroll})
	return out


## `CreateMonSprite_FieldMove`: the picture with its shiny or normal palette by tag, kept out of weather fades.
func _start_sprite(number: int, personality: int, ot_id: int, no_ducking: bool) -> void:
	var entry: Dictionary = _sprites.data.species(number)
	var shiny: bool = ((ot_id >> 16) ^ (ot_id & 0xFFFF) ^ (personality >> 16) ^ (personality & 0xFFFF)) < SHINY_ODDS
	_tag = int(entry.get("index", number)) + (SHINY_TAG_OFFSET if shiny else 0)
	var slot: int = _sprites.palette.sprite_index(_tag)
	if slot == 0xFF:
		slot = _sprites.palette.alloc_sprite(_tag)
		if slot != 0xFF:
			var colors := PackedByteArray()
			for color: Variant in entry.get("palette", {}).get("shiny" if shiny else "normal", []):
				colors.append_array([int(color) & 0xFF, int(color) >> 8])
			_sprites.palette.load(colors, Gen3Palette.OBJ_OFFSET + slot * 16)
	if slot != 0xFF and _sprites.weather != null:
		_sprites.weather.preserve_palette(slot + 16)
	sprite = {"sprite_slot": _sprites.effect_slot(false), "position": Vector2i(320, 80), "size": PIC_SIZE, "priority": 0,
		"subpriority": 0, "palette": slot & 0xF, "tiles": front_pic_tiles(_sprites.data, number, personality),
		"slide": Slide.DUMMY, "timer": 0, "slid_offscreen": false, "species": number, "no_ducking": no_ducking}
	_sprites.pics.append(sprite)


## `LoadSpecialPokePic`'s front picture as 4bpp tiles in 1D order: Unown by its personality letter, Spinda spotted.
static func front_pic_tiles(data: GameData, number: int, personality: int) -> PackedByteArray:
	var pic: Dictionary = data.species_pic(number)
	if number == Gen3Layout.UNOWN_SPECIES:
		var letter: int = ((personality >> 18) & 0xC0) | ((personality >> 12) & 0x30) \
			| ((personality >> 6) & 0x0C) | (personality & 0x03)
		pic = data.unown_pic(letter % Gen3Layout.UNOWN_FORMS)
	var out := PackedByteArray()
	out.resize(PIC_SIZE.x * PIC_SIZE.y / 2)
	var record: Dictionary = data.atlas(str(pic.get("atlas", "")))
	if pic.is_empty() or record.is_empty():
		return out
	var indices: PackedByteArray = data.atlas_indices(pic["atlas"])
	var cell: int = int(record["cell"])
	var columns: int = int(record["columns"])
	var corner: Vector2i = Vector2i(int(pic["slot"]) % columns, int(pic["slot"]) / columns) * cell
	for y: int in mini(cell, PIC_SIZE.y):
		for x: int in mini(cell, PIC_SIZE.x):
			var index: int = indices[(corner.y + y) * int(record["width"]) + corner.x + x] & 15
			out[_pixel_byte(x, y)] |= index << ((x % 2) * 4)
	if int(data.species(number).get("index", 0)) == Gen3Layout.SPINDA:
		_draw_spinda_spots(out, personality, data.world_spinda_spots())
	return out


static func _pixel_byte(x: int, y: int) -> int:
	return ((y / 8) * 8 + x / 8) * GbaTiles.TILE_BYTES + (y % 8) * 4 + (x % 8) / 2


## `DRAW_SPINDA_SPOTS`: personality bytes move the spots; a u8 row past the picture falls in later frames.
static func _draw_spinda_spots(out: PackedByteArray, personality: int, spots: PackedByteArray) -> void:
	for spot: int in spots.size() / SPINDA_SPOT_BYTES:
		var at: int = spot * SPINDA_SPOT_BYTES
		var corner := Vector2i((spots[at] + (personality & 0x0F) - 8) & 0xFF,
			(spots[at + 1] + ((personality >> 4) & 0x0F) - 8) & 0xFF)
		for row: int in 16:
			var y: int = (corner.y + row) & 0xFF
			var bits: int = spots.decode_u16(at + 2 + row * 2)
			for column: int in 16:
				var x: int = corner.x + column
				var shift: int = (x & 1) * 4
				var color: int = (out[_pixel_byte(x, y)] >> shift) & 15 if y < PIC_SIZE.y else 0
				if bits & (1 << column) and color >= 1 and color <= 3:
					out[_pixel_byte(x, y)] += 4 << shift
		personality >>= 8


func _run_outdoors() -> void:
	match state:
		0:
			_data[11] = registers["winin"]
			_data[12] = registers["winout"]
			_data[1] = 0xF0F1
			_data[2] = 0x5051
			_data[3] = 0x3F
			_data[4] = 0x3E
			state += 1
		1:
			_load_gfx()
			for word: int in TILEMAP_WORDS:
				bg0_map[BANNER_WORD + word] = _tilemap[word] | 0xF000
			state += 1
		2:
			_create_banner()
		3:
			_data[5] = _s16(_data[5] - 16)
			if sprite["slid_offscreen"]:
				state += 1
		4:
			_shrink_banner()
		5:
			bg0_map.fill(0)
			_data[1] = 0x00F1
			_data[2] = 0x00A1
			_data[3] = _data[11]
			_data[4] = _data[12]
			state += 1
		6:
			_end()


func _load_gfx() -> void:
	bg0_map.fill(0)
	_sprites.palette.load(_palette, 15 * 16)


func _create_banner() -> void:
	_data[5] = _s16(_data[5] - 16)
	var horiz: int = maxi(((_data[1] & 0xFFFF) >> 8) - 16, 0)
	var top: int = maxi(((_data[2] & 0xFFFF) >> 8) - 2, 40)
	var bottom: int = mini((_data[2] & 0xFF) + 2, 120)
	_data[1] = (horiz << 8) | (_data[1] & 0xFF)
	_data[2] = (top << 8) | bottom
	if horiz == 0 and top == 40 and bottom == 120:
		sprite["slide"] = Slide.ON
		state += 1


func _shrink_banner() -> void:
	_data[5] = _s16(_data[5] - 16)
	var top: int = mini(((_data[2] & 0xFFFF) >> 8) + 6, 80)
	var bottom: int = maxi((_data[2] & 0xFF) - 6, 81)
	_data[2] = (top << 8) | bottom
	if top == 80 and bottom == 81:
		state += 1


## FRLG also narrows WIN1 to BG0 and OBJ, which the field's full-screen WIN0 hides in every version.
func _run_indoors() -> void:
	match state:
		0:
			state += 1
		1:
			_load_gfx()
			state += 1
		2:
			if _slide_banner(true):
				if _frlg:
					_data[5] = registers["winin"]
					registers["winin"] = (_data[5] & 0xFF) | 0x1100
				registers.merge({"win1h": 0x00F0, "win1v": 0x2878}, true)
				sprite["slide"] = Slide.ON
				state += 1
			_scroll_indoor_bg()
		3:
			_scroll_indoor_bg()
			if sprite["slid_offscreen"]:
				state += 1
		4:
			_scroll_indoor_bg()
			_data[3] = _data[1] & 7
			_data[4] = 0
			registers.merge({"win1h": 0xFFFF, "win1v": 0xFFFF}, true)
			if _frlg:
				registers["winin"] = _data[5]
			state += 1
		5:
			_scroll_indoor_bg()
			if _slide_banner(false):
				state += 1
		6:
			bg0_map.fill(0)
			_end()


func _scroll_indoor_bg() -> void:
	_data[1] = _s16(_data[1] - 16)
	_data[3] = _s16(_data[3] + 16)


## `SlideIndoorBannerOnscreen` copies two tilemap columns behind the scroll; `SlideIndoorBannerOffscreen` blanks two.
func _slide_banner(on: bool) -> bool:
	if _data[4] >= 32:
		return true
	var column: int = (_data[3] >> 3) & 0xFFFF
	if on:
		column &= 0x1F
	if column < _data[4]:
		return false
	var source: int = (32 - _data[4]) & 0x1F
	column = (32 - column) & 0x1F if on else (_data[1] >> 3) & 0x1F
	for row: int in 10:
		for step: int in 2:
			var word: int = 0xF000
			if on:
				word |= _tilemap[((source + step) & 0x1F) + row * 32]
			bg0_map[BANNER_WORD + ((column + step) & 0x1F) + row * 32] = word
	_data[4] += 2
	return false


## FRLG's `ChangeBgX`/`ChangeBgY` zero BG0's scroll; the Hoenn games leave it.
func _end() -> void:
	if _frlg:
		bg0_scroll = Vector2i.ZERO
	_sprites.pics.erase(sprite)
	if _sprites.weather != null:
		_sprites.weather.reset_preserved()
	_sprites.palette.sprite_tags.erase(_sprites.palette.sprite_index(_tag))
	active = false


static func _s16(value: int) -> int:
	return ((value & 0xFFFF) ^ 0x8000) - 0x8000
