class_name Gen2BattleTransition
extends RefCounted

## `DoBattleTransition` (engine/battle/battle_transition.asm) and Generation 1's
## `BattleTransition` (engine/battle/battle_transitions.asm): what the overworld
## does between the encounter and the battle screen. Node-free, so a whole one
## steps headless, answering with a screen of cells, a DMG palette order and a
## per-scanline offset. Crystal walks a jumptable an entry a frame and
## Generation 1 is straight-line, but `BattleTransition_CircleData1` to `...5`
## are [constant WEDGES] byte for byte and the two half-circle tables cover
## [constant SPIN_QUADRANTS]' twenty positions.

const COLUMNS: int = 20
const ROWS: int = 18

## What a cell of [method cells] holds. `BATTLETRANSITION_SQUARE` and
## `..._BLACK` are the two tiles `LoadBattleTransitionGFX` loads, and a cell the
## transition has not written is the map showing through.
const CELL_NONE: int = 0
const CELL_SQUARE: int = 1
const CELL_BLACK: int = 2

## `%11100100`, the order that draws every colour as itself.
const IDENTITY: int = 0xE4

## Which map objects are still in OAM, which is the one thing the transition does
## to the sprites over it. Nothing in the loop writes shadow OAM, so the sprites
## `.InitGFX`'s `UpdateSprites` left stand over the wedges until each outro's own
## setup runs `RespawnPlayerAndOpponent`, which hides every object but the player
## and `hLastTalked`, and `StartTrainerBattle_Finish` runs `ClearSprites`.
const SPRITES_ALL: int = 0
const SPRITES_BATTLERS: int = 1
const SPRITES_NONE: int = 2

## `ld a, [wBattleMonLevel] / add 3`: the lead has to be more than this far under
## the opponent for the stronger pair of animations.
const STRONGER_MARGIN: int = 3

## `StartTrainerBattle_Flash.pals`, the thirteen `dc` bytes it walks two frames
## at a time. The last is not a palette: `cp %00000001` is what ends the pass.
const FLASH_PALETTES: Array[int] = [
	0xF9, 0xFE, 0xFF, 0xFE, 0xF9, 0xE4, 0x90, 0x40, 0x00, 0x40, 0x90, 0xE4, 0x01,
]
const FLASH_TERMINATOR: int = 0x01

## `PokeBallTransition`, the 16x16 overlay, one big-endian word per row.
const POKE_BALL: Array[int] = [
	0b0000001111000000, 0b0000111111110000, 0b0011110000111100, 0b0011000000001100,
	0b0110000000000110, 0b0110001111000110, 0b1100011000110011, 0b1111110000111111,
	0b1111110000111111, 0b1100011000110011, 0b0110001111000110, 0b0110000000000110,
	0b0011000000001100, 0b0011110000111100, 0b0000111111110000, 0b0000001111000000,
]
## `hlcoord 2, 1` and the sixteen rows `ld b, SCREEN_WIDTH - 4` walks.
const BALL_AT := Vector2i(2, 1)
const BALL_SIDE: int = 16

## The four animations, as the jumptable's own runs of scenes. `TRANS_STRONGER_F`
## is set when the lead is more than three levels under the opponent and
## `TRANS_NO_CAVE_F` when the environment is not a cave, and the pair indexes
## `StartTrainerBattle_DetermineWhichAnimation.StartingPoints`.
const SCENES: Array = [
	## BATTLETRANSITION_CAVE. `init` is `.InitGFX` in front of the jumptable
	## rather than an entry in it.
	[&"init", &"ball", &"bgmap", &"flash", &"flash", &"flash", &"next", &"wavy_setup", &"sine"],
	## BATTLETRANSITION_CAVE_STRONGER, which has no setup of its own
	[&"init", &"ball", &"bgmap", &"flash", &"flash", &"flash", &"next", &"zoom"],
	## BATTLETRANSITION_NO_CAVE
	[&"init", &"ball", &"bgmap", &"flash", &"flash", &"flash", &"next", &"spin_setup", &"spin"],
	## BATTLETRANSITION_NO_CAVE_STRONGER
	[&"init", &"ball", &"bgmap", &"flash", &"flash", &"flash", &"next", &"scatter_setup", &"scatter"],
]

