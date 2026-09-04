class_name Gen2BattleAnimPlayer
extends RefCounted

## One battle animation playing: `RunBattleAnimScript`'s frame loop
## (engine/battle_anims/anim_commands.asm). [Gen2BattleAnimScript] is the
## interpreter and [Gen2BattleAnimObject] is one object; this runs the script
## until it yields, steps every live object and collects what they would put in
## `wShadowOAM`. [method unimplemented] reports what an animation asked for and
## did not get.

## `NUM_BATTLE_ANIM_STRUCTS`: an eleventh object is simply not spawned.
const MAX_OBJECTS: int = 10

const OBJECT_STRUCT_BYTES: int = 24

## `BattleAnimCmd_ClearObjs` clears `$a0` bytes where the ten structs are `$f0`,
## stopping inside the seventh. Zeroing a struct's first byte frees it, so seven
## go and the last three survive a command that reads as clearing everything:
## the cartridge's own bug (docs/bugs_and_glitches.md), reproduced.
const CLEAR_OBJS_BYTES: int = 0xA0

## The hardware's forty sprites.
const MAX_SPRITES: int = 40

## The five sheets `anim_1gfx` through `anim_5gfx` may have loaded at once.
const TILE_DICT_ENTRIES: int = 5

## The window graphics load into, `BATTLEANIM_BASE_TILE` up to `vTiles1`.
## `BattleAnimCmd_*GFX` stops once the running tile id reaches it, so a
## five-sheet animation can silently load fewer.
const MAX_TILES: int = 128 - Gen2BattleAnimObject.BASE_TILE

## `wBattleAnimFlags` bits (constants/ram_constants.asm).
const FLAG_KEEP_SPRITES: int = 1 << 3

## The two `AnimObjGFX` rows with no sheet: the battler graphics commands fill
## them from whichever picture is on the field.
const GFX_PLAYERHEAD: int = 0x28
const GFX_ENEMYFEET: int = 0x29

## `vTiles0`, whose top `BattleAnimCmd_BattlerGFX_*` counts back from.
const OBJECT_TILES: int = 0x80

## `NUM_BG_EFFECTS`: a sixth is not queued.
const MAX_BG_EFFECTS: int = Gen2BattleAnimBgEffects.MAX_EFFECTS

## What `Rollout_FillLYOverridesBackup` and `.playframe` check `wFXAnimID` for.
const ROLLOUT: int = 0xCD

## `BATTLE_AFTERANIMS` and the four offsets from it written into
## `wBattleAfterAnim`; `BattleAnimRunScript` adds the base back.
const BATTLE_AFTERANIMS: int = 0x10E
const AFTER_ANIM_NONE: int = 0
const AFTER_ANIM_ENEMY_DAMAGE: int = 0x10F - BATTLE_AFTERANIMS
const AFTER_ANIM_ENEMY_STAT_DOWN: int = 0x110 - BATTLE_AFTERANIMS
const AFTER_ANIM_PLAYER_DAMAGE: int = 0x112 - BATTLE_AFTERANIMS
const AFTER_ANIM_WOBBLE: int = 0x113 - BATTLE_AFTERANIMS

## A guard on the steps one frame may take: only `FRAMEBLOCKMODE_02` takes none.
const GEN1_MAX_STEPS: int = 64

## `DrawFrameBlock`'s exception: GROWL keeps the sprite buffer between blocks,
## because `DoGrowlSpecialEffects` is what doubles the note and clears up.
const GEN1_GROWL: int = 0x2D

## `SUBANIMTYPE_HVFLIP` compares the whole byte, so anything but a bare flip,
## an OBP1 bit included, comes out with no flags at all.
const GEN1_HVFLIP_FLAGS: Dictionary = {
	0x00: Gen2BattleAnimObject.OAM_YFLIP | Gen2BattleAnimObject.OAM_XFLIP,
	Gen2BattleAnimObject.OAM_XFLIP: Gen2BattleAnimObject.OAM_YFLIP,
	Gen2BattleAnimObject.OAM_YFLIP: Gen2BattleAnimObject.OAM_XFLIP,
}

## The status animations `PlayOpponentBattleAnim` plays on the target, past
## `wFXAnimID`'s low byte and so reached by `BattleAnimRunScript`'s `.not_move`.
## Only these five of the block are named, the rest having no caller: `ANIM_SLP`
## and `ANIM_SAP` sit among them and nothing in either pin asks for one.
const ANIM_CONFUSED: int = 0x103
const ANIM_BRN: int = 0x105
const ANIM_PSN: int = 0x106
const ANIM_FRZ: int = 0x108
const ANIM_PAR: int = 0x109

var _data: Gen2BattleAnimData = null
var _script: Gen2BattleAnimScript = null
var _anim_index: int = 0
var _enemy_turn: bool = false

var _objects: Array[Gen2BattleAnimObject] = []
var _last_object_index: int = 0
## `wBattleAnimTileDict`: five (graphics id, tile offset) pairs.
var _tile_dict: Array = []
## [code]{ gfx, tile }[/code] per loaded tile, so a renderer knows where an OAM
## tile id's pixels come from.
var _tiles: Array = []
var _keep_sprites: bool = false
var _sprites: Array = []
## What the last frame's `RunBattleAnimCommand` ran, for the caller that owns
## what the interpreter does not: `anim_sound` and `anim_cry` need an audio player.
var _frame_commands: Array = []
var _unimplemented: Dictionary = {}
## `wActiveBGEffects`: five `battle_bg_effect` slots.
var _bg_effects: Array[Gen2BattleAnimBgEffect] = []
## The video state the bg effects and `BattleAnimFunc_Surf` share.
var _background: Gen2BattleAnimBackground = null

## Generation 1's own state; see [method create_gen1].
var _gen1: bool = false
var _gen1_at: int = 0
var _gen1_done: bool = false
var _gen1_delay: int = 0
var _gen1_transform: int = Gen1Layout.SUBANIMTYPE_NORMAL
var _gen1_rows: Array = []
var _gen1_row: int = 0
var _gen1_mode: int = -1
var _gen1_write: int = 0
var _gen1_block: int = 0
var _gen1_steps: Array = []
var _gen1_wait: int = 0

## `wCurItem`, read by `GetBallAnimPal` to colour a thrown ball. Nothing else
## asks, and a non-ball falls out of `BallColors` on its own terminator.
var cur_item: int = 0

## The Fly and Dig bits three bg effects check before touching a battler.
var player_off_field: bool = false
var enemy_off_field: bool = false


## Starts [param index] of `BattleAnimations`, null when the cache has no such
## animation. [param param] is `wBattleAnimParam` and [param on_enemy_turn] is
## `hBattleTurn`, the two inputs set before `PlayBattleAnim`.
static func create(
	anim_data: Gen2BattleAnimData, index: int, on_enemy_turn: bool = false,
	param: int = 0, wobbles: Array[int] = []
) -> Gen2BattleAnimPlayer:
	if anim_data == null:
		return null
	var region: Dictionary = anim_data.region(&"scripts")
	var address: int = anim_data.pointer(&"scripts", index)
	if region.is_empty() or address < 0:
		return null

	var player := Gen2BattleAnimPlayer.new()
	player._data = anim_data
	player._anim_index = index
	player._enemy_turn = on_enemy_turn
	# `ClearBattleAnims` zeroes the whole animation block before the script's
	# pointer is loaded, so every object slot, the tile dict and the flags start
	# empty on each animation rather than carrying over from the last one.
	player._objects.resize(MAX_OBJECTS)
	player._tile_dict.resize(TILE_DICT_ENTRIES)
	player._bg_effects.resize(MAX_BG_EFFECTS)
	for slot: int in MAX_BG_EFFECTS:
		player._bg_effects[slot] = Gen2BattleAnimBgEffect.new()
	player._background = Gen2BattleAnimBackground.new()
	player._script = Gen2BattleAnimScript.create(
		region["data"], int(region["address"]), address, param, wobbles
	)
	return player


