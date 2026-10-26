class_name Gen3ObjectEvents
extends RefCounted

## `event_object_movement.c` in backup coordinates, drawn by [Gen3ObjectSprites]; facility templates remain unmodeled.

const COUNT: int = 16
const TEMPLATES_COUNT: int = 64
const LOCALID_PLAYER: int = 0xFF
const MAP_UNDEFINED: int = 0xFF
const OBJ_KIND_CLONE: int = 255
const OBJ_EVENT_GFX_VARS: int = 240
const VAR_OBJ_GFX_ID_0: int = 0x4010
const VIEW_LEFT: int = 2
const VIEW_RIGHT: int = Gen3MapGrid.OFFSET_W + 2
const VIEW_BOTTOM: int = Gen3MapGrid.OFFSET_H + 2
const ELEVATION_MULTI_LEVEL: int = 15
## Emerald's Pyramid spawns up to COUNT templates before the first empty one; Trainer Hill spawns two.
const PYRAMID_LAYOUTS: Array[int] = [361, 378]
const TRAINER_HILL_LAYOUTS: Array[int] = [415, 416, 417, 418]
const HILL_TRAINERS_PER_FLOOR: int = 2
const EMPTY_TEMPLATE: Dictionary = {
	"local_id": 0, "graphics_id": 0, "kind": 0, "x": 0, "y": 0, "elevation": 0, "movement_type": 0,
	"movement_range_x": 0, "movement_range_y": 0, "trainer_type": 0,
	"trainer_sight_or_berry_tree_id": 0, "script_offset": 0, "flag": 0,
}

enum Collision { NONE, OUTSIDE_RANGE, IMPASSABLE, ELEVATION_MISMATCH, OBJECT_EVENT }
enum Direction { NONE, SOUTH, NORTH, WEST, EAST }
enum Motion {
	FACE, WALK, IN_PLACE, JUMP, DELAY, LOCK, UNLOCK, CONTEXT_FACE, SET_FLAG, EMOTE, REVEAL,
	ANIM, START_ANIM, OBSTACLE, AFFINE, FLY, LEVITATE, FIGURE_8, LOCK_ANIM,
}
enum Facing { PLAYER, AWAY_PLAYER, ORIGINAL }
enum ObjectFlag { LANDING_EFFECT, INVISIBLE, FIXED_PRIORITY, INANIMATE, HIDE_REFLECTION }
enum Jump { FAR, SPECIAL, NORMAL, IN_PLACE, TURN, HOP_IN_PLACE, HOP, ACRO_FAR }
enum Pace { SLOW, NORMAL, FAST, CURRENT, FASTER, SLIDE, FRLG_SLOW, SLOWEST, RUN_SLOW, RUN }
const STEP_PIXELS: Array = [[1, 0], [1], [2], [2, 3, 3, 2, 3, 3], [4], [8], [1, 1, 0],
	[0, 0, 0, 0, 0, 0, 0, 0, 0, 1], [1, 2], [2]]
const STEP_FRAMES: Array[int] = [31, 16, 8, 6, 4, 2, 23, 160, 11, 8]
const JUMP_Y: Array = [
	[-4, -6, -8, -10, -11, -12, -12, -12, -11, -10, -9, -8, -6, -4, 0, 0],
	[0, -2, -3, -4, -5, -6, -6, -6, -5, -5, -4, -3, -2, 0, 0, 0],
	[-2, -4, -6, -8, -9, -10, -10, -10, -9, -8, -6, -5, -3, -2, 0, 0],
]
## `InitJump`'s distance (in place, normal, far) and `sJumpYTable` arc, by jump.
const JUMP_SHAPES: Dictionary = {
	Jump.FAR: {"distance": 2, "arc": 0, "shadow": true},
	Jump.SPECIAL: {"distance": 1, "arc": 0, "special": true},
	Jump.NORMAL: {"distance": 1, "arc": 2, "shadow": true},
	Jump.IN_PLACE: {"distance": 0, "arc": 0, "shadow": true},
	Jump.TURN: {"distance": 0, "arc": 2, "shadow": true, "turn": true},
	Jump.HOP_IN_PLACE: {"distance": 0, "arc": 1, "shadow": true, "wheelie": true},
	Jump.HOP: {"distance": 1, "arc": 1, "shadow": true, "wheelie": true},
	Jump.ACRO_FAR: {"distance": 2, "arc": 0, "shadow": true, "wheelie": true},
}
const FLDEFF_SHADOW: int = 3
const FLDEFF_FIELD_MOVE_SHOW_MON: int = 6
const FLDEFF_SURF_BLOB: int = 8
const FLDEFF_DUST: int = 10
const UNDERWATER_BOB: int = -1
enum Bob { NONE, PLAYER_AND_MON, JUST_MON }
## `surfBlobDirectionAnims`, by movement direction.
const SURF_BLOB_ANIMS: Array[int] = [0, 0, 1, 2, 3, 0, 0, 1, 1]
const FLDEFF_SAND_FOOTPRINTS: int = 13
const FLDEFF_BERRY_TREE_GROWTH_SPARKLE: int = 23
const FLDEFF_DEEP_SAND_FOOTPRINTS: int = 24
const FLDEFF_FEET_IN_FLOWING_WATER: int = 34
const FLDEFF_BIKE_TIRE_TRACKS: int = 35
const FLDEFF_SAND_PILE: int = 39
const FLDEFF_HOT_SPRINGS_WATER: int = 42
const FLDEFF_BUBBLES: int = 53
const LINKED_EFFECTS: Array[int] = [15, FLDEFF_FEET_IN_FLOWING_WATER, FLDEFF_SAND_PILE, FLDEFF_HOT_SPRINGS_WATER]
const TRACK_EFFECTS: Array[int] = [FLDEFF_SAND_FOOTPRINTS, FLDEFF_DEEP_SAND_FOOTPRINTS, FLDEFF_BIKE_TIRE_TRACKS]
## `bikeTireTracks_Transitions`; a step's `SetObjectEventDirection` keeps its row index in range.
const BIKE_TRACK_ANIMS: Array[int] = [1, 2, 7, 8, 1, 2, 6, 5, 5, 8, 3, 4, 6, 7, 3, 4]
enum Tracks { NONE, FOOT, BIKE_TIRE }
## Map effect: y below the cell's corner, priority (-1: the object's), subpriority (-1: one ahead of it).
const MAP_EFFECT_PLACEMENT: Dictionary = {5: [0, 3, 151], 13: [8, 2, 149], 14: [8, -1, 0], 23: [4, -1, -1],
	24: [8, 2, 149], 35: [8, 2, 149], 49: [8, 2, -1], 53: [0, 1, 82]}
const DISPLAY_WIDTH: int = 240
const DISPLAY_HEIGHT: int = 160
const MOVEMENT_TYPE_INVISIBLE: int = 0x4C
const MB_LONG_GRASS: int = 0x03
## The first anim past the face/go rows: the bow, a raised hand, a wheelie, the mount.
const ANIM_STD_COUNT: int = 20
const ANIM_REMOVE_OBSTACLE: int = 1
const ANIM_SHAKE_HEAD: int = 28
## `Get*DirectionAnimNum` rows add these to their first anim; FRLG's spin row differs.
const DIRECTION_ANIM_OFFSETS: Array[int] = [0, 0, 1, 2, 3, 0, 0, 1, 1]
const SPIN_ANIM_OFFSETS: Array[int] = [0, 0, 1, 2, 3, 0, 1, 2, 3]
## South rows of `ANIM_STD_GO_*`, `ANIM_RUN_*`, FRLG's `ANIM_SPIN_*` and `ANIM_MOVING_WHEELIE_*`.
const ANIM_GO: int = 4
const ANIM_RUN: int = ANIM_STD_COUNT
const ANIM_SPIN: int = ANIM_STD_COUNT + 4
const ANIM_PEDAL: int = ANIM_STD_COUNT + 16
## `sDirectionAnimFuncsBySpeed` and the slow walks' `GetMoveDirectionAnimNum`, by [enum Pace].
const PACE_STEP_ANIMS: Array[int] = [ANIM_GO, ANIM_GO, ANIM_GO + 4, ANIM_GO + 4, ANIM_GO + 8,
	ANIM_GO + 12, ANIM_GO, ANIM_GO, ANIM_RUN, ANIM_RUN]
const IN_PLACE_STEP_ANIMS: Dictionary = {32: ANIM_GO, 16: ANIM_GO, 8: ANIM_GO + 4, 4: ANIM_GO + 8}
const OBSTACLE_BLINK_FRAMES: int = 32
## Hoenn's `MOVEMENT_ACTION_START_ANIM_IN_DIRECTION`, which the berry-tree callback runs.
const START_ANIM_IN_DIRECTION: int = 0x39
const LOCALID_NONE: int = 0
## `sFigure8XOffsets`/`sFigure8YOffsets` (`FIGURE_8_LENGTH` 72), walked forward then back.
const FIGURE_8_X: Array[int] = [
	1, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 1, 2, 2, 1, 2, 2, 1, 2, 2, 1, 2, 1, 1,
	2, 1, 1, 2, 1, 1, 2, 1, 1, 2, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
	0, 1, 1, 1, 0, 1, 1, 0, 1, 0, 1, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0,
]
const FIGURE_8_Y: Array[int] = [
	0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 1, 1, 0, 1, 1, 0, 1, 1, 0, 1, 1, 0, 1, 1,
	0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
	0, 0, -1, 0, 0, -1, 0, 0, -1, 0, -1, -1, 0, -1, -1, 0, -1, -1, -1, -1, -1, -1, -1, -2,
]
## `GetObjectEventGraphicsInfo` past the table: Ruby's LITTLE_BOY_1, FRLG's LITTLE_BOY, Emerald's NINJA_BOY.
const GRAPHICS_FALLBACK: Dictionary = {&"ruby": 5, &"sapphire": 5, &"firered": 16, &"leafgreen": 16, &"emerald": 5}
const OBJ_EVENT_GFX_BARD: int = 69
const VAR_FARAWAY_ISLAND_STEP_COUNTER: int = 0x403A
## `trig.c`'s `gSineTable`: sin(i * pi / 128) in Q8.8, truncated; 320 entries, so index + 64 reads the cosine.
static var SINE: PackedInt32Array = _sine_table()
## `MOVEMENT_ACTION_*`: [Hoenn id, FRLG id, motion, parameter].
const MOTION_FAMILIES: Array = [
	[0x00, 0x00, Motion.FACE, 0], [0x04, 0x0C, Motion.WALK, Pace.SLOW],
	[0x08, 0x10, Motion.WALK, Pace.NORMAL], [0x0C, 0x14, Motion.JUMP, Jump.FAR],
	[0x15, 0x1D, Motion.WALK, Pace.FAST], [0x19, 0x21, Motion.IN_PLACE, 32],
	[0x1D, 0x25, Motion.IN_PLACE, 16], [0x21, 0x29, Motion.IN_PLACE, 8],
	[0x25, 0x2D, Motion.IN_PLACE, 4], [0x29, 0x31, Motion.WALK, Pace.CURRENT],
	[0x2D, 0x35, Motion.WALK, Pace.FASTER], [0x31, 0x39, Motion.WALK, Pace.SLIDE],
	[0x35, 0x3D, Motion.WALK, Pace.RUN], [0x3A, 0x46, Motion.JUMP, Jump.SPECIAL],
	[0x42, 0x4E, Motion.JUMP, Jump.NORMAL], [0x46, 0x52, Motion.JUMP, Jump.IN_PLACE],
	[0x4A, 0x56, Motion.JUMP, Jump.TURN],
]
## `MoveNextDirectionInSequence` routes, in movement-type order (0x1D–0x34).
const PATROL_ROUTES: Array = [
	[2, 4, 3, 1],
	[4, 3, 1, 2],
	[1, 2, 4, 3],
	[3, 1, 2, 4],
	[2, 3, 4, 1],
	[3, 4, 1, 2],
	[1, 2, 3, 4],
	[4, 1, 2, 3],
	[3, 2, 1, 4],
	[2, 1, 4, 3],
	[4, 3, 2, 1],
	[1, 4, 3, 2],
	[4, 2, 1, 3],
	[2, 1, 3, 4],
	[3, 4, 2, 1],
	[1, 3, 4, 2],
	[2, 3, 1, 4],
	[1, 4, 2, 3],
	[3, 1, 4, 2],
	[4, 2, 3, 1],
	[2, 4, 1, 3],
	[1, 3, 2, 4],
	[3, 2, 4, 1],
	[4, 1, 3, 2],
]
## `movement_type_func_tables.h`: four-way tables preserve unequal probabilities.
const RANDOM_DIRECTIONS: Dictionary = {
	1: [1, 2, 3, 4], 2: [1, 2, 3, 4], 3: [1, 2], 4: [1, 2], 5: [3, 4], 6: [3, 4],
	0xD: [1, 2], 0xE: [3, 4], 0xF: [2, 3], 0x10: [2, 4], 0x11: [1, 3], 0x12: [1, 4],
	0x13: [2, 1, 3, 1], 0x14: [1, 2, 4, 1], 0x15: [2, 3, 4, 2], 0x16: [3, 4, 1, 1],
}
## `GetCopyDirection` composes the entry-facing and movement-type tables.
const COPY_PLAYER_DIRECTIONS: Array = [[2, 1, 4, 3], [1, 2, 3, 4], [3, 4, 2, 1], [4, 3, 1, 2]]
const COPY_OBJECT_DIRECTIONS: Array = [[2, 1, 4, 3], [1, 2, 3, 4], [4, 3, 1, 2], [3, 4, 2, 1]]
const COPY_ACTIONS: Array[int] = [-1, 0, 0x08, 0x15, 0x2D, 0x31, 0x46, 0x42, 0x0C]
const ROTATION_DIRECTIONS: Array = [[1, 4, 3, 1, 2], [1, 3, 4, 2, 1]]
const MOVEMENT_TYPE_BURIED: int = 0x3F
## `gTrainerFacingDirectionMovementTypes`, by `DIR_*`, diagonals included.
const TRAINER_FACING_TYPES: Array[int] = [8, 8, 7, 9, 10, 8, 8, 7, 7]
const ASH_PUFF: int = 49
const EXCLAMATION_MARK_ICON: int = 0
const ICON_PASSES: int = 61