## `StartTrainerBattle_SpinToBlack.spin_quadrants`: which corner a wedge is
## drawn from, which wedge, and where it starts. Bit 0 is
## `RIGHT_QUADRANT_F` and bit 1 `LOWER_QUADRANT_F`.
const UPPER_LEFT: int = 0
const UPPER_RIGHT: int = 1
const LOWER_LEFT: int = 2
const LOWER_RIGHT: int = 3
const SPIN_QUADRANTS: Array = [
	[UPPER_LEFT, 1, 1, 6], [UPPER_LEFT, 2, 0, 3], [UPPER_LEFT, 3, 1, 0],
	[UPPER_LEFT, 4, 5, 0], [UPPER_LEFT, 5, 9, 0],
	[UPPER_RIGHT, 5, 10, 0], [UPPER_RIGHT, 4, 14, 0], [UPPER_RIGHT, 3, 18, 0],
	[UPPER_RIGHT, 2, 19, 3], [UPPER_RIGHT, 1, 18, 6],
	[LOWER_RIGHT, 1, 18, 11], [LOWER_RIGHT, 2, 19, 14], [LOWER_RIGHT, 3, 18, 17],
	[LOWER_RIGHT, 4, 14, 17], [LOWER_RIGHT, 5, 10, 17],
	[LOWER_LEFT, 5, 9, 17], [LOWER_LEFT, 4, 5, 17], [LOWER_LEFT, 3, 1, 17],
	[LOWER_LEFT, 2, 0, 14], [LOWER_LEFT, 1, 1, 11],
]
## `.wedge1` to `.wedge5`, read as pairs: how many cells to black out along the
## row, then how many to step back before the next one. `-1` ends the wedge.
const WEDGES: Dictionary = {
	1: [2, 3, 5, 4, 9, -1],
	2: [1, 1, 2, 2, 4, 2, 4, 2, 3, -1],
	3: [2, 1, 3, 1, 4, 1, 4, 1, 4, 1, 3, 1, 2, 1, 1, 1, 1, -1],
	4: [4, 1, 4, 0, 3, 1, 3, 0, 2, 1, 2, 0, 1, -1],
	5: [4, 0, 3, 0, 3, 0, 2, 0, 2, 0, 1, 0, 1, 0, 1, -1],
}
## `BattleTransitions`, the jumptable `GetBattleTransitionID_WildOrTrainer`,
## `..._CompareLevels` and `..._IsDungeonMap` index with one bit each. Only the
## circles flash; the other six open on the wipe itself.
## `wBattleTransitionSpiralDirection` is 1 when the lead is stronger, which is
## the trainer row that spirals inward.
const GEN1_TRAINER_BIT: int = 1
const GEN1_STRONGER_BIT: int = 2
const GEN1_DUNGEON_BIT: int = 4
const GEN1_SCENES: Dictionary = {
	0: [&"gen1_init", &"gen1_flash", &"gen1_double_circle"],
	GEN1_TRAINER_BIT: [&"gen1_init", &"gen1_spiral_in"],
	GEN1_STRONGER_BIT: [&"gen1_init", &"gen1_flash", &"gen1_circle"],
	GEN1_TRAINER_BIT | GEN1_STRONGER_BIT: [&"gen1_init", &"gen1_spiral_out"],
	GEN1_DUNGEON_BIT: [&"gen1_init", &"gen1_stripes"],
	GEN1_DUNGEON_BIT | GEN1_TRAINER_BIT: [&"gen1_init", &"gen1_shrink"],
	GEN1_DUNGEON_BIT | GEN1_STRONGER_BIT: [&"gen1_init", &"gen1_stripes"],
	GEN1_DUNGEON_BIT | GEN1_STRONGER_BIT | GEN1_TRAINER_BIT: [&"gen1_init", &"gen1_split"],
}

## `BattleTransition_InwardSpiral`: down, right, up and left from `hlcoord 0, 0`.
const GEN1_SPIRAL_DIRECTIONS: Array[int] = [COLUMNS, 1, -COLUMNS, -1]
const GEN1_SPIRAL_FIRST_ARM: int = ROWS - 1
## `wInwardSpiralUpdateScreenCounter`: cells written between two `Delay3`s.
const GEN1_SPIRAL_TRANSFER: int = 7

## `BattleTransition_Spiral.outwardSpiral`: three `..._OutwardSpiral_` calls a
## frame from `hlcoord 10, 10`. A probe past `wTileMap` never reads its tile.
const GEN1_OUTWARD_AT := Vector2i(10, 10)
const GEN1_OUTWARD_DIRECTION: int = 3
const GEN1_OUTWARD_FRAMES: int = 120
const GEN1_OUTWARD_PER_FRAME: int = 3
## Probe, then the cell kept to, per `wOutwardSpiralCurrentDirection`.
const GEN1_OUTWARD_STEPS: Array[Vector2i] = [
	Vector2i(-1, -COLUMNS), Vector2i(COLUMNS, -1),
	Vector2i(1, COLUMNS), Vector2i(-COLUMNS, 1),
]

