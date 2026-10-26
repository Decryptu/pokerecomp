class_name Gen3PlayerAvatar
extends RefCounted

## `field_player_avatar.c`: state, `PlayerStep`, collisions, the Strength, surf, dismount and secret base mat tasks
## and rotating gates; `field_effect.c`'s field-move and Waterfall tasks. [Gen3Bike] rides the bikes.

enum Flag { ON_FOOT = 1, MACH_BIKE = 2, ACRO_BIKE = 4, SURFING = 8,
	UNDERWATER = 16, CONTROLLABLE = 32, FORCED_MOVE = 64, DASH = 128 }
enum State { NORMAL, MACH_BIKE, ACRO_BIKE, SURFING, UNDERWATER, FIELD_MOVE, FISHING, WATERING, VS_SEEKER }
enum Collision { NONE, OUTSIDE_RANGE, IMPASSABLE, ELEVATION_MISMATCH, OBJECT_EVENT,
	STOP_SURFING, LEDGE_JUMP, PUSHED_BOULDER, DIRECTIONAL_STAIR_WARP, WHEELIE_HOP,
	ISOLATED_VERTICAL_RAIL, ISOLATED_HORIZONTAL_RAIL, VERTICAL_RAIL, HORIZONTAL_RAIL,
	ROTATING_GATE = 8 }
enum Task { NONE, PUSH_WAIT, PUSH_MOVE, SURF_WAIT, SURF_JUMP, MOUNT_INIT, MOUNT_POSE, MOUNT_SHOW_MON, MOUNT_JUMP,
	MOUNT_END, MOVE_INIT, MOVE_POSE, MOVE_SHOW_MON, MOVE_RUN, WATERFALL_SHOW_MON, WATERFALL_WAIT, WATERFALL_RIDE,
	MAT_JUMP, MAT_SPIN_TURN, MAT_SPIN_DELAY, MAT_SPIN_LEAVE }
enum Running { NOT_MOVING, TURN_DIRECTION, MOVING }
enum Tile { NOT_MOVING, TRANSITION, CENTER }
enum Copy { NONE, FACE, WALK, SPIN, JUMP_2 = 8 }
enum Forced { SLIP, WALK, CURRENT, SLIDE, SPIN, MAT_JUMP, MAT_SPIN, MUDDY_SLOPE }
## `Get*MovementAction` families by name: Hoenn's id, FRLG's (-1 absent).
const ACTIONS: Dictionary = {&"face": [0x00, 0x00], &"walk_slow": [0x04, 0x0C], &"walk_normal": [0x08, 0x10],
	&"jump_2": [0x0C, 0x14], &"walk_fast": [0x15, 0x1D], &"in_place_slow": [0x19, 0x21],
	&"in_place_normal": [0x1D, 0x25], &"in_place_fast": [0x21, 0x29], &"ride_current": [0x29, 0x31],
	&"walk_faster": [0x2D, 0x35], &"run": [0x35, 0x3D], &"run_slow": [-1, 0x41], &"jump": [0x42, 0x4E],
	&"jump_in_place": [0x46, 0x52], &"spin": [-1, 0x94]}
## `PlayerAnimIsMultiFrameStationary`'s action ranges, Ruby's acro rows two below Emerald's.
const STATIONARY: Dictionary = {&"ruby": [[0, 3], [0x10, 0x14], [0x19, 0x28], [0x62, 0x6D], [0x7A, 0x7D]],
	&"emerald": [[0, 3], [0x10, 0x14], [0x19, 0x28], [0x64, 0x6F], [0x7C, 0x7F]],
	&"firered": [[0, 7], [0x18, 0x1C], [0x21, 0x30], [0x70, 0x7B], [0x88, 0x8B]]}
## `sForcedMovementTestFuncs` by behavior: the forced movement and its direction (0: the movement direction).
const HOENN_FORCED: Dictionary = {0x48: [Forced.SLIP, 0], 0x20: [Forced.SLIP, 0],
	0x43: [Forced.WALK, 1], 0x42: [Forced.WALK, 2], 0x41: [Forced.WALK, 3], 0x40: [Forced.WALK, 4],
	0x53: [Forced.CURRENT, 1], 0x52: [Forced.CURRENT, 2], 0x51: [Forced.CURRENT, 3], 0x50: [Forced.CURRENT, 4],
	0x47: [Forced.SLIDE, 1], 0x46: [Forced.SLIDE, 2], 0x45: [Forced.SLIDE, 3], 0x44: [Forced.SLIDE, 4],
	0x13: [Forced.CURRENT, 1], 0xBB: [Forced.MAT_JUMP, 0], 0xBC: [Forced.MAT_SPIN, 0], 0xD0: [Forced.MUDDY_SLOPE, 1]}
## FRLG's list adds the spin tiles and drops the mats, which are stubs there, and the muddy slope.
const FRLG_FORCED: Dictionary = {0x48: [Forced.SLIP, 0], 0x23: [Forced.SLIP, 0],
	0x43: [Forced.WALK, 1], 0x42: [Forced.WALK, 2], 0x41: [Forced.WALK, 3], 0x40: [Forced.WALK, 4],
	0x53: [Forced.CURRENT, 1], 0x52: [Forced.CURRENT, 2], 0x51: [Forced.CURRENT, 3], 0x50: [Forced.CURRENT, 4],
	0x54: [Forced.SPIN, 4], 0x55: [Forced.SPIN, 3], 0x56: [Forced.SPIN, 2], 0x57: [Forced.SPIN, 1],
	0x47: [Forced.SLIDE, 1], 0x46: [Forced.SLIDE, 2], 0x45: [Forced.SLIDE, 3], 0x44: [Forced.SLIDE, 4],
	0x13: [Forced.CURRENT, 1]}