const STATE_MOTIONS: Array = [
	[0x59, 0x67, Motion.REVEAL, 0],
	[0x3E, 0x4A, Motion.CONTEXT_FACE, Facing.PLAYER],
	[0x3F, 0x4B, Motion.CONTEXT_FACE, Facing.AWAY_PLAYER],
	[0x4E, 0x5A, Motion.CONTEXT_FACE, Facing.ORIGINAL],
	[0x50, 0x5C, Motion.SET_FLAG, ObjectFlag.LANDING_EFFECT, false],
	[0x51, 0x5D, Motion.SET_FLAG, ObjectFlag.LANDING_EFFECT, true],
	[0x54, 0x60, Motion.SET_FLAG, ObjectFlag.INVISIBLE, true],
	[0x55, 0x61, Motion.SET_FLAG, ObjectFlag.INVISIBLE, false],
	[0x5C, 0x6A, Motion.SET_FLAG, ObjectFlag.FIXED_PRIORITY, true],
	[0x5D, 0x6B, Motion.SET_FLAG, ObjectFlag.FIXED_PRIORITY, false],
	[0x52, 0x5E, Motion.SET_FLAG, ObjectFlag.INANIMATE, true],
	[0x53, 0x5F, Motion.SET_FLAG, ObjectFlag.INANIMATE, false],
	[0x5A, 0x68, Motion.OBSTACLE, 0],
	[0x5B, 0x69, Motion.OBSTACLE, 0],
	[0x5E, 0x6C, Motion.AFFINE, 1],
	[0x5F, 0x6D, Motion.AFFINE, 0],
]
## Rows past [constant MOTION_FAMILIES]/[constant STATE_MOTIONS]: [Ruby, Emerald, FRLG id (-1 absent), motion,
## parameter, options]. A `family` is four actions, south to east; an ANIM parameter is its anim, the family's
## first, or -1 for the current one; `step` is a row's first step anim when not its pace's or duration's.
const MORE_ACTIONS: Array = [
	[0x39, 0x39, 0x45, Motion.ANIM, -1, {}],
	[0x4F, 0x4F, 0x5B, Motion.ANIM, ANIM_STD_COUNT, {"direction": Direction.SOUTH}],
	[0x60, 0x62, 0x6E, Motion.WALK, Pace.SLOW, {"direction": Direction.SOUTH, "affine": 0}],
	[0x61, 0x63, 0x6F, Motion.WALK, Pace.SLOW, {"direction": Direction.SOUTH, "affine": 1}],
	[0x62, 0x64, 0x70, Motion.FACE, 0, {"family": true, "step": ANIM_PEDAL}],
	[0x66, 0x68, 0x74, Motion.ANIM, ANIM_STD_COUNT, {"family": true}],
	[0x6A, 0x6C, 0x78, Motion.ANIM, ANIM_STD_COUNT + 8, {"family": true}],
	[0x6E, 0x70, 0x7C, Motion.JUMP, Jump.HOP_IN_PLACE, {"family": true}],
	[0x72, 0x74, 0x80, Motion.JUMP, Jump.HOP, {"family": true}],
	[0x76, 0x78, 0x84, Motion.JUMP, Jump.ACRO_FAR, {"family": true}],
	[0x7A, 0x7C, 0x88, Motion.IN_PLACE, 8, {"family": true, "step": ANIM_PEDAL}],
	[0x7E, 0x80, 0x8C, Motion.WALK, Pace.FAST, {"family": true, "anim": ANIM_STD_COUNT}],
	[0x82, 0x84, 0x90, Motion.WALK, Pace.FAST, {"family": true, "step": ANIM_PEDAL}],
	[0x86, 0x88, -1, Motion.WALK, Pace.FAST, {"family": true, "anim": ANIM_STD_COUNT + 8}],
	[-1, 0x60, -1, Motion.SET_FLAG, ObjectFlag.HIDE_REFLECTION, {"value": true}],
	[-1, 0x61, -1, Motion.SET_FLAG, ObjectFlag.HIDE_REFLECTION, {"value": false}],
	[-1, 0x94, -1, Motion.LOCK_ANIM, 1, {}],
	[-1, 0x95, -1, Motion.LOCK_ANIM, 0, {}],
	[-1, 0x96, -1, Motion.WALK, Pace.FAST, {"direction": Direction.WEST, "affine": 2}],
	[-1, 0x97, -1, Motion.WALK, Pace.FAST, {"direction": Direction.EAST, "affine": 3}],
	[-1, 0x98, -1, Motion.LEVITATE, 0, {}],
	[-1, 0x99, -1, Motion.LEVITATE, 1, {}],
	[-1, 0x9A, -1, Motion.LEVITATE, 2, {}],
	[-1, 0x9B, -1, Motion.FIGURE_8, 0, {}],
	[-1, 0x9C, 0xA4, Motion.FLY, 1, {}],
	[-1, 0x9D, 0xA5, Motion.FLY, 0, {}],
	[-1, -1, 0x04, Motion.FACE, 0, {"family": true, "fast": true}],
	[-1, -1, 0x41, Motion.WALK, Pace.RUN_SLOW, {"family": true}],
	[-1, -1, 0x94, Motion.WALK, Pace.FAST, {"family": true, "step": ANIM_SPIN}],
	[-1, -1, 0x98, Motion.START_ANIM, ANIM_STD_COUNT, {"mode": 0}],
	[-1, -1, 0x99, Motion.START_ANIM, ANIM_STD_COUNT, {"mode": 1}],
	[-1, -1, 0x9A, Motion.START_ANIM, ANIM_STD_COUNT, {"mode": 2}],
	[-1, -1, 0x9B, Motion.WALK, Pace.SLOWEST, {"family": true}],
	[-1, -1, 0x9F, Motion.START_ANIM, ANIM_SHAKE_HEAD, {"mode": 0}],
	[-1, -1, 0xA0, Motion.WALK, Pace.FAST, {"family": true, "glide": true}],
]
## `MovementAction_PauseSpriteAnim` runs every frame while the completed hold remains set.
const PAUSE_AFTER: Array[int] = [Motion.FACE, Motion.WALK, Motion.IN_PLACE, Motion.JUMP, Motion.ANIM, Motion.FIGURE_8]

## `MetatileBehavior_Is*Blocked` by side; Hoenn adds the two-sided rows and the secret base's breakable door.
const BLOCKED_SIDES: Dictionary = {
	Direction.SOUTH: [0x33, 0x36, 0x37], Direction.NORTH: [0x32, 0x34, 0x35],
	Direction.WEST: [0x31, 0x35, 0x37], Direction.EAST: [0x30, 0x34, 0x36],
}
const HOENN_BLOCKED_SIDES: Dictionary = {
	Direction.SOUTH: [0xC0], Direction.NORTH: [0xC0],
	Direction.WEST: [0xC1, 0xBE], Direction.EAST: [0xC1, 0xBE],
}
## `GetOppositeDirection`, diagonals included.
const OPPOSITE: Array[int] = [Direction.NONE, Direction.NORTH, Direction.SOUTH, Direction.EAST, Direction.WEST, 8, 7, 6, 5]
## FRLG's `ShouldInitObjectEventStateFromTemplate` hides CUT_TREE/ROCK_SMASH_ROCK near connections by temp flag.
const FRLG_OBSTACLES: Array[int] = [95, 96]
const FRLG_HIDE_FLAGS: Vector2i = Vector2i(0x11, 0x1F)
## `IsMapTypeOutdoors`: route, town, underwater, city and ocean route.
const OUTDOOR_MAP_TYPES: Array[int] = [3, 1, 5, 2, 6]


class ObjectEvent:
	extends RefCounted
	var active: bool = false
	var is_player: bool = false
	var tracked_by_camera: bool = false
	var graphics_id: int = 0
	var movement_type: int = 0
	var trainer_type: int = 0
	var local_id: int = LOCALID_PLAYER
	var map_number: int = MAP_UNDEFINED
	var map_group: int = MAP_UNDEFINED
	var current_elevation: int = 0
	var previous_elevation: int = 0
	var initial := Vector2i.ZERO
	var current := Vector2i.ZERO
	var previous := Vector2i.ZERO
	var facing: int = 0
	var movement_direction: int = 0
	var movement_range := Vector2i.ZERO
	var trainer_range: int = 0
	var current_behavior: int = 0:
		set(value):
			current_behavior = value & 0xFF
	var previous_behavior: int = 0:
		set(value):
			previous_behavior = value & 0xFF
	var previous_movement_direction: int = 0
	var facing_locked: bool = false
	var invisible: bool = false
	var disable_jump_landing_effect: bool = false
	var fixed_priority: bool = false
	var frozen: bool = false
	var inanimate: bool = false
	var disable_anim: bool = false
	var enable_anim: bool = false
	var hide_reflection: bool = false
	var has_shadow: bool = false
	var has_reflection: bool = false
	var in_short_grass: bool = false
	var in_flowing_water: bool = false
	var in_sand_pile: bool = false
	var in_hot_springs: bool = false
	## The sprite's anims, `x2` (`jump_y` is `y2`) and the pause flags `FreezeObjectEvent` backs up.
	var anim := Gen3SpriteAnim.new()
	var x2: int = 0
	var affine := Gen3AffineAnim.new()
	var affine_anim: int = -1
	var affine_anim_paused: bool = false
	var anim_paused_backup: bool = false
	var affine_anim_paused_backup: bool = false
	var single_movement_active: bool = false
	var held_movement_active: bool = false
	var held_movement_finished: bool = false
	var held_action_done: bool = false
	var buried_initialized: bool = false
	var movement_action: int = -1
	var movement_frame: int = 0
	## `sActionFuncId` and the sprite's `data` an action keeps past the frame count.
	var action_step: int = 0
	var sprite_data := PackedInt32Array([0, 0, 0, 0, 0, 0, 0, 0])
	var levitate_task: Dictionary = {}
	var movement_state: int = 0
	var direction_sequence_index: int = 0
	var movement_delay: int = 0
	var pixel_position := Vector2i.ZERO
	var jump_y: int = 0
	var priority: int = 2
	var subpriority: int = 0
	var subsprite_table: int = 0
	var subsprite_mode: int = Gen3ObjectSprites.Subsprites.OFF
	var palette_num: int = 0
	var off_screen: bool = false
	var sprite_invisible: bool = false
	## `triggerGroundEffectsOnMove`, which the next update's `DoGroundEffects_OnSpawn` consumes.
	var trigger_ground_effects: bool = true
	var player_copyable_movement: int = 0
	var berry_initialized: bool = false
	var berry_sparkling: bool = false
	var berry_just_picked: bool = false
	var disguise_spawned: bool = false
	var disguise_effect_id: int = 0
	## `fieldEffectSpriteId`: the surf blob or underwater bob this object owns.
	var field_effect_sprite: Dictionary = {}
	var disguise_state: int = 0
	var disguise_frame: int = 0
	var disguise_ready: bool = false


var _player_dashing: bool = false
var _player_tile_center: bool = false
var camera: Gen3FieldCamera
var events: Gen3EventData
var sprites: Gen3ObjectSprites
## `FLDEFF_FIELD_MOVE_SHOW_MON`; its task runs from [method Gen3PlayerAvatar.step_movement_tasks].
var field_move_mon: Gen3FieldMoveMon
var cut_grass: Gen3CutGrass
var secret_power: Gen3SecretPower
## Task effects in `sActiveList` until their task calls `FieldEffectActiveListRemove`.
var task_effects: Array[int] = []
var objects: Array[ObjectEvent] = []
## `gSaveBlock1Ptr->objectEventTemplates` for the camera's map.
var templates: Array = []
var _frlg: bool = false
var _ranged := PackedByteArray()
var _facing := PackedByteArray()
var _blocked: Dictionary = {}
var _motions: Dictionary = {}
var _effect_requests: Array = []
## Reveals queued this frame, by slot; [Gen3TrainerSee] takes them before its next task run.
var buried_reveals: Array[int] = []
var _effect_sprites: Array[Dictionary] = []
## Emerald's `GetCurrentMauvilleOldMan`, which picks the bard's graphics.
var mauville_man: int = 0
## Emerald's `sLockedAnimObjectEvents`: `ids` and `count`, null when freed.
var _locked_anims: Variant = null
## `ApplyLevitateMovement` tasks: slot, `data[2]` timer and `data[3]` delta.
var _levitating: Array[Dictionary] = []
var _graphics: Dictionary = {}


## [param palettes] is the field's palette RAM, shared with the background and the weather.
func _init(field_camera: Gen3FieldCamera, event_data: Gen3EventData, palettes: Gen3Palette = null) -> void:
	camera = field_camera
	events = event_data
	if events.berries == null:
		events.berries = Gen3BerryTrees.new(camera.data, events.random)
	var id: StringName = camera.data.id
	_frlg = id in [RomRegistry.FIRERED, RomRegistry.LEAFGREEN]
	for type: int in 256:
		var row: Dictionary = camera.data.world_movement_type(type)
		if row.is_empty():
			break
		_ranged.append(int(row["ranged"]))
		_facing.append(int(row["facing"]))
	for side: int in BLOCKED_SIDES:
		_blocked[side] = BLOCKED_SIDES[side] + ([] if _frlg else HOENN_BLOCKED_SIDES[side])
	_build_motions()
	for slot: int in COUNT:
		objects.append(ObjectEvent.new())
	sprites = Gen3ObjectSprites.new(camera.data, palettes)
	sprites.effects = _effect_sprites
	sprites.init_palettes(0)
	field_move_mon = Gen3FieldMoveMon.new(sprites)
	cut_grass = Gen3CutGrass.new(self)
	secret_power = Gen3SecretPower.new(self)
	load_templates()


## `LoadObjEventTemplatesFromHeader`; FRLG copies a clone's target in, keeping the clone's id, position and kind.
func load_templates() -> void:
	templates.clear()
	for row: Dictionary in camera.data.world_map_events(camera.group, camera.number).get("objects", []):
		if int(row["kind"]) != OBJ_KIND_CLONE:
			templates.append(row.duplicate())
			continue
		var template: Dictionary = _clone_target(row).duplicate()
		template.merge(row, true)
		templates.append(template)


func _clone_target(clone: Dictionary) -> Dictionary:
	var rows: Array = camera.data.world_map_events(int(clone["target_group"]),
		int(clone["target_number"])).get("objects", [])
	return rows[int(clone["target_local_id"]) - 1]


## `UpdateObjectEventsForCameraUpdate`: a crossing loads templates, clears temp data and shifts objects by `gCamera`.
func follow_camera() -> void:
	if camera.crossed:
		load_templates()
		events.clear_temp()
		for object: ObjectEvent in objects:
			if object.active:
				object.initial -= camera.shift
				object.current -= camera.shift
				object.previous -= camera.shift
				object.pixel_position -= camera.shift * 16
	spawn_in_view()
	remove_outside_view()


## `TrySpawnObjectEvents`.
func spawn_in_view() -> void:
	for index: int in _template_count():
		var template: Dictionary = templates[index] if index < templates.size() else EMPTY_TEMPLATE
		var at := Vector2i(int(template["x"]), int(template["y"])) + Vector2i.ONE * Gen3MapGrid.MAP_OFFSET
		if _in_view(at) and not events.flag_get(int(template["flag"])):
			spawn(template, camera.number, camera.group)


func _template_count() -> int:
	if camera.data.id != RomRegistry.EMERALD:
		return templates.size()
	var layout: int = int(camera.header["layout_id"])
	if layout in TRAINER_HILL_LAYOUTS:
		return HILL_TRAINERS_PER_FLOOR
	if layout not in PYRAMID_LAYOUTS:
		return templates.size()
	for index: int in COUNT:
		if index >= templates.size() or int(templates[index]["local_id"]) == 0:
			return index
	return COUNT