## Both squeezes as their `BattleTransition_CopyTiles` calls.
const GEN1_SHRINK_ROWS: Array = [[7, 8, -2], [10, 9, 2]]
const GEN1_SHRINK_COLUMNS: Array = [[8, 9, -2], [11, 10, 2]]
const GEN1_SPLIT_ROWS: Array = [[16, 17, -2], [1, 0, 2]]
const GEN1_SPLIT_COLUMNS: Array = [[18, 19, -2], [1, 0, 2]]
const GEN1_SQUEEZE_PASSES: int = ROWS / 2
const GEN1_ROW_COPIES: int = 8
const GEN1_COLUMN_COPIES: int = 9
## Shrink's `ld c, 6`, which is Split's two `Delay3`s.
const GEN1_SQUEEZE_STEP_FRAMES: int = 6
const GEN1_SQUEEZE_END_FRAMES: int = 10

## `BattleTransition_HalfCircle1` and `...2`, with the Y quadrant their caller
## passes folded into [method _draw_wedge]'s own two bits: the first table is
## always drawn downward and the second upward.
const GEN1_HALF_CIRCLE_1: Array = [
	[UPPER_RIGHT, 1, 18, 6], [UPPER_RIGHT, 2, 19, 3], [UPPER_RIGHT, 3, 18, 0],
	[UPPER_RIGHT, 4, 14, 0], [UPPER_RIGHT, 5, 10, 0],
	[UPPER_LEFT, 5, 9, 0], [UPPER_LEFT, 4, 5, 0], [UPPER_LEFT, 3, 1, 0],
	[UPPER_LEFT, 2, 0, 3], [UPPER_LEFT, 1, 1, 6],
]
const GEN1_HALF_CIRCLE_2: Array = [
	[LOWER_LEFT, 1, 1, 11], [LOWER_LEFT, 2, 0, 14], [LOWER_LEFT, 3, 1, 17],
	[LOWER_LEFT, 4, 5, 17], [LOWER_LEFT, 5, 9, 17],
	[LOWER_RIGHT, 5, 10, 17], [LOWER_RIGHT, 4, 14, 17], [LOWER_RIGHT, 3, 18, 17],
	[LOWER_RIGHT, 2, 19, 14], [LOWER_RIGHT, 1, 18, 11],
]

## `BattleTransition_HorizontalStripes` and `..._VerticalStripes`: two cursors
## from opposite corners, each blacking every second cell of its row or column.
## A row is the step count, where each cursor starts, what a step moves it by,
## and the run a cursor writes as a step and a count.
const GEN1_STRIPES_HORIZONTAL: Array = [
	20, Vector2i(0, 0), Vector2i(1, 0), Vector2i(19, 1), Vector2i(-1, 0),
	Vector2i(0, 2), 9,
]
const GEN1_STRIPES_VERTICAL: Array = [
	18, Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 17), Vector2i(0, -1),
	Vector2i(2, 0), 10,
]

## `BattleTransition_FlashScreen`'s `ld b, $3` over [constant FLASH_PALETTES]'
## twelve, two frames each, where Generation 2 walks them as three scenes.
const GEN1_FLASH_PALETTES: int = 12
const GEN1_FLASH_FRAMES: int = GEN1_FLASH_PALETTES * 2 * 3

## `BattleTransition_TransferDelay3`, the whole cost of a step of all four: the
## tiles are written between frames and `Delay3` spends the rest.
const GEN1_STEP_FRAMES: int = 3

## What `BattleTransition` spends in front of the animation: its caller's
## `DelayFrame`, then `Delay3`, `DelayFrame` and `Delay3` around the OAM clear.
const GEN1_LEAD_FRAMES: int = 8

## `BattleTransition_BlackScreen` writes `rBGP`, `rOBP0` and `rOBP1` rather than
## filling the tilemap, so every colour on screen is drawn as colour 3.
const GEN1_BLACK_ORDER: int = 0xFF

## `ld c, 2 / DelayFrames` between wedges, and the three `DelayFrame`s
## `.end` spends before it hands to `BATTLETRANSITION_FINISH`.
## `StartTrainerBattle_SpeckleToBlack.done` spends the same three; the zoom and
## the wavy outros hand on with none.
const SPIN_STEP_FRAMES: int = 2
const SPIN_END_FRAMES: int = 3

## `StartTrainerBattle_ZoomToBlack.boxes`: width, height and the top-left corner
## of each. The nine are one call rather than nine, with a `WaitBGMap` between
## them: measured with `wEnvironment` forced to CAVE and the opponent above the
## lead, the whole outro is the frames 96 to 132 of that trace and each box is
## four of them.
const ZOOM_BOXES: Array = [
	[4, 2, 8, 8], [6, 4, 7, 7], [8, 6, 6, 6], [10, 8, 5, 5], [12, 10, 4, 4],
	[14, 12, 3, 3], [16, 14, 2, 2], [18, 16, 1, 1], [20, 18, 0, 0],
]
const ZOOM_BOX_FRAMES: int = 4

## `StartTrainerBattle_SetUpForRandomScatterOutro`'s `ld a, $10`, and the twelve
## tiles a frame of `..._SpeckleToBlack` blacks out.
const SCATTER_FRAMES: int = 0x10
const SCATTER_PER_FRAME: int = 12

