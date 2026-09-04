extends RefCounted

## Every Generation 1 battle animation, played to its end on Red, Blue and
## Yellow. What pins the layer is walking all 203 rather than sampling: a table
## read a byte off still decodes into plausible rows, and only running every one
## of them through the four tables it indexes fails.

var _r: RefCounted = null

## `assert_table_length` in each pinned data file, shared by both. Only
## `AttackAnimationPointers` differs: Yellow dropped `ZigZagScreenAnim`.
const EXPECTED_COUNTS: Dictionary = {
	&"subanims": Gen1Layout.SUBANIM_COUNT,
	&"frame_blocks": Gen1Layout.FRAME_BLOCK_COUNT,
	&"base_coords": Gen1Layout.BASE_COORD_COUNT,
}

## `SpecialEffectPointers` is 40 rows in both dumps.
const SPECIAL_EFFECT_COUNT: int = 39

## `FallingObjects_DeltaXs`' nine bytes and what the two objects that walk off
## the end read behind it. Byte 10 is where the two dumps disagree.
const FALLING_DELTAS: Array[int] = [0, 1, 3, 5, 7, 9, 11, 13, 15, 0xFA]
const FALLING_OVERRUN: Dictionary = {&"red": 0x8A, &"blue": 0x8A, &"yellow": 0x89}

## `MoveAnimationTilesPointers`, whose third row is the first cut short.
const TILESET_TILES: Array[int] = [79, 79, 64]

## `PoundAnim`: tileset 0 at delay 8, POUND's sound and `SUBANIM_0_STAR_TWICE`.
const POUND_INDEX: int = 0
const POUND_DELAY: int = 8
const POUND_SUBANIM: int = 0x01

## `Subanim_0StarTwice`: two `FRAMEBLOCK_01` frames, both `FRAMEBLOCKMODE_00`.
const POUND_ROWS: Array = [[0x01, 0x0F, 0x00], [0x01, 0x1D, 0x00]]
## `FrameBlock01` is nine sprites, the first of them the block's own corner.
const POUND_SPRITES: int = 9
## Where the first of them lands with `BASECOORD_0F`, which is `$20, $70`: the
## base coordinate plus the sprite's own zero offsets, and `$31` over its tile.
const POUND_FIRST_SPRITE: Array[int] = [0x20, 0x70, 0x31 + 0x2C, 0x00]

## `SUBANIMTYPE_ENEMY` reads the other way round: it flips on the player's turn
## and not on the enemy's. `Subanim_1StarBigMoving` is a plain one beside it.
const ENEMY_SUBANIM: int = 24
const HFLIP_SUBANIM: int = 4

## A guard: the longest is `AnimationWavyScreen`'s 255 frames and its framing.
const MAX_FRAMES: int = 1024

## How many of `SpecialEffectPointers`' ids the corpus names, all of them drawn.
const IMPLEMENTED_EFFECTS: Dictionary = {&"red": 36, &"blue": 36, &"yellow": 36}

## The whole engine in two numbers: a delay read wrong moves the frames and a
## transform read wrong moves the sprites. Yellow is one animation short and the
## same sprites, `ZigZagScreenAnim` being `SE_WAVY_SCREEN` alone.
const EXPECTED_TOTALS: Dictionary = {
	&"red": [24828, 141410],
	&"blue": [24828, 141410],
	&"yellow": [24316, 141410],
}


func run(r: RefCounted) -> void:
	_r = r
	r.each_game_of(RomRegistry.GEN1, _one_game)


func _one_game() -> void:
	var anims: Gen2BattleAnimData = Gen2BattleAnimData.from_game_data(_r.data)
	if not _r.check(anims != null, "%s: no battle animation layer in the cache." % _r.game_id):
		return
	if not _r.check(anims.gen1(), "%s: the animation layer is not Generation 1's." % _r.game_id):
		return
	_verify_tables(anims)
	_verify_pound(anims)
	_verify_transforms(anims)
	_play_every_animation(anims)


