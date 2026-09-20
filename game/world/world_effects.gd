class_name Gen2WorldEffects
extends RefCounted

## Scene-free state for the effects the overworld paces in hardware frames:
## `ShakeScreen`'s packed byte, and the sprites drawn over the map rather than
## as map objects, each a frameset over a `GameData.overworld_effect()` sheet.

var _frame: int = 0
var _duration: int = 0
var _amplitude: int = 0
var _shake_step: int = 1
var _kind: StringName = &"none"
var _source: Dictionary = {}
var _sprites: Array = []
## `VermilionDockSSAnneLeavesScript`'s frame, empty while no ship is leaving.
var _ss_anne: Dictionary = {}
## An OAM coordinate less what puts it on screen: y 16 and x 8.
const OAM_ORIGIN: Vector2i = Vector2i(8, 16)

## The effect sprites, each named for the sheet it draws from.
const SPRITE_BOULDER_DUST: StringName = &"boulder_dust"
const SPRITE_GRASS_RUSTLE: StringName = &"grass_rustle"
const SPRITE_HEADBUTT_TREE: StringName = &"headbutt_tree"
const SPRITE_CUT_TREE: StringName = &"cut_tree"
const SPRITE_CUT_LEAF: StringName = &"cut_grass"
const SPRITE_SHADOW: StringName = &"shadow"
const SPRITE_HEAL_MACHINE: StringName = &"heal_machine"
const SPRITE_FLY_MON: StringName = &"fly_mon"

## `HealMachineAnim`'s OAM tables as (screen pixel, tile, flip), the `dbsprite`
## (y + 16, x + 8) taken off. `.PC_ElmsLab_OAM` opens with the machine's two
## `$7c` halves, which `.HOF_LoadBallsOntoMachine` does not place.
const HEAL_MACHINE_BAR: Array = [
	[Vector2i(26, 16), 0, false],
	[Vector2i(30, 16), 0, false],
]
const HEAL_MACHINE_BALLS: Array = [
	[Vector2i(24, 22), 1, false],
	[Vector2i(32, 22), 1, true],
	[Vector2i(24, 27), 1, false],
	[Vector2i(32, 27), 1, true],
	[Vector2i(24, 32), 1, false],
	[Vector2i(32, 32), 1, true],
]
## `.HOF_OAM`, whose six balls are a ring rather than two columns.
const HEAL_MACHINE_HOF_BALLS: Array = [
	[Vector2i(73, 44), 1, false],
	[Vector2i(78, 44), 1, false],
	[Vector2i(69, 43), 1, false],
	[Vector2i(82, 43), 1, false],
	[Vector2i(65, 41), 1, false],
	[Vector2i(85, 41), 1, false],
]
## `PokeCenterOAMData` in the same shape. `AnimateHealingMachine` places the
## monitor before its party loop, so the first row is the machine itself, and
## its counts are Crystal's to the frame.
static func gen1_heal_machine_oam() -> Array:
	var out: Array = []
	for row: Array in Gen1Layout.HEAL_MACHINE_OAM:
		out.append([
			Vector2i(int(row[1]) - OAM_X_ORIGIN, int(row[0]) - OAM_Y_ORIGIN),
			int(row[2]) - Gen1Layout.HEAL_MACHINE_VTILE,
			bool(row[3]),
		])
	return out


## Where a hardware object counts from.
const OAM_X_ORIGIN: int = 8
const OAM_Y_ORIGIN: int = 16

## `.PlaceHealingMachineTile`'s `bcpixel 2, 4`, added to every entry of the table
## on Elm's Lab alone; the other two machine types add nothing.
const HEAL_MACHINE_ELMS_LAB_OFFSET := Vector2i(16, 32)
const HEAL_MACHINE_ELMS_LAB: int = 1
const HEAL_MACHINE_HALL_OF_FAME: int = 2
## `.LoadBallsOntoMachine`'s `ld c, 30 / call DelayFrames` and
## `.FlashPalettes8Times`' eight rounds of ten, which is what the script waits.
const HEAL_MACHINE_BALL_FRAMES: int = 30
const HEAL_MACHINE_FLASH_INTERVAL: int = 10
const HEAL_MACHINE_FLASHES: int = 8
## A palette of the sprite's own rather than one of the map's: `.LoadPalettes`
## in Crystal and `rOBP1` in Generation 1.
const HEAL_MACHINE_PALETTE: int = -1
## A Generation 1 sprite wearing `rOBP1`: the record's `rotation` is the byte.
const OBP_PALETTE: int = -2
const SPRITE_SMOKE: StringName = &"smoke"

const FLY_FROM_FRAMES: int = 128
const FLY_TO_FRAMES: int = 64
const FLY_MON_X: int = 80
const FLY_MON_Y: int = 84
const FLY_TO_START_Y: int = 252
const FLY_HOLD_FRAMES: int = 0x40
const FLY_FROM_SWING_STEP: int = 8
const FLY_FROM_SWING_MAX: int = 0x40
const FLY_TO_SWING: int = 11 * 8
const FLY_TO_SWING_STEP: int = 2
const FLY_MON_FRAME_LENGTH: int = 9
const FLY_LEAF_INTERVAL: int = 8
const FLY_LEAF_SWING: int = 0x40
const FLY_LEAF_LIMIT: int = 0x100 - 9 * 8

## constants/sprite_data_constants.asm. Every emote-object spawn names its
## palette: PAL_OW_EMOTE for the dust and the emote bubbles, PAL_OW_TREE for the
## grass and for `.OAMData_Tree`.
const PAL_OW_RED: int = 0
const PAL_OW_EMOTE: int = 5
const PAL_OW_TREE: int = 6
const PAL_OW_ROCK: int = 7

## ShakeHeadbuttTree's `ld a, 32 / ld [wFrameCounter], a`, and OWCutAnimation's
## own, which both branches of its jumptable write.
const HEADBUTT_TREE_FRAMES: int = 32
const CUT_FRAMES: int = 32

