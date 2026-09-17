class_name Gen1AnimatedObjects
extends RefCounted

## `engine/gfx/animated_objects.asm`: ten object structs, each walking a
## frameset of OAM sets into `wShadowOAM` once a frame, over the tables and
## callbacks [Gen1YellowIntro] or [Gen1SurfingMinigame] hands it.

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
const STRUCT_VAR3: int = 13
const STRUCT_VAR4: int = 14
const STRUCT_SIZE: int = 16
const OAM_END: int = Gen1Lcd.OAM_SLOTS * Gen1Lcd.OAM_BYTES

const FLIP_MASK: int = Gen1Lcd.OAM_XFLIP | Gen1Lcd.OAM_YFLIP | Gen1Lcd.OAM_PRIO
const FRAME_FLIP_SHIFT: int = 1
const FRAME_FLIP_MASK: int = 0xC0

## `endanim`, `dorestart`, `dorepeat` and `delanim` as the importer writes them.
const ROW_END: int = -1
const ROW_RESTART: int = -2
const ROW_REPEAT: int = -3
const ROW_DELETE: int = -4

var tables: Dictionary = {}
var shadow: PackedByteArray = PackedByteArray()
## The object jumptable: `(struct: PackedByteArray, index: int)`.
var callback: Callable = Callable()
## The Yellow intro's scene 7 leaves every attribute byte where it stands.
var write_attributes: bool = true
var oam_offset: int = 0

var _structs: Array[PackedByteArray] = []
var _loaded: int = 0


func _init() -> void:
	clear()


func clear() -> void:
	_structs = []
	for _index: int in OBJECTS:
		var struct := PackedByteArray()
		struct.resize(STRUCT_SIZE)
		_structs.append(struct)
	_loaded = 0
	oam_offset = 0


func object(index: int) -> PackedByteArray:
	return _structs[index]


## `SpawnAnimatedObject`: the first free struct, or -1 with none left.
func spawn(kind: int, x: int, y: int) -> int:
	var spawns: Array = tables.get("spawn_states", [])
	if kind >= spawns.size():
		return -1
	for index: int in OBJECTS:
		var struct: PackedByteArray = _structs[index]
		if struct[STRUCT_LIVE] != 0:
			continue
		_loaded += 1
		struct.fill(0)
		struct[STRUCT_LIVE] = _loaded & 0xFF
		struct[STRUCT_FRAMESET] = int(spawns[kind][0])
		struct[STRUCT_CALLBACK] = int(spawns[kind][1])
		struct[STRUCT_X] = x & 0xFF
		struct[STRUCT_Y] = y & 0xFF
		struct[STRUCT_FRAME] = 0xFF
		return index
	return -1


func mask(index: int) -> void:
	if index >= 0 and index < OBJECTS:
		_structs[index][STRUCT_LIVE] = 0


func mask_all() -> void:
	for struct: PackedByteArray in _structs:
		struct[STRUCT_LIVE] = 0


## `SetCurrentAnimatedObjectCallbackAndResetFrameStateRegisters`, which sets
## the frameset rather than the callback its name says.
static func set_frameset(struct: PackedByteArray, frameset: int) -> void:
	struct[STRUCT_FRAMESET] = frameset & 0xFF
	struct[STRUCT_TIMER] = 0
	struct[STRUCT_DURATION_OFFSET] = 0
	struct[STRUCT_FRAME] = 0xFF


## `RunObjectAnimations` from [param from], the rest of the buffer zeroed.
func run(from: int = 0) -> void:
	oam_offset = from
	for index: int in OBJECTS:
		var struct: PackedByteArray = _structs[index]
		if struct[STRUCT_LIVE] == 0:
			continue
		if callback.is_valid():
			callback.call(struct, index)
		if not _update_frame(struct, index):
			return
	while oam_offset < OAM_END:
		shadow[oam_offset] = 0
		oam_offset += 1


