class_name Gen2BattleScreenMap
extends RefCounted

## `wTilemap` as a battle leaves it: which tile of which battler's picture sits in
## each of the 20x18 cells. An animation does not draw a picture, it edits this
## map, and the screen hands it to [Gen2BattleAnimBackground] and takes back
## whatever the animation left, which is why a Fly is still gone after its own
## animation ends. Node-free, so an effect's work can be asserted headless.

const COLUMNS: int = Gen2BattleAnimBackground.SCREEN_WIDTH
const ROWS: int = Gen2BattleAnimBackground.SCREEN_HEIGHT

## `GetEnemyFrontpicCoords` and `GetPlayerBackpicCoords`: where each box sits and
## how many tiles square it is.
const ENEMY_AT: Vector2i = Vector2i(12, 0)
const PLAYER_AT: Vector2i = Vector2i(2, 6)
const ENEMY_SIDE: int = 7
const PLAYER_SIDE: int = 6

## `LoadMonBackPic`'s `hlcoord 1, 5`, and the seven tiles a side
## `ScaleSpriteByTwo` doubles a 32x32 back pic up to. Crystal shrank it to 6x6.
const GEN1_PLAYER_AT: Vector2i = Vector2i(1, 5)
const GEN1_PLAYER_SIDE: int = 7


static func player_box_at(generation: int) -> Vector2i:
	return GEN1_PLAYER_AT if generation == RomRegistry.GEN1 else PLAYER_AT


static func player_box_side(generation: int) -> int:
	return GEN1_PLAYER_SIDE if generation == RomRegistry.GEN1 else PLAYER_SIDE


## Where each picture's tiles start in VRAM. `AppearUser` names both, `xor a` for
## the enemy and `ld a, $31` for the player, and `.BGSquares`' own offsets are
## counted from the same two.
const ENEMY_BASE_TILE: int = 0x00
const PLAYER_BASE_TILE: int = 0x31

const BLANK_TILE: int = Gen2BattleAnimBackground.BLANK_TILE


## `MonFaintedAnimation`'s own block, which is not the picture's: seven columns
## from one left of it, and seven rows ending one below, so the picture sinks
## through a margin rather than out of its own frame.
## `PlayerMonFaintedAnimation` and `EnemyMonFaintedAnimation` name the two.
const FAINT_AT: Dictionary = {false: Vector2i(12, 0), true: Vector2i(1, 5)}
const FAINT_COLUMNS: int = 7
const FAINT_ROWS: int = 7
## `ld b, 7` outer, each spending `ld c, 2 / DelayFrames`.
const FAINT_STEPS: int = 7
const FAINT_STEP_FRAMES: int = 2


## The map a battle sits at: both pictures whole, blank everywhere else.
static func seeded(generation: int = RomRegistry.GEN2) -> PackedByteArray:
	var out: PackedByteArray = PackedByteArray()
	out.resize(COLUMNS * ROWS)
	out.fill(BLANK_TILE)
	stamp(out, false, generation)
	stamp(out, true, generation)
	return out


## One outer step of `MonFaintedAnimation`: the block's rows each take the one
## above, and its top row is blanked with the routine's own seven spaces. Seven
## of these sink the whole picture off its square.
static func faint_step(map: PackedByteArray, player_side: bool) -> void:
	if map.size() != COLUMNS * ROWS:
		return
	var at: Vector2i = FAINT_AT[player_side]
	for index: int in FAINT_ROWS - 1:
		var row: int = at.y + FAINT_ROWS - 1 - index
		var above: int = row - 1
		for column: int in FAINT_COLUMNS:
			var x: int = at.x + column
			if x < 0 or x >= COLUMNS or row < 0 or row >= ROWS:
				continue
			map[row * COLUMNS + x] = (
				map[above * COLUMNS + x] if above >= 0 else BLANK_TILE
			)
	for column: int in FAINT_COLUMNS:
		var x: int = at.x + column
		if x < 0 or x >= COLUMNS or at.y < 0 or at.y >= ROWS:
			continue
		map[at.y * COLUMNS + x] = BLANK_TILE