## `StartTrainerBattle_SineWave`'s own `cp $60`, and the two-scanline step its
## `ld e, 0 / add 2` loop walks the screen with.
const SINE_FRAMES: int = 0x60
const SINE_STEP: int = 2
const SCREEN_LINES: int = 144

## What a `.DoSineWave` call costs. It writes all 144 `wLYOverrides` through
## `calc_sine_wave`, whose multiply loop is longer the larger the amplitude, so
## a call late in the outro spends more frames than an early one. Measured on the
## same forced-CAVE trace: the fifteen working calls land on frames 97, 99, 101,
## 103, 105, 107, 110, 113, 116, 119, 122, 125, 128, 131 and 135, the `cp $60`
## that ends it on 138 and `..._Finish` on 139.
const SINE_STEP_FRAMES: Array[int] = [2, 2, 2, 2, 2, 3, 3, 3, 3, 3, 3, 3, 3, 4, 3]

## The three frames `LoadPokeBallGraphics` spends before the next scene: its own
## `DelayFrame` and the two `BattleStart_CopyTilemapAtOnce` behind it costs. On
## the Route 30 trace it runs on frame 813 and `..._SetUpBGMap` on 817.
const BALL_FRAMES: int = 3

## `DoBattleTransition.InitGFX` before the jumptable, and `.done` after it. Both
## are runs of VRAM copies this port does at once, and the counts are measured
## against a real cartridge rather than derived, because a `WaitBGMap` is worth
## whatever the copy in front of it left. `.InitGFX` is 19 frames on that trace,
## 793 to 811, and `._DetermineWhichAnimation` is the twentieth; the tail is
## `StartTrainerBattle_Finish` on 959 and the screen fully black on 962.
const LEAD_FRAMES: int = 19
const TAIL_FRAMES: int = 4

var _scene: Array = []
var _step: int = 0
var _counter: int = 0
var _sine_offset: int = 0
## `ld d, [hl]`: the amplitude a frame's wave is drawn at is the counter as it
## stood before that frame's own step.
var _sine_amplitude: int = 0
var _delay: int = 0
## Whether the scene that set [member _delay] had already handed on: a scene's
## own frames belong to it rather than to the one it hands to.
var _pending_next: bool = false
var _finished: bool = false
var _trainer: bool = false
var _darkness: bool = false
var _order: int = IDENTITY
var _ball_drawn: bool = false
var _sprites: int = SPRITES_ALL
## Which stripe plan is running, and whether this is `BattleTransition`.
var _gen1_stripes: Array = []
var _gen1: bool = false
## `wTileMap` as a squeeze moves it: the cell each one draws, or -1 for black.
var _gen1_map: PackedInt32Array = PackedInt32Array()
## Where either spiral has reached, and which way the outward one faces.
var _gen1_arms: Array = []
var _gen1_arm: int = 0
var _gen1_cursor: int = 0
var _gen1_direction: int = 0
var _cells: PackedByteArray = PackedByteArray()
var _sine: PackedByteArray = PackedByteArray()
var _rng: RandomNumberGenerator = null


## [param stronger] is `TRANS_STRONGER_F`, [param cave] the environment test,
## [param trainer] `wOtherTrainerClass`, [param darkness]
## `wTimeOfDayPalset`'s `DARKNESS_PALSET`, which is the one thing that skips the
## flash. [param sine] is `sine_table 32` as the cartridge stores it, which the
## wavy outro reads; the battle animations' own copy is the same table.
static func create(
	stronger: bool, cave: bool, trainer: bool, darkness: bool,
	rng: RandomNumberGenerator = null, sine: PackedByteArray = PackedByteArray()
) -> Gen2BattleTransition:
	var out := Gen2BattleTransition.new()
	out._scene = SCENES[(1 if stronger else 0) | (0 if cave else 2)]
	out._trainer = trainer
	out._darkness = darkness
	out._sine = sine
	out._rng = rng if rng != null else RandomNumberGenerator.new()
	out._cells = PackedByteArray()
	out._cells.resize(COLUMNS * ROWS)
	return out


## The scatter outro on its own, for a cover that is not a battle: no ball, no
## flash and no BG map of squares, because nothing is being transitioned to.
## `StartTrainerBattle_SetUpForRandomScatterOutro` and `..._SpeckleToBlack` are
## the whole of it, which is what a view switch is dressed in.
static func create_outro(rng: RandomNumberGenerator = null) -> Gen2BattleTransition:
	var out := Gen2BattleTransition.new()
	out._scene = [&"scatter_setup", &"scatter"]
	out._rng = rng if rng != null else RandomNumberGenerator.new()
	out._cells = PackedByteArray()
	out._cells.resize(COLUMNS * ROWS)
	return out