## False once the buffer is full.
func _update_frame(struct: PackedByteArray, index: int) -> bool:
	var frame: Dictionary = _advance_duration(struct)
	var set_id: int = int(frame["set"])
	if set_id == ROW_DELETE:
		mask(index)
		return true
	if set_id < 0:
		return true
	var sets: Array = tables.get("oam_sets", [])
	if set_id >= sets.size():
		return true
	var oam_set: Dictionary = sets[set_id]
	var vtile: int = (struct[STRUCT_VTILE] + int(oam_set["tile"])) & 0xFF
	var flips: int = int(frame["flips"])
	for sprite: Array in oam_set["sprites"]:
		if oam_offset >= OAM_END:
			return false
		var y: int = (struct[STRUCT_Y] + struct[STRUCT_YOFF]
			+ _flipped(int(sprite[0]), flips & Gen1Lcd.OAM_YFLIP)) & 0xFF
		var x: int = (struct[STRUCT_X] + struct[STRUCT_XOFF]
			+ _flipped(int(sprite[1]), flips & Gen1Lcd.OAM_XFLIP)) & 0xFF
		var attributes: int = ((int(sprite[3]) ^ flips) & FLIP_MASK) \
			| (int(sprite[3]) & Gen1Lcd.OAM_PAL1)
		if attributes & Gen1Lcd.OAM_PAL1:
			attributes |= Gen1Lcd.OAM_HIGH_PALS
		shadow[oam_offset] = y
		shadow[oam_offset + 1] = x
		shadow[oam_offset + 2] = (vtile + int(sprite[2])) & 0xFF
		if write_attributes:
			shadow[oam_offset + 3] = attributes
		oam_offset += Gen1Lcd.OAM_BYTES
	return true


## `GetCurrentAnimatedObjectTileYCoordinate` and its X twin.
static func _flipped(offset: int, flipped: int) -> int:
	if flipped == 0:
		return offset
	return (-(offset + Gen1Lcd.TILE)) & 0xFF


## `UpdateDurationTimerAndFrameStateForCurrentAnimatedObject`. A `dorepeat`
## row is drawn as nothing for its count, which is how a score blinks.
func _advance_duration(struct: PackedByteArray) -> Dictionary:
	var framesets: Array = tables.get("frames", [])
	var rows: Array = framesets[struct[STRUCT_FRAMESET]] \
		if struct[STRUCT_FRAMESET] < framesets.size() else []
	for _guard: int in 8:
		if struct[STRUCT_TIMER] != 0:
			struct[STRUCT_TIMER] -= 1
			var row: Array = _row(rows, struct[STRUCT_FRAME])
			return {"set": int(row[0]), "flips": (int(row[1]) & FRAME_FLIP_MASK) >> FRAME_FLIP_SHIFT}
		struct[STRUCT_FRAME] = (struct[STRUCT_FRAME] + 1) & 0xFF
		var next: Array = _row(rows, struct[STRUCT_FRAME])
		var command: int = int(next[0])
		if command == ROW_RESTART:
			struct[STRUCT_TIMER] = 0
			struct[STRUCT_FRAME] = 0xFF
			continue
		if command == ROW_END:
			struct[STRUCT_TIMER] = 0
			struct[STRUCT_FRAME] = (struct[STRUCT_FRAME] - 2) & 0xFF
			continue
		struct[STRUCT_TIMER] = ((int(next[1]) & Gen1Layout.ANIM_FRAME_DURATION_MASK)
			+ struct[STRUCT_DURATION_OFFSET]) & 0xFF
		return {"set": command, "flips": (int(next[1]) & FRAME_FLIP_MASK) >> FRAME_FLIP_SHIFT}
	return {"set": ROW_END, "flips": 0}


static func _row(rows: Array, index: int) -> Array:
	if index < 0 or index >= rows.size():
		return [ROW_END, 0]
	return rows[index]