func _in_view(at: Vector2i) -> bool:
	return at.x >= camera.pos.x - VIEW_LEFT and at.x <= camera.pos.x + VIEW_RIGHT \
		and at.y >= camera.pos.y and at.y <= camera.pos.y + VIEW_BOTTOM


## `RemoveObjectEventsOutsideView`: retain objects with a current/spawn cell in view.
func remove_outside_view() -> void:
	for object: ObjectEvent in objects:
		if object.active and not object.is_player and not _in_view(object.current) \
				and not _in_view(object.initial):
			_deactivate(object)


## `GetObjectEventGraphicsInfo`: var ids read their var, Emerald's bard the Mauville man, past the table the fallback.
func graphics_info(graphics_id: int) -> Dictionary:
	var id: int = graphics_id & 0xFF
	if id >= OBJ_EVENT_GFX_VARS:
		id = events.var_get(VAR_OBJ_GFX_ID_0 + id - OBJ_EVENT_GFX_VARS) & 0xFF
	var key: int = -1 - mauville_man if camera.data.id == RomRegistry.EMERALD and id == OBJ_EVENT_GFX_BARD else id
	if not _graphics.has(key):
		var info: Dictionary = camera.data.world_object_graphics(mauville_man, true) if key < 0 \
			else camera.data.world_object_graphics(id)
		_graphics[key] = info if not info.is_empty() \
			else camera.data.world_object_graphics(GRAPHICS_FALLBACK.get(camera.data.id, 0))
	return _graphics[key]


## `ObjectEventSetGraphicsId`; the anim and its copied tiles run on, FRLG's same-size reallocation included.
func set_graphics_id(object: ObjectEvent, graphics_id: int) -> void:
	sprites.load_palette(graphics_info(graphics_id), false)
	_take_graphics(object, graphics_id)
	object.pixel_position = object.current * 16


func _take_graphics(object: ObjectEvent, graphics_id: int) -> void:
	var info: Dictionary = graphics_info(graphics_id)
	object.anim.anims = info.get("anims", [])
	object.anim.step_positions = info.get("step_positions", [])
	object.anim.images = info.get("images", [])
	object.inanimate = bool(info.get("inanimate", false))
	object.palette_num = int(info.get("palette_slot", 0))
	object.graphics_id = graphics_id & 0xFF


## `TrySetupObjectEventSprite` after `InitObjectEventStateFromTemplate`.
func _setup_sprite(object: ObjectEvent) -> void:
	var info: Dictionary = graphics_info(object.graphics_id)
	sprites.load_palette(info, true)
	object.affine.anims = info.get("affine_anims", [])
	if object.movement_type == MOVEMENT_TYPE_INVISIBLE:
		object.invisible = true
	object.priority = int(info.get("oam", {}).get("priority", 0))
	object.subsprite_mode = Gen3ObjectSprites.Subsprites.OFF if info.get("subsprite_tables", []).is_empty() \
		else Gen3ObjectSprites.Subsprites.ON
	object.subpriority = Gen3ObjectSprites.subpriority(object, object.previous_elevation, camera.screen_origin(), 1)
	_update_visibility(object)


func _update_visibility(object: ObjectEvent) -> void:
	var info: Dictionary = graphics_info(object.graphics_id)
	var corner: Vector2i = Gen3ObjectSprites.corner(object, info, camera.screen_origin())
	var right: int = wrapi(corner.x + int(info.get("width", 0)), -32768, 32768)
	var bottom: int = wrapi(corner.y + int(info.get("height", 0)), -32768, 32768)
	object.off_screen = corner.x >= DISPLAY_WIDTH + 16 or right < -16 \
		or corner.y >= DISPLAY_HEIGHT + 16 or bottom < -16
	object.sprite_invisible = object.invisible or object.off_screen


## `InitObjectEventStateFromTemplate`: the slot, -1 if out or full; an FRLG clone spawns as its target at its own cell.
func spawn(template: Dictionary, number: int, group: int) -> int:
	var at := Vector2i(int(template["x"]), int(template["y"]))
	var clone: bool = _frlg and int(template["kind"]) == OBJ_KIND_CLONE
	if clone:
		number = int(template["target_number"])
		group = int(template["target_group"])
		template = _clone_target(template)
	var slot: int = _available_slot(int(template["local_id"]), number, group)
	if slot < 0 or (_frlg and not _frlg_should_init(template, clone, at)):
		return -1
	var object := ObjectEvent.new()
	object.active = true
	object.graphics_id = int(template["graphics_id"])
	object.movement_type = int(template["movement_type"])
	object.local_id = int(template["local_id"])
	object.map_number = number
	object.map_group = group
	object.initial = at + Vector2i.ONE * Gen3MapGrid.MAP_OFFSET
	object.current = object.initial
	object.previous = object.initial
	object.pixel_position = object.current * 16
	object.current_elevation = int(template["elevation"]) & 0xF
	object.previous_elevation = object.current_elevation
	object.movement_range = Vector2i(int(template["movement_range_x"]), int(template["movement_range_y"]))
	object.trainer_type = int(template["trainer_type"]) & 0xFF
	object.trainer_range = int(template["trainer_sight_or_berry_tree_id"]) & 0xFF
	set_direction(object, _facing[object.movement_type])
	if object.graphics_id >= OBJ_EVENT_GFX_VARS:
		object.graphics_id = events.var_get(VAR_OBJ_GFX_ID_0 + object.graphics_id - OBJ_EVENT_GFX_VARS) & 0xFF
	if _ranged[object.movement_type]:
		object.movement_range = object.movement_range.max(Vector2i.ONE)
	_take_graphics(object, object.graphics_id)
	if not object.inanimate:
		object.anim.start(DIRECTION_ANIM_OFFSETS[object.facing])
	_setup_sprite(object)
	objects[slot] = object
	return slot


func _available_slot(local_id: int, number: int, group: int) -> int:
	var free: int = -1
	for slot: int in COUNT:
		var object: ObjectEvent = objects[slot]
		if not object.active:
			free = slot if free < 0 else free
		elif object.local_id == local_id and object.map_number == number and object.map_group == group:
			return -1
	return free


## `SetObjectEventDirection`: locked facing still updates previous facing and movement direction.
static func set_direction(object: ObjectEvent, direction: int) -> void:
	object.previous_movement_direction = object.facing
	if not object.facing_locked:
		object.facing = direction
	object.movement_direction = direction


static func turn(object: ObjectEvent, direction: int) -> void:
	set_direction(object, direction)
	if not object.inanimate:
		object.anim.start(DIRECTION_ANIM_OFFSETS[object.facing])
		object.anim.seek(0)


## `GetObjectEventIdByXY` / `GetObjectEventIdByPosition`: current cell; elevation <= 0 matches any.
func at_position(at: Vector2i, elevation: int = -1) -> int:
	for slot: int in COUNT:
		var object: ObjectEvent = objects[slot]
		if object.active and object.current == at and (elevation <= 0
				or object.current_elevation == 0 or object.current_elevation == elevation):
			return slot
	return -1


## `ShouldInitObjectEventStateFromTemplate` tests a clone at its own position, its obstacle check at the target's.
func _frlg_should_init(template: Dictionary, clone: bool, at: Vector2i) -> bool:
	if int(template["graphics_id"]) not in FRLG_OBSTACLES:
		return true
	if clone and not _obstacle_in_view_ok(at):
		return false
	if int(camera.header["map_type"]) not in OUTDOOR_MAP_TYPES:
		return true
	var x: int = int(template["x"])
	var y: int = int(template["y"])
	var last := Vector2i(camera.grid.layout_width - 1, camera.grid.layout_height - 1)
	if (camera.pos.x == 0 and x <= Gen3MapGrid.MAP_OFFSET + 1) \
			or (camera.pos.x == last.x and x >= last.x - (Gen3MapGrid.MAP_OFFSET + 1)) \
			or (camera.pos.y == 0 and y <= Gen3MapGrid.MAP_OFFSET - 1) \
			or (camera.pos.y == last.y and y >= last.y - (Gen3MapGrid.MAP_OFFSET - 1)):
		var flag: int = int(template["flag"])
		if flag >= FRLG_HIDE_FLAGS.x and flag <= FRLG_HIDE_FLAGS.y:
			events.flag_set(flag)
		return false
	return true


## `TemplateIsObstacleAndWithinView` refuses clone obstacles within nine columns/seven rows of the focus.
func _obstacle_in_view_ok(at: Vector2i) -> bool:
	var pos: Vector2i = camera.pos
	if (pos.x < at.x and pos.x + Gen3MapGrid.MAP_OFFSET + 1 < at.x) \
			or (pos.x >= at.x and pos.x - (Gen3MapGrid.MAP_OFFSET + 1) > at.x):
		return true
	return at.y < pos.y - (Gen3MapGrid.MAP_OFFSET - 1) or at.y > pos.y + Gen3MapGrid.MAP_OFFSET - 1


## `GetCollisionAtCoords`: the lowest of [method collision_flags_at]'s collisions; invalid directions refuse.
func collision_at(object: ObjectEvent, x: int, y: int, direction: int) -> int:
	if direction < 1 or direction > 4:
		return Collision.IMPASSABLE
	if _outside_range(object, x, y):
		return Collision.OUTSIDE_RANGE
	if _impassable(object, x, y, direction):
		return Collision.IMPASSABLE
	if _elevation_mismatch(object.current_elevation, x, y):
		return Collision.ELEVATION_MISMATCH
	if _object_at(object, x, y):
		return Collision.OBJECT_EVENT
	return Collision.NONE


## `GetCollisionFlagsAtCoords`: bit `collision - 1` for each one present.
func collision_flags_at(object: ObjectEvent, x: int, y: int, direction: int) -> int:
	if direction < 1 or direction > 4:
		return 1 << (Collision.IMPASSABLE - 1)
	return int(_outside_range(object, x, y)) | int(_impassable(object, x, y, direction)) << 1 \
		| int(_elevation_mismatch(object.current_elevation, x, y)) << 2 | int(_object_at(object, x, y)) << 3


## FRLG's nine-bit behavior narrows at the u8 side predicates.
func _impassable(object: ObjectEvent, x: int, y: int, direction: int) -> bool:
	var grid: Gen3MapGrid = camera.grid
	return grid.collision_at(x, y) != 0 or grid.border_id_at(x, y) == Gen3MapGrid.Connection.INVALID \
		or object.current_behavior in _blocked[direction] \
		or (grid.behavior_at(x, y) & 0xFF) in _blocked[OPPOSITE[direction]] \
		or (object.tracked_by_camera and not camera.can_move(direction))


## `IsCoordOutsideObjectEventMovementRange`; a zero range is unbounded.
func _outside_range(object: ObjectEvent, x: int, y: int) -> bool:
	return (object.movement_range.x != 0 and absi(x - object.initial.x) > object.movement_range.x) \
		or (object.movement_range.y != 0 and absi(y - object.initial.y) > object.movement_range.y)


## `IsElevationMismatchAt`: elevations 0 and 15 match anything.
func _elevation_mismatch(elevation: int, x: int, y: int) -> bool:
	var map_elevation: int = camera.grid.elevation_at(x, y)
	return elevation != 0 and map_elevation != 0 and map_elevation != ELEVATION_MULTI_LEVEL \
		and map_elevation != elevation


## `DoesObjectCollideWithObjectAt`: another active object on or leaving the cell, at a compatible elevation.
func _object_at(object: ObjectEvent, x: int, y: int) -> bool:
	var at := Vector2i(x, y)
	for other: ObjectEvent in objects:
		if other.active and other != object and (other.current == at or other.previous == at) \
				and (object.current_elevation == 0 or other.current_elevation == 0
					or object.current_elevation == other.current_elevation):
			return true
	return false


## `ObjectEventUpdateElevation`: skip multi-level cells; previous elevation skips zero.
func update_elevation(object: ObjectEvent) -> void:
	var elevation: int = camera.grid.elevation_at(object.current.x, object.current.y)
	if elevation == ELEVATION_MULTI_LEVEL \
			or camera.grid.elevation_at(object.previous.x, object.previous.y) == ELEVATION_MULTI_LEVEL:
		return
	object.current_elevation = elevation
	if elevation != 0:
		object.previous_elevation = elevation


func _build_motions() -> void:
	for row: Array in MOTION_FAMILIES:
		var base: int = int(row[1 if _frlg else 0])
		var parameter: int = int(row[3])
		if _frlg and int(row[2]) == Motion.WALK and parameter == Pace.SLOW:
			parameter = Pace.FRLG_SLOW
		for direction: int in range(1, 5):
			_motions[base + direction - 1] = [int(row[2]), direction, parameter]
	for delay: int in 5:
		_motions[(0x18 if _frlg else 0x10) + delay] = [Motion.DELAY, 0, 1 << delay]
	_motions[0x4C if _frlg else 0x40] = [Motion.LOCK, 0, 0]
	_motions[0x4D if _frlg else 0x41] = [Motion.UNLOCK, 0, 0]
	for row: Array in STATE_MOTIONS:
		_motions[int(row[1 if _frlg else 0])] = [int(row[2]), 0, int(row[3])] + row.slice(4)
	var emotes: Array = icon_effects()
	for index: int in emotes.size():
		_motions[(0x62 if _frlg else 0x56) + index] = [Motion.EMOTE, 0, emotes[index]]
	if _frlg:
		for direction: int in range(1, 5):
			_motions[0x08 + direction - 1] = [Motion.WALK, direction, 0]
			_motions[0xA6 + direction - 1] = [Motion.JUMP, direction, Jump.SPECIAL]
	elif camera.data.id == RomRegistry.EMERALD:
		for index: int in 4:
			_motions[0x8C + index] = [Motion.WALK, [7, 8, 5, 6][index], 1]
			_motions[0x90 + index] = [Motion.WALK, [7, 8, 5, 6][index], 0]
	_build_more_motions()


func _build_more_motions() -> void:
	var column: int = 2 if _frlg else (1 if camera.data.id == RomRegistry.EMERALD else 0)
	for row: Array in MORE_ACTIONS:
		var options: Dictionary = row[5]
		if int(row[column]) < 0:
			continue
		if int(row[3]) == Motion.SET_FLAG:
			_motions[int(row[column])] = [Motion.SET_FLAG, 0, int(row[4]), options["value"]]
			continue
		var family: bool = options.get("family", false)
		for direction: int in (range(1, 5) if family else [int(options.get("direction", 0))]):
			_motions[int(row[column]) + (direction - 1 if family else 0)] = [int(row[3]), direction, int(row[4]), options]


static func _sine_table() -> PackedInt32Array:
	var out := PackedInt32Array()
	for index: int in 320:
		out.append(int(sin(index * PI / 128.0) * 256.0))
	return out


## `dirn_to_anim`: a family's action for one direction; past east, its south one.
static func direction_action(base: int, direction: int) -> int:
	return base + (direction - 1 if direction >= Direction.SOUTH and direction <= Direction.EAST else 0)


## `ObjectEventSetHeldMovement`: true refuses; completion does not clear the hold.
func set_held_movement(object: ObjectEvent, action: int) -> bool:
	if not object.active or movement_overridden(object) or not _motions.has(action):
		return true
	_unfreeze(object)
	object.movement_action = action
	object.held_movement_active = true
	object.held_movement_finished = false
	object.held_action_done = false
	object.movement_frame = 0
	object.action_step = 0
	return false