## `.Frameset_CutTree`, as [first frame, tile offsets] pairs. `oamframe X, n`
## lasts n + 1 frames and `oamwait n` draws nothing for n + 1, which is what puts
## the two gaps in: the tree stands for three frames, splits for seventeen, and
## then its halves slide apart in two steps of two. `oamdelete` ends it four
## frames before the counter does.
const CUT_TREE_STEPS: Array = [
	[0, [Vector2i(0, 0), Vector2i(8, 0), Vector2i(0, 8), Vector2i(8, 8)]],
	[3, [Vector2i(-2, 0), Vector2i(10, 0), Vector2i(-2, 8), Vector2i(10, 8)]],
	[20, []],
	[22, [Vector2i(-4, 0), Vector2i(12, 0), Vector2i(-4, 8), Vector2i(12, 8)]],
	[24, []],
	[26, [Vector2i(-8, 0), Vector2i(16, 0), Vector2i(-8, 8), Vector2i(16, 8)]],
	[28, []],
]

## `Cut_GetLeafSpawnCoords`, as pixel offsets from where the player is drawn.
## Its own table is screen coordinates, indexed by the facing and then by which
## quarter of the block the player stands in, because Cut clears the whole block
## and the leaves are spawned over it. Order is the source's: DOWN, UP, LEFT,
## RIGHT, each with top-left, top-right, bottom-left, bottom-right.
const CUT_LEAF_ORIGINS: Array[Vector2i] = [
	Vector2i(16, 16), Vector2i(0, 16), Vector2i(16, 32), Vector2i(0, 32),
	Vector2i(16, -16), Vector2i(0, -16), Vector2i(16, 0), Vector2i(0, 0),
	Vector2i(-16, 16), Vector2i(0, 16), Vector2i(-16, 0), Vector2i(0, 0),
	Vector2i(16, 16), Vector2i(32, 16), Vector2i(16, 0), Vector2i(32, 0),
]

## `SpriteAnimFunc_CutLeaves` steps four leaves an eighth of a turn apart, each
## by three of angle and half a pixel of radius from `Cut_SpawnLeaf`'s $4 seed.
const CUT_LEAF_ANGLES: Array[int] = [0x00, 0x10, 0x20, 0x30]
const CUT_LEAF_ANGLE_STEP: int = 3
const CUT_LEAF_RADIUS_STEP: int = 0x80
const CUT_LEAF_RADIUS_BASE: int = 0x0400
## `.OAMData_Leaf`'s single `dbsprite -1, -1, 4, 4`.
const CUT_LEAF_OFFSET := Vector2i(-4, -4)

## The rod `FacingFishDown` and its three siblings add to the player's own four,
## in Gen2WorldSprite's DOWN, UP, LEFT, RIGHT order: offset, which tile of the
## gender's sheet, and whether it is mirrored. Down and up hang $fc, the sides $fd.
const FISHING_ROD_TILES: Array = [
	{"offset": Vector2i(0, 16), "tile": 6, "flip_x": false},
	{"offset": Vector2i(0, -8), "tile": 6, "flip_x": false},
	{"offset": Vector2i(-8, 5), "tile": 7, "flip_x": true},
	{"offset": Vector2i(16, 5), "tile": 7, "flip_x": false},
]

## The other six, written over the player's own $02, $06 and $0a: a fishing player
## is the standing top half and these, and right mirrors left and swaps its cells.
const FISHING_BODY_TILES: Array = [
	[{"tile": 0, "flip_x": false}, {"tile": 1, "flip_x": false}],
	[{"tile": 2, "flip_x": false}, {"tile": 3, "flip_x": false}],
	[{"tile": 4, "flip_x": false}, {"tile": 5, "flip_x": false}],
	[{"tile": 5, "flip_x": true}, {"tile": 4, "flip_x": true}],
]

const FISHING_SHEETS: Array[String] = ["chris_fish", "kris_fish"]


## `MovementFunction_Shadow`: y offset 14 along the axis the jump is on and 12
## across it, x offset zero, in the source's DOWN, UP, LEFT, RIGHT order.
const SHADOW_OFFSETS: Array[Vector2i] = [
	Vector2i(0, 14), Vector2i(0, 14), Vector2i(0, 12), Vector2i(0, 12),
]

## `MovementFunction_BoulderDust`'s `.dust_coords`, indexed by the boulder's own
## walking direction in the source's DOWN, UP, LEFT, RIGHT order.
const DUST_OFFSETS: Array[Vector2i] = [
	Vector2i(0, -4), Vector2i(0, 8), Vector2i(6, 2), Vector2i(-6, 2),
]


func start_screen_shake(packed_value: int, kind: StringName = &"screen_shake", source: Dictionary = {}) -> Dictionary:
	var value: int = clampi(packed_value, 0, 0xFF)
	_duration = value & 0x3F
	_amplitude = 1 << ((value >> 6) & 0x03) if _duration > 0 else 0
	_shake_step = 1
	_frame = 0
	_kind = kind if _duration > 0 else &"none"
	_source = source.duplicate(true)
	return snapshot()


func start_gen1_elevator_shake() -> Dictionary:
	_duration = Gen1Layout.ELEVATOR_SHAKE_FRAMES
	_amplitude = 1
	_shake_step = Gen1Layout.ELEVATOR_SHAKE_STEP
	_frame = 0
	_kind = &"gen1_elevator_shake"
	_source = {}
	return snapshot()


## `ShakeHeadbuttTree` over the cell the player is facing: the tree's four tiles
## are replaced with the tileset's own grass tile and an eight-tile sheet is
## animated in front of them for 32 frames.
func start_headbutt_tree(cell: Vector2i) -> void:
	_sprites.append({
		"kind": SPRITE_HEADBUTT_TREE,
		"cell": cell,
		"object_index": -2,
		"palette": PAL_OW_TREE,
		"frame": 0,
		"duration": HEADBUTT_TREE_FRAMES,
	})


## `OWCutAnimation`: [param animation] is `CheckOverworldTileArrays`' byte, 0 the
## splitting tree and 1 the leaves, whose corner of the block [param player_cell] picks.
func start_cut(
	cell: Vector2i, animation: int, direction: Vector2i, player_cell: Vector2i
) -> void:
	if animation == 0:
		_sprites.append({
			"kind": SPRITE_CUT_TREE,
			"cell": cell,
			"object_index": -2,
			"palette": PAL_OW_TREE,
			"frame": 0,
			"duration": CUT_FRAMES,
		})
		return
	var origin: Vector2i = CUT_LEAF_ORIGINS[
		_direction_index(direction) * 4 + (player_cell.x & 1) + (player_cell.y & 1) * 2
	]
	for angle: int in CUT_LEAF_ANGLES:
		_sprites.append({
			"kind": SPRITE_CUT_LEAF,
			"cell": cell,
			"object_index": -1,
			"palette": PAL_OW_TREE,
			"frame": 0,
			"duration": CUT_FRAMES,
			"origin": origin,
			"angle": angle,
		})