## `PlayAnimation`: `battle_anim` rows, each a special effect or a subanimation
## of frame blocks drawn straight into `wShadowOAM`. There is no `param` and no
## wobble list, and a row's sound byte is dropped for want of an audio driver.
static func create_gen1(
	anim_data: Gen2BattleAnimData, index: int, on_enemy_turn: bool = false
) -> Gen2BattleAnimPlayer:
	if anim_data == null or not anim_data.gen1():
		return null
	var address: int = anim_data.pointer(Gen2BattleAnimData.GEN1_REGION, index)
	if address < 0:
		return null

	var player := Gen2BattleAnimPlayer.new()
	player._data = anim_data
	player._anim_index = index
	player._enemy_turn = on_enemy_turn
	player._gen1 = true
	player._gen1_at = address
	player._objects.resize(MAX_OBJECTS)
	player._tile_dict.resize(TILE_DICT_ENTRIES)
	player._bg_effects.resize(MAX_BG_EFFECTS)
	for slot: int in MAX_BG_EFFECTS:
		player._bg_effects[slot] = Gen2BattleAnimBgEffect.new()
	player._background = Gen2BattleAnimBackground.new()
	return player


## `hBattleTurn`, which two callbacks and the enemy-side coordinate fix read.
func enemy_turn() -> bool:
	return _enemy_turn


func data() -> Gen2BattleAnimData:
	return _data


func profile() -> StringName:
	return _data.profile()


## `wFXAnimID`, which two routines compare against `ROLLOUT`.
func anim_index() -> int:
	return _anim_index


func background() -> Gen2BattleAnimBackground:
	return _background


## The live `wActiveBGEffects` slots.
func bg_effects() -> Array:
	var out: Array = []
	for effect: Gen2BattleAnimBgEffect in _bg_effects:
		if effect.active():
			out.append(effect)
	return out


## `BGEffect_CheckFlyDigStatus`: whether the battler is off the field mid-Fly or
## mid-Dig, which stops three effects touching a picture that is not there.
func fly_dig_status(player_side: bool) -> bool:
	return player_off_field if player_side else enemy_off_field


## `wLastAnimObjectIndex` stepped on without an object being built, which is what
## a battler-object effect does when the battler is off the field.
func bump_object_index() -> void:
	_last_object_index = (_last_object_index + 1) & 0xFF


## `_QueueBattleAnimation`, with the four values `anim_obj` supplies.
func queue_object(row: int, x: int, y: int, param: int) -> void:
	_queue_object([row, x, y, param])


## `wAnimObject1YOffset`, which `BattleBGEffect_Rollout` writes straight into the
## first struct whether or not a live object is standing in it.
func set_first_object_y_offset(value: int) -> void:
	if _objects[0] == null:
		_objects[0] = Gen2BattleAnimObject.new()
	_objects[0].y_offset = value & 0xFF


func finished() -> bool:
	return _gen1_done if _gen1 else _script.finished()


func failed() -> bool:
	return false if _gen1 else _script.failed()


## The sprites the last frame put in `wShadowOAM`, each
## [code]{ y, x, tile, attributes }[/code] with the cartridge's own byte values.
## A y or x of zero is off screen: OAM subtracts 16 and 8 from what is written.
func sprites() -> Array:
	return _sprites


## What each tile of the animation window currently holds, indexed from
## [constant Gen2BattleAnimObject.BASE_TILE]. An OAM tile id below that base is
## not an animation tile at all.
##
## Two shapes: [code]{ gfx, tile }[/code] is a tile of an imported sheet, and
## [code]{ battler_tile }[/code] a tile of `vTiles2`, which is where the battle's
## own two pictures live, in the numbering [Gen2BattleScreenMap] uses. Only
## `anim_battlergfx_1row` and `..._2row` produce the second.
func tiles() -> Array:
	return _tiles


## Each [code]{ name, byte, operands }[/code], as the script reports them.
func frame_commands() -> Array:
	return _frame_commands


## The live objects, for a caller that wants more than their sprites.
func objects() -> Array:
	var out: Array = []
	for object: Gen2BattleAnimObject in _objects:
		if object != null and object.active():
			out.append(object)
	return out


## What this animation asked for and did not get, as
## [code]{ "bg_effects": [id, ...], "functions": [id, ...], "gen1_effects":
## [id, ...] }[/code], each id once. Empty lists when the animation ran whole.
func unimplemented() -> Dictionary:
	var out: Dictionary = {"bg_effects": [], "functions": [], "gen1_effects": []}
	for key: String in _unimplemented:
		var parts: PackedStringArray = key.split(":")
		(out[parts[0]] as Array).append(int(parts[1]))
	for kind: String in out:
		(out[kind] as Array).sort()
	return out


## One hardware frame of `.playframe`, in its order: the script, the bg effects,
## every object, the scanline table and the palettes. `.playframe` skips its own
## `BattleAnimDelayFrame` while Rollout's bg effect is live, because that effect
## waits a frame itself, but both paths spend exactly one frame, so a player
## stepped once per frame has nothing for the check to decide.
func advance_frame() -> bool:
	if finished():
		_finish()
		return false
	if _gen1:
		return _gen1_frame()

	_run_commands()
	_execute_bg_effects()
	_update_oam()
	_background.push_ly_overrides()
	_background.request_pals()
	if finished():
		_finish()
	return true


## `RunBattleAnimCommand`, plus the commands that reach past the interpreter.
func _run_commands() -> void:
	_frame_commands = _script.advance_frame()
	for command: Dictionary in _frame_commands:
		match command["name"]:
			Gen2BattleAnimScript.OBJ:
				_queue_object(command["operands"])
			&"gfx_1", &"gfx_2", &"gfx_3", &"gfx_4", &"gfx_5":
				_load_graphics(command["operands"])
			&"battler_gfx_1row":
				_load_battler_graphics(1)
			&"battler_gfx_2row":
				_load_battler_graphics(2)
			&"inc_obj":
				var target: Gen2BattleAnimObject = _object_with_index(
					int((command["operands"] as Array)[0])
				)
				if target != null:
					target.jumptable_index = (target.jumptable_index + 1) & 0xFF
			&"set_obj":
				var operands: Array = command["operands"]
				var found: Gen2BattleAnimObject = _object_with_index(int(operands[0]))
				if found != null:
					found.jumptable_index = int(operands[1])
			&"clear_objs":
				_clear_objects()
			&"keep_sprites":
				_keep_sprites = true
			&"bg_effect":
				_queue_bg_effect(command["operands"])
			&"inc_bg_effect":
				var live: Gen2BattleAnimBgEffect = _bg_effect_with_id(
					int((command["operands"] as Array)[0])
				)
				if live != null:
					live.jumptable_index = (live.jumptable_index + 1) & 0xFF
			&"bgp":
				_background.bgp = int((command["operands"] as Array)[0])
			&"obp0":
				_background.obp0 = int((command["operands"] as Array)[0])
			&"obp1":
				_background.obp1 = int((command["operands"] as Array)[0])
			&"reset_obp0":
				# `hSGB`'s $f0 is the branch the Color hardware does not take.
				_background.obp0 = 0xE0


## `QueueBattleAnimation`: the first free slot, or nothing at all. The index
## counter is bumped before the object is built and is never reset, so it wraps
## through a byte over a long animation.
func _queue_object(operands: Array) -> void:
	for slot: int in MAX_OBJECTS:
		var existing: Gen2BattleAnimObject = _objects[slot]
		if existing != null and existing.active():
			continue
		_last_object_index = (_last_object_index + 1) & 0xFF
		var row: Dictionary = _data.object_row(int(operands[0]))
		if row.is_empty():
			return
		_objects[slot] = Gen2BattleAnimObject.create(
			_last_object_index, row, _tile_offset(int(row[&"gfx"])),
			int(operands[1]), int(operands[2]), int(operands[3])
		)
		return