static func held_movement_status(object: ObjectEvent) -> int:
	return int(object.held_movement_finished) if object.held_movement_active else 16


static func clear_held_movement(object: ObjectEvent) -> void:
	object.movement_action = -1
	object.held_movement_active = false
	object.held_movement_finished = false
	object.held_action_done = false
	object.movement_frame = 0
	object.action_step = 0
	object.movement_state = 0


static func clear_held_movement_if_finished(object: ObjectEvent) -> int:
	var status: int = held_movement_status(object)
	if status == 1:
		clear_held_movement(object)
	return status


static func movement_overridden(object: ObjectEvent) -> bool:
	return object.single_movement_active or object.held_movement_active


## `FreezeObjectEvents`/`FreezeObjectEventsExceptOne` skip player and held actions; unfreezing visits every slot.
func freeze_except_player(except_slot: int = -1) -> void:
	for slot: int in COUNT:
		var object: ObjectEvent = objects[slot]
		if slot != except_slot and object.active and not object.is_player \
				and not object.held_movement_active and not object.frozen:
			object.frozen = true
			object.anim_paused_backup = object.anim.paused
			object.affine_anim_paused_backup = object.affine_anim_paused
			object.anim.paused = true
			object.affine_anim_paused = true


func unfreeze_all() -> void:
	for object: ObjectEvent in objects:
		if object.active:
			_unfreeze(object)


static func _unfreeze(object: ObjectEvent) -> void:
	if object.frozen:
		object.frozen = false
		object.anim.paused = object.anim_paused_backup
		object.affine_anim_paused = object.affine_anim_paused_backup


## `RemoveObjectEventByLocalIdAndMap` sets the template's hide flag, the current map's mutable rows first.
func remove(local_id: int, number: int, group: int) -> void:
	var object: ObjectEvent = by_identity(local_id, number, group)
	if object != null:
		events.flag_set(int(template_by_id(local_id, number, group).get("flag", 0)))
		_deactivate(object)


func by_identity(local_id: int, number: int, group: int) -> ObjectEvent:
	for object: ObjectEvent in objects:
		if object.active and object.local_id == local_id and object.map_number == number and object.map_group == group:
			return object
	return null


func berry_tree_sparkling(local_id: int, number: int, group: int) -> bool:
	var object: ObjectEvent = by_identity(local_id, number, group)
	return object != null and object.berry_sparkling


func mark_berry_tree_picked(local_id: int, number: int, group: int) -> void:
	var object: ObjectEvent = by_identity(local_id, number, group)
	if object != null:
		object.berry_just_picked = true


## `SetBerryTreesSeen` uses the inner 15x9 rectangle, not the spawn window.
func allow_seen_berry_growth() -> void:
	if _frlg:
		return
	var top_left: Vector2i = camera.pos + Vector2i(0, 3)
	for object: ObjectEvent in objects:
		var delta: Vector2i = object.current - top_left
		if object.active and object.movement_type == 0xC and delta.x >= 0 and delta.x <= 14 \
				and delta.y >= 0 and delta.y <= 8:
			events.berries.allow_growth(object.trainer_range)


func _deactivate(object: ObjectEvent) -> void:
	object.active = false
	_step_disguise_effect(object, objects.find(object), _effect_requests)


func template_by_id(local_id: int, number: int, group: int) -> Dictionary:
	var rows: Array = templates if number == camera.number and group == camera.group \
		else camera.data.world_map_events(group, number).get("objects", [])
	for row: Dictionary in rows:
		if int(row["local_id"]) == local_id:
			return row
	return {}


## FRLG's `HandleBoulderFallThroughHole`/`ActivateVictoryRoadSwitch`: reveal flags read the template's u16 trainer
## field, not the truncated type; switches ignore elevation and variable gates and visit every row in order.
func boulder_landing(object: ObjectEvent) -> Array:
	var requests: Array = []
	if not _frlg:
		return requests
	var behavior: int = camera.grid.behavior_at(object.current.x, object.current.y)
	if behavior == 0x66:
		var template: Dictionary = template_by_id(object.local_id, camera.number, camera.group)
		remove(object.local_id, camera.number, camera.group)
		events.flag_clear(int(template.get("trainer_type", 0)))
		requests.append({"kind": "sound", "name": "fall"})
	if behavior == 0x20:
		for row: Dictionary in camera.data.world_map_events(camera.group, camera.number).get("coords", []):
			if Vector2i(int(row["x"]), int(row["y"])) + Vector2i.ONE * Gen3MapGrid.MAP_OFFSET == object.current:
				requests.append({"kind": "script", "offset": int(row["script_offset"])})
	return requests


## `UpdateObjectEventCurrentMovement`: holds bypass freezing/collision; running input gates trainer reactions.
## `RunTasks` precedes the objects; each `AnimateSprite` follows its callback.
func step_movements(player_dashing: bool = false, player_tile_center: bool = false) -> Array:
	_player_dashing = player_dashing
	_player_tile_center = player_tile_center
	var requests: Array = _effect_requests.duplicate()
	_effect_requests.clear()
	_run_levitate_tasks()
	for slot: int in COUNT:
		var object: ObjectEvent = objects[slot]
		if not object.active:
			continue
		_init_movement_type(object, slot, requests)
		if object.trigger_ground_effects:
			_ground(object, slot, "spawn", requests)
			object.trigger_ground_effects = false
		if object.enable_anim:
			object.anim.paused = false
			object.disable_anim = false
			object.enable_anim = false
		if object.held_movement_active:
			_step_held(object, slot, requests)
		elif not object.frozen:
			_step_autonomous(object, slot, requests)
		if object.disable_anim:
			object.anim.paused = true
		_update_visibility(object)
		if not object.fixed_priority:
			object.subpriority = Gen3ObjectSprites.subpriority(object, object.previous_elevation, camera.screen_origin(), 1)
		object.anim.animate()
		object.affine.enabled = object.anim.affine
		object.affine.paused = object.affine_anim_paused
		object.affine.animate()
	for slot: int in COUNT:
		_step_disguise_effect(objects[slot], slot, requests)
	_step_effect_sprites(requests)
	requests.append_array(field_move_mon.animate())
	requests.append_array(cut_grass.animate())
	requests.append_array(secret_power.animate())
	sprites.step_reflections(self)
	return requests


## `ObjectEventExecHeldMovementAction` only sets `heldMovementFinished`; finished holds keep their last step.
func _step_held(object: ObjectEvent, slot: int, requests: Array) -> void:
	if not object.held_action_done:
		object.held_action_done = _advance_motion(object, slot, requests)
		object.held_movement_finished = object.held_movement_finished or object.held_action_done
		return
	object.held_movement_finished = true
	var row: Array = _motions[object.movement_action]
	var options: Dictionary = row[3] if row.size() > 3 and row[3] is Dictionary else {}
	if int(row[0]) == Motion.START_ANIM:
		_advance_start_anim(object, int(options["mode"]))
	elif int(row[0]) in PAUSE_AFTER and not options.get("fast", false) and not options.get("glide", false):
		object.anim.paused = true


func _init_movement_type(object: ObjectEvent, slot: int, requests: Array) -> void:
	_init_disguise(object, slot, requests)
	if not _frlg and object.movement_type == 0xC and not object.berry_initialized:
		_set_berry_graphics(object)
		object.berry_initialized = true
	if object.movement_type == MOVEMENT_TYPE_BURIED and not object.buried_initialized:
		object.fixed_priority = true
		object.buried_initialized = true


func start_effect_sprite(object: ObjectEvent, slot: int, effect: int, passes: int, follow: bool,
		requests: Array) -> Dictionary:
	if effect in [ASH_PUFF, FLDEFF_FEET_IN_FLOWING_WATER, FLDEFF_BERRY_TREE_GROWTH_SPARKLE] \
			or Gen3World.MAP_EFFECT_TEMPLATES.has(effect):
		return _start_map_effect(object, slot, effect, requests)
	var request: Dictionary = _effect_request(object, slot, effect)
	var sprite: Dictionary = {"request": request, "passes": 0, "end": passes, "follow": follow}
	if effect == FLDEFF_SHADOW or effect in icon_effects():
		sprite["sprite_slot"] = sprites.effect_slot()
		if int(sprite["sprite_slot"]) < 0:
			return {}
	if effect in icon_effects():
		var info: Dictionary = camera.data.world_icon_graphics(effect)
		var anim := Gen3SpriteAnim.new()
		anim.anims = info.get("anims", [])
		anim.images = info.get("images", [])
		anim.start(int(info.get("anim", 0)))
		sprite.merge({"anim": anim, "y_velocity": -5, "y_offset": 0, "palette": sprites.load_effect_palette(info)})
	if effect == FLDEFF_SHADOW:
		var info: Dictionary = graphics_info(object.graphics_id)
		sprite["shadow_size"] = int(info.get("shadow_size", 0))
		sprite["y_offset"] = (int(info.get("height", 0)) >> 1) - Gen3ObjectSprites.SHADOW_Y_OFFSETS[sprite["shadow_size"]]
	requests.append(request)
	_effect_sprites.append(sprite)
	return sprite


func _start_map_effect(object: ObjectEvent, slot: int, effect: int, requests: Array) -> Dictionary:
	var info: Dictionary = camera.data.world_ash_graphics() if effect == ASH_PUFF else camera.data.world_map_effect_graphics(15 if effect == FLDEFF_FEET_IN_FLOWING_WATER else effect)
	var sprite_slot: int = sprites.effect_slot()
	if info.is_empty() or sprite_slot < 0:
		return {}
	var anim := Gen3SpriteAnim.new()
	anim.anims = info["anims"]
	anim.images = info["images"]
	if effect == FLDEFF_FEET_IN_FLOWING_WATER:
		anim.start(1)
	if effect == FLDEFF_SAND_PILE:
		anim.seek(2)
	var place: Array = MAP_EFFECT_PLACEMENT.get(effect, [12, -1, 0])
	var request: Dictionary = _effect_request(object, slot, effect)
	request["at"] = object.previous if effect in TRACK_EFFECTS else object.current
	var position: Vector2i = camera.sprite_position(request["at"]) + Vector2i(8, int(place[0]))
	if effect == 5:
		position = object.pixel_position + Vector2i(8, 14) - camera.screen_origin() - camera.sprite_coord_offset()
	var sprite: Dictionary = {"request": request, "sprite_slot": sprite_slot, "anim": anim,
		"passes": 0, "end": -1, "follow": effect in LINKED_EFFECTS, "map_effect": true, "info": info,
		"position": Vector2i(wrapi(position.x, -32768, 32768), wrapi(position.y, -32768, 32768)),
		"priority": object.priority if int(place[1]) < 0 else int(place[1]),
		"subpriority": (object.subpriority - 1) & 0xFF if int(place[2]) < 0 else int(place[2]),
		"palette": sprites.load_effect_palette(info)}
	if effect in [10, 14, 16]:
		sprite["elevation"] = object.previous_elevation
	if sprite["follow"]:
		_init_linked_map_effect(object, sprite, requests)
	requests.append(request)
	_effect_sprites.append(sprite)
	return sprite


func _init_linked_map_effect(object: ObjectEvent, sprite: Dictionary, requests: Array) -> void:
	var effect: int = int(sprite["request"]["effect_id"])
	var offset: int = 2 if effect == FLDEFF_SAND_PILE else (8 if effect == FLDEFF_HOT_SPRINGS_WATER else 4)
	sprite["y_offset"] = (int(graphics_info(object.graphics_id).get("height", 0)) >> 1) - offset
	if effect == 15:
		requests.append({"kind": "sound", "name": "puddle"})
	elif effect == FLDEFF_SAND_PILE:
		var position: Vector2i = object.pixel_position + Vector2i(8, 14) - camera.screen_origin() - camera.sprite_coord_offset()
		sprite["last_position"] = Vector2i(wrapi(position.x, -32768, 32768), wrapi(position.y, -32768, 32768))
	else:
		sprite["last_cell"] = Vector2i(-1, -1)


## `FldEff_SurfBlob`: off the active list at once, alive until [method destroy_effect_sprite].
func start_surf_blob(slot: int, at: Vector2i) -> Dictionary:
	var object: ObjectEvent = objects[slot]
	var info: Dictionary = camera.data.world_surf_blob_graphics()
	var sprite_slot: int = sprites.effect_slot()
	if info.is_empty() or sprite_slot < 0:
		return {}
	var anim := Gen3SpriteAnim.new()
	anim.anims = info["anims"]
	anim.images = info["images"]
	var sprite: Dictionary = {"request": _effect_request(object, slot, FLDEFF_SURF_BLOB), "sprite_slot": sprite_slot,
		"anim": anim, "info": info, "map_effect": true, "unlisted": true, "passes": 0, "end": -1, "follow": false,
		"position": camera.sprite_position(at) + Vector2i(8, 8), "priority": object.priority,
		"subpriority": 150, "palette": 0, "bob": Bob.NONE, "velocity": 0 if _frlg else -1, "timer": 0,
		"interval": 0, "last_cell": Vector2i(-1, -1), "y2": 0}
	_effect_sprites.append(sprite)
	return sprite


## `StartUnderwaterSurfBlobBobbing` passes the player's own sprite, so the dummy bobs the player.
func start_underwater_bob(slot: int) -> Dictionary:
	var sprite_slot: int = sprites.effect_slot()
	if sprite_slot < 0:
		return {}
	var sprite: Dictionary = {"request": _effect_request(objects[slot], slot, UNDERWATER_BOB),
		"sprite_slot": sprite_slot, "unlisted": true, "passes": 0, "end": -1, "follow": false, "timer": 0, "bob_y": 1}
	_effect_sprites.append(sprite)
	return sprite


## `DestroySprite`, which frees neither tiles nor palette.
func destroy_effect_sprite(sprite: Dictionary) -> void:
	var index: int = _effect_sprites.find(sprite)
	if index >= 0:
		_effect_sprites.remove_at(index)


## `UpdateSurfBlobFieldEffect`: elevation 3 beside halves the rate; FRLG's starts still, 2nd frames lower the player.
func _update_surf_blob(sprite: Dictionary) -> void:
	var player: ObjectEvent = objects[int(sprite["request"]["object_id"])]
	var anim: Gen3SpriteAnim = sprite["anim"]
	anim.start_if_different(SURF_BLOB_ANIMS[player.movement_direction])
	if int(sprite["y2"]) == 0 and player.current != sprite["last_cell"]:
		sprite["last_cell"] = player.current
		sprite["interval"] = 0
		for direction: int in range(Direction.SOUTH, Direction.EAST + 1):
			var at: Vector2i = player.current + Gen3FieldCamera.DIRECTIONS[direction]
			if camera.grid.elevation_at(at.x, at.y) == 3:
				sprite["interval"] = 1
				break
	if int(sprite["bob"]) != Bob.NONE:
		var timer: int = (int(sprite["timer"]) + 1) & 0xFFFF
		sprite["timer"] = timer
		if timer & ([7, 15] if _frlg else [3, 7])[int(sprite["interval"])] == 0:
			sprite["y2"] = int(sprite["y2"]) + int(sprite["velocity"])
		if timer & (0x1F if _frlg else 0xF) == 0:
			sprite["velocity"] = -int(sprite["velocity"])
		if int(sprite["bob"]) != Bob.JUST_MON:
			player.jump_y = int(sprite["y2"]) + int(_frlg and anim.cmd_index != 0)
			sprite["position"] = linked_sprite_position(player) + Vector2i(0, 8)
	sprite["priority"] = player.priority