## `SpawnShadow`, under a jumping object for twice the jump it was spawned in.
## Tracks whoever is jumping, and sits below them because the jump is an offset
## on the sprite alone.
func start_jump_shadow(object_index: int, cell: Vector2i, direction: Vector2i, step_passes: int) -> void:
	_sprites.append({
		"kind": SPRITE_SHADOW,
		"cell": cell,
		"object_index": object_index,
		"palette": PAL_OW_EMOTE,
		"frame": 0,
		"duration": (int(float(maxi(0, step_passes)) / 2.0) + 1) * 2,
		"direction": _direction_index(direction),
	})


## `ShakeGrass`, spawned where a step onto grass starts and tracking whoever
## took it. [param frames] is the step's own duration less one.
func start_grass_rustle(object_index: int, cell: Vector2i, frames: int) -> void:
	if frames <= 0:
		return
	_sprites.append({
		"kind": SPRITE_GRASS_RUSTLE,
		"cell": cell,
		"object_index": object_index,
		"palette": PAL_OW_TREE,
		"frame": 0,
		"duration": frames,
	})


## `SpawnStrengthBoulderDust`, spawned where the boulder starts sliding.
## `MovementFunction_BoulderDust` spends `(step duration + 1) * 2` frames, so the
## dust outlives the push.
func start_boulder_dust(object_index: int, cell: Vector2i, direction: Vector2i, step_passes: int) -> void:
	_sprites.append({
		"kind": SPRITE_BOULDER_DUST,
		"cell": cell,
		"object_index": object_index,
		"palette": PAL_OW_EMOTE,
		"frame": 0,
		"duration": (maxi(0, step_passes) + 1) * 2,
		"direction": _direction_index(direction),
	})


## `HealMachineAnim`: OAM at fixed screen pixels, wearing
## `gfx/overworld/heal_machine.pal` (`palette: -1`); [param balls] is `wPartyCount`.
func start_heal_machine(
	machine_type: int, balls: int, generation: int = RomRegistry.GEN2
) -> void:
	if balls <= 0:
		return
	_sprites.append({
		"kind": SPRITE_HEAL_MACHINE,
		"cell": Vector2i.ZERO,
		"object_index": -1,
		"screen": true,
		"palette": HEAL_MACHINE_PALETTE,
		"frame": 0,
		"duration": balls * HEAL_MACHINE_BALL_FRAMES
			+ HEAL_MACHINE_FLASHES * HEAL_MACHINE_FLASH_INTERVAL,
		"machine_type": clampi(machine_type, 0, HEAL_MACHINE_HALL_OF_FAME),
		"balls": mini(balls, HEAL_MACHINE_BALLS.size()),
		"generation": generation,
	})


## `FlyFromAnim` and `FlyToAnim`, one record whose frame counter drives the icon
## and every leaf in the air. The two `depixel`s and every offset below are OAM
## coordinates, which count from (8, 16). `SpriteAnimFunc_FlyFrom` holds until
## VAR2 reaches $40, then rises two pixels a frame while VAR4 widens the swing to
## $40; `SpriteAnimFunc_FlyTo` descends two a frame into a swing narrowing by two
## and stops on the frame its wrapped row matches the departure's.
## `.Frameset_RedWalk` alternates the icon's two drawings every nine frames and
## `.SpawnLeaf` puts a leaf at column zero every eight.
func start_fly(icon: int, arriving: bool) -> void:
	_sprites.append({
		"kind": SPRITE_FLY_MON,
		"cell": Vector2i.ZERO,
		"object_index": -1,
		"screen": true,
		"palette": PAL_OW_RED,
		"frame": 0,
		"duration": FLY_TO_FRAMES if arriving else FLY_FROM_FRAMES,
		"icon": maxi(icon, 0),
		"arriving": arriving,
	})


## Where `FlyFunction_FrameTimer` reaches `ld de, SFX_FLY`.
static func fly_sfx_frames(arriving: bool) -> Array[int]:
	var out: Array[int] = []
	var counter: int = FLY_TO_FRAMES if arriving else FLY_FROM_FRAMES
	for frame: int in counter:
		var left: int = counter - frame
		if left >= FLY_HOLD_FRAMES and left % 8 == 0:
			out.append(frame)
	return out


## `engine/overworld/player_animations.asm` as steps a screen spends a frame at
## a time: the drawing left standing (`image`, `y`, `x`, `bird`, `half`,
## `hidden`), `hold` frames or a `wait` on the driver, and the screen's actions.
const PLAYER_ANIM_SPIN_IMAGES: Array[int] = [0x00, 0x08, 0x04, 0x0C]
## `GetPlayerTeleportAnimFrameDelay` under `wOnSGB`, which `SpinPlayerSprite`
## also draws as the image while rising or falling: `hl` is left on the delay byte.
const PLAYER_ANIM_DELAY: int = 2
const PLAYER_ANIM_STEP_Y: int = 0x10
const PLAYER_ANIM_OFF_SCREEN_Y: int = 0xEC - 0x100
const PLAYER_ANIM_SETUP_FRAMES: int = 3
const PLAYER_ANIM_STOP_MUSIC_FADE: int = 4
const PLAYER_ANIM_EXIT_SPIN_DELAY: int = 16
const PLAYER_ANIM_ENTER_SPIN_END: int = 8
const PLAYER_ANIM_NOT_ON_PAD_FRAMES: int = 10
const PLAYER_ANIM_HOLE_HALF_FRAMES: int = 2
const PLAYER_ANIM_HOLE_WAIT_FRAMES: int = 50
const PLAYER_ANIM_FLAPS_IN_PLACE: int = 8
const PLAYER_ANIM_FLAP_FRAMES: int = 3
const PLAYER_ANIM_FLY_REST_FRAMES: int = 40
const PLAYER_ANIM_FLY_OUT_IMAGE: int = 0x0C
const PLAYER_ANIM_FLY_BACK_IMAGE: int = 0x08
## `LoadBirdSpriteGraphics`' two `CopyVideoData`s, with Red and Blue's twelve tiles ahead.
const PLAYER_ANIM_BIRD_LOAD_FRAMES: int = 4
const PLAYER_ANIM_BIRD_ENTER_LOAD_FRAMES: Dictionary = {
	RomRegistry.RED: 6, RomRegistry.BLUE: 6, RomRegistry.YELLOW: 4,
}
## `LoadPlayerSpriteGraphics` behind the landing, the bird's index still drawn.
const PLAYER_ANIM_PLAYER_LOAD_FRAMES: int = 4
## `RestoreFacingDirectionAndYScreenPos` to `EnterMapAnim`, measured, and
## `LoadMapData` alone behind a pad.
const PLAYER_ANIM_SPECIAL_LOAD_FRAMES: Dictionary = {
	RomRegistry.RED: 32, RomRegistry.BLUE: 32, RomRegistry.YELLOW: 36,
}
const PLAYER_ANIM_PAD_LOAD_FRAMES: Dictionary = {
	RomRegistry.RED: 12, RomRegistry.BLUE: 12, RomRegistry.YELLOW: 16,
}
## `GBFadeOutToWhite` and `GBFadeInFromWhite`'s rows; Yellow's `UpdateCGBPal_BGP` holds one more.
const PLAYER_ANIM_FADE_OUT_ROWS: Array[int] = [5, 6, 7]
const PLAYER_ANIM_FADE_IN_ROWS: Array[int] = [6, 5, 4]
const PLAYER_ANIM_FADE_STEP_FRAMES: int = 8
const PLAYER_ANIM_CGB_FADE_FRAMES: Dictionary = {RomRegistry.YELLOW: 1}
const PLAYER_ANIM_KINDS: Array[StringName] = [&"fly", &"escape", &"pad", &"hole"]