## `BattleAnimCmd_*GFX`: each named sheet into the window in turn, until full.
func _load_graphics(operands: Array) -> void:
	var next_tile: int = 0
	var entry: int = 0
	for gfx: Variant in operands:
		if next_tile >= MAX_TILES:
			return
		if entry >= TILE_DICT_ENTRIES:
			return
		_tile_dict[entry] = {"gfx": int(gfx), "tile": next_tile}
		entry += 1
		var row: Dictionary = _data.gfx(int(gfx))
		var count: int = int(row.get("tiles", 0)) if not row.is_empty() else 0
		for tile: int in count:
			if next_tile + tile >= MAX_TILES:
				break
			_tiles.resize(maxi(_tiles.size(), next_tile + tile + 1))
			_tiles[next_tile + tile] = {"gfx": int(gfx), "tile": tile}
		next_tile += count


## `BattleAnimCmd_BattlerGFX_1Row` and `..._2Row`: one or two rows of each
## battler's picture copied into the top of the animation window, so an effect can
## lift a battler's feet or head off the tilemap and move them as objects.
## The dict entries are crosswise with what is copied, `PLAYERHEAD` holding the
## enemy's rows, and the object rows are crossed the same way, so the two cancel.
## Both crossings are the cartridge's and neither is tidied.
func _load_battler_graphics(rows: int) -> void:
	var slot: int = _free_tile_dict_slot()
	if slot < 0 or slot + 1 >= TILE_DICT_ENTRIES:
		return

	var enemy_tiles: int = Gen2BattleScreenMap.ENEMY_SIDE * rows
	var player_tiles: int = Gen2BattleScreenMap.PLAYER_SIDE * rows
	var first: int = (OBJECT_TILES - player_tiles - enemy_tiles) \
		- Gen2BattleAnimObject.BASE_TILE
	var second: int = (OBJECT_TILES - player_tiles) - Gen2BattleAnimObject.BASE_TILE
	_tile_dict[slot] = {"gfx": GFX_PLAYERHEAD, "tile": first}
	_tile_dict[slot + 1] = {"gfx": GFX_ENEMYFEET, "tile": second}

	# The enemy's bottom rows, then the player's top ones, each column of the
	# picture contributing `rows` tiles: `.LoadFeet` steps the source by the
	# picture's own height and the destination by what it just copied.
	_copy_battler_rows(
		first, rows, Gen2BattleScreenMap.ENEMY_SIDE,
		Gen2BattleScreenMap.ENEMY_BASE_TILE + Gen2BattleScreenMap.ENEMY_SIDE - rows
	)
	_copy_battler_rows(
		second, rows, Gen2BattleScreenMap.PLAYER_SIDE,
		Gen2BattleScreenMap.PLAYER_BASE_TILE
	)


## One picture's rows into the window. Both pictures are square, so the source
## stride is the same [param side] the column count is.
func _copy_battler_rows(at: int, rows: int, side: int, source: int) -> void:
	for column: int in side:
		for row: int in rows:
			var window: int = at + column * rows + row
			if window < 0 or window >= MAX_TILES:
				continue
			_tiles.resize(maxi(_tiles.size(), window + 1))
			_tiles[window] = {"battler_tile": source + column * side + row}


## The first tile dict slot nothing has claimed. `BattleAnimCmd_BattlerGFX_*`
## walks the dict for a zero graphics id rather than starting at the front, which
## is what lets it sit behind an `anim_1gfx`.
func _free_tile_dict_slot() -> int:
	for slot: int in TILE_DICT_ENTRIES:
		var entry: Variant = _tile_dict[slot]
		if not entry is Dictionary or int((entry as Dictionary).get("gfx", 0)) == 0:
			return slot
	return -1


## `GetBattleAnimTileOffset`: where in the window a graphics id was loaded, or
## zero when it was not loaded at all, which draws the window's first tiles
## rather than nothing.
func _tile_offset(gfx: int) -> int:
	for entry: Variant in _tile_dict:
		if entry is Dictionary and int((entry as Dictionary)["gfx"]) == gfx:
			return int((entry as Dictionary)["tile"])
	return 0


func _object_with_index(index: int) -> Gen2BattleAnimObject:
	for object: Gen2BattleAnimObject in _objects:
		if object != null and object.index == index:
			return object
	return null


## `BattleAnimCmd_ClearObjs` and its own byte count; see
## [constant CLEAR_OBJS_BYTES].
func _clear_objects() -> void:
	@warning_ignore("integer_division")
	var freed: int = (CLEAR_OBJS_BYTES + OBJECT_STRUCT_BYTES - 1) / OBJECT_STRUCT_BYTES
	for slot: int in mini(freed, MAX_OBJECTS):
		if _objects[slot] != null:
			_objects[slot].deinit()


## `QueueBGEffect`: the first free slot, or nothing at all. Unlike an object, a
## refused effect leaves no trace: there is no index counter to step on.
func _queue_bg_effect(operands: Array) -> void:
	for slot: int in MAX_BG_EFFECTS:
		if _bg_effects[slot].active():
			continue
		_bg_effects[slot] = Gen2BattleAnimBgEffect.create(
			int(operands[0]), int(operands[1]), int(operands[2]), int(operands[3])
		)
		return


func _bg_effect_with_id(id: int) -> Gen2BattleAnimBgEffect:
	for effect: Gen2BattleAnimBgEffect in _bg_effects:
		if effect.id == id:
			return effect
	return null


## `_ExecuteBGEffects`: every live slot in order. An id past this profile's own
## table is reported rather than run; cartridge data never produces one.
func _execute_bg_effects() -> void:
	for effect: Gen2BattleAnimBgEffect in _bg_effects:
		if not effect.active():
			continue
		if not Gen2BattleAnimBgEffects.run(self, effect):
			_note(&"bg_effects", effect.id)


## `BattleAnim_UpdateOAM_All`: every live object stepped and drawn in slot order,
## stopping at the first whose sprites would not fit. The slot's index byte is
## tested once, at the top of the loop, so an object whose own callback calls
## `DeinitBattleAnimation` is still drawn once more where it stands. Measured on a
## cartridge: TACKLE's `anim_incobj 1` frees the target's two rows on the frame it
## runs and OAM still holds their fourteen sprites.
func _update_oam() -> void:
	_sprites = []
	for object: Gen2BattleAnimObject in _objects:
		if object == null or not object.active():
			continue
		_do_battle_anim_frame(object)
		var update: Dictionary = object.oam_update(_data, _enemy_turn, _anim_index)
		var new_sprites: Array = update["sprites"]
		if _sprites.size() + new_sprites.size() > MAX_SPRITES:
			# `BattleAnimOAMUpdate` returns carry once the pointer reaches the end
			# of the shadow buffer, and the caller stops there.
			for sprite: Variant in new_sprites:
				if _sprites.size() >= MAX_SPRITES:
					break
				_sprites.append(sprite)
			return
		_sprites.append_array(new_sprites)


## `DoBattleAnimFrame`: the object's own motion callback, in
## [Gen2BattleAnimFunctions]. A callback outside the jumptable is reported rather
## than run; only a hand-built object can reach that.
func _do_battle_anim_frame(object: Gen2BattleAnimObject) -> void:
	if not Gen2BattleAnimFunctions.run(self, object):
		_note(&"functions", object.function)


## `BattleAnim_ClearOAM`. Keeping the sprites does not keep their colours: every
## one is moved onto `PAL_BATTLE_OB_ENEMY`, which the source asserts is zero.
func _finish() -> void:
	if not _keep_sprites:
		_sprites = []
		return
	var kept: Array = []
	for sprite: Variant in _sprites:
		var entry: Dictionary = (sprite as Dictionary).duplicate()
		entry["attributes"] = int(entry["attributes"]) & ~(
			Gen2BattleAnimObject.OAM_PALETTE | Gen2BattleAnimObject.OAM_BANK1
		) & 0xFF
		kept.append(entry)
	_sprites = kept


func _note(kind: StringName, id: int) -> void:
	_unimplemented["%s:%d" % [kind, id]] = true


## One frame of `PlayAnimation`: every `DelayFrames` is a countdown here, and a
## `FRAMEBLOCKMODE_02` row takes none, so several can build one picture.
func _gen1_frame() -> bool:
	_frame_commands = []
	if _gen1_wait <= 0:
		for _step: int in GEN1_MAX_STEPS:
			if _gen1_done or _gen1_wait > 0:
				break
			_gen1_step()
	_gen1_wait = maxi(_gen1_wait - 1, 0)
	if finished():
		_finish()
	return true