func _update_underwater_bob(sprite: Dictionary) -> void:
	var timer: int = int(sprite["timer"])
	if timer & 3 == 0:
		objects[int(sprite["request"]["object_id"])].jump_y += int(sprite["bob_y"])
	sprite["timer"] = (timer + 1) & 0xFFFF
	if int(sprite["timer"]) & 15 == 0:
		sprite["bob_y"] = -int(sprite["bob_y"])


## The sprite's x and y: the object's centre with `coordOffsetEnabled` taken off, as linked effects read it.
func linked_sprite_position(object: ObjectEvent) -> Vector2i:
	var height: int = int(graphics_info(object.graphics_id).get("height", 0))
	var linked: Vector2i = object.pixel_position + Vector2i(8, 16 - (height >> 1)) \
		- camera.screen_origin() - camera.sprite_coord_offset()
	return Vector2i(wrapi(linked.x, -32768, 32768), wrapi(linked.y, -32768, 32768))


func icon_effects() -> Array:
	return [0, 33, 46, 66, 64] if _frlg else [0, 33, 46]


func field_effect_active(effect: int) -> bool:
	if effect == FLDEFF_FIELD_MOVE_SHOW_MON:
		return field_move_mon.active
	if effect == Gen3CutGrass.FLDEFF_CUT_GRASS:
		return cut_grass.active
	if secret_power.active and effect == int(secret_power.sprite["effect"]):
		return true
	if effect in task_effects:
		return true
	return _effect_sprites.any(func(sprite: Dictionary) -> bool:
		return sprite["request"]["effect_id"] == effect and not sprite.get("unlisted", false))


func _step_effect_sprites(requests: Array) -> void:
	for sprite: Dictionary in _effect_sprites.duplicate():
		var request: Dictionary = sprite["request"]
		var object: ObjectEvent = by_identity(int(request["local_id"]), int(request["map_number"]), int(request["map_group"]))
		var shadow: bool = int(request["effect_id"]) == FLDEFF_SHADOW
		if (_grass_finished(sprite, object) if sprite.get("grass", false) else _effect_finished(sprite, object)) \
				or (sprite["follow"] and object == null) or (shadow and not _shadow_allowed(object)):
			var stop: Dictionary = request.duplicate()
			stop["kind"] = "stop_field_effect"
			requests.append(stop)
			_effect_sprites.remove_at(_effect_sprites.find(sprite))
			if sprite.has("anim"):
				sprites.free_effect_palette(sprite)
		else:
			if int(request["effect_id"]) == FLDEFF_SURF_BLOB:
				_update_surf_blob(sprite)
			elif int(request["effect_id"]) == UNDERWATER_BOB:
				_update_underwater_bob(sprite)
			elif sprite.get("grass", false) or sprite.get("map_effect", false):
				sprites.update_field_effect(self, sprite)
			if int(request["effect_id"]) == FLDEFF_FEET_IN_FLOWING_WATER and sprite["last_cell"] != object.current:
				sprite["last_cell"] = object.current
				if not sprite.get("invisible", false):
					requests.append({"kind": "sound", "name": "puddle"})
			if sprite.has("y_velocity"):
				sprite["y_offset"] += sprite["y_velocity"]
				sprite["y_velocity"] = int(sprite["y_velocity"]) + 1 if sprite["y_offset"] != 0 else 0
			if sprite.has("anim"):
				(sprite["anim"] as Gen3SpriteAnim).animate()
			sprite["passes"] = int(sprite["passes"]) + 1


func _effect_finished(sprite: Dictionary, object: ObjectEvent) -> bool:
	if sprite.get("unlisted", false):
		return false
	if int(sprite["request"]["effect_id"]) in TRACK_EFFECTS:
		return _fade_tracks(sprite)
	if int(sprite["request"]["effect_id"]) == FLDEFF_BUBBLES and sprites.field_effect_off_screen(self, sprite):
		return true
	if int(sprite["request"]["effect_id"]) == FLDEFF_FEET_IN_FLOWING_WATER:
		return object == null or not object.in_flowing_water
	if int(sprite["request"]["effect_id"]) == FLDEFF_SAND_PILE:
		return object == null or not object.in_sand_pile
	if int(sprite["request"]["effect_id"]) == FLDEFF_HOT_SPRINGS_WATER:
		return object == null or not object.in_hot_springs
	if sprite.has("anim") and not (sprite["anim"] as Gen3SpriteAnim).anims.is_empty():
		return (sprite["anim"] as Gen3SpriteAnim).ended
	return int(sprite["end"]) >= 0 and int(sprite["passes"]) >= int(sprite["end"])


func _fade_tracks(sprite: Dictionary) -> bool:
	var timer: int = int(sprite.get("timer", 0)) + 1
	sprite["timer"] = timer
	if not sprite.get("blinking", false):
		sprite["blinking"] = timer > 40
		sprite["invisible"] = false
		return false
	sprite["invisible"] = not sprite.get("invisible", false)
	return timer > 56


func shadow_sprites() -> Array[Dictionary]:
	return _effect_sprites.filter(func(sprite: Dictionary) -> bool:
		return int(sprite["request"]["effect_id"]) == FLDEFF_SHADOW)


## `UpdateShadowFieldEffect`: grass tests only the current cell; water and reflections test both.
func _shadow_allowed(object: ObjectEvent) -> bool:
	if object == null or not object.has_shadow:
		return false
	var grass: Array = [2, 0xD1] if _frlg else [2, 3]
	return object.current_behavior not in grass and reflection_type(object.current_behavior, _frlg) == 0 \
		and reflection_type(object.previous_behavior, _frlg) == 0 and not camera.data.world_surfable(object.current_behavior) \
		and not camera.data.world_surfable(object.previous_behavior)


static func set_trainer_movement_type(object: ObjectEvent, type: int) -> void:
	object.movement_type = type
	object.direction_sequence_index = 0
	object.player_copyable_movement = 0
	object.movement_state = 0


## `OverrideMovementTypeForObjectEvent` (Emerald's `TryOverrideTemplateCoordsForObjectEvent`) and
## `OverrideTemplateCoordsForObjectEvent` write the current map's saved template.
func override_template_movement_type(object: ObjectEvent, type: int) -> void:
	var template: Dictionary = _base_template(object)
	if not template.is_empty():
		template["movement_type"] = type


func override_template_coords(object: ObjectEvent) -> void:
	var template: Dictionary = _base_template(object)
	if not template.is_empty():
		template["x"] = object.current.x - Gen3MapGrid.MAP_OFFSET
		template["y"] = object.current.y - Gen3MapGrid.MAP_OFFSET


func _base_template(object: ObjectEvent) -> Dictionary:
	if object.map_number != camera.number or object.map_group != camera.group:
		return {}
	for template: Dictionary in templates:
		if int(template["local_id"]) == object.local_id:
			return template
	return {}


func _advance_motion(object: ObjectEvent, slot: int, requests: Array) -> bool:
	var row: Array = _motions[object.movement_action]
	var motion: int = int(row[0])
	var parameter: int = int(row[2])
	var options: Dictionary = row[3] if row.size() > 3 and row[3] is Dictionary else {}
	if object.movement_frame == 0:
		_start_motion(object, row, options, slot, requests)
		_start_state_motion(object, row, slot, requests)
	match motion:
		Motion.REVEAL:
			if object.movement_type == MOVEMENT_TYPE_BURIED:
				return false
			object.movement_frame += 1
			return object.movement_type not in [0x39, 0x3A] or update_reveal_disguise(object)
		Motion.WALK:
			return _advance_walk(object, int(row[1]), parameter, options, slot, requests)
		Motion.JUMP:
			return _advance_jump(object, parameter, slot, requests)
		Motion.IN_PLACE:
			return _advance_in_place(object, parameter)
		Motion.DELAY:
			object.movement_frame += 1
			return object.movement_frame == parameter
		Motion.ANIM:
			object.movement_frame += 1
			return object.movement_frame > 1 and object.anim.ended
		Motion.START_ANIM:
			object.movement_frame += 1
			return object.movement_frame > 1 and _advance_start_anim(object, int(options["mode"]))
		Motion.OBSTACLE, Motion.FLY:
			object.movement_frame += 1
			return _advance_obstacle(object) if motion == Motion.OBSTACLE else _advance_fly(object, parameter)
		Motion.FIGURE_8:
			object.movement_frame += 1
			return _advance_figure_8(object, slot, requests)
		Motion.LEVITATE:
			return _levitate(object, slot, parameter)
	return true


## `MovementAction_WalkInPlaceSlow_Step1` adds a delay frame while its count is odd.
func _advance_in_place(object: ObjectEvent, duration: int) -> bool:
	if duration == 32 and (duration - object.movement_frame) & 1:
		object.anim.delay = (object.anim.delay + 1) & 0x3F
	object.movement_frame += 1
	if object.movement_frame != duration:
		return false
	object.anim.paused = true
	return true


func _start_motion(object: ObjectEvent, row: Array, options: Dictionary, slot: int, requests: Array) -> void:
	var motion: int = int(row[0])
	var direction: int = int(row[1])
	if motion == Motion.FACE and options.get("fast", false) or options.get("glide", false):
		if object.facing != direction:
			object.anim.start(DIRECTION_ANIM_OFFSETS[direction])
		if options.get("fast", false):
			object.anim.animate()
	if direction != 0 and motion != Motion.ANIM:
		set_direction(object, direction)
	match motion:
		Motion.FACE:
			_shift_coords(object, object.current)
			object.anim.paused = not options.get("fast", false)
		Motion.WALK:
			_start_walk(object, direction, int(row[2]), options, slot, requests)
		Motion.JUMP:
			_start_jump(object, direction, JUMP_SHAPES[int(row[2])], slot, requests)
		Motion.IN_PLACE:
			object.anim.paused = false
		Motion.LOCK:
			object.facing_locked = true
		Motion.UNLOCK:
			object.facing_locked = false
		Motion.ANIM:
			_start_anim_in_direction(object, direction, int(row[2]), options)
		Motion.START_ANIM:
			object.anim.start(int(row[2]))
			object.anim.paused = false
			object.disable_anim = false
			for index: int in range(4, 8):
				object.sprite_data[index] = 0
	_start_step_anim(object, motion, direction, int(row[2]), options)


## In place and the wheelie face step on the action's direction, the rest on the facing.
func _start_step_anim(object: ObjectEvent, motion: int, direction: int, parameter: int, options: Dictionary) -> void:
	var anim: int = -1
	var facing: int = object.facing
	match motion:
		Motion.FACE:
			if not options.get("fast", false):
				anim = int(options.get("step", ANIM_GO))
				_set_step_anim(object, anim + DIRECTION_ANIM_OFFSETS[direction if anim == ANIM_PEDAL else facing])
			return
		Motion.WALK:
			if not options.has("anim") and not options.get("glide", false):
				anim = int(options.get("step", PACE_STEP_ANIMS[parameter]))
		Motion.JUMP:
			if not JUMP_SHAPES[parameter].has("special") and not JUMP_SHAPES[parameter].has("wheelie"):
				anim = ANIM_GO
		Motion.IN_PLACE:
			anim = int(options.get("step", IN_PLACE_STEP_ANIMS[parameter]))
			facing = direction
	if anim < 0:
		return
	_set_step_anim_alternating(object, anim + (SPIN_ANIM_OFFSETS if anim == ANIM_SPIN else DIRECTION_ANIM_OFFSETS)[facing])
	if anim == ANIM_SPIN:
		object.anim.seek(0)


static func _set_step_anim(object: ObjectEvent, number: int) -> void:
	if object.inanimate:
		return
	var sprite: Gen3SpriteAnim = object.anim
	sprite.anim_num = number & 0xFF
	var positions: Array = sprite.step_positions
	if not positions.is_empty():
		sprite.seek(int(positions[0]) if sprite.cmd_index <= int(positions[0]) else int(positions[1]))


static func _set_step_anim_alternating(object: ObjectEvent, number: int) -> void:
	if object.inanimate:
		return
	var sprite: Gen3SpriteAnim = object.anim
	sprite.anim_num = number & 0xFF
	var index: int = sprite.cmd_index
	var positions: Array = sprite.step_positions
	if not positions.is_empty():
		if index == int(positions[0]):
			index = int(positions[3])
		elif index == int(positions[1]):
			index = int(positions[2])
	sprite.seek(index)


func _start_state_motion(object: ObjectEvent, row: Array, slot: int, requests: Array) -> void:
	match int(row[0]):
		Motion.CONTEXT_FACE:
			var direction: int = _context_facing(object, int(row[2]))
			if direction >= 0:
				set_direction(object, direction)
				_shift_coords(object, object.current)
				_set_step_anim(object, ANIM_GO + DIRECTION_ANIM_OFFSETS[object.facing])
				object.anim.paused = true
		Motion.SET_FLAG:
			_set_flag(object, int(row[2]), bool(row[3]))
		Motion.EMOTE:
			start_effect_sprite(object, slot, int(row[2]), ICON_PASSES, true, requests)
		Motion.REVEAL:
			if object.movement_type in [0x39, 0x3A]:
				start_reveal_disguise(object)
			elif object.movement_type == MOVEMENT_TYPE_BURIED:
				buried_reveals.append(slot)
		Motion.AFFINE:
			object.anim.affine = int(row[2]) == 1
			object.affine_anim = 0 if object.anim.affine else -1
			object.affine_anim_paused = object.anim.affine
			if object.anim.affine:
				object.affine.start(0)
				object.subsprite_mode = Gen3ObjectSprites.Subsprites.OFF
		Motion.LOCK_ANIM:
			if int(row[2]) == 1:
				_lock_anim(object)
			else:
				_unlock_anim(object)


func _set_flag(object: ObjectEvent, flag: int, value: bool) -> void:
	match flag:
		ObjectFlag.LANDING_EFFECT:
			object.disable_jump_landing_effect = value
		ObjectFlag.INVISIBLE:
			object.invisible = value
		ObjectFlag.FIXED_PRIORITY:
			object.fixed_priority = value
		ObjectFlag.INANIMATE:
			object.inanimate = value or bool(graphics_info(object.graphics_id).get("inanimate", false))
		ObjectFlag.HIDE_REFLECTION:
			object.hide_reflection = value