var _player_anim: Dictionary = {}


func player_anim() -> Dictionary:
	return _player_anim.duplicate()


func apply_player_anim(step: Dictionary) -> bool:
	var changed: bool = false
	for key: String in ["image", "y", "x", "bird", "hidden", "half"]:
		if step.has(key) and _player_anim.get(key) != step[key]:
			_player_anim[key] = step[key]
			changed = true
	return changed


func clear_player_anim() -> void:
	_player_anim = {}


## `_LeaveMapAnim` from `HandleFlyWarpOrDungeonWarp` or `WarpFound2.indoorMaps`
## to the `swap`; [param image] is what `InitFacingDirectionList` saves.
static func gen1_leave_steps(kind: StringName, id: StringName, image: int) -> Array:
	var steps: Array = [_standing(image)]
	match kind:
		&"pad":
			steps.append({"sfx": Gen1Layout.SFX_TELEPORT_EXIT_1})
			steps.append_array(_spin_moving(-PLAYER_ANIM_STEP_Y, PLAYER_ANIM_OFF_SCREEN_Y))
		&"hole":
			steps.append({"hold": PLAYER_ANIM_SETUP_FRAMES})
			steps.append({"half": true, "hold": PLAYER_ANIM_HOLE_HALF_FRAMES})
			steps.append({"hidden": true})
		&"escape":
			steps.append({"hold": PLAYER_ANIM_SETUP_FRAMES})
			steps.append({"stop_music": PLAYER_ANIM_STOP_MUSIC_FADE, "wait": &"music"})
			steps.append_array(_spin_in_place(
				PLAYER_ANIM_EXIT_SPIN_DELAY, -1, 0, Gen1Layout.SFX_TELEPORT_EXIT_2, 0
			))
			steps.append({"sfx": Gen1Layout.SFX_TELEPORT_EXIT_1})
			steps.append_array(_spin_moving(-PLAYER_ANIM_STEP_Y, PLAYER_ANIM_OFF_SCREEN_Y))
			steps.append({"hold": PLAYER_ANIM_NOT_ON_PAD_FRAMES})
		&"fly":
			steps.append({"hold": PLAYER_ANIM_SETUP_FRAMES})
			steps.append({"stop_music": PLAYER_ANIM_STOP_MUSIC_FADE, "wait": &"music"})
			steps.append({"hold": PLAYER_ANIM_BIRD_LOAD_FRAMES})
			steps.append_array(_fly_flaps(PLAYER_ANIM_FLY_OUT_IMAGE, PLAYER_ANIM_FLAPS_IN_PLACE, []))
			steps.append({"sfx": Gen1Layout.SFX_FLY})
			steps.append_array(_fly_flaps(
				PLAYER_ANIM_FLY_OUT_IMAGE, Gen1Layout.FLY_EXIT_COORDS_1.size(),
				Gen1Layout.FLY_EXIT_COORDS_1
			))
			steps.append({"hold": PLAYER_ANIM_FLY_REST_FRAMES})
			steps.append_array(_fly_flaps(
				PLAYER_ANIM_FLY_BACK_IMAGE, Gen1Layout.FLY_EXIT_COORDS_2.size(),
				Gen1Layout.FLY_EXIT_COORDS_2
			))
	steps.append_array(_fade_steps(PLAYER_ANIM_FADE_OUT_ROWS, id))
	steps.append(_standing(image))
	steps.append({"swap": true})
	return steps