## `BattleTransition`. [param index] is the three bits the three
## `GetBattleTransitionID_*` routines set, and a row [constant GEN1_SCENES] does
## not carry answers null, which is every trainer row.
static func create_gen1(index: int) -> Gen2BattleTransition:
	if not GEN1_SCENES.has(index):
		return null
	var out := Gen2BattleTransition.new()
	out._gen1 = true
	out._scene = GEN1_SCENES[index]
	out._gen1_stripes = GEN1_STRIPES_VERTICAL if (index & GEN1_STRONGER_BIT) != 0 \
		else GEN1_STRIPES_HORIZONTAL
	out._rng = RandomNumberGenerator.new()
	out._cells = PackedByteArray()
	out._cells.resize(COLUMNS * ROWS)
	out._gen1_direction = GEN1_OUTWARD_DIRECTION
	out._gen1_arms = _gen1_spiral_arms()
	if out._scene.has(&"gen1_spiral_out"):
		out._gen1_cursor = GEN1_OUTWARD_AT.y * COLUMNS + GEN1_OUTWARD_AT.x
	if out._scene.has(&"gen1_shrink") or out._scene.has(&"gen1_split"):
		out._gen1_map.resize(COLUMNS * ROWS)
		for cell: int in COLUMNS * ROWS:
			out._gen1_map[cell] = cell
	return out


## The arms as `(direction, length)`, in the order the calls run.
static func _gen1_spiral_arms() -> Array:
	var arms: Array = [[0, GEN1_SPIRAL_FIRST_ARM]]
	var arm: int = GEN1_SPIRAL_FIRST_ARM + 1
	while true:
		arm += 1
		arms.append([1, arm])
		arm -= 2
		arms.append([2, arm])
		arm += 1
		arms.append([3, arm])
		arm -= 2
		if arm <= 0:
			return arms
		arms.append([0, arm])
	return arms


## Which screen cell each cell draws, empty for a transition moving none.
func source_cells() -> PackedInt32Array:
	return _gen1_map


## Which scene is running, for a test or a trace: a key of [constant SCENE_STEPS].
func scene() -> StringName:
	if _finished or _step >= _scene.size():
		return &""
	return StringName(_scene[_step])


## `wJumptableIndex`'s exit bit.
func finished() -> bool:
	return _finished


## What the screen is holding: one entry per cell, [constant CELL_NONE] where the
## map is still showing.
func cells() -> PackedByteArray:
	return _cells


## The DMG order every background palette is drawn through, which is `wBGP` and
## `DmgToCgbBGPals`.
func palette_order() -> int:
	return _order


## Whether the Poke Ball is up, which is also when `.pal_loop` has put every
## background tile on `PAL_BG_TEXT` and `.copypals` has filled it.
func ball_drawn() -> bool:
	return _ball_drawn


## Which map objects the sprites are still drawn from: one of [constant
## SPRITES_ALL], [constant SPRITES_BATTLERS] and [constant SPRITES_NONE].
func sprites() -> int:
	return _sprites


## `wLYOverrides`, the per-scanline `rSCX` the wavy outro writes. Empty for the
## three that write none.
func raster_offsets() -> PackedInt32Array:
	var out := PackedInt32Array()
	if StringName(_scene[mini(_step, _scene.size() - 1)]) != &"sine" or _sine.is_empty():
		return out
	out.resize(SCREEN_LINES)
	## `ld e, 0` before the loop: the phase is the scanline alone. The wave does
	## not travel down the screen; only its amplitude grows.
	for line: int in SCREEN_LINES:
		out[line] = _sine_wave(line * SINE_STEP, _sine_amplitude)
	return out


## One frame of `DoBattleTransition.loop`: one jumptable entry, then its
## `DelayFrame`. A scene that spends frames of its own answers for them here
## rather than running ahead.
func advance_frame() -> bool:
	if _delay > 0:
		_delay -= 1
		if _delay == 0 and _pending_next:
			_pending_next = false
			_step += 1
		return true
	if _finished:
		return false
	_run()
	return true


## Which method runs a scene, so a jumptable stays a table.
const SCENE_STEPS: Dictionary = {
	&"init": &"_lead_in", &"ball": &"_load_poke_ball_graphics",
	&"bgmap": &"_begin_bg_map", &"flash": &"_flash", &"next": &"_next",
	&"wavy_setup": &"_wavy_setup", &"sine": &"_sine_wave_step",
	&"spin_setup": &"_outro_setup", &"spin": &"_spin_step",
	&"scatter_setup": &"_scatter_setup", &"scatter": &"_scatter_step",
	&"zoom": &"_zoom_outro",
	&"gen1_init": &"_gen1_lead_in", &"gen1_flash": &"_gen1_flash",
	&"gen1_circle": &"_gen1_circle_step",
	&"gen1_double_circle": &"_gen1_double_circle_step",
	&"gen1_stripes": &"_gen1_stripes_step",
	&"gen1_spiral_in": &"_gen1_inward_spiral_step",
	&"gen1_spiral_out": &"_gen1_outward_spiral_step",
	&"gen1_shrink": &"_gen1_shrink_step", &"gen1_split": &"_gen1_split_step",
}