func _gen1_step() -> void:
	if not _gen1_steps.is_empty():
		_gen1_effect_step()
	elif _gen1_mode >= 0 or _gen1_row < _gen1_rows.size():
		_gen1_subanim_step()
	else:
		_gen1_read_row()


## One `battle_anim` row; $FF is the terminator before it is an effect id.
func _gen1_read_row() -> void:
	var byte: int = _gen1_byte(_gen1_at)
	if byte == Gen1Layout.ANIM_END:
		_gen1_done = true
		return
	if byte >= Gen1Layout.ANIM_FIRST_SE_ID:
		_gen1_at += Gen1Layout.ANIM_SE_SIZE
		_gen1_begin_effect(byte)
		return
	_gen1_delay = byte & Gen1Layout.ANIM_DELAY_MASK
	var subanim: int = _gen1_byte(_gen1_at + 2)
	_gen1_at += Gen1Layout.ANIM_SUBANIM_SIZE
	_gen1_load_tileset(byte >> Gen1Layout.ANIM_TILESET_SHIFT)
	_gen1_begin_subanim(subanim)


## `LoadMoveAnimationTiles`: one sheet at `vSprites tile $31`, which every frame
## block tile is counted from, so the window is the sheet itself.
func _gen1_load_tileset(tileset: int) -> void:
	var row: Dictionary = _data.gfx(tileset)
	if row.is_empty():
		return
	_tiles = []
	_tiles.resize(int(row["tiles"]))
	for tile: int in _tiles.size():
		_tiles[tile] = {"gfx": tileset, "tile": tile}


## `LoadSubanimation`: the transform the header's type answers against whose
## turn it is. `SUBANIMTYPE_REVERSE` walks the rows backwards instead.
func _gen1_begin_subanim(index: int) -> void:
	var subanim: Dictionary = _data.gen1_subanim(index)
	var kind: int = int(subanim.get("kind", Gen1Layout.SUBANIMTYPE_NORMAL))
	if kind == Gen1Layout.SUBANIMTYPE_ENEMY:
		_gen1_transform = Gen1Layout.SUBANIMTYPE_NORMAL if _enemy_turn \
			else Gen1Layout.SUBANIMTYPE_HFLIP
	else:
		_gen1_transform = kind if _enemy_turn else Gen1Layout.SUBANIMTYPE_NORMAL

	_gen1_rows = subanim.get("rows", [])
	if _gen1_transform == Gen1Layout.SUBANIMTYPE_REVERSE:
		_gen1_rows.reverse()
	_gen1_row = 0
	_gen1_mode = -1
	# `PlaySubanimation` rewinds without clearing, so a shorter block leaves
	# the tail of a longer one.
	_gen1_write = 0


func _gen1_subanim_step() -> void:
	if _gen1_mode >= 0:
		var counter: int = _gen1_rows.size() - _gen1_row + 1
		_gen1_end_block()
		_gen1_steps = _gen1_block_effect_steps(counter)
		if not _gen1_steps.is_empty():
			return
	if _gen1_row >= _gen1_rows.size():
		_gen1_rows = []
		return
	var row: Dictionary = _gen1_rows[_gen1_row]
	_gen1_row += 1
	_gen1_block = _gen1_write
	_gen1_draw_block(int(row["frame_block"]), int(row["base_coord"]))
	_gen1_mode = int(row["mode"])
	_gen1_wait = 0 if _gen1_mode == Gen1Layout.FRAMEBLOCKMODE_KEEP_NO_DELAY \
		else _gen1_delay


## After `DrawFrameBlock`'s delay: `FRAMEBLOCKMODE_04` rewinds so the next block
## lands on this one, and GROWL keeps the buffer while rewinding to the top.
func _gen1_end_block() -> void:
	var mode: int = _gen1_mode
	_gen1_mode = -1
	if mode == Gen1Layout.FRAMEBLOCKMODE_KEEP_NO_DELAY \
			or mode == Gen1Layout.FRAMEBLOCKMODE_KEEP:
		return
	if mode == Gen1Layout.FRAMEBLOCKMODE_HOLD:
		_gen1_write = _gen1_block
		return
	if _anim_index != GEN1_GROWL:
		_sprites = []
	_gen1_write = 0


## One frame block into `wShadowOAM`: every sum is a byte, every tile plus `$31`.
func _gen1_draw_block(frame_block: int, base_coord: int) -> void:
	var base: Vector2i = _data.gen1_base_coord(base_coord)
	for sprite: Dictionary in _data.gen1_frame_block(frame_block):
		if _gen1_write >= MAX_SPRITES:
			return
		var placed: Dictionary = _gen1_place(sprite, base)
		_sprites.resize(maxi(_sprites.size(), _gen1_write + 1))
		_sprites[_gen1_write] = placed
		_gen1_write += 1


## `DrawFrameBlock`'s four branches over `wSubAnimTransform`.
func _gen1_place(sprite: Dictionary, base: Vector2i) -> Dictionary:
	var y: int = base.y + int(sprite["y"])
	var x: int = base.x + int(sprite["x"])
	var flags: int = int(sprite["attributes"])
	match _gen1_transform:
		Gen1Layout.SUBANIMTYPE_HVFLIP:
			y = Gen1Layout.ANIM_FLIP_Y - y
			x = Gen1Layout.ANIM_FLIP_X - x
			flags = GEN1_HVFLIP_FLAGS.get(flags, 0)
		Gen1Layout.SUBANIMTYPE_HFLIP:
			y += Gen1Layout.ANIM_HFLIP_DROP
			x = Gen1Layout.ANIM_FLIP_X - x
			flags ^= Gen2BattleAnimObject.OAM_XFLIP
		Gen1Layout.SUBANIMTYPE_COORDFLIP:
			y = Gen1Layout.ANIM_FLIP_Y - base.y + int(sprite["y"])
			x = Gen1Layout.ANIM_FLIP_X - base.x + int(sprite["x"])
	return {
		"y": y & 0xFF,
		"x": x & 0xFF,
		"tile": (int(sprite["tile"]) + Gen1Layout.ANIM_BASE_TILE) & 0xFF,
		"attributes": flags & 0xFF,
	}


func _gen1_byte(address: int) -> int:
	return _data.byte_at(Gen2BattleAnimData.GEN1_REGION, address)


## `DoSpecialEffect`: the routine `SpecialEffectPointers` names, as a list of
## [code]{ frames, ... }[/code] steps whose other keys are [constant
## GEN1_EFFECT_KEYS]. An id with no list is reported and costs no frames.
func _gen1_begin_effect(id: int) -> void:
	_gen1_steps = _gen1_effect_steps(id)
	if _gen1_steps.is_empty():
		_note(&"gen1_effects", id)


func _gen1_effect_step() -> void:
	var step: Dictionary = _gen1_steps.pop_front()
	for key: StringName in GEN1_EFFECT_KEYS:
		if step.has(key):
			_gen1_apply(key, step[key])
	_gen1_wait = int(step.get(&"frames", 0))


## One step's effect. `visible`, `shift` and `scale` name a side the way
## `CallWithTurnFlipped` does: whether it is the animation's actor.
func _gen1_apply(key: StringName, value: Variant) -> void:
	match key:
		&"bgp":
			_background.bgp = int(value)
			_background.request_pals()
		&"scx":
			_background.scx = int(value) & 0xFF
		&"scy":
			_background.scy = int(value) & 0xFF
		&"end_subanim":
			_gen1_row = _gen1_rows.size()
		&"copy_sprites":
			_gen1_copy_sprites(int(value))
		&"visible":
			var side: Array = value
			_background.report_battler(_gen1_side(bool(side[0])), bool(side[1]))
		&"shift":
			var moved: Array = value
			_background.battler_shift[_gen1_side(bool(moved[0]))] = moved[1] as Vector2
		&"scale":
			var sized: Array = value
			_background.battler_scale[_gen1_side(bool(sized[0]))] = float(sized[1])
		&"substitute":
			_gen1_command(Gen2BattleAnimScript.RAISE_SUB)
		&"minimize":
			# `anim_minimizeopp` puts the dot on `hBattleTurn`'s own picture.
			_gen1_command(Gen2BattleAnimScript.MINIMIZE_OPP)
		&"wavy":
			_gen1_wavy_screen(int(value))
		&"rows":
			_gen1_shake_rows(int(value))
		&"tileset":
			_gen1_load_tileset(int(value))
		&"sprites":
			_sprites = (value as Array).duplicate()
			_gen1_write = _sprites.size()