const MB_STOP_SPINNING: int = 0x58
const HOENN_ARROW_WARPS: Array = [[0x65, 0x6D, 0x1C], [0x64, 0x1B], [0x63], [0x62]]
const MB_WARP_DOOR: int = 0x69
const FRLG_STAIR_WARPS: Dictionary = {3: [0x6D, 0x6F], 4: [0x6C, 0x6E]}
## `PlayerAvatar_SecretBaseMatSpinStep1`'s turns by movement direction and `Step2`'s delays by completed laps.
const MAT_SPIN_TURNS: Array[int] = [3, 4, 2, 1]
const MAT_SPIN_DELAYS: Array[int] = [0x10, 0x10, 0x11, 0x12, 0x13]
const HOENN_NO_RUNNING: Array[int] = [0x0A, 0x03, 0x28, 0x74, 0x75, 0x76, 0x77]
const MB_FORTREE_BRIDGE: int = 0x78
const FRLG_NO_RUNNING: int = 0x0A
const MB_ROCK_STAIRS: int = 0x2A
const MAP_TYPE_INDOOR: int = 8
const FLAG_SYS_B_DASH: Dictionary = {
	&"ruby": 0x860, &"sapphire": 0x860, &"firered": 0x82F, &"leafgreen": 0x82F, &"emerald": 0x8C0,
}
const GAME_STAT_JUMPED_DOWN_LEDGES: int = 43
const LOCALID_FARAWAY_ISLAND_MEW: int = 1
const FLDEFF_USE_SURF: int = 9
const FLDEFF_USE_STRENGTH: int = 40
const FLDEFF_USE_WATERFALL: int = 43
## The sounds of `StartCutTreeFieldEffect` and `FieldMove_RockSmash`, which then re-enable the script.
const FIELD_MOVE_SOUNDS: Dictionary = {2: "cut", 37: "rock_smash"}
## The modeled `CreateFieldMoveTask` effects and the `GAME_STAT_USED_*` their `FldEff_Use*` counts, or -1.
const FIELD_MOVE_STATS: Dictionary = {Gen3CutGrass.FLDEFF_USE_CUT_ON_GRASS: 18, Gen3CutGrass.FLDEFF_USE_CUT_ON_TREE: 18,
	37: 19, FLDEFF_USE_STRENGTH: -1}
const MB_WATERFALL: int = 0x13
## Ruby's `ShouldDoBrailleStrengthEffect` spots and `DoBrailleStrengthEffect`'s chamber entrance, in backup cells.
const DESERT_RUINS: Vector2i = Vector2i(24, 6)
const DESERT_RUINS_SPOTS: Array[Vector2i] = [Vector2i(16, 30), Vector2i(17, 30), Vector2i(18, 30)]
const SEALED_CHAMBER_ENTRANCE: Dictionary = {Vector2i(14, 26): 0x22A, Vector2i(15, 26): 0x22B, Vector2i(16, 26): 0x22C,
	Vector2i(14, 27): 0xE32, Vector2i(15, 27): 0x233, Vector2i(16, 27): 0xE34}
const FLAG_SYS_BRAILLE_STRENGTH: int = 0x850
const TERRAIN_WATER: int = 2
const MAP_TYPE_UNDERWATER: int = 5
const MOVEMENT_TYPE_PLAYER: int = 0xB
## `sPlayerAvatarGfxIds`; FRLG's graphics-state indices differ from Hoenn's.
const HOENN_GRAPHICS: Array = [[0, 89], [1, 90], [63, 91], [2, 92], [111, 112],
	[3, 93], [137, 138], [191, 192]]
const FRLG_GRAPHICS: Dictionary = {State.NORMAL: [0, 7], State.MACH_BIKE: [1, 8],
	State.SURFING: [2, 9], State.FIELD_MOVE: [3, 10], State.FISHING: [4, 11], State.VS_SEEKER: [5, 12]}
const STATE_FLAGS: Array[int] = [Flag.ON_FOOT, Flag.MACH_BIKE, Flag.ACRO_BIKE, Flag.SURFING, Flag.UNDERWATER]
const LEDGES: Array[int] = [0, 0x3B, 0x3A, 0x39, 0x38]
const RAIL_COLLISIONS: Dictionary = {0xD1: Collision.WHEELIE_HOP,
	0xD3: Collision.ISOLATED_VERTICAL_RAIL, 0xD4: Collision.ISOLATED_HORIZONTAL_RAIL,
	0xD5: Collision.VERTICAL_RAIL, 0xD6: Collision.HORIZONTAL_RAIL}
const HOENN_FISHABLE: Array[int] = [0x10, 0x15, 0x11, 0x12, 0x14, 0x50, 0x51, 0x52, 0x53]

## `rotating_gate.c`: puzzle rows are x, y, shape, initial orientation.
const RS_GATES: Dictionary = {
	"12:1": [[12, 5, 3, 0], [14, 7, 3, 3], [16, 4, 5, 1], [15, 14, 1, 0],
		[18, 13, 4, 2], [8, 20, 4, 2], [16, 20, 7, 1]],
	"29:8": [[13, 3, 4, 3], [12, 6, 4, 2], [3, 6, 4, 2], [3, 9, 5, 3],
		[8, 8, 0, 1], [2, 12, 6, 2], [9, 13, 1, 0], [3, 14, 2, 1],
		[9, 15, 3, 2], [3, 18, 5, 2], [2, 19, 4, 0], [5, 21, 0, 0],
		[9, 19, 3, 3], [12, 20, 4, 1]],
}
const EMERALD_GATES: Dictionary = {
	"12:1": [[6, 7, 5, 1], [9, 15, 5, 2], [3, 19, 5, 1], [2, 6, 4, 1],
		[9, 12, 4, 0], [6, 23, 4, 0], [12, 22, 4, 0], [6, 3, 3, 2]],
	"29:8": [[14, 5, 4, 1], [10, 6, 1, 2], [6, 6, 3, 1], [14, 8, 4, 1],
		[3, 10, 2, 3], [9, 14, 0, 1], [3, 15, 6, 0], [2, 17, 1, 2],
		[12, 18, 6, 3], [5, 18, 3, 1], [10, 19, 2, 2]],
}
const GATE_ARMS: Array = [[1, 0, 1, 0, 0, 0, 0, 0], [1, 1, 1, 0, 0, 0, 0, 0],
	[1, 0, 1, 1, 0, 0, 0, 0], [1, 1, 1, 1, 0, 0, 0, 0],
	[1, 0, 1, 0, 1, 0, 0, 0], [1, 1, 1, 0, 1, 0, 0, 0],
	[1, 0, 1, 1, 1, 0, 0, 0], [1, 0, 1, 0, 1, 1, 0, 0]]