func _run() -> void:
	if _step >= _scene.size():
		_finished = true
		return
	call(SCENE_STEPS[StringName(_scene[_step])])


func _lead_in() -> void:
	_delay = LEAD_FRAMES
	_next()


func _begin_bg_map() -> void:
	_counter = 0
	_next()


func _wavy_setup() -> void:
	_outro_setup()
	_sine_offset = 0


func _outro_setup() -> void:
	_respawn()
	_counter = 0
	_next()


func _scatter_setup() -> void:
	_respawn()
	_counter = SCATTER_FRAMES
	_next()


func _zoom_outro() -> void:
	_respawn()
	_zoom_step()


## `RespawnPlayerAndOpponent`, which every one of the four outros opens with:
## `HideAllObjects`, then the player and, in a scripted battle, `hLastTalked`.
func _respawn() -> void:
	_sprites = SPRITES_BATTLERS


func _next() -> void:
	if _delay > 0:
		_pending_next = true
		return
	_step += 1


## `StartTrainerBattle_LoadPokeBallGraphics`, which returns at once for a wild
## battle: the ball is what says a person is on the other side.
func _load_poke_ball_graphics() -> void:
	if not _trainer:
		_next()
		return
	for row: int in BALL_SIDE:
		var bits: int = int(POKE_BALL[row])
		for column: int in BALL_SIDE:
			# `sla a` walks from bit 7 down and `and a / jr z` stops on a byte
			# whose remaining bits are all clear, so a zero never writes a cell.
			if (bits & (1 << (BALL_SIDE - 1 - column))) == 0:
				continue
			_write(BALL_AT.x + column, BALL_AT.y + row, CELL_SQUARE)
	_ball_drawn = true
	_delay = BALL_FRAMES
	_next()


## `StartTrainerBattle_Flash.DoFlashAnimation`, two frames a palette. Darkness is
## the one palset it does nothing for, and the pass ends on the entry that is not
## a palette at all.
func _flash() -> void:
	if _darkness:
		_counter = 0
		_next()
		return
	@warning_ignore("integer_division")
	var index: int = _counter / 2
	_counter += 1
	var value: int = int(FLASH_PALETTES[mini(index, FLASH_PALETTES.size() - 1)])
	if value == FLASH_TERMINATOR:
		_counter = 0
		_order = IDENTITY
		_next()
		return
	_order = value


## `StartTrainerBattle_SineWave`, whose counter is the amplitude and whose
## offset is what steps it.
func _sine_wave_step() -> void:
	if _counter >= SINE_FRAMES:
		_finish()
		return
	## `ld a, [hl] / inc [hl]` reads the offset before incrementing it, so the
	## counter is stepped by the old one: 0, 1, 3, 6, 10 and on up the triangular
	## numbers, which is the run a real cartridge walks.
	_sine_amplitude = _counter
	_counter = (_counter + _sine_offset) & 0xFF
	_sine_offset = (_sine_offset + 1) & 0xFF
	_delay = SINE_STEP_FRAMES[mini(_sine_offset - 1, SINE_STEP_FRAMES.size() - 1)] - 1


## `calc_sine_wave`: `d * sin(a * pi/32)` out of the cartridge's own table, as a
## signed byte.
func _sine_wave(phase: int, amplitude: int) -> int:
	var index: int = phase & 0x3F
	var negative: bool = index >= 0x20
	if negative:
		index &= 0x1F
	var word: int = 0
	if index * 2 + 1 < _sine.size():
		word = int(_sine[index * 2]) | (int(_sine[index * 2 + 1]) << 8)
	var value: int = ((word * amplitude) >> 8) & 0xFF
	if negative:
		value = (-value) & 0xFF
	return value - 256 if value >= 128 else value


## `StartTrainerBattle_SpinToBlack`, one wedge a step.
func _spin_step() -> void:
	if _counter >= SPIN_QUADRANTS.size():
		_delay = SPIN_END_FRAMES
		_finish()
		return
	_wedge_row(SPIN_QUADRANTS[_counter])
	_counter += 1
	_delay = SPIN_STEP_FRAMES


## A row of [constant SPIN_QUADRANTS] or of a half-circle table, same columns.
func _wedge_row(entry: Array) -> void:
	_draw_wedge(int(entry[0]), int(entry[1]), Vector2i(int(entry[2]), int(entry[3])))