## `EnterMapAnim` from `RestoreFacingDirectionAndYScreenPos`'s frame.
static func gen1_enter_steps(kind: StringName, id: StringName, image: int, on_pad: bool) -> Array:
	var loading: Dictionary = PLAYER_ANIM_PAD_LOAD_FRAMES if kind == &"pad" \
		else PLAYER_ANIM_SPECIAL_LOAD_FRAMES
	var steps: Array = [{"hold": int(loading[id])}]
	var arrived: Dictionary = _standing(image)
	arrived["y"] = PLAYER_ANIM_OFF_SCREEN_Y
	arrived["hold"] = PLAYER_ANIM_SETUP_FRAMES
	steps.append(arrived)
	steps.append_array(_fade_steps(PLAYER_ANIM_FADE_IN_ROWS, id))
	if kind == &"fly":
		steps.append({"hold": int(PLAYER_ANIM_BIRD_ENTER_LOAD_FRAMES[id])})
		steps.append({"sfx": Gen1Layout.SFX_FLY})
		steps.append_array(_fly_flaps(
			PLAYER_ANIM_FLY_BACK_IMAGE, Gen1Layout.FLY_ENTER_COORDS.size(),
			Gen1Layout.FLY_ENTER_COORDS
		))
		steps.append({"bird": false, "hold": PLAYER_ANIM_PLAYER_LOAD_FRAMES})
		steps.append({"wait": &"sfx"})
		steps.append({"music": true})
	else:
		steps.append({"sfx": Gen1Layout.SFX_TELEPORT_ENTER_1})
		if kind == &"hole":
			steps.append({"hold": PLAYER_ANIM_HOLE_WAIT_FRAMES})
		steps.append_array(_spin_moving(PLAYER_ANIM_STEP_Y, Gen1Layout.PLAYER_SPRITE_PIXELS.y))
		if kind != &"hole":
			steps.append({"sfx": Gen1Layout.SFX_TELEPORT_ENTER_2})
		if kind != &"hole" and not on_pad:
			## `ld hl, wFacingDirectionList` after the fall's five rotations.
			steps.append_array(_spin_in_place(
				0, 1, PLAYER_ANIM_ENTER_SPIN_END, -1, PLAYER_ANIM_SPIN_IMAGES.size() + 1
			))
			steps.append({"wait": &"sfx"})
			steps.append({"music": true})
	steps.append(_standing(image))
	return steps


static func _standing(image: int) -> Dictionary:
	return {
		"image": image, "y": Gen1Layout.PLAYER_SPRITE_PIXELS.y,
		"x": Gen1Layout.PLAYER_SPRITE_PIXELS.x, "bird": false, "hidden": false, "half": false,
	}


## `PlayerSpinInPlace`, which ends the moment the delay reaches [param end].
static func _spin_in_place(delay: int, delta: int, end: int, sfx: int, first: int) -> Array:
	var steps: Array = []
	var index: int = first
	while true:
		var step: Dictionary = {"image": PLAYER_ANIM_SPIN_IMAGES[index % PLAYER_ANIM_SPIN_IMAGES.size()]}
		index += 1
		if delay & 3 == 0 and sfx >= 0:
			step["sfx"] = sfx
		delay += delta
		steps.append(step)
		if delay == end:
			return steps
		step["hold"] = delay
	return steps


## `PlayerSpinWhileMovingUpOrDown`.
static func _spin_moving(delta_y: int, to_y: int) -> Array:
	var steps: Array = []
	var y: int = PLAYER_ANIM_OFF_SCREEN_Y if delta_y > 0 else Gen1Layout.PLAYER_SPRITE_PIXELS.y
	while y != to_y:
		y += delta_y
		var step: Dictionary = {"image": PLAYER_ANIM_DELAY, "y": y}
		steps.append(step)
		if y != to_y:
			step["hold"] = PLAYER_ANIM_DELAY
	return steps


## `DoFlyAnimation`: a flap, `Delay3`, then the list's next pair.
static func _fly_flaps(image: int, count: int, coords: Array) -> Array:
	var steps: Array = []
	for index: int in count:
		image ^= 1
		steps.append({"image": image, "bird": true, "hold": PLAYER_ANIM_FLAP_FRAMES})
		if not coords.is_empty():
			var pair: Vector2i = coords[index]
			steps.append({"y": _signed(pair.x), "x": pair.y})
	return steps


static func _fade_steps(rows: Array[int], id: StringName) -> Array:
	var steps: Array = []
	var frames: int = PLAYER_ANIM_FADE_STEP_FRAMES + int(PLAYER_ANIM_CGB_FADE_FRAMES.get(id, 0))
	for row: int in rows:
		steps.append({
			"fade": Gen1Layout.FADE_PALS[row * Gen1Layout.FADE_PAL_ROW + Gen1Layout.FADE_PAL_BACKGROUND],
			"hold": frames,
		})
	return steps


## The three sprites that are temporary map objects on the cartridge, so their
## countdowns are `HandleMap`'s passes rather than screen frames
## (Gen2WorldAPI.FRAMES_PER_OVERWORLD_PASS). The other four are a routine's own
## `DelayFrame` loop: `ShakeHeadbuttTree`, `OWCutAnimation` and `HealMachineAnim`
## each spin on one while the script waits, so they keep the screen's rate.
const PASS_PACED_SPRITES: Array[StringName] = [
	SPRITE_SHADOW, SPRITE_GRASS_RUSTLE, SPRITE_BOULDER_DUST,
]


## One `HandleMap` pass: the tracking sprites, and `step_shake`'s own screen
## shake, which is a movement and so is spent with the object that runs it.
func advance_pass() -> bool:
	var moved: bool = _spend_sprites(true)
	if not active():
		return moved
	_frame += 1
	if not active():
		_kind = &"none"
		_source = {}
	return true


## One hardware frame: the four sprites whose source routine spins on
## `DelayFrame` rather than being stepped by `HandleObjectStep`.
func advance_frame() -> bool:
	_advance_ss_anne()
	return _spend_sprites(false) or ss_anne_active()


func _spend_sprites(pass_paced: bool) -> bool:
	var moved: bool = false
	var running: Array = []
	for sprite: Dictionary in _sprites:
		if PASS_PACED_SPRITES.has(StringName(sprite["kind"])) != pass_paced:
			running.append(sprite)
			continue
		sprite["frame"] = int(sprite["frame"]) + 1
		if int(sprite["frame"]) < int(sprite["duration"]):
			running.append(sprite)
		moved = true
	_sprites = running
	return moved


func active() -> bool:
	return _frame < _duration and _duration > 0


func sprites_active() -> bool:
	return not _sprites.is_empty() or ss_anne_active()


## `StepFunction_ScreenShake.Run` reaches hSCY and nothing else: the whole shake
## is one vertical scroll offset whose sign `.GetSign` flips on what is left of
## the duration, and the pass that runs it out deletes the object with the offset
## undone. In hardware pixels, and the background's alone, since a scroll moves
## no sprite.
func offset() -> Vector2:
	if not active():
		return Vector2.ZERO
	## `dec [hl]` before the sign, so the first pass already reads one less.
	var remaining: int = _duration - 1 - _frame
	if remaining <= 0:
		return Vector2.ZERO
	var pass_index: int = remaining / _shake_step
	return Vector2(0.0, float(_amplitude if pass_index % 2 == 0 else -_amplitude))


