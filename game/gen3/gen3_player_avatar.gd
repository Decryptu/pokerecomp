class_name Gen3PlayerAvatar
extends RefCounted

## `field_player_avatar.c`: initialization, state queries and collision
## decisions. Collision effects are returned as requests for the movement host;
## movement tasks, sprites and Hoenn's rotating-gate puzzles are not modeled.

enum Flag { ON_FOOT = 1, MACH_BIKE = 2, ACRO_BIKE = 4, SURFING = 8,
	UNDERWATER = 16, CONTROLLABLE = 32, FORCED_MOVE = 64, DASH = 128 }
enum State { NORMAL, MACH_BIKE, ACRO_BIKE, SURFING, UNDERWATER, FIELD_MOVE, FISHING, WATERING, VS_SEEKER }
enum Collision { NONE, OUTSIDE_RANGE, IMPASSABLE, ELEVATION_MISMATCH, OBJECT_EVENT,
	STOP_SURFING, LEDGE_JUMP, PUSHED_BOULDER, DIRECTIONAL_STAIR_WARP, WHEELIE_HOP,
	ISOLATED_VERTICAL_RAIL, ISOLATED_HORIZONTAL_RAIL, VERTICAL_RAIL, HORIZONTAL_RAIL }
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

var objects: Gen3ObjectEvents
var object_id: int = -1
var gender: int = 0
var flags: int = 0
var _frlg: bool = false


## `InitPlayerAvatar` takes backup coordinates. The slot is reserved before
## spawning map objects, as `InitObjectEventsLocal` does. Null on a full pool or
## a duplicate player, rather than the cartridge's out-of-bounds write.
static func open(field_objects: Gen3ObjectEvents, at: Vector2i, direction: int, player_gender: int) -> Gen3PlayerAvatar:
	if player_gender not in [0, 1] or direction < 0 or direction > 4:
		return null
	var avatar := Gen3PlayerAvatar.new()
	avatar.objects = field_objects
	avatar.gender = player_gender
	avatar._frlg = field_objects.camera.data.id in [RomRegistry.FIRERED, RomRegistry.LEAFGREEN]
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


## `SetCameraToTrackPlayer` follows initialization in `overworld.c`.
func track_camera() -> void:
	object().tracked_by_camera = true


func graphics_for(state: int) -> int:
	if _frlg:
		return int(FRLG_GRAPHICS[state][gender]) if FRLG_GRAPHICS.has(state) else -1
	return int(HOENN_GRAPHICS[state][gender]) if state >= 0 and state < HOENN_GRAPHICS.size() else -1


## `SetPlayerAvatarStateMask` preserves control, forced movement and dash.
func set_state_mask(mask: int) -> void:
	flags = ((flags & (Flag.DASH | Flag.FORCED_MOVE | Flag.CONTROLLABLE)) | mask) & 0xFF


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
	if _frlg and ((direction == Gen3ObjectEvents.Direction.WEST and behavior in [0x6D, 0x6F])
			or (direction == Gen3ObjectEvents.Direction.EAST and behavior in [0x6C, 0x6E])):
		return _result(Collision.DIRECTIONAL_STAIR_WARP)
	at += Gen3FieldCamera.DIRECTIONS[direction]
	return collision_at(object(), at, direction)


## `CheckForObjectEventCollision`. Emerald's static query skips dismounts,
## ledges and boulders. The host owns the resulting tasks and game statistics.
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
	if collision == Collision.NONE and not _frlg:
		collision = int(RAIL_COLLISIONS.get(grid.behavior_at(at.x, at.y), Collision.NONE))
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
	if slot < 0 or objects.objects[slot].graphics_id != (97 if _frlg else 87):
		return -1
	var boulder: Gen3ObjectEvents.ObjectEvent = objects.objects[slot]
	var target: Vector2i = boulder.current + Gen3FieldCamera.DIRECTIONS[direction]
	var behavior: int = objects.camera.grid.behavior_at(target.x, target.y)
	# FRLG's fall warp bypasses both ordinary collision and the door test.
	if _frlg and behavior == 0x66:
		return slot
	if objects.collision_at(boulder, target.x, target.y, direction) == Collision.NONE and (behavior & 0xFF) != 0x60:
		return slot
	return -1


## `IsPlayerFacingSurfableFishableWater`: FRLG reads terrain attributes;
## Hoenn reads the behavior predicates, which exclude waterfalls.
func facing_fishable_water() -> bool:
	var player: Gen3ObjectEvents.ObjectEvent = object()
	if player.facing < 1 or player.facing > 4:
		return false
	var at: Vector2i = player.current + Gen3FieldCamera.DIRECTIONS[player.facing]
	if player.previous_elevation != 3 \
			or objects.collision_at(player, at.x, at.y, player.facing) != Collision.ELEVATION_MISMATCH:
		return false
	var grid: Gen3MapGrid = objects.camera.grid
	if _frlg:
		var attributes: int = grid.attributes_at(at.x, at.y)
		return attributes >= 0 and ((attributes >> 9) & 0x1F) == 2
	return grid.behavior_at(at.x, at.y) in HOENN_FISHABLE


static func _result(collision: int, requests: Array = []) -> Dictionary:
	return {"collision": collision, "requests": requests}