## `BattleTransition`'s prologue. Its OAM clear keeps the player's block and the
## enemy trainer's, which Generation 2 only reaches at its outro.
func _gen1_lead_in() -> void:
	_sprites = SPRITES_BATTLERS
	_delay = GEN1_LEAD_FRAMES
	_next()


## `BattleTransition_FlashScreen_`. Its last write is `dc 3, 2, 1, 0`, so `rBGP`
## is back at [constant IDENTITY] by the time the wipe starts.
func _gen1_flash() -> void:
	@warning_ignore("integer_division")
	_order = int(FLASH_PALETTES[(_counter / 2) % GEN1_FLASH_PALETTES])
	_counter += 1
	if _counter < GEN1_FLASH_FRAMES:
		return
	_counter = 0
	_next()


## `BattleTransition_Circle`: `HalfCircle1` whole, then `HalfCircle2`.
func _gen1_circle_step() -> void:
	var first: int = GEN1_HALF_CIRCLE_1.size()
	if _counter >= first + GEN1_HALF_CIRCLE_2.size():
		_finish()
		return
	_wedge_row(GEN1_HALF_CIRCLE_1[_counter] if _counter < first \
		else GEN1_HALF_CIRCLE_2[_counter - first])
	_counter += 1
	_delay = GEN1_STEP_FRAMES - 1


## `BattleTransition_DoubleCircle`: the same twenty wedges, a pair a step.
func _gen1_double_circle_step() -> void:
	if _counter >= GEN1_HALF_CIRCLE_1.size():
		_finish()
		return
	_wedge_row(GEN1_HALF_CIRCLE_1[_counter])
	_wedge_row(GEN1_HALF_CIRCLE_2[_counter])
	_counter += 1
	_delay = GEN1_STEP_FRAMES - 1


## Whichever of the two stripe plans [method create_gen1] seated.
func _gen1_stripes_step() -> void:
	if _counter >= int(_gen1_stripes[0]):
		_finish()
		return
	var run: Vector2i = _gen1_stripes[5]
	for cursor: int in 2:
		var at: Vector2i = (_gen1_stripes[1 + cursor * 2] as Vector2i) \
			+ (_gen1_stripes[2 + cursor * 2] as Vector2i) * _counter
		for _cell: int in int(_gen1_stripes[6]):
			_write(at.x, at.y, CELL_BLACK)
			at += run
	_counter += 1
	_delay = GEN1_STEP_FRAMES - 1


## `BattleTransition_InwardSpiral_`: seven cells, then the `Delay3` they trip.
func _gen1_inward_spiral_step() -> void:
	for _cell: int in GEN1_SPIRAL_TRANSFER:
		while _gen1_arm < _gen1_arms.size() and int((_gen1_arms[_gen1_arm] as Array)[1]) <= 0:
			_gen1_arm += 1
		if _gen1_arm >= _gen1_arms.size():
			_finish()
			return
		var arm: Array = _gen1_arms[_gen1_arm]
		if _gen1_cursor >= 0 and _gen1_cursor < _cells.size():
			_cells[_gen1_cursor] = CELL_BLACK
		_gen1_cursor += GEN1_SPIRAL_DIRECTIONS[int(arm[0])]
		arm[1] = int(arm[1]) - 1
	_delay = GEN1_STEP_FRAMES - 1


## Each direction turns into the cell ninety degrees off it while it is map.
func _gen1_outward_spiral_step() -> void:
	if _counter >= GEN1_OUTWARD_FRAMES:
		_finish()
		return
	for _pass: int in GEN1_OUTWARD_PER_FRAME:
		var steps: Vector2i = GEN1_OUTWARD_STEPS[_gen1_direction]
		var probe: int = _gen1_cursor + steps.x
		if _gen1_written(probe):
			_gen1_cursor += steps.y
		else:
			_gen1_cursor = probe
			_gen1_direction = (_gen1_direction + 1) % GEN1_OUTWARD_STEPS.size()
		if _gen1_cursor >= 0 and _gen1_cursor < _cells.size():
			_cells[_gen1_cursor] = CELL_BLACK
	_counter += 1
	_delay = 0


func _gen1_written(cell: int) -> bool:
	return cell >= 0 and cell < _cells.size() and int(_cells[cell]) == CELL_BLACK


## `BattleTransition_Shrink`: both halves of each axis move toward the middle.
func _gen1_shrink_step() -> void:
	_gen1_squeeze(GEN1_SHRINK_ROWS, GEN1_SHRINK_COLUMNS)


## `BattleTransition_Split`: the halves move apart and the middle fills.
func _gen1_split_step() -> void:
	_gen1_squeeze(GEN1_SPLIT_ROWS, GEN1_SPLIT_COLUMNS)