## What a renderer draws this frame: one record per live sprite, each carrying
## the sheet, the palette row and the tiles, as pixel offsets from the anchor.
## That anchor is the cell for the headbutt tree, which stands still, and the
## tracked object's own drawn position for the other two.
func sprites() -> Array:
	var out: Array = _ss_anne_puffs()
	for sprite: Dictionary in _sprites:
		if StringName(sprite["kind"]) == SPRITE_FLY_MON:
			out.append_array(_fly_records(sprite))
			continue
		out.append({
			"kind": sprite["kind"],
			"cell": sprite["cell"],
			"object_index": int(sprite["object_index"]),
			"screen": bool(sprite.get("screen", false)),
			"palette": int(sprite["palette"]),
			"rotation": _palette_rotation(sprite),
			"frame": int(sprite["frame"]),
			"tiles": _tiles_for(sprite),
		})
	return out


## `AnimateBoulderDust`: `LoadSmokeTileFourTimes`' block two cells past the
## player, walked a pixel back a step and flashing `rOBP1`. [param player] is
## `wSpritePlayerStateData1YPixels` and its neighbour, [param facing] the
## DOWN, UP, LEFT, RIGHT index and [param offsets] the cartridge's own table.
func start_gen1_boulder_dust(player: Vector2i, facing: int, offsets: Array) -> void:
	if facing < 0 or facing >= offsets.size():
		return
	_sprites.append({
		"kind": SPRITE_SMOKE,
		"cell": Vector2i.ZERO,
		"object_index": -1,
		"screen": true,
		"palette": OBP_PALETTE,
		"frame": 0,
		"duration": Gen1Layout.BOULDER_DUST_STEPS * Gen1Layout.BOULDER_DUST_STEP_FRAMES,
		"pixel": player + (offsets[facing] as Vector2i) - OAM_ORIGIN,
		"drift": Gen1Layout.BOULDER_DUST_DRIFT[facing],
		"obp": Gen1Layout.BOULDER_DUST_OBP1,
		"flash": Gen1Layout.BOULDER_DUST_OBP1_FLASH,
	})


## `VermilionDockSSAnneLeavesScript` from its `ld c, 120`: eight columns, each a
## puff over the funnel and sixteen drifts of eight frames scrolling the band
## `SyncScrollWithLY` writes `rSCX` inside, then the erase, the horn and its
## `ld c, 120`. Each drift moves every puff two pixels right; the puffs wear
## `rOBP1` at zero and stand until `wUpdateSpritesEnabled` comes back.
func start_gen1_ss_anne() -> void:
	_ss_anne = {"frame": 0}


func ss_anne_active() -> bool:
	return not _ss_anne.is_empty()


## `rSCX` for lines $50 to $7F this frame, which is the drifts done so far.
func ss_anne_band_offset() -> int:
	if _ss_anne.is_empty():
		return 0
	var frame: int = int(_ss_anne["frame"]) - Gen1Layout.SS_ANNE_LEAD_FRAMES
	var drifting: int = Gen1Layout.SS_ANNE_COLUMNS * Gen1Layout.SS_ANNE_DRIFTS \
		* Gen1Layout.SS_ANNE_DRIFT_FRAMES
	if frame < 0 or frame >= drifting:
		return 0
	return frame / Gen1Layout.SS_ANNE_DRIFT_FRAMES


func _advance_ss_anne() -> void:
	if _ss_anne.is_empty():
		return
	var frame: int = int(_ss_anne["frame"])
	var drifting: int = Gen1Layout.SS_ANNE_COLUMNS * Gen1Layout.SS_ANNE_DRIFTS \
		* Gen1Layout.SS_ANNE_DRIFT_FRAMES
	var total: int = Gen1Layout.SS_ANNE_LEAD_FRAMES + drifting \
		+ Gen1Layout.SS_ANNE_ERASE_FRAMES + Gen1Layout.SS_ANNE_TAIL_FRAMES
	if frame >= total:
		_ss_anne = {}
		return
	_ss_anne["frame"] = frame + 1


## The puffs as [method sprites] records: one per column begun, each drifted
## two pixels for every drift begun since it was emitted, the emitting drift
## included. Gone with the erase, when the sprites come back under `UpdateSprites`.
func _ss_anne_puffs() -> Array:
	var out: Array = []
	if _ss_anne.is_empty():
		return out
	var frame: int = int(_ss_anne["frame"]) - Gen1Layout.SS_ANNE_LEAD_FRAMES
	var column_frames: int = Gen1Layout.SS_ANNE_DRIFTS * Gen1Layout.SS_ANNE_DRIFT_FRAMES
	if frame < 0 or frame >= Gen1Layout.SS_ANNE_COLUMNS * column_frames:
		return out
	var drift: int = frame / Gen1Layout.SS_ANNE_DRIFT_FRAMES
	for column: int in Gen1Layout.SS_ANNE_COLUMNS:
		if column * Gen1Layout.SS_ANNE_DRIFTS > drift:
			break
		var moved: int = drift - column * Gen1Layout.SS_ANNE_DRIFTS + 1
		var pixel: Vector2i = Vector2i(
			Gen1Layout.SS_ANNE_SMOKE_START_X - Gen1Layout.SS_ANNE_SMOKE_STEP * (column + 1)
				+ Gen1Layout.SS_ANNE_SMOKE_DRIFT * moved,
			Gen1Layout.SS_ANNE_SMOKE_Y
		) - OAM_ORIGIN
		out.append({
			"kind": SPRITE_SMOKE, "cell": Vector2i.ZERO, "object_index": -1,
			"screen": true, "palette": OBP_PALETTE, "rotation": 0, "frame": frame,
			"tiles": _smoke_tiles(pixel),
		})
	return out


## `WriteOAMBlock` of one tile four times: the 2x2 at [param pixel].
static func _smoke_tiles(pixel: Vector2i) -> Array:
	var out: Array = []
	for index: int in 4:
		out.append({
			"offset": pixel + Vector2i((index & 1) * 8, (index >> 1) * 8),
			"tile": 0, "flip_x": false,
		})
	return out


## The cells a live effect takes the map's own tiles away from.
## `HideHeadbuttTree` writes the tileset's grass tile over the tree's four
## graphics tiles while the animation runs, which is what stops the tree drawing
## through it.
func hidden_tree_cells() -> Array:
	var out: Array = []
	for sprite: Dictionary in _sprites:
		if StringName(sprite["kind"]) == SPRITE_HEADBUTT_TREE:
			out.append(sprite["cell"])
	return out