## `InitNpcForMovement` and its slow siblings; Emerald pauses an anim-locked object's anim. The Acro Bike's
## pop and end rows start their anim on the new facing.
func _start_walk(object: ObjectEvent, direction: int, pace: int, options: Dictionary,
		slot: int, requests: Array) -> void:
	_shift_coords(object, object.current + Gen3FieldCamera.DIRECTIONS[direction])
	object.anim.paused = pace != Pace.SLOW and _locked_anim_index(object) >= 0
	if options.has("anim"):
		object.anim.start(int(options["anim"]) + DIRECTION_ANIM_OFFSETS[object.facing])
		object.anim.seek(0)
	if options.has("affine"):
		object.affine_anim_paused = false
		var number: int = int(options["affine"])
		if object.affine_anim != number:
			if number == 0:
				object.affine.start(number)
			else:
				object.affine.change(number)
		object.affine_anim = number
	_ground(object, slot, "begin_step", requests)


func _advance_walk(object: ObjectEvent, direction: int, pace: int, options: Dictionary,
		slot: int, requests: Array) -> bool:
	if options.get("glide", false):
		object.anim.animate()
	var pixels: Array = STEP_PIXELS[pace]
	object.pixel_position += Gen3FieldCamera.DIRECTIONS[direction] * int(pixels[object.movement_frame % pixels.size()])
	object.movement_frame += 1
	if object.movement_frame != STEP_FRAMES[pace]:
		return false
	_finish_motion(object, slot, requests)
	object.anim.paused = object.anim.paused or not options.get("glide", false)
	if options.has("affine"):
		object.affine_anim_paused = true
	return true


## `StartSpriteAnimInDirection`; `MOVEMENT_ACTION_START_ANIM_IN_DIRECTION` restarts the current anim on its movement.
func _start_anim_in_direction(object: ObjectEvent, direction: int, anim: int, options: Dictionary) -> void:
	if direction == 0:
		direction = object.movement_direction
	if anim < 0:
		anim = object.anim.anim_num
	elif options.get("family", false):
		anim += DIRECTION_ANIM_OFFSETS[direction]
	object.anim.set_and_start(anim, 0)
	set_direction(object, direction)


## FRLG's `MovementAction_RaiseHand*_Step1`, head shake: end with the anim, hop twice, hold 81, or sway once.
func _advance_start_anim(object: ObjectEvent, mode: int) -> bool:
	var data: PackedInt32Array = object.sprite_data
	if mode == 2:
		data[7] = (data[7] + 4) & 0xFF
		object.x2 = SINE[data[7]] >> 7
		return data[7] == 0
	if mode == 0:
		return object.anim.ended
	match data[7]:
		0:
			data[6] += 10
			if data[6] > 127:
				data[6] = 0
				data[5] += 1
				data[7] = data[5]
				_restart_anim(object, 0)
			object.jump_y = -(3 * SINE[data[6]] >> 7)
			object.single_movement_active = object.jump_y != 0
		1:
			data[4] += 1
			if data[4] > 16:
				data[4] = 0
				_restart_anim(object, ANIM_STD_COUNT)
				data[7] = 0
			else:
				object.single_movement_active = false
		2:
			object.single_movement_active = false
			data[4] += 1
			if data[4] > 80:
				data[4] = 0
				return true
	return false


static func _restart_anim(object: ObjectEvent, anim: int) -> void:
	object.anim.start(anim)
	object.anim.paused = false
	object.disable_anim = false


## Rock Smash and Cut: the obstacle's anim, then 32 blinking frames, then invisible.
func _advance_obstacle(object: ObjectEvent) -> bool:
	match object.action_step:
		0:
			object.anim.set_and_start(ANIM_REMOVE_OBSTACLE, 0)
			object.action_step = 1
		1:
			if object.anim.ended:
				object.sprite_data[3] = OBSTACLE_BLINK_FRAMES
				object.action_step = 2
		2:
			object.invisible = not object.invisible
			object.sprite_data[3] -= 1
			if object.sprite_data[3] == 0:
				object.invisible = true
				object.action_step = 3
		3:
			return true
	return false


## `MovementAction_FlyUp`/`FlyDown` move `y2` eight pixels a frame over the screen height.
func _advance_fly(object: ObjectEvent, up: int) -> bool:
	match object.action_step:
		0:
			object.jump_y = 0 if up == 1 else -DISPLAY_HEIGHT
			object.action_step = 1
		1:
			object.jump_y += -8 if up == 1 else 8
			if object.jump_y == (-DISPLAY_HEIGHT if up == 1 else 0):
				object.action_step = 2
		2:
			return true
	return false


## `AnimateSpriteInFigure8`: four quarter loops over the offset tables.
func _advance_figure_8(object: ObjectEvent, slot: int, requests: Array) -> bool:
	var data: PackedInt32Array = object.sprite_data
	if object.movement_frame == 1:
		data[6] = 0
		data[7] = 0
		object.anim.paused = false
	var index: int = data[6] if data[7] % 2 == 0 else FIGURE_8_X.size() - 1 - data[6]
	object.x2 += FIGURE_8_X[index] * (1 if data[7] in [0, 3] else -1)
	object.jump_y += FIGURE_8_Y[index]
	data[6] += 1
	if data[6] == FIGURE_8_X.size():
		data[6] = 0
		data[7] += 1
	if data[7] != 4:
		return false
	object.x2 = 0
	object.jump_y = 0
	_finish_motion(object, slot, requests)
	object.anim.paused = true
	return true


## Emerald's levitate task: start, stop, or stop once `y2` is back at 0.
func _levitate(object: ObjectEvent, slot: int, mode: int) -> bool:
	if mode == 0:
		object.levitate_task = {"slot": slot, "timer": 0, "delta": -1}
		_levitating.append(object.levitate_task)
		return true
	if mode == 2 and object.jump_y != 0:
		return false
	_levitating.erase(object.levitate_task)
	if mode == 1:
		object.jump_y = 0
	return true


## `ApplyLevitateMovement`: `y2` moves one pixel every fourth frame and turns every sixteenth.
func _run_levitate_tasks() -> void:
	for task: Dictionary in _levitating:
		var object: ObjectEvent = objects[int(task["slot"])]
		if int(task["timer"]) & 3 == 0:
			object.jump_y += int(task["delta"])
		if int(task["timer"]) & 15 == 0:
			task["delta"] = -int(task["delta"])
		task["timer"] = (int(task["timer"]) + 1) & 0xFFFF


## `MovementAction_LockAnim_Step0`/`UnlockAnim_Step0`: 16 ids, a new one in the first free slot, repeats ignored.
func _lock_anim(object: ObjectEvent) -> void:
	if _locked_anims == null:
		var ids := PackedInt32Array()
		ids.resize(COUNT)
		ids[0] = object.local_id
		_locked_anims = {"ids": ids, "count": 1}
	elif _locked_anim_index(object) < 0:
		var free: int = (_locked_anims["ids"] as PackedInt32Array).find(LOCALID_NONE)
		if free < 0:
			return
		_locked_anims["ids"][free] = object.local_id
		_locked_anims["count"] += 1
	else:
		return
	object.inanimate = true
	object.facing_locked = true


func _unlock_anim(object: ObjectEvent) -> void:
	if _locked_anims == null:
		return
	var index: int = _locked_anim_index(object)
	if index >= 0:
		_locked_anims["ids"][index] = LOCALID_NONE
		_locked_anims["count"] -= 1
	if int(_locked_anims["count"]) == 0:
		_locked_anims = null
	if index >= 0:
		object.inanimate = bool(graphics_info(object.graphics_id).get("inanimate", false))
		object.facing_locked = false
		object.anim.paused = false


func _locked_anim_index(object: ObjectEvent) -> int:
	return -1 if _locked_anims == null else (_locked_anims["ids"] as PackedInt32Array).find(object.local_id)


static func _effect_request(object: ObjectEvent, slot: int, effect: int, kind: String = "field_effect") -> Dictionary:
	return {"kind": kind, "effect_id": effect, "object_id": slot,
		"local_id": object.local_id, "map_number": object.map_number, "map_group": object.map_group}


func _init_disguise(object: ObjectEvent, slot: int, requests: Array) -> void:
	if object.movement_type not in [0x39, 0x3A]:
		return
	if object.direction_sequence_index == 0 or (object.direction_sequence_index == 1 and not object.disguise_spawned):
		object.disguise_spawned = true
		object.direction_sequence_index = 1
		object.disguise_effect_id = object.movement_type - 0x1D
		object.disguise_state = 0
		object.disguise_frame = 0
		object.disguise_ready = false
		requests.append(_effect_request(object, slot, object.disguise_effect_id))


## Trainer approach also calls `StartRevealDisguise`/`UpdateRevealDisguise`.
static func start_reveal_disguise(object: ObjectEvent) -> void:
	if object.direction_sequence_index == 1:
		object.disguise_state += 1


static func update_reveal_disguise(object: ObjectEvent) -> bool:
	if object.direction_sequence_index in [0, 2]:
		return true
	if object.disguise_ready:
		object.direction_sequence_index = 2
		object.disguise_state += 1
		return true
	return false


## Disguise callback precedes animation: seven four-frame images, END, then readiness on the next callback.
func _step_disguise_effect(object: ObjectEvent, slot: int, requests: Array) -> void:
	if not object.disguise_spawned:
		return
	if not object.active or object.disguise_state == 3:
		requests.append(_effect_request(object, slot, object.disguise_effect_id, "stop_field_effect"))
		object.disguise_spawned = false
		return
	if object.disguise_state == 1:
		object.disguise_state = 2
		object.disguise_frame = 0
	if object.disguise_state == 2:
		object.disguise_ready = object.disguise_frame > 28
		object.disguise_frame = mini(object.disguise_frame + 1, 30)


## `GetDirectionToFace` prefers x; an absent local-ID player leaves coords.
func _context_facing(object: ObjectEvent, mode: int) -> int:
	if mode == Facing.ORIGINAL:
		return _facing[object.movement_type]
	var player: ObjectEvent = _player_event()
	if player == null:
		return -1
	var direction: int = Direction.SOUTH
	if object.current.x != player.current.x:
		direction = Direction.WEST if object.current.x > player.current.x else Direction.EAST
	elif object.current.y > player.current.y:
		direction = Direction.NORTH
	return OPPOSITE[direction] if mode == Facing.AWAY_PLAYER else direction


## `InitJump` and `DoShadowFieldEffect`; the special jump and wheelie hops start anims.
func _start_jump(object: ObjectEvent, direction: int, shape: Dictionary, slot: int, requests: Array) -> void:
	_shift_coords(object, object.current + Gen3FieldCamera.DIRECTIONS[direction] * mini(int(shape["distance"]), 1))
	object.anim.paused = false
	if shape.get("special", false):
		object.anim.start(ANIM_STD_COUNT + DIRECTION_ANIM_OFFSETS[direction])
	elif shape.get("wheelie", false):
		object.anim.start_if_different(ANIM_STD_COUNT + DIRECTION_ANIM_OFFSETS[direction])
	if shape.get("shadow", false) and not object.has_shadow:
		object.has_shadow = true
		start_effect_sprite(object, slot, FLDEFF_SHADOW, -1, true, requests)
	_ground(object, slot, "begin_step", requests, false)


## `DoJumpSpriteMovement`: the special jump runs at half speed; a far jump moves its cell at halfway.
func _advance_jump(object: ObjectEvent, parameter: int, slot: int, requests: Array) -> bool:
	var shape: Dictionary = JUMP_SHAPES[parameter]
	var distance: int = int(shape["distance"])
	var special: bool = shape.get("special", false)
	var duration: int = (32 if distance == 2 else 16) << int(special)
	var shift: int = int(distance == 2) + int(special)
	if distance != 0 and (not special or object.movement_frame % 2 == 0):
		object.pixel_position += Gen3FieldCamera.DIRECTIONS[object.movement_direction]
	object.jump_y = int(JUMP_Y[int(shape["arc"])][object.movement_frame >> shift])
	object.movement_frame += 1
	if object.movement_frame == duration / 2:
		if distance == 2:
			_shift_coords(object, object.current + Gen3FieldCamera.DIRECTIONS[object.movement_direction])
			_ground(object, slot, "begin_step", requests, false)
		elif shape.get("turn", false):
			set_direction(object, OPPOSITE[object.movement_direction])
			_set_step_anim(object, ANIM_GO + DIRECTION_ANIM_OFFSETS[object.facing])
	if object.movement_frame != duration:
		return false
	object.jump_y = 0
	_finish_motion(object, slot, requests, not special and not object.disable_jump_landing_effect)
	object.has_shadow = object.has_shadow and special
	return true


func _finish_motion(object: ObjectEvent, slot: int, requests: Array, landing: bool = false) -> void:
	_shift_coords(object, object.current)
	_ground(object, slot, "finish_step", requests, true, landing)


static func _shift_coords(object: ObjectEvent, at: Vector2i) -> void:
	object.previous = object.current
	object.current = Vector2i(wrapi(at.x, -32768, 32768), wrapi(at.y, -32768, 32768))


## `DoGroundEffects_*`; a jump's start and halfway shift set `disableCoveringGroundEffects` ([param covering]).
func _ground(object: ObjectEvent, slot: int, kind: String, requests: Array, covering: bool = true,
		landing: bool = false) -> void:
	if not object.fixed_priority:
		update_elevation(object)
		object.subsprite_table = Gen3ObjectSprites.ELEVATION_SUBSPRITE_TABLE[object.previous_elevation]
		object.priority = Gen3ObjectSprites.ELEVATION_PRIORITY[object.previous_elevation]
	object.current_behavior = camera.grid.behavior_at(object.current.x, object.current.y)
	object.previous_behavior = camera.grid.behavior_at(object.previous.x, object.previous.y)
	if covering and not _frlg and object.current_behavior == MB_LONG_GRASS and object.previous_behavior == MB_LONG_GRASS:
		object.subsprite_table = Gen3ObjectSprites.LONG_GRASS_TABLE_HIGH \
			if Gen3ObjectSprites.ELEVATION_PRIORITY[object.previous_elevation] == 1 else Gen3ObjectSprites.LONG_GRASS_TABLE
	# `sGroundEffectFuncs` order decides each effect's sprite slot.
	_ground_grass(object, slot, kind, covering, requests)
	if kind != "finish_step":
		_update_reflection(object, slot)
	_ground_flowing_water(object, slot, covering, requests)
	if kind == "begin_step":
		_ground_tracks(object, slot, requests)
	if kind == "finish_step":
		_ground_ripple(object, slot, requests)
	if kind != "spawn" and not landing:
		_ground_puddle(object, slot, requests)
	_ground_sand_pile(object, slot, covering, requests)
	if landing:
		_jump_landing(object, slot, requests)
	_ground_short_grass(object, slot, covering, requests)
	_ground_hot_springs(object, slot, covering, requests)
	if kind == "finish_step":
		_ground_seaweed(object, slot, requests)
	requests.append({"kind": kind, "object_id": slot})


func _grass_effect(behavior: int) -> int:
	behavior &= 0xFF
	if behavior == 2 or (_frlg and behavior == 0xD1):
		return 4
	return 17 if not _frlg and behavior == MB_LONG_GRASS else -1


func _ground_effects_visible(object: ObjectEvent) -> bool:
	var steps: int = events.var_get(VAR_FARAWAY_ISLAND_STEP_COUNTER)
	return not _is_faraway_mew(object) or (steps != 0xFFFF and steps % 4 == 0)