func _verify_tables(anims: Gen2BattleAnimData) -> void:
	_r.check(
		anims.count(Gen2BattleAnimData.GEN1_REGION) == Gen1Layout.anim_count(_r.game_id),
		"%s: AttackAnimationPointers holds %d rows, expected %d." % [
			_r.game_id, anims.count(Gen2BattleAnimData.GEN1_REGION),
			Gen1Layout.anim_count(_r.game_id),
		]
	)
	for table: StringName in EXPECTED_COUNTS:
		_r.check(
			_r.data.battle_anim_table(table) > 0,
			"%s: %s is not in the cached region." % [_r.game_id, table]
		)
	_r.check(
		anims.gen1_frame_block(Gen1Layout.FRAME_BLOCK_COUNT - 1).size() > 0
			and anims.gen1_subanim(Gen1Layout.SUBANIM_COUNT - 1).get("rows", []).size() > 0
			and anims.gen1_base_coord(Gen1Layout.BASE_COORD_COUNT - 1) != Vector2i.ZERO,
		"%s: the last row of one of the three tables does not decode." % _r.game_id
	)

	for index: int in FALLING_DELTAS.size():
		_r.check(
			anims.gen1_falling_delta(index) == FALLING_DELTAS[index],
			"%s: FallingObjects_DeltaXs byte %d is $%02X, expected $%02X." % [
				_r.game_id, index, anims.gen1_falling_delta(index), FALLING_DELTAS[index],
			]
		)
	_r.check(
		anims.gen1_falling_delta(FALLING_DELTAS.size())
			== int(FALLING_OVERRUN[_r.game_id]),
		"%s: the byte a petal reads past FallingObjects_DeltaXs is $%02X." % [
			_r.game_id, anims.gen1_falling_delta(FALLING_DELTAS.size()),
		]
	)

	var effects: PackedInt32Array = _r.data.battle_anim_special_effects()
	_r.check(
		effects.size() == SPECIAL_EFFECT_COUNT,
		"%s: SpecialEffectPointers holds %d ids, expected %d." % [
			_r.game_id, effects.size(), SPECIAL_EFFECT_COUNT,
		]
	)
	for index: int in TILESET_TILES.size():
		var row: Dictionary = anims.gfx(index)
		_r.check(
			int(row.get("tiles", 0)) == TILESET_TILES[index],
			"%s: animation tileset %d holds %d tiles, expected %d." % [
				_r.game_id, index, int(row.get("tiles", 0)), TILESET_TILES[index],
			]
		)
		_r.check(
			_r.data.battle_anim_gfx_indices(index).size()
				== TILESET_TILES[index] * PokeTiles.TILE_WIDTH * PokeTiles.TILE_HEIGHT,
			"%s: animation tileset %d did not decode to its own pixels." % [_r.game_id, index]
		)


## POUND end to end, down to the first sprite that lands on screen.
func _verify_pound(anims: Gen2BattleAnimData) -> void:
	var address: int = anims.pointer(Gen2BattleAnimData.GEN1_REGION, POUND_INDEX)
	var byte: int = anims.byte_at(Gen2BattleAnimData.GEN1_REGION, address)
	_r.check(
		byte == POUND_DELAY and byte >> Gen1Layout.ANIM_TILESET_SHIFT == 0,
		"%s: POUND's row is $%02X, not tileset 0 at delay %d." % [
			_r.game_id, byte, POUND_DELAY,
		]
	)
	_r.check(
		anims.byte_at(Gen2BattleAnimData.GEN1_REGION, address + 2) == POUND_SUBANIM,
		"%s: POUND does not play SUBANIM_0_STAR_TWICE." % _r.game_id
	)

	var subanim: Dictionary = anims.gen1_subanim(POUND_SUBANIM)
	var rows: Array = []
	for row: Dictionary in subanim.get("rows", []):
		rows.append([row["frame_block"], row["base_coord"], row["mode"]])
	_r.check(
		rows == POUND_ROWS,
		"%s: SUBANIM_0_STAR_TWICE decoded to %s." % [_r.game_id, rows]
	)
	_r.check(
		int(subanim.get("kind", -1)) == Gen1Layout.SUBANIMTYPE_HFLIP,
		"%s: SUBANIM_0_STAR_TWICE is type %d, expected SUBANIMTYPE_HFLIP." % [
			_r.game_id, int(subanim.get("kind", -1)),
		]
	)
	_r.check(
		anims.gen1_frame_block(int(POUND_ROWS[0][0])).size() == POUND_SPRITES,
		"%s: FRAMEBLOCK_01 is not %d sprites." % [_r.game_id, POUND_SPRITES]
	)

	var player: Gen2BattleAnimPlayer = Gen2BattleAnimPlayer.create_gen1(anims, POUND_INDEX)
	if not _r.check(player != null, "%s: POUND would not start." % _r.game_id):
		return
	player.advance_frame()
	var sprites: Array = player.sprites()
	if not _r.check(sprites.size() == POUND_SPRITES, "%s: POUND drew %d sprites on its first frame, expected %d." % [_r.game_id, sprites.size(), POUND_SPRITES]):
		return
	var first: Dictionary = sprites[0]
	_r.check(
		[first["y"], first["x"], first["tile"], first["attributes"]] == POUND_FIRST_SPRITE,
		"%s: POUND's first sprite is %s, expected %s." % [
			_r.game_id, [first["y"], first["x"], first["tile"], first["attributes"]],
			POUND_FIRST_SPRITE,
		]
	)