## The tile the four hidden ones are replaced with, which the source's own
## comment pins: "Assumes any tileset with headbutt trees has grass at tile $05".
const HEADBUTT_TREE_HIDDEN_TILE: int = 0x05


func snapshot() -> Dictionary:
	return {
		"active": active(),
		"kind": _kind,
		"frame": _frame,
		"duration": _duration,
		"amplitude": _amplitude,
		"offset": offset(),
		"source": _source.duplicate(true),
		"sprites": sprites(),
	}


## One sprite's tiles this frame: [{ offset, tile, flip_x }], where `tile` is an
## index into the sheet the kind names.
func _tiles_for(sprite: Dictionary) -> Array:
	var frame: int = int(sprite["frame"])
	match StringName(sprite["kind"]):
		SPRITE_HEADBUTT_TREE:
			## `.Frameset_HeadbuttTree` is four `oamframe`s of two, which last
			## three frames each: tiles 0-3, tiles 4-7, tiles 0-3, then tiles 4-7
			## with each tile flipped where it stands.
			var step: int = int(float(frame % 12) / 3.0)
			var base: int = 0 if step == 0 or step == 2 else 4
			var flip: bool = step == 3
			var tiles: Array = []
			for index: int in 4:
				tiles.append({
					"offset": Vector2i((index & 1) * 8, (index >> 1) * 8),
					"tile": base + index,
					"flip_x": flip,
				})
			return tiles
		SPRITE_GRASS_RUSTLE:
			## `SetFacingGrassShake` swaps FACING_GRASS_1 and FACING_GRASS_2 on
			## bit 2 of the step frame, so each is up for four frames, and the
			## second sits one pixel down and one out on each side.
			if frame & 4 == 0:
				return [
					{"offset": Vector2i(0, 8), "tile": 0, "flip_x": false},
					{"offset": Vector2i(8, 8), "tile": 0, "flip_x": true},
				]
			return [
				{"offset": Vector2i(-1, 9), "tile": 0, "flip_x": false},
				{"offset": Vector2i(9, 9), "tile": 0, "flip_x": true},
			]
		SPRITE_CUT_TREE:
			## The frameset's own steps, held until the next one starts and gone
			## once `oamdelete` is reached.
			var tree: Array = []
			for step: Array in CUT_TREE_STEPS:
				if frame < int(step[0]):
					break
				tree = step[1]
			var cut: Array = []
			for index: int in tree.size():
				cut.append({"offset": tree[index], "tile": index, "flip_x": false})
			return cut
		SPRITE_CUT_LEAF:
			## `SpriteAnimFunc_CutLeaves`: the leaf sits on a circle whose angle
			## steps by three a frame and whose radius is the high byte of a
			## sixteen-bit accumulator growing by $80, so it widens every second
			## frame. `AnimSeqs_Sine` is the y offset and `AnimSeqs_Cosine` the x.
			var radius: int = (
				CUT_LEAF_RADIUS_BASE + (frame + 1) * CUT_LEAF_RADIUS_STEP
			) >> 8
			var angle: int = (int(sprite["angle"]) + frame * CUT_LEAF_ANGLE_STEP) & 0xFF
			return [{
				"offset": (sprite["origin"] as Vector2i) + CUT_LEAF_OFFSET + Vector2i(
					_signed(_cosine(angle, radius)), _signed(_sine(angle, radius))
				),
				"tile": 0,
				"flip_x": false,
			}]
		SPRITE_SHADOW:
			## `FacingShadow`: one tile drawn twice, the second mirrored.
			var at: Vector2i = SHADOW_OFFSETS[int(sprite.get("direction", 0))]
			return [
				{"offset": at, "tile": 0, "flip_x": false},
				{"offset": at + Vector2i(8, 0), "tile": 0, "flip_x": true},
			]
		SPRITE_HEAL_MACHINE:
			return _heal_machine_tiles(sprite, frame)
		SPRITE_SMOKE:
			## One `Delay3` a step, the block moved before the first.
			var step: int = frame / Gen1Layout.BOULDER_DUST_STEP_FRAMES + 1
			return _smoke_tiles((sprite["pixel"] as Vector2i) + (sprite["drift"] as Vector2i) * step)
		SPRITE_BOULDER_DUST:
			## `SetFacingBoulderDust` swaps FACING_BOULDER_DUST_1 and _2 on bit 1
			## of the step frame, and each draws its one tile four times in a
			## 16x16 square at the direction's own offset.
			var dust_tile: int = 0 if frame & 2 == 0 else 1
			var at: Vector2i = DUST_OFFSETS[int(sprite.get("direction", 0))]
			var dust: Array = []
			for index: int in 4:
				dust.append({
					"offset": at + Vector2i((index & 1) * 8, (index >> 1) * 8),
					"tile": dust_tile,
					"flip_x": false,
				})
			return dust
	return []


func _fly_records(sprite: Dictionary) -> Array:
	var frame: int = int(sprite["frame"])
	var arriving: bool = bool(sprite["arriving"])
	var out: Array = [{
		"kind": SPRITE_FLY_MON,
		"cell": Vector2i.ZERO,
		"object_index": -1,
		"screen": true,
		"palette": PAL_OW_RED,
		"rotation": 0,
		"frame": frame,
		"icon": int(sprite["icon"]),
		"tiles": _fly_mon_tiles(arriving, frame),
	}]
	for spawned: int in range(0, frame + 1, FLY_LEAF_INTERVAL):
		var leaf: Dictionary = _fly_leaf_tile(spawned, frame - spawned)
		if leaf.is_empty():
			continue
		out.append({
			"kind": SPRITE_CUT_LEAF,
			"cell": Vector2i.ZERO,
			"object_index": -1,
			"screen": true,
			"palette": PAL_OW_TREE,
			"rotation": 0,
			"frame": frame - spawned,
			"tiles": [leaf],
		})
	return out


func _fly_mon_tiles(arriving: bool, frame: int) -> Array:
	var at: Vector2i = _fly_mon_pixel(arriving, frame) + Vector2i(-8, -8)
	var step: int = int(float(frame % (FLY_MON_FRAME_LENGTH * 4)) / float(FLY_MON_FRAME_LENGTH))
	var tiles: Array = []
	for index: int in 4:
		tiles.append({
			"offset": at + Vector2i((index & 1) * 8, (index >> 1) * 8),
			"tile": step & 1,
			"flip_x": step == 3,
		})
	return tiles