func _ground_grass(object: ObjectEvent, slot: int, kind: String, covering: bool, requests: Array) -> void:
	var effect: int = _grass_effect(object.current_behavior)
	if effect < 0 or kind == "finish_step" or not _ground_effects_visible(object):
		return
	if kind == "begin_step" and not covering and effect == 4:
		return
	_start_grass(object, slot, effect, kind == "spawn", requests)


## `GetGroundEffectFlags_ShortGrass` latches before the display gate; FRLG's predicate always returns false.
func _ground_short_grass(object: ObjectEvent, slot: int, covering: bool, requests: Array) -> void:
	var inside: bool = not _frlg and covering and object.current_behavior == 7 and object.previous_behavior == 7
	var start: bool = inside and not object.in_short_grass
	object.in_short_grass = inside
	if start and _ground_effects_visible(object):
		_start_grass(object, slot, 41, false, requests)


## `GetGroundEffectFlags_SandHeap`: FRLG's deep-sand predicate is always false.
func _ground_sand_pile(object: ObjectEvent, slot: int, covering: bool, requests: Array) -> void:
	var inside: bool = not _frlg and covering and (object.current_behavior & 0xFF) == 6 and (object.previous_behavior & 0xFF) == 6
	var start: bool = inside and not object.in_sand_pile
	object.in_sand_pile = inside
	if start and _ground_effects_visible(object):
		start_effect_sprite(object, slot, FLDEFF_SAND_PILE, -1, true, requests)


func _ground_hot_springs(object: ObjectEvent, slot: int, covering: bool, requests: Array) -> void:
	var inside: bool = covering and (object.current_behavior & 0xFF) == 0x28 and (object.previous_behavior & 0xFF) == 0x28
	var start: bool = inside and not object.in_hot_springs
	object.in_hot_springs = inside
	if start and _ground_effects_visible(object):
		start_effect_sprite(object, slot, FLDEFF_HOT_SPRINGS_WATER, -1, true, requests)


## `GetGroundEffectFlags_Tracks` on pos2's u8 behavior; FRLG's sand adds MB_SAND_CAVE and drops the others.
func _ground_tracks(object: ObjectEvent, slot: int, requests: Array) -> void:
	var behavior: int = object.previous_behavior & 0xFF
	var deep: bool = not _frlg and behavior == 6
	if not deep and behavior != 0x21 and behavior != (0x2B if _frlg else 0x25):
		return
	var kind: int = int(graphics_info(object.graphics_id).get("tracks", Tracks.NONE))
	if not _ground_effects_visible(object) or kind == Tracks.NONE \
			or (kind == Tracks.BIKE_TIRE and object.current == object.previous):
		return
	var effect: int = FLDEFF_BIKE_TIRE_TRACKS if kind == Tracks.BIKE_TIRE else (FLDEFF_DEEP_SAND_FOOTPRINTS if deep else FLDEFF_SAND_FOOTPRINTS)
	var sprite: Dictionary = start_effect_sprite(object, slot, effect, -1, false, requests)
	if not sprite.is_empty():
		(sprite["anim"] as Gen3SpriteAnim).start(object.facing if kind == Tracks.FOOT
			else BIKE_TRACK_ANIMS[object.previous_movement_direction * 4 + object.facing - 5])


## `GetGroundEffectFlags_ShallowFlowingWater`: both cells must share water or log terrain; jump filters reset it.
func _ground_flowing_water(object: ObjectEvent, slot: int, covering: bool, requests: Array) -> void:
	var current: int = _flowing_water_kind(object.current_behavior)
	var inside: bool = covering and current != 0 and current == _flowing_water_kind(object.previous_behavior)
	var start: bool = inside and not object.in_flowing_water
	object.in_flowing_water = inside
	if start and _ground_effects_visible(object):
		start_effect_sprite(object, slot, FLDEFF_FEET_IN_FLOWING_WATER, -1, true, requests)


## `MetatileBehavior_IsShallowFlowingWater` and `IsPacifidlogLog` take u8; FRLG only accepts shallow water.
func _flowing_water_kind(behavior: int) -> int:
	behavior &= 0xFF
	if behavior == 0x17 or (not _frlg and behavior in [0x1B, 0x1C]):
		return 1
	return 2 if not _frlg and behavior >= 0x74 and behavior <= 0x77 else 0


## `GetGroundEffectFlags_Puddle` tests both u8 behaviors; only a landing filters the finish-step splash.
func _ground_puddle(object: ObjectEvent, slot: int, requests: Array) -> void:
	if (object.current_behavior & 0xFF) == 0x16 and (object.previous_behavior & 0xFF) == 0x16 \
			and _ground_effects_visible(object):
		start_effect_sprite(object, slot, 15, -1, true, requests)


## `GetGroundEffectFlags_Ripple` takes u8; `DoRippleFieldEffect` places ripples at pos1 feet without pos2.
func _ground_ripple(object: ObjectEvent, slot: int, requests: Array) -> void:
	var behavior: int = object.current_behavior & 0xFF
	if (behavior in [0x10, 0x16] or (not _frlg and behavior == 0x14)) and _ground_effects_visible(object):
		start_effect_sprite(object, slot, 5, -1, false, requests)


## `UpdateBubblesFieldEffect` masks (data[0] + 0x80) with 0x100 each callback, so its zero start never rises.
func _ground_seaweed(object: ObjectEvent, slot: int, requests: Array) -> void:
	var behavior: int = object.current_behavior & 0xFF
	if (behavior == 0x22 or (not _frlg and behavior == 0x2A)) and _ground_effects_visible(object):
		start_effect_sprite(object, slot, FLDEFF_BUBBLES, -1, false, requests)


## `GetGroundEffectFlags_JumpLanding` selects the first matching u8 terrain predicate, then normal dust.
func _jump_landing(object: ObjectEvent, slot: int, requests: Array) -> void:
	if not _ground_effects_visible(object):
		return
	var effect: int = _grass_effect(object.current_behavior)
	if effect < 0:
		var behavior: int = object.current_behavior & 0xFF
		var impact: int = FLDEFF_DUST
		if behavior == 0x16:
			impact = 16
		elif camera.data.world_surfable(behavior):
			impact = 14
		elif behavior == 0x17 or (not _frlg and behavior in [0x1B, 0x1C]):
			impact = 16
		start_effect_sprite(object, slot, impact, -1, false, requests)
		return
	_start_grass(object, slot, 12 if effect == 4 else 18, false, requests)
	if effect == 4 and not _effect_sprites.any(func(row: Dictionary) -> bool:
		return row.has("cell") and row["cell"] == object.current and int(row["request"]["effect_id"]) == 4 \
			and by_identity(int(row["request"]["local_id"]), int(row["request"]["map_number"]),
				int(row["request"]["map_group"])) == object):
		_start_grass(object, slot, 4, true, requests)


func _start_grass(object: ObjectEvent, slot: int, effect: int, settled: bool, requests: Array) -> void:
	var info: Dictionary = camera.data.world_grass_graphics(effect)
	if info.is_empty():
		return
	var sprite_slot: int = sprites.effect_slot()
	if sprite_slot < 0:
		return
	var anim := Gen3SpriteAnim.new()
	anim.anims = info["anims"]
	anim.images = info["images"]
	if settled:
		anim.seek(4 if effect == 4 else 6)
	var request: Dictionary = _effect_request(object, slot, effect)
	var position: Vector2i = camera.sprite_position(object.current) + Vector2i(8, 12 if effect == 12 else 8)
	position = Vector2i(wrapi(position.x, -32768, 32768), wrapi(position.y, -32768, 32768))
	var sprite: Dictionary = {"request": request, "sprite_slot": sprite_slot, "anim": anim,
		"passes": 0, "end": -1, "follow": effect in [4, 17, 41], "grass": true, "moved": false, "info": info,
		"cell": object.current, "map": Vector2i(camera.group, camera.number),
		"position": position,
		"elevation": object.previous_elevation, "priority": Gen3ObjectSprites.ELEVATION_PRIORITY[object.previous_elevation]
			if effect == 17 else 2, "palette": sprites.load_effect_palette(info)}
	requests.append(request)
	_effect_sprites.append(sprite)


func _grass_finished(sprite: Dictionary, object: ObjectEvent) -> bool:
	var effect: int = int(sprite["request"]["effect_id"])
	var anim: Gen3SpriteAnim = sprite["anim"]
	if effect == 41:
		return _short_grass_finished(sprite, object)
	if effect in [12, 18]:
		return anim.ended
	var map := Vector2i(camera.group, camera.number)
	if camera.crossed and sprite["map"] != map:
		var shifted: Vector2i = sprite["cell"] - camera.shift
		sprite["cell"] = Vector2i(wrapi(shifted.x, -32768, 32768), wrapi(shifted.y, -32768, 32768))
		sprite["map"] = map
	var cell: Vector2i = sprite["cell"]
	if object == null or _grass_effect(camera.grid.behavior_at(cell.x, cell.y)) != effect:
		return true
	if sprite["moved"] and anim.ended:
		return true
	if object.current != cell and object.previous != cell:
		sprite["moved"] = true
	return false


## `UpdateShortGrassFieldEffect` follows pos1 only, restarting an ended animation when that position changes.
func _short_grass_finished(sprite: Dictionary, object: ObjectEvent) -> bool:
	if object == null or not object.in_short_grass:
		return true
	var height: int = int(graphics_info(object.graphics_id).get("height", 0))
	var linked: Vector2i = linked_sprite_position(object)
	var anim: Gen3SpriteAnim = sprite["anim"]
	if linked != sprite.get("linked_position", linked) and anim.ended:
		anim.start(0)
	sprite["linked_position"] = linked
	sprite["position"] = linked + Vector2i(0, (height >> 1) - 8)
	sprite["priority"] = object.priority
	sprite["subpriority"] = (object.subpriority - 1) & 0xFF
	sprite["invisible"] = object.sprite_invisible
	return false


func _update_reflection(object: ObjectEvent, slot: int) -> void:
	var type: int = nearby_reflection_type(object)
	if type != 0 and not object.has_reflection and _ground_effects_visible(object):
		sprites.start_reflection(self, object, slot, type == 1)
	object.has_reflection = type != 0


## `ObjectEventGetNearbyReflectionType`: FRLG probes 1x2 cells; each engine reads the behavior as u8.
func nearby_reflection_type(object: ObjectEvent) -> int:
	var info: Dictionary = graphics_info(object.graphics_id)
	var width: int = 1 if _frlg else (int(info.get("width", 0)) + 8) >> 4
	var height: int = 2 if _frlg else (int(info.get("height", 0)) + 8) >> 4
	for y: int in range(1, height + 1):
		for x: int in range(maxi(width, 1)):
			for at: Vector2i in [object.current, object.previous]:
				for offset: int in ([0] if x == 0 else [x, -x]):
					var type: int = reflection_type(camera.grid.behavior_at(at.x + offset, at.y + y), _frlg)
					if type != 0:
						return type
	return 0


static func reflection_type(behavior: int, frlg: bool) -> int:
	behavior &= 0xFF
	if behavior == (0x23 if frlg else 0x20):
		return 1
	var water: Array = [0x10, 0x16, 0x1A, 0x1B] if frlg else [0x10, 0x14, 0x16, 0x1A, 0x2B]
	return 2 if behavior in water else 0


func _step_autonomous(object: ObjectEvent, slot: int, requests: Array) -> void:
	var type: int = object.movement_type
	if type == 0xC and not _frlg:
		_step_berry(object, slot, requests)
	elif type in [0x39, 0x3A, MOVEMENT_TYPE_BURIED]:
		clear_held_movement(object)
		object.single_movement_active = false
	elif type in [2, 3, 4, 5, 6]:
		_step_wander(object, slot, requests)
	elif type == 1 or (type >= 0xD and type <= 0x16):
		_step_random_facing(object, slot, requests)
	elif type in [0x17, 0x18]:
		_step_rotation(object, slot, requests)
	elif type >= 0x19 and type <= 0x34:
		_step_patrol(object, slot, requests)
	elif type in [0x35, 0x36, 0x37, 0x38, 0x3B, 0x3C, 0x3D, 0x3E]:
		_step_copy_player(object, slot, requests)
	elif (type >= 7 and type <= 10) or type == 0x4C:
		_step_stationary(object, slot, requests)
	elif (type >= 0x40 and type <= 0x4B) or (not _frlg and type >= 0x4D and type <= 0x50):
		_step_in_place(object, slot, requests)


func _set_berry_graphics(object: ObjectEvent) -> void:
	var tree: Dictionary = events.berries.record(object.trainer_range)
	var stage: int = int(tree.get("stage", 0))
	object.invisible = stage == 0
	if stage == 0:
		return
	var berry: int = int(tree["berry"])
	var info: Dictionary = camera.data.world_berry(berry if berry >= 1 and berry <= 44 else 1)
	set_graphics_id(object, int(info["berry_graphics"][stage - 1]))
	object.anim.images = camera.data.world_sprite_images(int(info.get("berry_images", -1)))
	object.palette_num = int(info["berry_palettes"][stage - 1]) & 15
	object.anim.start(stage - 1)


## `MovementType_BerryTreeGrowth`: a TRUE callback runs the next state at once; each sparkle phase spends timers 1-65.
func _step_berry(object: ObjectEvent, slot: int, requests: Array) -> void:
	while true:
		match object.movement_state:
			0:
				clear_held_movement(object)
				object.single_movement_active = false
				var stage: int = int(events.berries.record(object.trainer_range).get("stage", 0))
				object.invisible = stage == 0
				if stage == 0:
					if not object.berry_just_picked and object.anim.anim_num == 4:
						start_effect_sprite(object, slot, FLDEFF_BERRY_TREE_GROWTH_SPARKLE, -1, false, requests)
						object.anim.anim_num = 0
					return
				if object.anim.anim_num == stage - 1:
					_set_berry_graphics(object)
					_set_single_movement(object, START_ANIM_IN_DIRECTION)
					object.movement_state = 1
					object.movement_delay = 1
				else:
					object.movement_state = 2
			1:
				if not _exec_single_movement(object, slot, requests):
					return
				object.movement_state = 0
				object.movement_delay = 0
			2:
				object.single_movement_active = true
				object.movement_state = 3
				object.movement_delay = 0
				object.berry_sparkling = true
				start_effect_sprite(object, slot, FLDEFF_BERRY_TREE_GROWTH_SPARKLE, -1, false, requests)
			3, 4:
				object.movement_delay += 1
				object.invisible = bool(object.movement_delay & 2)
				object.anim.paused = true
				if object.movement_delay <= 64:
					return
				if object.movement_state == 3:
					_set_berry_graphics(object)
					object.movement_state = 4
					object.movement_delay = 0
				else:
					object.movement_state = 0
					object.berry_sparkling = false