func _gen1_side(flipped: bool) -> bool:
	return _enemy_turn if flipped else not _enemy_turn


func _gen1_command(name: StringName) -> void:
	_frame_commands.append({"name": name, "byte": 0, "operands": []})


## `WavyScreenLineOffsets` under `rSCX`, rotated one entry a frame. A phase
## below zero puts the scanline table back.
func _gen1_wavy_screen(phase: int) -> void:
	if phase < 0:
		_background.lcdc_pointer = Gen2BattleAnimBackground.LCDC_OFF
		_background.set_ly_overrides(0)
		return
	_background.lcdc_pointer = Gen2BattleAnimBackground.LCDC_SCX
	for line: int in Gen2BattleAnimBackground.SCREEN_LINES:
		var at: int = (line + phase) % GEN1_WAVY_OFFSETS.size()
		_background.ly_overrides_backup[line] = GEN1_WAVY_OFFSETS[at] & 0xFF
	_background.push_ly_overrides()


## `CallWithTurnFlipped`: five routines are another one run on the other side.
const GEN1_EFFECT_FLIPPED: Dictionary = {
	0xDB: 0xF4,  # SE_SLIDE_ENEMY_MON_OFF -> SE_SLIDE_MON_OFF
	0xDC: 0xDD,  # SE_SHOW_ENEMY_MON_PIC -> SE_SHOW_MON_PIC
	0xDE: 0xF3,  # SE_BLINK_ENEMY_MON -> SE_BLINK_MON
	0xDF: 0xEF,  # SE_HIDE_ENEMY_MON_PIC -> SE_HIDE_MON_PIC
	0xE0: 0xF5,  # SE_FLASH_ENEMY_MON_PIC -> SE_FLASH_MON_PIC
}

## `SetAnimationBGPalette`'s four callers and the Super Game Boy byte each loads.
const GEN1_EFFECT_BGP: Dictionary = {
	0xFD: 0x6F,  # SE_DARK_SCREEN_PALETTE
	0xFC: 0xE4,  # SE_RESET_SCREEN_PALETTE
	0xF9: 0xF4,  # SE_DARKEN_MON_PALETTE
	0xF0: 0x90,  # SE_LIGHT_SCREEN_PALETTE
}

## The routines that walk a picture off its square, as
## [code][steps, pixels, frames, horizontal, hide][/code]. A horizontal slide
## goes towards the edge the picture stands against.
const GEN1_EFFECT_SLIDES: Dictionary = {
	0xF7: [7, 8, 2, false, false],  # SE_SLIDE_MON_UP
	GEN1_SE_SLIDE_MON_DOWN: [7, 8, 3, false, true],
	0xF4: [8, 8, 3, true, true],    # SE_SLIDE_MON_OFF
	0xE5: [4, 8, 4, true, false],   # SE_SLIDE_MON_HALF_OFF
	0xE9: [2, 8, 8, false, true],   # SE_SLIDE_MON_DOWN_AND_HIDE
}

const GEN1_SE_SLIDE_MON_DOWN: int = 0xF6
const GEN1_SE_DARK_SCREEN_FLASH: int = 0xFE
const GEN1_SE_SHAKE_SCREEN: int = 0xFB
const GEN1_SE_FLASH_SCREEN_LONG: int = 0xF8
const GEN1_SE_FLASH_MON_PIC: int = 0xF5
const GEN1_SE_BLINK_MON: int = 0xF3
const GEN1_SE_MOVE_MON_HORIZONTALLY: int = 0xF2
const GEN1_SE_RESET_MON_POSITION: int = 0xF1
const GEN1_SE_HIDE_MON_PIC: int = 0xEF
const GEN1_SE_SQUISH_MON_PIC: int = 0xEE
const GEN1_SE_MINIMIZE_MON: int = 0xEA
const GEN1_SE_DELAY_ANIMATION_10: int = 0xE1
const GEN1_SE_SHOW_MON_PIC: int = 0xDD
const GEN1_SE_SHAKE_BACK_AND_FORTH: int = 0xDA
const GEN1_SE_SUBSTITUTE_MON: int = 0xD9
const GEN1_SE_WAVY_SCREEN: int = 0xD8

## What one step of an effect may write. `frames` is every step's own duration.
const GEN1_EFFECT_KEYS: Array[StringName] = [
	&"tileset", &"bgp", &"scx", &"scy", &"visible", &"shift", &"scale",
	&"substitute", &"minimize", &"wavy", &"rows", &"sprites", &"copy_sprites",
	&"end_subanim",
]

## `%00011011`, `AnimationFlashScreen`'s inverted palette, and the white it
## follows it with. Two frames each, then the palette that was there.
const GEN1_FLASH_INVERTED: int = 0x1B
const GEN1_FLASH_FRAMES: int = 2

## `FlashScreenLongSGB`, the twelve `rBGP` bytes `AnimationFlashScreenLong`
## cycles three times. `FlashScreenLongDelay` spends 2 frames on the first cycle
## and 1 on the other two.
const GEN1_FLASH_LONG_PALETTES: Array[int] = [
	0x2F, 0x3F, 0xFF, 0x3F, 0x2F, 0x1B, 0x06, 0x01, 0x00, 0x01, 0x06, 0x1B,
]
const GEN1_FLASH_LONG_FRAMES: Array[int] = [2, 1, 1]

## `PredefShakeScreenHorizontally` with `b = 8`: the window out by the count for
## five frames and back for four, the count dropping. `rWX` right is scroll left.
const GEN1_SHAKE_AMPLITUDE: int = 8
const GEN1_SHAKE_OUT_FRAMES: int = 5
const GEN1_SHAKE_BACK_FRAMES: int = 4
const GEN1_SHAKE_ONE_OUT: int = 4
const GEN1_SHAKE_ONE_BACK: int = 3

## `AnimationBlinkMon`: six times off and on, five frames each.
const GEN1_BLINK_CYCLES: int = 6
const GEN1_BLINK_FRAMES: int = 5

## `AnimationShakeBackAndForth`: sixteen times a tile each way, three frames a
## side, and the picture cleared rather than drawn back.
const GEN1_SHAKE_MON_CYCLES: int = 0x10
const GEN1_SHAKE_MON_FRAMES: int = 3

## `AnimationSquishMonPic`: four passes of a squeeze each way, three frames each,
## then hidden. The squeeze is horizontal and `battler_scale` is one number for a
## square, so it is drawn as a shrink.
const GEN1_SQUISH_PASSES: int = 4
const GEN1_SQUISH_FRAMES: int = 3

## `AnimationMoveMonHorizontally`: one tile towards the other side, three frames.
const GEN1_MOVE_FRAMES: int = 3

const GEN1_DELAY_FRAMES: int = 10

## `WavyScreenLineOffsets`, rotated one entry per frame for 255 of them.
const GEN1_WAVY_OFFSETS: Array[int] = [
	0, 0, 0, 0, 0, 1, 1, 1, 2, 2, 2, 2, 2, 1, 1, 1,
	0, 0, 0, 0, 0, -1, -1, -1, -2, -2, -2, -2, -2, -1, -1, -1,
]
const GEN1_WAVY_FRAMES: int = 0xFF

const GEN1_TILE: int = 8