## `GetSubanimationTransform1` and `..._2`, the same table read either way.
func _verify_transforms(anims: Gen2BattleAnimData) -> void:
	_r.check(
		int(anims.gen1_subanim(ENEMY_SUBANIM).get("kind", -1))
			== Gen1Layout.SUBANIMTYPE_ENEMY,
		"%s: subanimation %d is not SUBANIMTYPE_ENEMY." % [_r.game_id, ENEMY_SUBANIM]
	)
	_r.check(
		int(anims.gen1_subanim(HFLIP_SUBANIM).get("kind", -1))
			== Gen1Layout.SUBANIMTYPE_HFLIP,
		"%s: subanimation %d is not SUBANIMTYPE_HFLIP." % [_r.game_id, HFLIP_SUBANIM]
	)


## Every animation on both turns, run to its end.
func _play_every_animation(anims: Gen2BattleAnimData) -> void:
	var count: int = Gen1Layout.anim_count(_r.game_id)
	var frames: int = 0
	var drawn: int = 0
	var missing: Dictionary = {}
	var answered: Dictionary = {}
	for index: int in count:
		for enemy_turn: bool in [false, true]:
			var player: Gen2BattleAnimPlayer = Gen2BattleAnimPlayer.create_gen1(
				anims, index, enemy_turn
			)
			if not _r.check(player != null, "%s: animation %d would not start." % [
				_r.game_id, index,
			]):
				return
			var spent: int = 0
			while not player.finished() and spent < MAX_FRAMES:
				player.advance_frame()
				drawn += player.sprites().size()
				spent += 1
			if not _r.check(spent < MAX_FRAMES, "%s: animation %d never ended." % [
				_r.game_id, index,
			]):
				return
			frames += spent
			for id: int in player.unimplemented().get("gen1_effects", []):
				missing[id] = int(missing.get(id, 0)) + 1
	for index: int in count:
		_count_effects(anims, index, missing, answered)

	var totals: Array = EXPECTED_TOTALS[_r.game_id]
	_r.check(
		[frames, drawn] == totals,
		"%s: the corpus ran for %d frames drawing %d sprites, expected %s." % [
			_r.game_id, frames, drawn, totals,
		]
	)
	_r.check(
		answered.size() == int(IMPLEMENTED_EFFECTS[_r.game_id]),
		"%s: %d special effects are drawn, expected %d." % [
			_r.game_id, answered.size(), int(IMPLEMENTED_EFFECTS[_r.game_id]),
		]
	)
	var names: Array = missing.keys()
	names.sort()
	_r.note("%d animations, %d frames, %d sprites, %d special effects drawn, %d not (%s)" % [
		count, frames, drawn, answered.size(), missing.size(),
		", ".join(_hex(names)),
	])


## Which special effect ids the corpus names, read off the stream rather than
## the player, so one no animation reaches is not counted either way.
func _count_effects(
	anims: Gen2BattleAnimData, index: int, missing: Dictionary, answered: Dictionary
) -> void:
	var at: int = anims.pointer(Gen2BattleAnimData.GEN1_REGION, index)
	for _row: int in Gen2BattleAnimPlayer.GEN1_MAX_STEPS:
		var byte: int = anims.byte_at(Gen2BattleAnimData.GEN1_REGION, at)
		if byte == Gen1Layout.ANIM_END:
			return
		if byte < Gen1Layout.ANIM_FIRST_SE_ID:
			at += Gen1Layout.ANIM_SUBANIM_SIZE
			continue
		at += Gen1Layout.ANIM_SE_SIZE
		_r.check(
			anims.gen1_has_special_effect(byte),
			"%s: animation %d names special effect $%02X, which is not in the table." % [
				_r.game_id, index, byte,
			]
		)
		if not missing.has(byte):
			answered[byte] = true


static func _hex(ids: Array) -> PackedStringArray:
	var out := PackedStringArray()
	for id: Variant in ids:
		out.append("$%02X" % int(id))
	return out