## `SlideBattlePicOut`, which is not the picture's box either: seven rows from
## one above the player's, and the whole of the enemy's, shifted a column at a
## time until the picture is off the screen. `DoBattle`'s `hlcoord 1, 5 / ld a, 9`
## walks the player's left and `ResetEnemyBattleVars`' `hlcoord 18, 0 / ld a, 8`
## the enemy's right; the count is both the columns touched and the steps.
const SLIDE_AT: Dictionary = {false: Vector2i(18, 0), true: Vector2i(1, 5)}
const SLIDE_ROWS: int = 7
const SLIDE_STEPS: Dictionary = {false: 8, true: 9}
const SLIDE_STEP_FRAMES: int = 2


## One outer step of `SlideBattlePicOut`: every touched cell takes its
## neighbour's on the side the picture is leaving towards, which is `.back`'s
## `ld a, [hld] / ld [hli], a` for the player and `.forward`'s
## `ld a, [hli] / ld [hld], a` for the enemy.
static func slide_step(map: PackedByteArray, player_side: bool) -> void:
	if map.size() != COLUMNS * ROWS:
		return
	var at: Vector2i = SLIDE_AT[player_side]
	var count: int = int(SLIDE_STEPS[player_side])
	for row_index: int in SLIDE_ROWS:
		var y: int = at.y + row_index
		if y < 0 or y >= ROWS:
			continue
		for index: int in count:
			# The player's walk reads to the right of what it writes; the
			# enemy's reads to the left of it.
			var to: int = at.x + index - 1 if player_side else at.x - index + 1
			var from: int = at.x + index if player_side else at.x - index
			if to < 0 or to >= COLUMNS or from < 0 or from >= COLUMNS:
				continue
			map[y * COLUMNS + to] = map[y * COLUMNS + from]


## `InitBattleDisplay`'s `hlcoord 1, 5 / lb bc, 3, 7 / ClearBox`, which runs
## between `CopyBackpic` and the slide and takes the top two tile rows of the
## player's back pic off the map. It is what makes the slide's eighteen sprites
## necessary: those rows fall in the band the enemy's own scroll owns, so
## `.LoadTrainerBackpicAsOAM` carries them and `PlaceGraphic` puts the pic back.
const INTRO_CLEAR_AT: Vector2i = Vector2i(1, 5)
const INTRO_CLEAR_COLUMNS: int = 7
const INTRO_CLEAR_ROWS: int = 3


static func clear_intro_box(map: PackedByteArray) -> void:
	if map.size() != COLUMNS * ROWS:
		return
	for row: int in INTRO_CLEAR_ROWS:
		var y: int = INTRO_CLEAR_AT.y + row
		if y < 0 or y >= ROWS:
			continue
		for column: int in INTRO_CLEAR_COLUMNS:
			var x: int = INTRO_CLEAR_AT.x + column
			if x < 0 or x >= COLUMNS:
				continue
			map[y * COLUMNS + x] = BLANK_TILE


## `PlaceGraphic` over one battler's box: a tile is
## [code]base + column * side + row[/code], the column-major order `.BGSquares`
## indexes and `AppearUser` restores.
static func stamp(
	map: PackedByteArray, player_side: bool, generation: int = RomRegistry.GEN2,
	shift: Vector2i = Vector2i.ZERO
) -> void:
	if map.size() != COLUMNS * ROWS:
		return
	var at: Vector2i = (player_box_at(generation) if player_side else ENEMY_AT) + shift
	var side: int = player_box_side(generation) if player_side else ENEMY_SIDE
	var base: int = PLAYER_BASE_TILE if player_side else ENEMY_BASE_TILE
	for column: int in side:
		for row: int in side:
			_write(
				map, at + Vector2i(column, row), base + column * side + row
			)


## `ClearMonPicFromTileMap`: the seven by seven box, wherever the picture was
## last drawn.
static func clear_battler(
	map: PackedByteArray, player_side: bool, generation: int,
	shift: Vector2i = Vector2i.ZERO
) -> void:
	if map.size() != COLUMNS * ROWS:
		return
	var at: Vector2i = (player_box_at(generation) if player_side else ENEMY_AT) + shift
	var side: int = player_box_side(generation) if player_side else ENEMY_SIDE
	for column: int in side:
		for row: int in side:
			_write(map, at + Vector2i(column, row), BLANK_TILE)