## `AnimationIdSpecialEffects`' flashing rows, as how often each flashes.
const GEN1_FLASH_EVERY_FOUR: int = 4
const GEN1_BLOCK_FLASH: Dictionary = {
	0x05: 1,  # MEGA_PUNCH
	0x0C: 1,  # GUILLOTINE
	0x19: 1,  # MEGA_KICK
	0x1D: 1,  # HEADBUTT
	0x32: 1,  # DISABLE
	0x3D: 1,  # BUBBLEBEAM
	0x73: 1,  # REFLECT
	0x93: 1,  # SPORE
	0x3F: GEN1_FLASH_EVERY_FOUR,  # HYPER_BEAM
	0x55: 8,  # THUNDERBOLT
}
const GEN1_TAIL_WHIP: int = 0x27
const GEN1_BLIZZARD: int = 0x3B
const GEN1_SELFDESTRUCT: int = 0x78
const GEN1_EXPLOSION: int = 0x99
const GEN1_ROCK_SLIDE: int = 0x9D

const GEN1_TAIL_WHIP_FRAMES: int = 20
const GEN1_GROWL_NOTE_SPRITES: int = 4
const GEN1_BLIZZARD_FLASHES: Array[int] = [13, 9, 5, 1]
const GEN1_ROCK_SLIDE_QUIET: int = 12
const GEN1_ROCK_SLIDE_SHAKE: int = 8
## `PredefShakeScreenHorizontally` and `..._Vertically` with `b = 1`.

const GEN1_SE_WATER_DROPLETS: int = 0xFA
const GEN1_SE_SHOOT_BALLS_UPWARD: int = 0xED
const GEN1_SE_SHOOT_MANY_BALLS_UPWARD: int = 0xEC
const GEN1_SE_BOUNCE_UP_AND_DOWN: int = 0xEB
const GEN1_SE_TRANSFORM_MON: int = 0xE8
const GEN1_SE_LEAVES_FALLING: int = 0xE7
const GEN1_SE_PETALS_FALLING: int = 0xE6
const GEN1_SE_SHAKE_ENEMY_HUD: int = 0xE4
const GEN1_SE_SHAKE_ENEMY_HUD_2: int = 0xE3
const GEN1_SE_SPIRAL_BALLS_INWARD: int = 0xE2

## What the object routines write into OAM: a window tile id already.
const GEN1_BALL_TILE: int = 0x7A
const GEN1_DROPLET_TILE: int = 0x71
const GEN1_LEAF_TILE: int = 0x37

## `SpiralBallAnimationCoordinates` as `(x, y)`: three rows hold the three balls
## and the window walks one row every five frames.
const GEN1_SPIRAL_COORDS: Array[Vector2i] = [
	Vector2i(0x28, 0x38), Vector2i(0x18, 0x40), Vector2i(0x10, 0x50),
	Vector2i(0x18, 0x60), Vector2i(0x28, 0x68), Vector2i(0x38, 0x60),
	Vector2i(0x40, 0x50), Vector2i(0x38, 0x40), Vector2i(0x28, 0x40),
	Vector2i(0x1E, 0x46), Vector2i(0x18, 0x50), Vector2i(0x1E, 0x5B),
	Vector2i(0x28, 0x60), Vector2i(0x32, 0x5B), Vector2i(0x38, 0x50),
	Vector2i(0x32, 0x46), Vector2i(0x28, 0x48), Vector2i(0x20, 0x50),
	Vector2i(0x28, 0x58), Vector2i(0x30, 0x50), Vector2i(0x28, 0x50),
]
const GEN1_SPIRAL_BALLS: int = 3
const GEN1_SPIRAL_FRAMES: int = 5
## `wSpiralBallsBaseX` and `..._BaseY` on the enemy's turn; the player's are 0.
const GEN1_SPIRAL_ENEMY_BASE: Vector2i = Vector2i(80, -40)

## `_AnimationShootBallsUpward`, by whether the square is the player's.
const GEN1_PILLAR_BASE: Dictionary = {true: Vector2i(5 * 8, 6 * 8), false: Vector2i(16 * 8, 0)}
const GEN1_PILLAR_BALLS: int = 5
const GEN1_BALL_RISE: int = 4

## `UpwardBallsAnimXCoordinates*`, the row they stand on and a pillar's balls.
const GEN1_MANY_PILLAR_X: Dictionary = {
	true: [0x10, 0x40, 0x28, 0x18, 0x38, 0x30],
	false: [0x60, 0x90, 0x78, 0x68, 0x88, 0x80],
}
const GEN1_MANY_PILLAR_Y: Dictionary = {true: 0x50, false: 0x28}
const GEN1_MANY_PILLAR_BALLS: int = 4

## `FallingObjects_InitialXCoords` and `..._InitialMovementData`, laid out for
## twenty whether three or twenty fall. The deltas themselves are imported.
const GEN1_FALLING_X: Array[int] = [
	0x38, 0x40, 0x50, 0x60, 0x70, 0x88, 0x90, 0x56, 0x67, 0x4A,
	0x77, 0x84, 0x98, 0x32, 0x22, 0x5C, 0x6C, 0x7D, 0x8E, 0x99,
]
const GEN1_FALLING_MOVEMENT: Array[int] = [
	0x00, 0x84, 0x06, 0x81, 0x02, 0x88, 0x01, 0x83, 0x05, 0x89,
	0x09, 0x80, 0x07, 0x87, 0x03, 0x82, 0x04, 0x85, 0x08, 0x86,
]
const GEN1_FALLING_FRAMES: int = 3
## Where an object leaves the screen, parks, and ends the effect by reaching.
const GEN1_FALLING_LIMIT: int = 112
const GEN1_FALLING_OFF: int = 144 + 16
const GEN1_FALLING_END: int = 104
const GEN1_PETALS: int = 20
const GEN1_LEAVES: int = 3

## `_AnimationWaterDroplets`: an x off the left edge, stepping 27 and wrapping
## by 168, walked down sixteen rows at a time.
const GEN1_DROPLET_FIRST_X: int = -16
const GEN1_DROPLET_STEP: int = 27
const GEN1_DROPLET_WRAP_X: int = 144
const GEN1_DROPLET_SPAN: int = 168
const GEN1_DROPLET_ROWS: Array[int] = [16, 24]
const GEN1_DROPLET_ROW_STEP: int = 16
const GEN1_DROPLET_LAST_ROW: int = 112
const GEN1_DROPLET_PASSES: int = 32

const GEN1_BOUNCE_CYCLES: int = 5

## `ShakeEnemyHUD_ShakeBG`'s `lb de, 2, 8` and where its window opens.
const GEN1_HUD_SHAKE_AMPLITUDE: int = 2
const GEN1_HUD_SHAKE_CYCLES: int = 8
const GEN1_HUD_SHAKE_FRAMES: int = 2
const GEN1_HUD_SHAKE_LINES: int = 7 * 8


## The frames one `SpecialEffectPointers` routine spends: a palette byte or a
## walk off a square out of the tables above, and the rest named here.
func _gen1_effect_steps(id: int) -> Array:
	var flipped: bool = GEN1_EFFECT_FLIPPED.has(id)
	var effect: int = int(GEN1_EFFECT_FLIPPED[id]) if flipped else id
	if GEN1_EFFECT_BGP.has(effect):
		return [{&"bgp": int(GEN1_EFFECT_BGP[effect])}]
	if GEN1_EFFECT_SLIDES.has(effect):
		return _gen1_slide_steps(GEN1_EFFECT_SLIDES[effect], flipped)
	match effect:
		GEN1_SE_DARK_SCREEN_FLASH:
			return [
				{&"frames": GEN1_FLASH_FRAMES, &"bgp": GEN1_FLASH_INVERTED},
				{&"frames": GEN1_FLASH_FRAMES, &"bgp": 0},
				{&"bgp": _background.bgp},
			]
		GEN1_SE_FLASH_SCREEN_LONG:
			return _gen1_flash_long_steps()
		GEN1_SE_SHAKE_SCREEN:
			return _gen1_shake_screen_steps()
		GEN1_SE_DELAY_ANIMATION_10:
			return [{&"frames": GEN1_DELAY_FRAMES}]
		GEN1_SE_WAVY_SCREEN:
			return _gen1_wavy_steps()
		GEN1_SE_SPIRAL_BALLS_INWARD:
			return _gen1_spiral_steps(flipped)
		GEN1_SE_SHOOT_BALLS_UPWARD:
			return _gen1_upward_steps(flipped, false)
		GEN1_SE_SHOOT_MANY_BALLS_UPWARD:
			return _gen1_upward_steps(flipped, true)
		GEN1_SE_PETALS_FALLING:
			return _gen1_falling_steps(GEN1_DROPLET_TILE, GEN1_PETALS)
		GEN1_SE_LEAVES_FALLING:
			return _gen1_falling_steps(GEN1_LEAF_TILE, GEN1_LEAVES)
		GEN1_SE_WATER_DROPLETS:
			return _gen1_droplet_steps()
		GEN1_SE_SHAKE_ENEMY_HUD, GEN1_SE_SHAKE_ENEMY_HUD_2:
			return _gen1_hud_shake_steps()
	return _gen1_mon_effect_steps(effect, flipped)