## `MovementType_CopyPlayer*` latches the entry facing once; [Gen3PlayerAvatar] supplies T_TILE_CENTER.
func _step_copy_player(object: ObjectEvent, slot: int, requests: Array) -> void:
	var player: ObjectEvent = _player_event()
	if player == null and object.movement_state != 2:
		return
	if object.movement_state == 0:
		clear_held_movement(object)
		object.single_movement_active = false
		if object.direction_sequence_index == 0:
			object.direction_sequence_index = player.facing
		object.movement_state = 1
	if object.movement_state == 1:
		var copy: int = player.player_copyable_movement
		if player.movement_action < 0 or _player_tile_center or copy <= 0 or copy >= COPY_ACTIONS.size():
			return
		_choose_copy_movement(object, player, copy)
		object.single_movement_active = true
		object.movement_state = 2
	if _exec_single_movement(object, slot, requests):
		object.single_movement_active = false
		object.movement_state = 1


func _copy_direction(object: ObjectEvent, direction: int) -> int:
	var initial: int = object.direction_sequence_index
	if initial < 1 or initial > 4 or direction < 1 or direction > 4:
		return 0
	var relative: int = int(COPY_PLAYER_DIRECTIONS[initial - 1][direction - 1])
	return int(COPY_OBJECT_DIRECTIONS[_facing[object.movement_type] - 1][relative - 1])


func _choose_copy_movement(object: ObjectEvent, player: ObjectEvent, copy: int) -> void:
	var direction: int = _copy_direction(object, player.movement_direction)
	if copy == 2 and _is_faraway_mew(object):
		direction = _mew_direction(player)
		if direction == 0:
			_set_single_movement(object, direction_action(0, _copy_direction(object, player.movement_direction)))
			return
	var base: int = COPY_ACTIONS[copy]
	if _frlg and base != 0:
		base += 8 if base < 0x3A else 12
	if copy not in [1, 6]:
		var at: Vector2i = object.current + Gen3FieldCamera.DIRECTIONS[direction] * (2 if copy == 8 else 1)
		at = Vector2i(wrapi(at.x, -32768, 32768), wrapi(at.y, -32768, 32768))
		if collision_at(object, at.x, at.y, direction) != Collision.NONE \
				or (object.movement_type >= 0x3B and not _is_poke_grass(at)):
			base = 0
	_set_single_movement(object, direction_action(base, direction))


func _is_poke_grass(at: Vector2i) -> bool:
	return camera.grid.behavior_at(at.x, at.y) & 0xFF in [2, 0xD1 if _frlg else 3]


func _is_faraway_mew(object: ObjectEvent) -> bool:
	return events.game == RomRegistry.EMERALD and camera.group == 26 and camera.number == 57 \
		and object.graphics_id == 229


## `faraway_island.c`: rocks before distance; the step counter picks candidates without consuming the RNG.
func _mew_direction(player: ObjectEvent) -> int:
	var mew: ObjectEvent = null
	for candidate: ObjectEvent in objects:
		if candidate.active and candidate.local_id == 1 and candidate.map_group == camera.group \
				and candidate.map_number == camera.number:
			mew = candidate
			break
	if mew == null or player.previous == player.current:
		return 0
	var delta := Vector2i(wrapi(player.previous.x - mew.current.x, -32768, 32768),
		wrapi(player.previous.y - mew.current.y, -32768, 32768))
	var steps: int = events.var_get(VAR_FARAWAY_ISLAND_STEP_COUNTER)
	mew.invisible = steps % 8 != 0
	if steps % 9 == 0:
		return 0
	for rock: Vector2i in [Vector2i(21, 16), Vector2i(25, 16), Vector2i(16, 17), Vector2i(20, 20)]:
		var direction: int = _mew_rock_escape(mew, player, rock, delta)
		if direction != 0:
			return direction
	return _mew_avoid_player(mew, player, delta, steps)


func _mew_avoid_player(mew: ObjectEvent, player: ObjectEvent, delta: Vector2i, steps: int) -> int:
	var away: Array[int] = []
	for direction: int in [2, 1, 4, 3]:
		var displacement: Vector2i = Gen3FieldCamera.DIRECTIONS[direction]
		if delta.x * displacement.x + delta.y * displacement.y < 0 and _mew_can_move(mew.current + displacement, player):
			away.append(direction)
	if not away.is_empty():
		return away[steps % mini(away.size(), 2)]
	var axes: Array[int] = _mew_axis_candidates(mew, player, delta)
	for direction: int in axes:
		if direction != 0 and _mew_can_move(mew.current + Gen3FieldCamera.DIRECTIONS[direction], player):
			return direction
	var candidates: Array[int] = []
	for direction: int in [2, 4, 1, 3]:
		if _mew_can_move(mew.current + Gen3FieldCamera.DIRECTIONS[direction], player):
			candidates.append(direction)
	return 0 if candidates.is_empty() else candidates[steps % candidates.size()]


func _mew_axis_candidates(mew: ObjectEvent, player: ObjectEvent, delta: Vector2i) -> Array[int]:
	var axes: Array[int] = []
	if delta.y == 0:
		if player.current.y > mew.current.y:
			axes.append(2)
		elif player.current.y < mew.current.y:
			axes.append(1)
		axes.append_array([2, 1])
	if delta.x == 0:
		if player.current.x > mew.current.x:
			axes.append(3)
		elif player.current.x < mew.current.x:
			axes.append(4)
		axes.append_array([4, 3])
	return axes


func _mew_rock_escape(mew: ObjectEvent, player: ObjectEvent, rock: Vector2i, delta: Vector2i) -> int:
	for axis: int in 2:
		var other: int = 1 - axis
		if player.previous[axis] != rock[axis]:
			continue
		var safe: bool = mew.current[other] <= rock[other] if player.previous[other] < rock[other] else mew.current[other] >= rock[other]
		if safe:
			continue
		var direction: int = 0
		if absi(delta[axis]) == 1:
			direction = [4, 1][axis] if delta[axis] > 0 else [3, 2][axis]
		elif delta[axis] == 0:
			direction = [2, 3][axis] if delta[other] > 0 else [1, 4][axis]
		if direction != 0 and _mew_can_move(mew.current + Gen3FieldCamera.DIRECTIONS[direction], player):
			return direction
	return 0


func _mew_can_move(at: Vector2i, player: ObjectEvent) -> bool:
	at = Vector2i(wrapi(at.x, -32768, 32768), wrapi(at.y, -32768, 32768))
	return at != player.current and _is_poke_grass(at)


func _set_single_movement(object: ObjectEvent, action: int) -> void:
	object.movement_action = action
	object.movement_frame = 0
	object.action_step = 0


func _exec_single_movement(object: ObjectEvent, slot: int, requests: Array) -> bool:
	if not _advance_motion(object, slot, requests):
		return false
	object.movement_action = -1
	object.movement_frame = 0
	object.action_step = 0
	return true


func _step_stationary(object: ObjectEvent, slot: int, requests: Array) -> void:
	if object.movement_state == 0:
		clear_held_movement(object)
		object.single_movement_active = false
		_set_single_movement(object, direction_action(0, object.facing))
		if object.movement_type == MOVEMENT_TYPE_INVISIBLE:
			object.invisible = true
		object.movement_state = 1
	if object.movement_state == 1 and _exec_single_movement(object, slot, requests):
		object.movement_state = 2
	if object.movement_state == 2:
		object.single_movement_active = false


func _step_in_place(object: ObjectEvent, slot: int, requests: Array) -> void:
	if object.movement_state == 0:
		clear_held_movement(object)
		object.single_movement_active = false
		var pace: int = (object.movement_type - 0x40) >> 2
		var base: int = 0x1D + pace * 4 if pace < 3 else 0x19
		_set_single_movement(object, direction_action(base + (8 if _frlg else 0), object.facing))
		object.movement_state = 1
	if _exec_single_movement(object, slot, requests):
		object.movement_state = 0


func _step_patrol(object: ObjectEvent, slot: int, requests: Array) -> void:
	if object.movement_state == 0:
		clear_held_movement(object)
		object.single_movement_active = false
		object.movement_state = 1
	if object.movement_state == 1:
		if object.movement_type < 0x1D:
			_choose_back_and_forth(object)
		else:
			_choose_sequence(object)
		var blocked: bool = _collision_in_direction(object) != Collision.NONE
		var base: int = (0x1D if blocked else 0x08) + (8 if _frlg else 0)
		_set_single_movement(object, direction_action(base, object.facing if blocked else object.movement_direction))
		object.single_movement_active = true
		object.movement_state = 3 if object.movement_type < 0x1D else 2
	if _exec_single_movement(object, slot, requests):
		object.single_movement_active = false
		object.movement_state = 1


func _collision_in_direction(object: ObjectEvent) -> int:
	var at: Vector2i = object.current + Gen3FieldCamera.DIRECTIONS[object.movement_direction]
	at = Vector2i(wrapi(at.x, -32768, 32768), wrapi(at.y, -32768, 32768))
	return collision_at(object, at.x, at.y, object.movement_direction)


func _choose_back_and_forth(object: ObjectEvent) -> void:
	var direction: int = _facing[object.movement_type]
	set_direction(object, OPPOSITE[direction] if object.direction_sequence_index != 0 else direction)
	if object.direction_sequence_index != 0 and object.current == object.initial:
		object.direction_sequence_index = 0
		set_direction(object, OPPOSITE[object.movement_direction])
	if _collision_in_direction(object) == Collision.OUTSIDE_RANGE:
		object.direction_sequence_index = (object.direction_sequence_index + 1) & 0xFF
		set_direction(object, OPPOSITE[object.movement_direction])


func _choose_sequence(object: ObjectEvent) -> void:
	var route: Array = PATROL_ROUTES[object.movement_type - 0x1D]
	var index: int = object.direction_sequence_index
	# Each route's returning leg changes direction at the spawn's axis.
	var return_index: int = 1 if int(route[0]) == OPPOSITE[int(route[1])] else 2
	var direction: int = int(route[return_index])
	var on_axis: bool = object.current.x == object.initial.x if direction >= Direction.WEST \
		else object.current.y == object.initial.y
	if index == return_index and on_axis:
		index += 1
	if index == 3 and object.current == object.initial:
		index = 0
	set_direction(object, int(route[index]))
	if _collision_in_direction(object) == Collision.OUTSIDE_RANGE:
		index += 1
		set_direction(object, int(route[index]))
	object.direction_sequence_index = index


func _start_facing(object: ObjectEvent) -> void:
	_set_single_movement(object, direction_action(0, object.facing))
	object.movement_state = 2


func _choose_delay(object: ObjectEvent) -> void:
	var index: int = events.random.next() & 3
	object.movement_delay = 32 + index * (16 if object.movement_type >= 0xF else 32)
	object.movement_state = 3


func _wait_delay(object: ObjectEvent) -> bool:
	object.movement_delay = wrapi(object.movement_delay - 1, -32768, 32768)
	return object.movement_delay == 0


func _step_wander(object: ObjectEvent, slot: int, requests: Array) -> void:
	if object.movement_state == 0:
		clear_held_movement(object)
		object.single_movement_active = false
		object.movement_state = 1
	if object.movement_state == 1:
		_start_facing(object)
	if object.movement_state == 2:
		if not _exec_single_movement(object, slot, requests):
			return
		_choose_delay(object)
	if object.movement_state == 3:
		if not _wait_delay(object):
			return
		object.movement_state = 4
	if object.movement_state == 4:
		var directions: Array = RANDOM_DIRECTIONS[object.movement_type]
		var direction: int = int(directions[events.random.next() & (directions.size() - 1)])
		set_direction(object, direction)
		if _collision_in_direction(object) != Collision.NONE:
			object.movement_state = 1
			_step_wander(object, slot, requests)
			return
		_set_single_movement(object, direction_action(0x08 + (8 if _frlg else 0), direction))
		object.single_movement_active = true
		object.movement_state = 6
	if _exec_single_movement(object, slot, requests):
		object.single_movement_active = false
		object.movement_state = 1


func _step_random_facing(object: ObjectEvent, slot: int, requests: Array) -> void:
	if object.movement_state == 0:
		clear_held_movement(object)
		object.single_movement_active = false
		object.movement_state = 1
	if object.movement_state == 1:
		_start_facing(object)
	if object.movement_state == 2:
		if _exec_single_movement(object, slot, requests):
			_choose_delay(object)
			object.single_movement_active = false
		return
	if object.movement_state == 3:
		if not _wait_delay(object) and not _trainer_close(object):
			return
		object.movement_state = 4
	var directions: Array = RANDOM_DIRECTIONS[object.movement_type]
	var direction: int = _trainer_direction(object, directions)
	if direction == Direction.NONE:
		direction = int(directions[events.random.next() & (directions.size() - 1)])
	set_direction(object, direction)
	object.movement_state = 1
	_step_random_facing(object, slot, requests)


func _step_rotation(object: ObjectEvent, slot: int, requests: Array) -> void:
	if object.movement_state == 3:
		var direction: int = _trainer_direction(object, [1, 2, 3, 4])
		if direction == Direction.NONE:
			direction = int(ROTATION_DIRECTIONS[object.movement_type - 0x17][object.facing])
		set_direction(object, direction)
		object.movement_state = 0
	if object.movement_state == 0:
		clear_held_movement(object)
		object.single_movement_active = false
		_set_single_movement(object, direction_action(0, object.facing))
		object.movement_state = 1
	if object.movement_state == 1:
		if _exec_single_movement(object, slot, requests):
			object.movement_delay = 48
			object.movement_state = 2
		return
	if _wait_delay(object) or _trainer_close(object):
		object.movement_state = 3


func _player_event() -> ObjectEvent:
	for object: ObjectEvent in objects:
		if object.active and object.local_id == LOCALID_PLAYER:
			return object
	return null


func _trainer_close(object: ObjectEvent) -> bool:
	if not _player_dashing or object.trainer_type not in [1, 3]:
		return false
	var player_event: ObjectEvent = _player_event()
	if player_event == null:
		return false
	var player: Vector2i = player_event.current
	var minimum := Vector2i(wrapi(object.current.x - object.trainer_range, -32768, 32768),
		wrapi(object.current.y - object.trainer_range, -32768, 32768))
	var maximum := Vector2i(wrapi(object.current.x + object.trainer_range, -32768, 32768),
		wrapi(object.current.y + object.trainer_range, -32768, 32768))
	return minimum.x <= player.x and player.x <= maximum.x and minimum.y <= player.y and player.y <= maximum.y


## `GetLimitedVectorDirection_*`: ties prefer y; blocked quadrants try the other axis, then north/south.
func _trainer_direction(object: ObjectEvent, directions: Array) -> int:
	if not _trainer_close(object):
		return Direction.NONE
	var delta: Vector2i = _player_event().current - object.current
	delta = Vector2i(wrapi(delta.x, -32768, 32768), wrapi(delta.y, -32768, 32768))
	var horizontal: int = Direction.WEST if delta.x < 0 else Direction.EAST
	var vertical: int = Direction.NORTH if delta.y < 0 else Direction.SOUTH
	var direction: int = horizontal if absi(delta.x) > absi(delta.y) else vertical
	if direction in directions:
		return direction
	direction = vertical if direction == horizontal else horizontal
	if direction in directions:
		return direction
	return Direction.NORTH if Direction.NORTH in directions else Direction.SOUTH