## `_AnimationSquishMonPic`: three tiles of each of the box's rows pulled a
## column inwards, the cell they leave blanked. `AnimCopyRowLeft` runs from four
## columns into the box and `..._Right` from two.
const SQUISH_LEFT_AT: int = 4
const SQUISH_RIGHT_AT: int = 2
const SQUISH_TILES: int = 3


static func squish_step(
	map: PackedByteArray, player_side: bool, generation: int, to_the_right: bool
) -> void:
	if map.size() != COLUMNS * ROWS:
		return
	var at: Vector2i = player_box_at(generation) if player_side else ENEMY_AT
	var side: int = player_box_side(generation) if player_side else ENEMY_SIDE
	var step: int = 1 if to_the_right else -1
	var head: int = at.x + (SQUISH_RIGHT_AT if to_the_right else SQUISH_LEFT_AT)
	for row: int in side:
		var y: int = at.y + row
		var x: int = head
		for _tile: int in SQUISH_TILES:
			_write(map, Vector2i(x + step, y), _cell(map, Vector2i(x, y)))
			x -= step
		_write(map, Vector2i(x + step, y), BLANK_TILE)


static func _cell(map: PackedByteArray, at: Vector2i) -> int:
	if at.x < 0 or at.x >= COLUMNS or at.y < 0 or at.y >= ROWS:
		return BLANK_TILE
	return int(map[at.y * COLUMNS + at.x])


## `AnimateSendingOutMon`, which is no `AttackAnimationPointers` row: the ball
## tile, then `DownscaledMonTiles_3x3` and `..._5x5` over these rows and columns,
## each block two rows up and a column left of the last.
const SEND_OUT_ROWS: Dictionary = {3: [0, 3, 6], 5: [0, 1, 3, 5, 6]}
const SEND_OUT_AT: Dictionary = {
	0: Vector2i(3, 6), 3: Vector2i(2, 4), 5: Vector2i(1, 2), 7: Vector2i(0, 0),
}
const SEND_OUT_SIZES: Array[int] = [0, 3, 5, 7]
## `Delay3`, `ld c, 4` and `ld c, 5`; the whole picture ends the routine.
const SEND_OUT_FRAMES: Dictionary = {0: 3, 3: 4, 5: 5, 7: 0}

## `ld b, $4c` with `ld a, [wIsInBattle]` still in `a`: the tile written is $4d
## in a wild battle and $4e in a trainer's, both of them back pic tiles.
const SEND_OUT_BALL_TILE: int = 0x4C


## One step of it: [param size] 0 is the ball tile and 7 the whole picture.
static func send_out_step(
	map: PackedByteArray, player_side: bool, generation: int, size: int,
	in_battle: int = 1
) -> void:
	if map.size() != COLUMNS * ROWS or not SEND_OUT_AT.has(size):
		return
	var side: int = player_box_side(generation) if player_side else ENEMY_SIDE
	var at: Vector2i = (player_box_at(generation) if player_side else ENEMY_AT) \
		+ (SEND_OUT_AT[size] as Vector2i)
	if size == 0:
		_write(map, at, SEND_OUT_BALL_TILE + in_battle)
		return
	if size >= side:
		stamp(map, player_side, generation)
		return
	var base: int = PLAYER_BASE_TILE if player_side else ENEMY_BASE_TILE
	var picked: Array = SEND_OUT_ROWS[size]
	for column: int in size:
		for row: int in size:
			_write(
				map, at + Vector2i(column, row),
				base + int(picked[column]) * side + int(picked[row])
			)


static func _write(map: PackedByteArray, at: Vector2i, tile: int) -> void:
	if at.x < 0 or at.x >= COLUMNS or at.y < 0 or at.y >= ROWS:
		return
	map[at.y * COLUMNS + at.x] = tile & 0xFF


static func result_trainer_step(map: PackedByteArray, columns: int) -> void:
	for column: int in columns:
		for row: int in ENEMY_SIDE:
			map[row * COLUMNS + COLUMNS - columns + column] = column * ENEMY_SIDE + row