## The routines that only move, hide or show one square's picture.
## `SE_FLASH_MON_PIC` and `SE_TRANSFORM_MON` are `ChangeMonPic` with a species
## the square already shows by then, so both redraw rather than being a gap.
func _gen1_mon_effect_steps(effect: int, flipped: bool) -> Array:
	match effect:
		GEN1_SE_HIDE_MON_PIC:
			return [{&"visible": [flipped, false]}]
		GEN1_SE_SHOW_MON_PIC, GEN1_SE_FLASH_MON_PIC, GEN1_SE_TRANSFORM_MON:
			return [{&"visible": [flipped, true]}]
		GEN1_SE_BOUNCE_UP_AND_DOWN:
			return _gen1_bounce_steps(flipped)
		GEN1_SE_RESET_MON_POSITION:
			return [{&"visible": [flipped, true], &"shift": [flipped, Vector2.ZERO]}]
		GEN1_SE_MOVE_MON_HORIZONTALLY:
			return [{
				&"frames": GEN1_MOVE_FRAMES,
				&"shift": [flipped, Vector2(-_gen1_edge(flipped) * GEN1_TILE, 0.0)],
			}]
		GEN1_SE_BLINK_MON:
			return _gen1_blink_steps(flipped)
		GEN1_SE_SHAKE_BACK_AND_FORTH:
			return _gen1_shake_mon_steps(flipped)
		GEN1_SE_SQUISH_MON_PIC:
			return _gen1_squish_steps(flipped)
		GEN1_SE_MINIMIZE_MON:
			return [{&"minimize": true}]
		GEN1_SE_SUBSTITUTE_MON:
			return [{&"substitute": true}]
	return []


## Which edge a picture leaves by: the back pic's left, the front pic's right.
func _gen1_edge(flipped: bool) -> float:
	return -1.0 if _gen1_side(flipped) else 1.0


func _gen1_slide_steps(slide: Array, flipped: bool) -> Array:
	var horizontal: bool = bool(slide[3])
	var step: float = float(int(slide[1])) * (_gen1_edge(flipped) if horizontal else 1.0)
	var out: Array = []
	for index: int in int(slide[0]):
		var moved: float = step * float(index + 1)
		out.append({
			&"frames": int(slide[2]),
			&"shift": [flipped, Vector2(moved, 0.0) if horizontal else Vector2(0.0, moved)],
		})
	if bool(slide[4]):
		out.append({&"visible": [flipped, false]})
	return out


func _gen1_flash_long_steps() -> Array:
	var out: Array = []
	for cycle: int in GEN1_FLASH_LONG_FRAMES.size():
		for value: int in GEN1_FLASH_LONG_PALETTES:
			out.append({&"frames": GEN1_FLASH_LONG_FRAMES[cycle], &"bgp": value})
	out.append({&"bgp": Gen2BattleAnimBackground.PALETTE_IDENTITY})
	return out


func _gen1_shake_screen_steps() -> Array:
	var out: Array = []
	for amplitude: int in range(GEN1_SHAKE_AMPLITUDE, 0, -1):
		out.append({&"frames": GEN1_SHAKE_OUT_FRAMES, &"scx": -amplitude})
		out.append({&"frames": GEN1_SHAKE_BACK_FRAMES, &"scx": 0})
	return out


func _gen1_blink_steps(flipped: bool) -> Array:
	var out: Array = []
	for _cycle: int in GEN1_BLINK_CYCLES:
		out.append({&"frames": GEN1_BLINK_FRAMES, &"visible": [flipped, false]})
		out.append({&"frames": GEN1_BLINK_FRAMES, &"visible": [flipped, true]})
	return out


func _gen1_shake_mon_steps(flipped: bool) -> Array:
	var out: Array = []
	for _cycle: int in GEN1_SHAKE_MON_CYCLES:
		for side: int in [-GEN1_TILE, GEN1_TILE]:
			out.append({
				&"frames": GEN1_SHAKE_MON_FRAMES,
				&"shift": [flipped, Vector2(float(side), 0.0)],
			})
	out.append({&"visible": [flipped, false], &"shift": [flipped, Vector2.ZERO]})
	return out


func _gen1_squish_steps(flipped: bool) -> Array:
	var out: Array = []
	var passes: int = GEN1_SQUISH_PASSES * 2
	for index: int in passes:
		out.append({
			&"frames": GEN1_SQUISH_FRAMES,
			&"scale": [flipped, float(passes - index - 1) / float(passes)],
		})
	out.append({&"visible": [flipped, false], &"scale": [flipped, 1.0]})
	return out


func _gen1_wavy_steps() -> Array:
	var out: Array = []
	for frame: int in GEN1_WAVY_FRAMES:
		out.append({&"frames": 1, &"wavy": frame})
	out.append({&"wavy": -1})
	return out


## `ShakeEnemyHUD_ShakeBG`: `hSCX` over the rows above the window, so only the
## enemy panel and its picture move. The back pic is OAM there and stays still,
## where here it is background and its top two rows shake with them.
func _gen1_shake_rows(offset: int) -> void:
	_background.lcdc_pointer = Gen2BattleAnimBackground.LCDC_SCX
	for line: int in Gen2BattleAnimBackground.SCREEN_LINES:
		_background.ly_overrides_backup[line] = \
			offset & 0xFF if line < GEN1_HUD_SHAKE_LINES else 0
	_background.push_ly_overrides()


## `AnimationSpiralBallsInward`: three balls along the coordinates, then a frame
## more of them, a clear and a flash.
func _gen1_spiral_steps(flipped: bool) -> Array:
	var base: Vector2i = Vector2i.ZERO if _gen1_side(flipped) \
		else GEN1_SPIRAL_ENEMY_BASE
	var out: Array = [{&"tileset": 0}]
	var pairs: int = GEN1_SPIRAL_COORDS.size()
	for step: int in pairs - GEN1_SPIRAL_BALLS + 1:
		out.append({
			&"frames": GEN1_SPIRAL_FRAMES,
			&"sprites": _gen1_balls(base, step, GEN1_SPIRAL_BALLS),
		})
	out.append({&"frames": 1, &"sprites": _gen1_balls(base, pairs - 2, 2) \
		+ [_gen1_ball(base, pairs - 1)]})
	out.append({&"sprites": []})
	out.append_array(_gen1_effect_steps(GEN1_SE_DARK_SCREEN_FLASH))
	return out


func _gen1_balls(base: Vector2i, from: int, count: int) -> Array:
	var out: Array = []
	for index: int in count:
		out.append(_gen1_ball(base, from + index))
	return out


func _gen1_ball(base: Vector2i, index: int) -> Dictionary:
	var at: Vector2i = GEN1_SPIRAL_COORDS[mini(index, GEN1_SPIRAL_COORDS.size() - 1)]
	return {
		"y": (base.y + at.y) & 0xFF, "x": (base.x + at.x) & 0xFF,
		"tile": GEN1_BALL_TILE, "attributes": 0,
	}