const GATE_SWEEPS: Array = [[],
	[Vector2i(-1, -1), Vector2i(-1, -2), Vector2i(0, -1), Vector2i(1, -1),
		Vector2i(0, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(-2, 0)],
	[Vector2i(0, -1), Vector2i(1, -2), Vector2i(0, 0), Vector2i(1, 0),
		Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(-1, -1), Vector2i(-2, -1)]]
const GATE_ROTATIONS: Dictionary = {
	1: {8: 0x17, 9: 0x16, 10: 0x22, 11: 0x23},
	2: {4: 0x27, 5: 0x26, 6: 0x12, 7: 0x13},
	3: {1: 0x11, 5: 0x10, 9: 0x24, 13: 0x25},
	4: {2: 0x21, 6: 0x20, 10: 0x14, 14: 0x15},
}

var objects: Gen3ObjectEvents
var object_id: int = -1
var gender: int = 0
var flags: int = 0
var running_state: Running = Running.NOT_MOVING
var tile_state: Tile = Tile.NOT_MOVING
var prevent_step: bool = false
var task: Task = Task.NONE
var bike: Gen3Bike
var frlg: bool = false
var _transition_flags: int = 0
var _last_spin_tile: int = 0
var _task_direction: int = 0
var _boulder_id: int = -1
var _shown_mon: Array = []
var _mount_cell: Vector2i = Vector2i.ZERO
var _field_move: int = 0
var _mat_count: int = 0
var _gate_map: String = ""
var _gates: Array = []


## `InitPlayerAvatar`, reserved before map objects; null on a full pool or a duplicate, which the cartridge overruns.
static func open(field_objects: Gen3ObjectEvents, at: Vector2i, direction: int, player_gender: int) -> Gen3PlayerAvatar:
	if player_gender not in [0, 1] or direction < 0 or direction > 4:
		return null
	var avatar := Gen3PlayerAvatar.new()
	avatar.objects = field_objects
	avatar.gender = player_gender
	avatar.frlg = field_objects.camera.data.id in [RomRegistry.FIRERED, RomRegistry.LEAFGREEN]
	avatar.bike = Gen3Bike.new(avatar, field_objects.camera.data.id)
	var template: Dictionary = Gen3ObjectEvents.EMPTY_TEMPLATE.duplicate()
	template.merge({"local_id": Gen3ObjectEvents.LOCALID_PLAYER,
		"graphics_id": avatar.graphics_for(State.NORMAL), "movement_type": MOVEMENT_TYPE_PLAYER,
		"x": at.x - Gen3MapGrid.MAP_OFFSET, "y": at.y - Gen3MapGrid.MAP_OFFSET}, true)
	avatar.object_id = field_objects.spawn(template, field_objects.camera.number, field_objects.camera.group)
	if avatar.object_id < 0:
		return null
	avatar.object().is_player = true
	Gen3ObjectEvents.set_direction(avatar.object(), direction)
	avatar.set_state_mask(Flag.CONTROLLABLE | Flag.ON_FOOT)
	return avatar


func object() -> Gen3ObjectEvents.ObjectEvent:
	return objects.objects[object_id]


func track_camera() -> void:
	object().tracked_by_camera = true


func graphics_for(state: int) -> int:
	if frlg:
		return int(FRLG_GRAPHICS[state][gender]) if FRLG_GRAPHICS.has(state) else -1
	return int(HOENN_GRAPHICS[state][gender]) if state >= 0 and state < HOENN_GRAPHICS.size() else -1


func set_state_mask(mask: int) -> void:
	flags = ((flags & (Flag.DASH | Flag.FORCED_MOVE | Flag.CONTROLLABLE)) | mask) & 0xFF


## `SetPlayerAvatarTransitionFlags`, after [method open]; FRLG's surf transition skips a player already surfing.
func transition(added: int) -> void:
	_transition_flags |= added
	_do_transition()


func _do_transition() -> void:
	var player: Gen3ObjectEvents.ObjectEvent = object()
	for state: int in State.FIELD_MOVE + 1:
		if not _transition_flags & (1 << state):
			continue
		if state == State.FIELD_MOVE:
			flags |= Flag.CONTROLLABLE
			continue
		var shown: int = State.MACH_BIKE if frlg and state == State.ACRO_BIKE else state
		if frlg and (state == State.UNDERWATER or (state == State.SURFING and flags & Flag.SURFING)):
			continue
		objects.set_graphics_id(player, graphics_for(shown))
		Gen3ObjectEvents.turn(player, player.movement_direction)
		set_state_mask(STATE_FLAGS[shown])
		if state == State.SURFING:
			player.field_effect_sprite = objects.start_surf_blob(object_id, player.current)
			set_surf_bob(Gen3ObjectEvents.Bob.PLAYER_AND_MON)
		elif state == State.UNDERWATER:
			player.field_effect_sprite = objects.start_underwater_bob(object_id)
		elif state != State.NORMAL:
			bike.clear_state()
			if frlg:
				_last_spin_tile = 0
			elif state == State.ACRO_BIKE:
				bike.handle_bumpy_slope_jump()
	_transition_flags = 0


func set_surf_bob(state: int) -> void:
	if not object().field_effect_sprite.is_empty():
		object().field_effect_sprite["bob"] = state


func graphics_by_current_state() -> int:
	for state: int in State.UNDERWATER + 1:
		var graphics: int = graphics_for(state)
		if graphics >= 0 and flags & STATE_FLAGS[state]:
			return graphics
	return 0


func state_flag_by_graphics(graphics: int) -> int:
	for state: int in State.UNDERWATER + 1:
		if graphics_for(state) >= 0 and graphics_for(state) == graphics:
			return STATE_FLAGS[state]
	return Flag.ON_FOOT


## `CheckForPlayerAvatarCollision`: FRLG stairs read the cell being left.
func check_collision(direction: int) -> Dictionary:
	if direction < 1 or direction > 4:
		return _result(Collision.IMPASSABLE)
	var at: Vector2i = object().current
	var behavior: int = objects.camera.grid.behavior_at(at.x, at.y) & 0xFF
	if frlg and behavior in FRLG_STAIR_WARPS.get(direction, []):
		return _result(Collision.DIRECTIONAL_STAIR_WARP)
	at += Gen3FieldCamera.DIRECTIONS[direction]
	return collision_at(object(), at, direction)


## `CheckForObjectEventCollision`, its effects left to [method collide]; Emerald's static query skips them.
func collision_at(probe: Gen3ObjectEvents.ObjectEvent, at: Vector2i, direction: int,
		static_only: bool = false) -> Dictionary:
	if direction < 1 or direction > 4:
		return _result(Collision.IMPASSABLE)
	var collision: int = objects.collision_at(probe, at.x, at.y, direction)
	var grid: Gen3MapGrid = objects.camera.grid
	if not static_only:
		if collision == Collision.ELEVATION_MISMATCH and flags & Flag.SURFING \
				and grid.elevation_at(at.x, at.y) == 3 and objects.at_position(at, 3) < 0:
			return _result(Collision.STOP_SURFING, [{"kind": "stop_surfing", "direction": direction}])
		if ledge_direction(grid.behavior_at(at.x, at.y), direction) != 0:
			return _result(Collision.LEDGE_JUMP, [{"kind": "jumped_ledge"}])
		if collision == Collision.OBJECT_EVENT:
			var boulder: int = _pushable_boulder(at, direction)
			if boulder >= 0:
				return _result(Collision.PUSHED_BOULDER,
					[{"kind": "push_boulder", "object_id": boulder, "direction": direction}])
	if collision == Collision.NONE and not frlg:
		var gate_result: Dictionary = rotating_gate_collision(direction, at, static_only)
		if gate_result["collision"] == Collision.ROTATING_GATE:
			return gate_result
		gate_result["collision"] = int(RAIL_COLLISIONS.get(grid.behavior_at(at.x, at.y), Collision.NONE))
		return gate_result
	return _result(collision)


## `GetLedgeJumpDirection` maps diagonal direction codes back to cardinals.
static func ledge_direction(behavior: int, direction: int) -> int:
	if direction > Gen3ObjectEvents.Direction.EAST:
		direction -= Gen3ObjectEvents.Direction.EAST
	return direction if direction > 0 and direction < LEDGES.size() and (behavior & 0xFF) == LEDGES[direction] else 0


func _pushable_boulder(at: Vector2i, direction: int) -> int:
	if not objects.events.flag_get(Gen3EventData.STRENGTH_FLAG[objects.events.game]):
		return -1
	var slot: int = objects.at_position(at)
	if slot < 0 or objects.objects[slot].graphics_id != (97 if frlg else 87):
		return -1
	var boulder: Gen3ObjectEvents.ObjectEvent = objects.objects[slot]
	var target: Vector2i = boulder.current + Gen3FieldCamera.DIRECTIONS[direction]
	var behavior: int = objects.camera.grid.behavior_at(target.x, target.y)
	# FRLG's fall warp bypasses both ordinary collision and the door test.
	if frlg and behavior == 0x66:
		return slot
	if objects.collision_at(boulder, target.x, target.y, direction) == Collision.NONE and (behavior & 0xFF) != 0x60:
		return slot
	return -1


## `IsPlayerFacingSurfableFishableWater`: FRLG reads terrain attributes, Hoenn the behaviors, waterfalls excluded.
func facing_fishable_water() -> bool:
	var player: Gen3ObjectEvents.ObjectEvent = object()
	if player.facing < 1 or player.facing > 4:
		return false
	var at: Vector2i = player.current + Gen3FieldCamera.DIRECTIONS[player.facing]
	if player.previous_elevation != 3 \
			or objects.collision_at(player, at.x, at.y, player.facing) != Collision.ELEVATION_MISMATCH:
		return false
	var grid: Gen3MapGrid = objects.camera.grid
	if frlg:
		return grid.terrain_at(at.x, at.y) == TERRAIN_WATER
	return grid.behavior_at(at.x, at.y) in HOENN_FISHABLE


static func _result(collision: int, requests: Array = []) -> Dictionary:
	return {"collision": collision, "requests": requests}


## `UpdatePlayerAvatarTransitionState`, before [method step]: a step's last frame, and a turn's, is `T_TILE_CENTER`.
func update_tile_state() -> void:
	var player: Gen3ObjectEvents.ObjectEvent = object()
	tile_state = Tile.NOT_MOVING
	if not Gen3ObjectEvents.movement_overridden(player):
		return
	var stationary: bool = _stationary(player.movement_action)
	if Gen3ObjectEvents.held_movement_status(player) == 0:
		if not stationary:
			tile_state = Tile.TRANSITION
	elif not stationary or running_state == Running.TURN_DIRECTION:
		tile_state = Tile.CENTER


func _stationary(action_id: int) -> bool:
	var game: StringName = &"firered" if frlg else (&"emerald" if objects.events.game == RomRegistry.EMERALD else &"ruby")
	for span: Array in STATIONARY[game]:
		if action_id >= int(span[0]) and action_id <= int(span[1]):
			return true
	return false


## `PlayerStep` for the d-pad's `DIR_*` and the GBA key masks; its warp arrow awaits the warp model.
func step(direction: int, new_keys: int, held_keys: int) -> Array:
	var requests: Array = []
	var player: Gen3ObjectEvents.ObjectEvent = object()
	if prevent_step or (frlg and _continue_spin(requests)):
		return requests
	if not frlg:
		bike.update_history(held_keys)
	if _special_anim_holds(player, direction):
		return requests
	player.inanimate = false
	player.disable_anim = false
	player.facing_locked = false
	flags &= ~Flag.DASH
	_do_transition()
	if _forced_movement(requests):
		return requests
	if flags & (Flag.MACH_BIKE | Flag.ACRO_BIKE):
		bike.move(direction, new_keys, held_keys, requests)
	else:
		_move_on_foot(direction, held_keys, requests)
	if running_state == Running.MOVING:
		flags &= ~Flag.CONTROLLABLE
	return requests


## `TryInterruptObjectEventSpecialAnim`: a bump yields to a new direction, Emerald's also to an open cell ahead.
func _special_anim_holds(player: Gen3ObjectEvents.ObjectEvent, direction: int) -> bool:
	if not Gen3ObjectEvents.movement_overridden(player) or Gen3ObjectEvents.clear_held_movement_if_finished(player) != 0:
		return false
	var bump: int = action(&"in_place_slow", Gen3ObjectEvents.Direction.SOUTH)
	if not player.held_movement_active or player.movement_action < bump or player.movement_action > bump + 3:
		return true
	if objects.events.game == RomRegistry.EMERALD:
		if direction == 0 or (player.movement_direction == direction and collision_at(player,
				player.current + Gen3FieldCamera.DIRECTIONS[direction], direction, true)["collision"] != Collision.NONE):
			return true
	elif direction == 0 or player.movement_direction == direction:
		return true
	Gen3ObjectEvents.clear_held_movement(player)
	return false


## `TryDoMetatileBehaviorForcedMovement`: once a step has cleared `CONTROLLABLE`, the cell stood on moves the player.
func _forced_movement(requests: Array) -> bool:
	var behavior: int = object().current_behavior
	var table: Dictionary = FRLG_FORCED if frlg else HOENN_FORCED
	if flags & Flag.CONTROLLABLE or not table.has(behavior):
		cancel_forced_movement()
		return false
	if frlg:
		_last_spin_tile = behavior
	return _force(table[behavior], requests)


func _force(row: Array, requests: Array) -> bool:
	var player: Gen3ObjectEvents.ObjectEvent = object()
	var direction: int = int(row[1])
	match int(row[0]):
		Forced.SLIP:
			player.disable_anim = true
			return _forced_step(player.movement_direction, &"walk_fast", requests)
		Forced.WALK:
			return _forced_step(direction, &"walk_normal", requests)
		Forced.CURRENT:
			return _forced_step(direction, &"ride_current", requests)
		Forced.SLIDE:
			player.disable_anim = true
			player.facing_locked = true
			return _forced_step(direction, &"walk_fast", requests)
		Forced.SPIN:
			requests.append({"kind": "sound", "name": "m_razor_wind2"})
			return _forced_step(direction, &"spin", requests)
		Forced.MAT_JUMP, Forced.MAT_SPIN:
			_start_mat(int(row[0]) == Forced.MAT_SPIN, requests)
			return true
	if player.movement_direction == Gen3ObjectEvents.Direction.NORTH and bike.player_speed() >= Gen3Bike.Speed.FASTEST:
		return false
	bike.update_counter_speed(0)
	player.facing_locked = true
	return _forced_step(Gen3ObjectEvents.Direction.SOUTH, &"walk_fast", requests)


## `DoForcedMovement`: a wall ends the forced movement, while a ledge or a task-starting collision keeps it.
func _forced_step(direction: int, family: StringName, requests: Array) -> bool:
	var collision: int = collide(check_collision(direction), direction, requests)
	flags |= Flag.FORCED_MOVE
	if collision != Collision.NONE:
		cancel_forced_movement()
		if collision < Collision.STOP_SURFING:
			return false
		if collision == Collision.LEDGE_JUMP:
			jump_ledge(direction, requests)
		flags |= Flag.FORCED_MOVE
	else:
		set_anim(action(family, direction), Copy.SPIN if family == &"spin" else Copy.WALK)
	running_state = Running.MOVING
	return true


## FRLG's `TryUpdatePlayerSpinDirection`: a spinning player takes each spin tile's turn until a stop tile.
func _continue_spin(requests: Array) -> bool:
	if not flags & Flag.FORCED_MOVE or int(FRLG_FORCED.get(_last_spin_tile, [-1])[0]) != Forced.SPIN:
		return false
	var player: Gen3ObjectEvents.ObjectEvent = object()
	if player.held_movement_finished:
		if player.current_behavior == MB_STOP_SPINNING:
			return false
		if int(FRLG_FORCED.get(player.current_behavior, [-1])[0]) == Forced.SPIN:
			_last_spin_tile = player.current_behavior
		Gen3ObjectEvents.clear_held_movement(player)
		_force(FRLG_FORCED[_last_spin_tile], requests)
	return true


## `MovePlayerNotOnBike`: Emerald bumps Faraway Island's Mew silently, and FRLG faces a stair warp.
func _move_on_foot(direction: int, held_keys: int, requests: Array) -> void:
	var player: Gen3ObjectEvents.ObjectEvent = object()
	if direction == 0:
		running_state = Running.NOT_MOVING
		face(player.facing)
		return
	if direction != player.movement_direction and running_state != Running.MOVING:
		running_state = Running.TURN_DIRECTION
		set_anim(action(&"in_place_fast", direction), Copy.FACE)
		return
	running_state = Running.MOVING
	var collision: int = collide(check_collision(direction), direction, requests)
	if collision == Collision.LEDGE_JUMP:
		jump_ledge(direction, requests)
	elif collision == Collision.OBJECT_EVENT and colliding_with_mew(direction):
		set_anim(action(&"in_place_slow", direction), Copy.WALK)
	elif frlg and collision == Collision.DIRECTIONAL_STAIR_WARP:
		face(direction)
	elif collision != Collision.NONE:
		if collision < Collision.STOP_SURFING or collision > Collision.ROTATING_GATE:
			collision_sound(direction, requests)
			set_anim(action(&"in_place_slow", direction), Copy.WALK)
	elif flags & Flag.SURFING:
		set_anim(action(&"walk_fast", direction), Copy.WALK)
	elif (frlg or not flags & Flag.UNDERWATER) and held_keys & Gen3Bike.KEY_B \
			and objects.events.flag_get(FLAG_SYS_B_DASH[objects.events.game]) \
			and not _running_disallowed(player.current_behavior):
		set_anim(action(&"run_slow" if on_rock_stairs(direction) else &"run", direction), Copy.WALK)
		flags |= Flag.DASH
	else:
		set_anim(action(&"walk_slow" if on_rock_stairs(direction) else &"walk_normal", direction), Copy.WALK)


## `IsRunningDisallowed`; Ruby's reads the indoor map type where the others read the header's running flag.
func _running_disallowed(behavior: int) -> bool:
	var header: Dictionary = objects.camera.header
	if objects.events.game in [RomRegistry.RUBY, RomRegistry.SAPPHIRE]:
		return running_disallowed_by_behavior(behavior) or int(header.get("map_type", 0)) == MAP_TYPE_INDOOR
	return not header.get("allow_running", false) or running_disallowed_by_behavior(behavior)


## `IsRunningDisallowedByMetatile` (FRLG's `MetatileBehaviorForbidsBiking`): Fortree's bridges only from below.
func running_disallowed_by_behavior(behavior: int) -> bool:
	if frlg:
		return behavior == FRLG_NO_RUNNING
	return behavior in HOENN_NO_RUNNING or (behavior == MB_FORTREE_BRIDGE and object().previous_elevation & 1 == 0)


## FRLG's `PlayerIsMovingOnRockStairs`: up from a stair cell or down onto one.
func on_rock_stairs(direction: int) -> bool:
	if not frlg or direction not in [Gen3ObjectEvents.Direction.NORTH, Gen3ObjectEvents.Direction.SOUTH]:
		return false
	var at: Vector2i = object().current
	if direction == Gen3ObjectEvents.Direction.SOUTH:
		at += Gen3FieldCamera.DIRECTIONS[direction]
	return objects.camera.grid.behavior_at(at.x, at.y) & 0xFF == MB_ROCK_STAIRS


## Emerald's `IsPlayerCollidingWithFarawayIslandMew`: Mew stepping out of the cell ahead.
func colliding_with_mew(direction: int) -> bool:
	if objects.events.game != RomRegistry.EMERALD:
		return false
	var map: Vector2i = Gen3CutGrass.FARAWAY_ISLAND_INTERIOR
	var mew: Gen3ObjectEvents.ObjectEvent = objects.by_identity(LOCALID_FARAWAY_ISLAND_MEW, map.y, map.x)
	return mew != null and mew.current != mew.previous \
		and mew.previous == object().current + Gen3FieldCamera.DIRECTIONS[direction]


## `CheckForObjectEventCollision`'s effects: the ledge stat, the dismount and push tasks, a turned gate's request.
func collide(result: Dictionary, direction: int, requests: Array) -> int:
	for request: Dictionary in result["requests"]:
		match request["kind"]:
			"jumped_ledge":
				objects.events.increment_stat(GAME_STAT_JUMPED_DOWN_LEDGES)
			"stop_surfing":
				_start_stop_surfing(direction, requests)
			"push_boulder":
				_boulder_id = int(request["object_id"])
				_task_direction = direction
				prevent_step = true
				objects.events.controls_locked = true
				task = Task.PUSH_WAIT
			_:
				requests.append(request)
	return int(result["collision"])


func _start_stop_surfing(direction: int, requests: Array) -> void:
	_task_direction = direction
	prevent_step = true
	objects.events.controls_locked = true
	flags = (flags & ~Flag.SURFING) | Flag.ON_FOOT
	if frlg:
		objects.freeze_except_player()
	requests.append({"kind": "restore_field_music"})
	task = Task.SURF_WAIT
	_start_dismount(requests)


## `PlayCollisionSoundIfNotFacingWarp`: silent from an arrow or FRLG stair warp, and into a door to the north.
func collision_sound(direction: int, requests: Array) -> void:
	var behavior: int = object().current_behavior
	var arrows: Array = [[0x65], [0x64], [0x63], [0x62]] if frlg else HOENN_ARROW_WARPS
	if behavior in arrows[direction - 1] or (frlg and behavior in FRLG_STAIR_WARPS.get(direction, [])):
		return
	if direction == Gen3ObjectEvents.Direction.NORTH:
		var at: Vector2i = object().current + Gen3FieldCamera.DIRECTIONS[direction]
		if objects.camera.grid.behavior_at(at.x, at.y) & 0xFF == MB_WARP_DOOR:
			return
	requests.append({"kind": "sound", "name": "wall_hit"})


func action(family: StringName, direction: int) -> int:
	return Gen3ObjectEvents.direction_action(int(ACTIONS[family][int(frlg)]), direction)


func set_anim(action_id: int, copy: int) -> void:
	if not Gen3ObjectEvents.movement_overridden(object()):
		object().player_copyable_movement = copy
		objects.set_held_movement(object(), action_id)


func face(direction: int) -> void:
	set_anim(action(&"face", direction), Copy.FACE)


func jump_ledge(direction: int, requests: Array) -> void:
	requests.append({"kind": "sound", "name": "ledge"})
	set_anim(action(&"jump_2", direction), Copy.JUMP_2)


## `DoPlayerMatJump` and `DoPlayerMatSpin`, whose tasks take their first turn at once.
func _start_mat(spin: bool, requests: Array) -> void:
	_mat_count = 0
	task = Task.MAT_JUMP
	if spin:
		_task_direction = object().movement_direction
		prevent_step = true
		objects.events.controls_locked = true
		requests.append({"kind": "sound", "name": "warp_in"})
		task = Task.MAT_SPIN_TURN
	_step_mat(requests)


## The jump mat hops twice in place. The spin mat turns the player a lap at a time, pausing longer after each,
## until the fourth lap faces it away; it then backs off the mat.
func _step_mat(requests: Array) -> void:
	var player: Gen3ObjectEvents.ObjectEvent = object()
	if task == Task.MAT_JUMP:
		prevent_step = true
	if Gen3ObjectEvents.clear_held_movement_if_finished(player) == 0:
		return
	match task:
		Task.MAT_JUMP:
			requests.append({"kind": "sound", "name": "ledge"})
			objects.set_held_movement(player, action(&"jump_in_place", player.facing))
			_mat_count += 1
			if _mat_count > 1:
				prevent_step = false
				_transition_flags |= Flag.CONTROLLABLE
				task = Task.NONE
		Task.MAT_SPIN_TURN:
			var turned: int = MAT_SPIN_TURNS[player.movement_direction - 1]
			objects.set_held_movement(player, action(&"face", turned))
			if turned == _task_direction:
				_mat_count += 1
			task = Task.MAT_SPIN_DELAY
			if _mat_count > 3 and turned == Gen3ObjectEvents.OPPOSITE[_task_direction]:
				task = Task.MAT_SPIN_LEAVE
		Task.MAT_SPIN_DELAY:
			objects.set_held_movement(player, MAT_SPIN_DELAYS[_mat_count])
			task = Task.MAT_SPIN_TURN
		Task.MAT_SPIN_LEAVE:
			objects.set_held_movement(player, action(&"walk_slow", Gen3ObjectEvents.OPPOSITE[_task_direction]))
			objects.events.controls_locked = false
			prevent_step = false
			task = Task.NONE


## `RunTasks` after [method step] and [method Gen3TrainerSee.run_tasks], then [method Gen3ObjectEvents.step_movements]
## with the dash flag and `T_TILE_CENTER`; the show-mon task, created after these, runs last.
func step_movement_tasks() -> Array:
	var requests: Array = []
	match task:
		Task.PUSH_WAIT:
			_start_push(requests)
		Task.PUSH_MOVE:
			_finish_push(requests)
		Task.SURF_WAIT:
			_start_dismount(requests)
		Task.SURF_JUMP:
			_finish_dismount(requests)
		Task.MOUNT_INIT, Task.MOUNT_POSE, Task.MOUNT_SHOW_MON, Task.MOUNT_JUMP, Task.MOUNT_END:
			_step_mount(requests)
		Task.MOVE_INIT, Task.MOVE_POSE, Task.MOVE_SHOW_MON, Task.MOVE_RUN:
			_step_field_move(requests)
		Task.WATERFALL_SHOW_MON, Task.WATERFALL_WAIT, Task.WATERFALL_RIDE:
			_step_waterfall()
		Task.MAT_JUMP, Task.MAT_SPIN_TURN, Task.MAT_SPIN_DELAY, Task.MAT_SPIN_LEAVE:
			_step_mat(requests)
	objects.field_move_mon.run_task()
	return requests


## `ForcedMovement_None`, behind `CancelPlayerForcedMovement`.
func cancel_forced_movement() -> void:
	if flags & Flag.FORCED_MOVE:
		object().facing_locked = false
		object().enable_anim = true
		Gen3ObjectEvents.set_direction(object(), object().facing)
		flags &= ~Flag.FORCED_MOVE


## Emerald's `PushBoulder_Move` clears finished holds before the override test; the others' `DoBoulderDust` does not.
func _start_push(requests: Array) -> void:
	var player: Gen3ObjectEvents.ObjectEvent = object()
	var boulder: Gen3ObjectEvents.ObjectEvent = objects.objects[_boulder_id]
	if objects.events.game == RomRegistry.EMERALD:
		Gen3ObjectEvents.clear_held_movement_if_finished(player)
		Gen3ObjectEvents.clear_held_movement_if_finished(boulder)
	if Gen3ObjectEvents.movement_overridden(player) or Gen3ObjectEvents.movement_overridden(boulder):
		return
	Gen3ObjectEvents.clear_held_movement_if_finished(player)
	Gen3ObjectEvents.clear_held_movement_if_finished(boulder)
	objects.set_held_movement(player, Gen3ObjectEvents.direction_action(0x25 if frlg else 0x1D, _task_direction))
	objects.set_held_movement(boulder, Gen3ObjectEvents.direction_action(0x08 if frlg else 0x04, _task_direction))
	objects.start_effect_sprite(boulder, _boulder_id, Gen3ObjectEvents.FLDEFF_DUST, -1, false, requests)
	requests.append({"kind": "sound", "name": "strength"})
	task = Task.PUSH_MOVE


func _finish_push(requests: Array) -> void:
	var player: Gen3ObjectEvents.ObjectEvent = object()
	var boulder: Gen3ObjectEvents.ObjectEvent = objects.objects[_boulder_id]
	if Gen3ObjectEvents.held_movement_status(player) == 0 or Gen3ObjectEvents.held_movement_status(boulder) == 0:
		return
	Gen3ObjectEvents.clear_held_movement_if_finished(player)
	Gen3ObjectEvents.clear_held_movement_if_finished(boulder)
	requests.append_array(objects.boulder_landing(boulder))
	prevent_step = false
	objects.events.controls_locked = false
	task = Task.NONE


func _start_dismount(requests: Array) -> void:
	if Gen3ObjectEvents.movement_overridden(object()) \
			and Gen3ObjectEvents.clear_held_movement_if_finished(object()) == 0:
		return
	set_surf_bob(Gen3ObjectEvents.Bob.JUST_MON)
	objects.set_held_movement(object(), Gen3ObjectEvents.direction_action(0xA6 if frlg else 0x3A, _task_direction))
	task = Task.SURF_JUMP


func _finish_dismount(requests: Array) -> void:
	if Gen3ObjectEvents.clear_held_movement_if_finished(object()) == 0:
		return
	objects.set_graphics_id(object(), graphics_for(State.NORMAL))
	objects.set_held_movement(object(), Gen3ObjectEvents.direction_action(0, object().facing))
	prevent_step = false
	objects.events.controls_locked = false
	if frlg:
		objects.unfreeze_all()
		requests.append({"kind": "refresh_help_context"})
	objects.destroy_effect_sprite(object().field_effect_sprite)
	object().field_effect_sprite = {}
	task = Task.NONE


## `FldEff_UseSurf`; the request is `Overworld_ChangeMusicTo(MUS_SURF)`, which FRLG may skip for the map's music.
func use_surf(species: int, personality: int, ot_id: int) -> Array:
	_shown_mon = [species, personality, ot_id]
	task = Task.MOUNT_INIT
	objects.task_effects.append(FLDEFF_USE_SURF)
	return [{"kind": "surf_music"}]


## `Task_SurfFieldEffect`: pose, show the mon, then jump onto the blob in front.
func _step_mount(requests: Array) -> void:
	var player: Gen3ObjectEvents.ObjectEvent = object()
	match task:
		Task.MOUNT_INIT:
			objects.events.controls_locked = true
			objects.freeze_except_player()
			prevent_step = true
			set_state_mask(Flag.SURFING)
			_mount_cell = player.current + Gen3FieldCamera.DIRECTIONS[player.movement_direction]
			task = Task.MOUNT_POSE
		Task.MOUNT_POSE:
			if Gen3ObjectEvents.movement_overridden(player) \
					and Gen3ObjectEvents.clear_held_movement_if_finished(player) == 0:
				return
			_start_pose()
			task = Task.MOUNT_SHOW_MON
		Task.MOUNT_SHOW_MON:
			if Gen3ObjectEvents.held_movement_status(player) == 0:
				return
			_show_mon(true)
			task = Task.MOUNT_JUMP
		Task.MOUNT_JUMP:
			if objects.field_effect_active(Gen3ObjectEvents.FLDEFF_FIELD_MOVE_SHOW_MON):
				return
			objects.set_graphics_id(player, graphics_for(State.SURFING))
			Gen3ObjectEvents.clear_held_movement_if_finished(player)
			objects.set_held_movement(player, Gen3ObjectEvents.direction_action(0x46 if frlg else 0x3A,
				player.movement_direction))
			player.field_effect_sprite = objects.start_surf_blob(object_id, _mount_cell)
			task = Task.MOUNT_END
		Task.MOUNT_END:
			_finish_mount(requests)


## `SetPlayerAvatarFieldMove` (FRLG's `StartPlayerAvatarSummonMonForFieldMoveAnim`) held in its direction.
func _start_pose() -> void:
	objects.set_graphics_id(object(), graphics_for(State.FIELD_MOVE))
	object().anim.start(0)
	objects.set_held_movement(object(), 0x45 if frlg else Gen3ObjectEvents.START_ANIM_IN_DIRECTION)


func _show_mon(no_ducking: bool) -> void:
	objects.field_move_mon.start(int(_shown_mon[0]), int(_shown_mon[1]), int(_shown_mon[2]),
		int(objects.camera.header["map_type"]) in Gen3ObjectEvents.OUTDOOR_MAP_TYPES, no_ducking)


## `CreateFieldMoveTask` (FRLG's `CreateFieldEffectShowMon`); false for an effect whose move function is not modeled.
func use_field_move(effect: int, species: int, personality: int, ot_id: int) -> bool:
	if not FIELD_MOVE_STATS.has(effect):
		return false
	if FIELD_MOVE_STATS[effect] >= 0:
		objects.events.increment_stat(FIELD_MOVE_STATS[effect])
	_field_move = effect
	_shown_mon = [species, personality, ot_id]
	task = Task.MOVE_INIT
	objects.task_effects.append(effect)
	return true


## `Task_DoFieldMove_*`: underwater skips the pose; afterwards the player faces the same way in its state's graphics.
func _step_field_move(requests: Array) -> void:
	var player: Gen3ObjectEvents.ObjectEvent = object()
	match task:
		Task.MOVE_INIT:
			objects.events.controls_locked = true
			prevent_step = true
			if Gen3ObjectEvents.movement_overridden(player) \
					and Gen3ObjectEvents.clear_held_movement_if_finished(player) == 0:
				return
			if int(objects.camera.header["map_type"]) == MAP_TYPE_UNDERWATER:
				_show_mon(false)
				task = Task.MOVE_SHOW_MON
			else:
				_start_pose()
				task = Task.MOVE_POSE
		Task.MOVE_POSE:
			if Gen3ObjectEvents.held_movement_status(player) == 1:
				_show_mon(false)
				task = Task.MOVE_SHOW_MON
		Task.MOVE_SHOW_MON:
			if objects.field_effect_active(Gen3ObjectEvents.FLDEFF_FIELD_MOVE_SHOW_MON):
				return
			objects.set_graphics_id(player, graphics_by_current_state())
			if player.facing >= 1 and player.facing <= 4:
				player.anim.start(player.facing - 1)
			task = Task.MOVE_RUN
		Task.MOVE_RUN:
			objects.task_effects.erase(_field_move)
			match _field_move:
				Gen3CutGrass.FLDEFF_USE_CUT_ON_GRASS:
					requests.append_array(objects.cut_grass.start(player))
				FLDEFF_USE_STRENGTH:
					requests.append_array(_start_strength())
				_:
					requests.append_array([{"kind": "sound", "name": FIELD_MOVE_SOUNDS[_field_move]}, {"kind": "script_enable"}])
			prevent_step = false
			task = Task.NONE


## `StartStrengthFieldEffect`; Ruby's braille branch opens the chamber and unlocks the field without the script.
func _start_strength() -> Array:
	var events: Gen3EventData = objects.events
	if events.game not in [RomRegistry.RUBY, RomRegistry.SAPPHIRE] or events.flag_get(FLAG_SYS_BRAILLE_STRENGTH) \
			or Vector2i(objects.camera.group, objects.camera.number) != DESERT_RUINS \
			or object().current not in DESERT_RUINS_SPOTS:
		return [{"kind": "script_enable"}]
	for cell: Vector2i in SEALED_CHAMBER_ENTRANCE:
		objects.camera.grid.set_metatile_id(cell.x, cell.y, SEALED_CHAMBER_ENTRANCE[cell])
	events.flag_set(FLAG_SYS_BRAILLE_STRENGTH)
	events.controls_locked = false
	return [{"kind": "sound", "name": "bang"}]


func use_waterfall(species: int, personality: int, ot_id: int) -> void:
	_shown_mon = [species, personality, ot_id]
	objects.events.controls_locked = true
	prevent_step = true
	task = Task.WATERFALL_SHOW_MON
	objects.task_effects.append(FLDEFF_USE_WATERFALL)


## `Task_UseWaterfall`, Init run by [method use_waterfall]: the banner unposed, then slow steps north over the falls.
func _step_waterfall() -> void:
	var player: Gen3ObjectEvents.ObjectEvent = object()
	match task:
		Task.WATERFALL_SHOW_MON:
			objects.events.controls_locked = true
			if Gen3ObjectEvents.movement_overridden(player):
				return
			Gen3ObjectEvents.clear_held_movement_if_finished(player)
			_show_mon(false)
			task = Task.WATERFALL_WAIT
		Task.WATERFALL_WAIT:
			if not objects.field_effect_active(Gen3ObjectEvents.FLDEFF_FIELD_MOVE_SHOW_MON):
				_ride_up()
		Task.WATERFALL_RIDE:
			if Gen3ObjectEvents.clear_held_movement_if_finished(player) == 0:
				return
			if player.current_behavior == MB_WATERFALL:
				_ride_up()
				return
			objects.events.controls_locked = false
			prevent_step = false
			objects.task_effects.erase(FLDEFF_USE_WATERFALL)
			task = Task.NONE


func _ride_up() -> void:
	objects.set_held_movement(object(), Gen3ObjectEvents.direction_action(0x08 if frlg else 0x04,
		Gen3ObjectEvents.Direction.NORTH))
	task = Task.WATERFALL_RIDE


func _finish_mount(requests: Array) -> void:
	var player: Gen3ObjectEvents.ObjectEvent = object()
	if Gen3ObjectEvents.clear_held_movement_if_finished(player) == 0:
		return
	prevent_step = false
	flags &= ~Flag.CONTROLLABLE
	objects.set_held_movement(player, Gen3ObjectEvents.direction_action(0, player.movement_direction))
	set_surf_bob(Gen3ObjectEvents.Bob.PLAYER_AND_MON)
	objects.unfreeze_all()
	objects.events.controls_locked = false
	objects.task_effects.erase(FLDEFF_USE_SURF)
	if frlg:
		requests.append({"kind": "refresh_help_context"})
	task = Task.NONE


## `RotatingGate_InitPuzzle` resets bytes in temp vars; graphics initialization reloads without resetting them.
func load_rotating_gates(reset: bool = false) -> void:
	_gate_map = "%d:%d" % [objects.camera.group, objects.camera.number]
	_gates = []
	if frlg:
		return
	var configs: Dictionary = EMERALD_GATES if objects.events.game == RomRegistry.EMERALD else RS_GATES
	_gates = configs.get(_gate_map, [])
	if reset:
		for gate: int in _gates.size():
			_set_gate_orientation(gate, int(_gates[gate][3]))


func gate_orientation(gate: int) -> int:
	var word: int = objects.events.var_get(Gen3EventData.VARS_START + gate / 2)
	return (word >> ((gate % 2) * 8)) & 0xFF


func _set_gate_orientation(gate: int, orientation: int) -> void:
	var id: int = Gen3EventData.VARS_START + gate / 2
	var shift: int = (gate % 2) * 8
	objects.events.var_set(id, (objects.events.var_get(id) & ~(0xFF << shift)) | ((orientation & 0xFF) << shift))


func rotating_gate_collision(direction: int, at: Vector2i, static_only: bool = false) -> Dictionary:
	if direction < 1 or direction > 4 or _gate_map != "%d:%d" % [objects.camera.group, objects.camera.number]:
		return _result(Collision.NONE)
	for gate: int in _gates.size():
		var row: Array = _gates[gate]
		var center := Vector2i(int(row[0]), int(row[1])) + Vector2i.ONE * Gen3MapGrid.MAP_OFFSET
		var relative: Vector2i = at - center + Vector2i(2, 2)
		if relative.x < 0 or relative.x > 3 or relative.y < 0 or relative.y > 3:
			continue
		var info: int = int(GATE_ROTATIONS[direction].get(relative.y * 4 + relative.x, 0xFF))
		if info == 0xFF or not _gate_has_arm(gate, info & 0xF):
			continue
		var rotation: int = info >> 4
		if not _gate_can_rotate(gate, center, rotation):
			return _result(Collision.ROTATING_GATE)
		if not static_only:
			var orientation: int = gate_orientation(gate)
			var next: int = ((orientation + 1) & 0xFF) % 4
			if rotation == 1:
				next = orientation - 1 if orientation != 0 else 3
			_set_gate_orientation(gate, next)
			return _result(Collision.NONE, [{"kind": "rotate_gate", "gate": gate,
				"orientation": orientation, "rotation": rotation}])
	return _result(Collision.NONE)


func _gate_has_arm(gate: int, info: int) -> bool:
	var arm: int = (info / 2 - gate_orientation(gate) + 4) % 4
	return arm >= 0 and int(GATE_ARMS[int(_gates[gate][2])][arm * 2 + info % 2]) != 0


## `RotatingGate_CanRotate` blocks collision 1 only, its bug letting arms through collision 2 or 3.
func _gate_can_rotate(gate: int, center: Vector2i, rotation: int) -> bool:
	var arms: Array = GATE_ARMS[int(_gates[gate][2])]
	for arm: int in arms.size():
		if int(arms[arm]) == 0:
			continue
		var index: int = (arm / 2 + gate_orientation(gate)) % 4 * 2 + arm % 2
		var at: Vector2i = center + GATE_SWEEPS[rotation][index]
		if objects.camera.grid.collision_at(at.x, at.y) == 1:
			return false
	return true