func _gen1_squeeze(rows: Array, columns: Array) -> void:
	if _counter >= GEN1_SQUEEZE_PASSES:
		_delay += GEN1_SQUEEZE_END_FRAMES
		_finish()
		return
	for row: Array in rows:
		_gen1_copy(int(row[0]) * COLUMNS, int(row[1]) * COLUMNS, int(row[2]) * COLUMNS,
			GEN1_ROW_COPIES, 1, COLUMNS)
	for column: Array in columns:
		_gen1_copy(int(column[0]), int(column[1]), int(column[2]),
			GEN1_COLUMN_COPIES, COLUMNS, ROWS)
	_gen1_publish()
	_counter += 1
	_delay = GEN1_SQUEEZE_STEP_FRAMES - 1


## `BattleTransition_CopyTiles1` and `..._CopyTiles2`, one routine with two
## strides: its `pop hl / pop de` swaps the pointers every pass, and `de` ends
## on the run to fill.
func _gen1_copy(
	source: int, destination: int, offset: int, passes: int, stride: int, length: int
) -> void:
	for _pass: int in passes:
		for cell: int in length:
			_gen1_write(destination + cell * stride, _gen1_read(source + cell * stride))
		var next: int = destination + offset
		destination = source
		source = next
	for cell: int in length:
		_gen1_write(destination + cell * stride, -1)


func _gen1_read(cell: int) -> int:
	return int(_gen1_map[cell]) if cell >= 0 and cell < _gen1_map.size() else -1


func _gen1_write(cell: int, value: int) -> void:
	if cell >= 0 and cell < _gen1_map.size():
		_gen1_map[cell] = value


## The filled cells, so a renderer taking no source map still draws them.
func _gen1_publish() -> void:
	for cell: int in _cells.size():
		_cells[cell] = CELL_BLACK if int(_gen1_map[cell]) < 0 else CELL_NONE


## `.load`: a run of cells blacked out along a row, then a step back and down
## (or up), until the wedge's own `-1`. Which way each of those goes is the
## quadrant's two bits.
func _draw_wedge(quadrant: int, wedge: int, at: Vector2i) -> void:
	var data: Array = WEDGES[wedge]
	var right: bool = (quadrant & 1) != 0
	var lower: bool = (quadrant & 2) != 0
	var cursor: Vector2i = at
	var index: int = 0
	while index < data.size():
		var run: int = int(data[index])
		index += 1
		var head: Vector2i = cursor
		for _cell: int in run:
			_write(cursor.x, cursor.y, CELL_BLACK)
			cursor.x += 1 if right else -1
		cursor = head
		# `ld bc, SCREEN_WIDTH / jr z, .upper / ld bc, -SCREEN_WIDTH`: an upper
		# quadrant's wedge grows down the screen and a lower one grows up it.
		cursor.y += -1 if lower else 1
		if index >= data.size():
			return
		var back: int = int(data[index])
		index += 1
		if back < 0:
			return
		cursor.x += (-back if right else back)


## `StartTrainerBattle_SpeckleToBlack`: twelve tiles a frame, resampling a tile
## that is already black rather than counting it.
func _scatter_step() -> void:
	if _counter <= 0:
		_delay = SPIN_END_FRAMES
		_finish()
		return
	_counter -= 1
	for _tile: int in SCATTER_PER_FRAME:
		var guard: int = 256
		while guard > 0:
			guard -= 1
			var y: int = _rng.randi_range(0, ROWS - 1)
			var x: int = _rng.randi_range(0, COLUMNS - 1)
			if _cells[y * COLUMNS + x] == CELL_BLACK:
				continue
			_cells[y * COLUMNS + x] = CELL_BLACK
			break


## `StartTrainerBattle_ZoomToBlack`, one box a frame: its own loop spends a
## `WaitBGMap` between them.
func _zoom_step() -> void:
	if _counter >= ZOOM_BOXES.size():
		_finish()
		return
	var box: Array = ZOOM_BOXES[_counter]
	for row: int in int(box[1]):
		for column: int in int(box[0]):
			_write(int(box[3]) + column, int(box[2]) + row, CELL_BLACK)
	_counter += 1
	_delay = ZOOM_BOX_FRAMES - 1


## `StartTrainerBattle_Finish`, and `DoBattleTransition.done` behind it:
## `ClearSprites` empties shadow OAM, and every background palette is filled with
## zero, which is what takes whatever the outro left to black.
func _finish() -> void:
	## Added rather than assigned: [constant SPIN_END_FRAMES] belongs to the outro.
	## Generation 1 adds none: `BattleTransition_BlackScreen` writes three
	## palette registers and returns.
	_delay += 0 if _gen1 else TAIL_FRAMES
	_finished = true
	_sprites = SPRITES_NONE
	_order = GEN1_BLACK_ORDER if _gen1 else IDENTITY
	_cells.fill(CELL_BLACK)


func _write(x: int, y: int, value: int) -> void:
	if x < 0 or x >= COLUMNS or y < 0 or y >= ROWS:
		return
	_cells[y * COLUMNS + x] = value