## `_AnimationShootBallsUpward`: balls rising four pixels a frame, each taken
## off as it reaches the top.
func _gen1_pillar_steps(base: Vector2i, balls: int) -> Array:
	var out: Array = []
	var rows: Array[int] = []
	for index: int in balls:
		rows.append((base.y + GEN1_TILE * (index + 1)) & 0xFF)
	out.append({&"frames": 1, &"sprites": _gen1_pillar(base.x, rows)})
	var live: int = balls
	while live > 0:
		for index: int in balls:
			if rows[index] == ((base.y + GEN1_TILE) & 0xFF):
				rows[index] = 0
				live -= 1
			elif rows[index] != 0:
				rows[index] = (rows[index] - GEN1_BALL_RISE) & 0xFF
		out.append({&"frames": 1, &"sprites": _gen1_pillar(base.x, rows)})
	return out


func _gen1_pillar(x: int, rows: Array[int]) -> Array:
	var out: Array = []
	for row: int in rows:
		out.append({"y": row, "x": x, "tile": GEN1_BALL_TILE, "attributes": 0})
	return out


func _gen1_upward_steps(flipped: bool, many: bool) -> Array:
	var player: bool = _gen1_side(flipped)
	var out: Array = [{&"tileset": 0}]
	if not many:
		var base: Vector2i = GEN1_PILLAR_BASE[player]
		out.append_array(_gen1_pillar_steps(base, GEN1_PILLAR_BALLS))
	else:
		var y: int = GEN1_MANY_PILLAR_Y[player]
		for x: int in GEN1_MANY_PILLAR_X[player]:
			out.append_array(_gen1_pillar_steps(Vector2i(x, y), GEN1_MANY_PILLAR_BALLS))
	out.append({&"frames": 1})
	out.append({&"sprites": []})
	return out


## `AnimationFallingObjects`: objects down two pixels every three frames,
## drifting through `FallingObjects_DeltaXs`, until the first reaches 104.
func _gen1_falling_steps(tile: int, count: int) -> Array:
	var out: Array = [{&"tileset": 1}]
	var rows: Array[int] = []
	var columns: Array[int] = []
	var movement: Array[int] = []
	for index: int in count:
		rows.append(0 if index == 0 else GEN1_TILE * (index + 1))
		columns.append(GEN1_FALLING_X[index])
		movement.append(GEN1_FALLING_MOVEMENT[index])
	var frame: Array = []
	while rows[0] != GEN1_FALLING_END:
		frame = []
		for index: int in count:
			movement[index] = _gen1_next_movement(movement[index])
			var step: int = _data.gen1_falling_delta(movement[index] & 0x7F)
			var left: bool = (movement[index] & 0x80) != 0
			rows[index] = rows[index] + 2 if rows[index] + 2 < GEN1_FALLING_LIMIT \
				else GEN1_FALLING_OFF
			columns[index] = (columns[index] - step if left else columns[index] + step) & 0xFF
			frame.append({
				"y": rows[index], "x": columns[index], "tile": tile,
				"attributes": Gen2BattleAnimObject.OAM_XFLIP if left else 0,
			})
		out.append({&"frames": GEN1_FALLING_FRAMES, &"sprites": frame})
	return out


## `FallingObjects_UpdateMovementByte`: the list's end turns the object round.
func _gen1_next_movement(byte: int) -> int:
	var next: int = (byte + 1) & 0xFF
	if (next & 0x7F) != Gen1Layout.FALLING_DELTA_TABLE:
		return next
	return (next & 0x80) ^ 0x80


## `AnimationWaterDropletsEverywhere`: a drizzle whose x carries between passes,
## shown a frame and cleared a frame, sixty-four times over.
func _gen1_droplet_steps() -> Array:
	var out: Array = [{&"tileset": 0}]
	var x: int = GEN1_DROPLET_FIRST_X
	for _pass: int in GEN1_DROPLET_PASSES:
		for y: int in GEN1_DROPLET_ROWS:
			var grid: Array = []
			var row: int = y
			while true:
				x = (x + GEN1_DROPLET_STEP) & 0xFF
				grid.append({
					"y": row, "x": x, "tile": GEN1_DROPLET_TILE, "attributes": 0,
				})
				if x < GEN1_DROPLET_WRAP_X:
					continue
				x = (x - GEN1_DROPLET_SPAN) & 0xFF
				row += GEN1_DROPLET_ROW_STEP
				if row >= GEN1_DROPLET_LAST_ROW:
					break
			out.append({&"frames": 1, &"sprites": grid})
			out.append({&"frames": 1, &"sprites": []})
	return out


## `AnimationBoundUpAndDown`: five slides down, the picture back after them.
func _gen1_bounce_steps(flipped: bool) -> Array:
	var out: Array = []
	for _cycle: int in GEN1_BOUNCE_CYCLES:
		out.append_array(_gen1_slide_steps(GEN1_EFFECT_SLIDES[GEN1_SE_SLIDE_MON_DOWN], flipped))
	out.append({&"visible": [flipped, true], &"shift": [flipped, Vector2.ZERO]})
	return out


func _gen1_hud_shake_steps() -> Array:
	var out: Array = []
	for _cycle: int in GEN1_HUD_SHAKE_CYCLES:
		out.append({&"frames": GEN1_HUD_SHAKE_FRAMES, &"rows": GEN1_HUD_SHAKE_AMPLITUDE})
		out.append({&"frames": GEN1_HUD_SHAKE_FRAMES, &"rows": -GEN1_HUD_SHAKE_AMPLITUDE})
	out.append({&"rows": 0})
	return out


## `DoSpecialEffectByAnimationId`, after every frame block of the twenty-five
## `AnimationIdSpecialEffects` names. [param counter] is `wSubAnimCounter`, which
## opens at the row count. The trade and ball rows wait for a caller.
func _gen1_block_effect_steps(counter: int) -> Array:
	var id: int = _anim_index + 1
	if GEN1_BLOCK_FLASH.has(id):
		return _gen1_flash_when(counter % int(GEN1_BLOCK_FLASH[id]) == 0)
	match id:
		GEN1_TAIL_WHIP:
			return [{&"frames": GEN1_TAIL_WHIP_FRAMES, &"end_subanim": true}]
		GEN1_GROWL:
			# The note doubles into the four slots behind it, which is why
			# `DrawFrameBlock` keeps GROWL's buffer between blocks.
			if counter > 1:
				return [{&"copy_sprites": GEN1_GROWL_NOTE_SPRITES}]
			return [{&"frames": 1}, {&"sprites": []}]
		GEN1_BLIZZARD:
			return _gen1_flash_when(GEN1_BLIZZARD_FLASHES.has(counter))
		GEN1_SELFDESTRUCT, GEN1_EXPLOSION:
			if counter == 1:
				return [{&"visible": [false, false]}]
			return _gen1_flash_when(counter % GEN1_FLASH_EVERY_FOUR == 0)
		GEN1_ROCK_SLIDE:
			return _gen1_rock_slide_steps(counter)
	return []


func _gen1_flash_when(condition: bool) -> Array:
	return _gen1_effect_steps(GEN1_SE_DARK_SCREEN_FLASH) if condition else []


## `DoRockSlideSpecialEffects`: quiet above eleven, a pixel each way to eight,
## a flash on the last block.
func _gen1_rock_slide_steps(counter: int) -> Array:
	if counter >= GEN1_ROCK_SLIDE_QUIET:
		return []
	if counter >= GEN1_ROCK_SLIDE_SHAKE:
		return [
			{&"frames": GEN1_SHAKE_ONE_OUT, &"scx": -1},
			{&"frames": 1, &"scx": -1},
			{&"frames": GEN1_SHAKE_ONE_OUT, &"scx": 0},
			{&"frames": GEN1_SHAKE_ONE_BACK, &"scy": -1},
			{&"frames": GEN1_SHAKE_ONE_BACK, &"scy": 0},
		]
	return _gen1_flash_when(counter == 1)


## `DoGrowlSpecialEffects`' `CopyData`: the note over the four slots behind it.
func _gen1_copy_sprites(count: int) -> void:
	for index: int in count:
		if index >= _sprites.size():
			return
		var at: int = count + index
		_sprites.resize(maxi(_sprites.size(), at + 1))
		_sprites[at] = (_sprites[index] as Dictionary).duplicate()