func _fly_mon_pixel(arriving: bool, frame: int) -> Vector2i:
	var moves: int = _fly_moves(arriving, frame)
	var swing: int = _fly_swing(arriving, moves)
	var swung: int = 0 if moves == 0 else _signed(_cosine((moves - 1) & 0xFF, swing))
	var y: int = FLY_TO_START_Y + 2 * moves if arriving else FLY_MON_Y - 2 * moves
	return Vector2i(FLY_MON_X + swung - 8, (y & 0xFF) - 16)


func _fly_moves(arriving: bool, frame: int) -> int:
	if arriving:
		return mini(frame + 1, ((FLY_MON_Y - FLY_TO_START_Y) & 0xFF) / 2)
	return clampi(frame - FLY_HOLD_FRAMES + 1, 0, FLY_MON_Y / 2)


func _fly_swing(arriving: bool, moves: int) -> int:
	if moves == 0:
		return 0
	if arriving:
		return maxi(FLY_TO_SWING - FLY_TO_SWING_STEP * (moves - 1), 0)
	return mini(FLY_FROM_SWING_STEP * (moves - 1), FLY_FROM_SWING_MAX)


## [param age] is `SpriteAnimFunc_FlyLeaf`'s run count, and `.SpawnLeaf` runs
## behind `DoNextFrameForAllSprites`, so age zero is the frame before its first
## move: nothing is drawn, and the deletion column is the run before this one.
func _fly_leaf_tile(spawned: int, age: int) -> Dictionary:
	if age <= 0 or 2 * (age - 1) >= FLY_LEAF_LIMIT:
		return {}
	var x: int = 2 * age
	var y: int = ((spawned & 0x18) << 1) + 0x40 - age
	var swung: int = _signed(_cosine((age - 1) & 0xFF, FLY_LEAF_SWING))
	return {
		"offset": Vector2i(x + swung - 8, y - 16) + CUT_LEAF_OFFSET,
		"tile": 0,
		"flip_x": false,
	}


## One ball a party member, thirty frames apart, over the machine's own tiles.
## Nothing is taken away again: the flashes run over the finished picture.
## Generation 1 has one machine and one table, so no machine type reaches it and
## none of them may move it.
func _heal_machine_tiles(sprite: Dictionary, frame: int) -> Array:
	var machine_type: int = int(sprite["machine_type"])
	var gen1: bool = int(sprite.get("generation", RomRegistry.GEN2)) == RomRegistry.GEN1
	var shown: int = clampi(
		int(float(frame) / float(HEAL_MACHINE_BALL_FRAMES)) + 1, 0, int(sprite["balls"])
	)
	var entries: Array = []
	if gen1:
		var oam: Array = gen1_heal_machine_oam()
		entries.append(oam[0])
		entries.append_array(oam.slice(1, shown + 1))
	elif machine_type != HEAL_MACHINE_HALL_OF_FAME:
		entries.append_array(HEAL_MACHINE_BAR)
		entries.append_array(HEAL_MACHINE_BALLS.slice(0, shown))
	else:
		entries.append_array(HEAL_MACHINE_HOF_BALLS.slice(0, shown))
	var shift: Vector2i = HEAL_MACHINE_ELMS_LAB_OFFSET \
		if machine_type == HEAL_MACHINE_ELMS_LAB and not gen1 else Vector2i.ZERO
	var machine: Array = []
	for entry: Array in entries:
		machine.append({
			"offset": (entry[0] as Vector2i) + shift,
			"tile": int(entry[1]),
			"flip_x": bool(entry[2]),
		})
	return machine


## `.FlashPalettes` rotates the four colours of the palette left by one and
## `.FlashPalettes8Times` calls it once every ten frames, so a sprite wearing its
## own palette reports which rotation is up. Eight rotations of four leave the
## palette where it started, which is why the animation needs no restore.
func _palette_rotation(sprite: Dictionary) -> int:
	if StringName(sprite["kind"]) == SPRITE_SMOKE:
		## The xor lands before the first `Delay3`, so the first step is flashed.
		var step: int = int(sprite["frame"]) / Gen1Layout.BOULDER_DUST_STEP_FRAMES
		return int(sprite["obp"]) ^ (int(sprite["flash"]) if step % 2 == 0 else 0)
	if StringName(sprite["kind"]) != SPRITE_HEAL_MACHINE:
		return 0
	var flashes_at: int = int(sprite["balls"]) * HEAL_MACHINE_BALL_FRAMES
	var frame: int = int(sprite["frame"])
	if frame < flashes_at:
		return 0
	return (int(float(frame - flashes_at) / float(HEAL_MACHINE_FLASH_INTERVAL)) + 1) & 3


## `BattleAnim_Sine` and `..._Cosine` over `BattleAnimSineWave`, which is what
## `AnimSeqs_Sine` reaches. The table is cartridge data rather than a derivation
## (entry 16 is $0100), so a caller with no cache draws no leaves rather than
## drawing them on a table of its own.
var _sine_table: Gen2BattleAnimData = null


## Hands this the sine table the cut leaves ride on. Called once by the screen
## that owns the effects; nothing else here needs a cache.
func set_sine_table(sine: Gen2BattleAnimData) -> void:
	_sine_table = sine


func _sine(angle: int, amplitude: int) -> int:
	return Gen2BattleAnimFunctions.sine_of(_sine_table, angle, amplitude) \
		if _sine_table != null else 0


func _cosine(angle: int, amplitude: int) -> int:
	return Gen2BattleAnimFunctions.cosine_of(_sine_table, angle, amplitude) \
		if _sine_table != null else 0


## A sprite offset is a byte the cartridge adds; a renderer drawing at a signed
## pixel needs the same byte read as a two's complement offset.
static func _signed(value: int) -> int:
	return RomFile.signed_byte(value)


## The source's DOWN, UP, LEFT, RIGHT order, which is what `.dust_coords` is
## indexed by.
static func _direction_index(direction: Vector2i) -> int:
	if direction == Vector2i.UP:
		return 1
	if direction == Vector2i.LEFT:
		return 2
	if direction == Vector2i.RIGHT:
		return 3
	return 0
