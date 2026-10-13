class_name Gen3ObjectEvents
extends RefCounted

## `event_object_movement.c`, in backup coordinates; sprites and generated facility templates remain unmodeled.

const COUNT: int = 16
const TEMPLATES_COUNT: int = 64
const LOCALID_PLAYER: int = 0xFF
const MAP_UNDEFINED: int = 0xFF
const OBJ_KIND_CLONE: int = 255
const OBJ_EVENT_GFX_VARS: int = 240
const VAR_OBJ_GFX_ID_0: int = 0x4010
## `TrySpawnObjectEvents`' margins around the view, in cells.
const VIEW_LEFT: int = 2
const VIEW_RIGHT: int = Gen3MapGrid.OFFSET_W + 2
const VIEW_BOTTOM: int = Gen3MapGrid.OFFSET_H + 2
const ELEVATION_MULTI_LEVEL: int = 15
## Emerald's Battle Pyramid floor and top spawn the templates before the first
## empty one, at most [constant COUNT]; Trainer Hill's four floors spawn two.
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
enum Motion { FACE, WALK, IN_PLACE, JUMP, DELAY, LOCK, UNLOCK, CONTEXT_FACE, SET_FLAG, EMOTE }
enum Facing { PLAYER, AWAY_PLAYER, ORIGINAL }
enum ObjectFlag { LANDING_EFFECT, INVISIBLE, FIXED_PRIORITY }
enum Jump { FAR, SPECIAL, NORMAL, IN_PLACE, TURN }
enum Pace { SLOW, NORMAL, FAST, CURRENT, FASTER, SLIDE, FRLG_SLOW }
const STEP_PIXELS: Array = [[1, 0], [1], [2], [2, 3, 3, 2, 3, 3], [4], [8], [1, 1, 0]]
const STEP_FRAMES: Array[int] = [31, 16, 8, 6, 4, 2, 23]
const JUMP_Y: Array = [
	[-4, -6, -8, -10, -11, -12, -12, -12, -11, -10, -9, -8, -6, -4, 0, 0],
	[-2, -4, -6, -8, -9, -10, -10, -10, -9, -8, -6, -5, -3, -2, 0, 0],
]
## `MOVEMENT_ACTION_*`: [Hoenn id, FRLG id, motion, parameter].
const MOTION_FAMILIES: Array = [
	[0x00, 0x00, Motion.FACE, 0], [0x04, 0x0C, Motion.WALK, Pace.SLOW],
	[0x08, 0x10, Motion.WALK, Pace.NORMAL], [0x0C, 0x14, Motion.JUMP, Jump.FAR],
	[0x15, 0x1D, Motion.WALK, Pace.FAST], [0x19, 0x21, Motion.IN_PLACE, 32],
	[0x1D, 0x25, Motion.IN_PLACE, 16], [0x21, 0x29, Motion.IN_PLACE, 8],
	[0x25, 0x2D, Motion.IN_PLACE, 4], [0x29, 0x31, Motion.WALK, Pace.CURRENT],
	[0x2D, 0x35, Motion.WALK, Pace.FASTER], [0x31, 0x39, Motion.WALK, Pace.SLIDE],
	[0x35, 0x3D, Motion.WALK, Pace.FAST], [0x3A, 0x46, Motion.JUMP, Jump.SPECIAL],
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
const ROTATION_DIRECTIONS: Array = [[1, 4, 3, 1, 2], [1, 3, 4, 2, 1]]

const INSTANT_MOTIONS: Array = [
	[0x3E, 0x4A, Motion.CONTEXT_FACE, Facing.PLAYER],
	[0x3F, 0x4B, Motion.CONTEXT_FACE, Facing.AWAY_PLAYER],
	[0x4E, 0x5A, Motion.CONTEXT_FACE, Facing.ORIGINAL],
	[0x50, 0x5C, Motion.SET_FLAG, ObjectFlag.LANDING_EFFECT, false],
	[0x51, 0x5D, Motion.SET_FLAG, ObjectFlag.LANDING_EFFECT, true],
	[0x54, 0x60, Motion.SET_FLAG, ObjectFlag.INVISIBLE, true],
	[0x55, 0x61, Motion.SET_FLAG, ObjectFlag.INVISIBLE, false],
	[0x5C, 0x6A, Motion.SET_FLAG, ObjectFlag.FIXED_PRIORITY, true],
	[0x5D, 0x6B, Motion.SET_FLAG, ObjectFlag.FIXED_PRIORITY, false],
]

## `MetatileBehavior_Is*Blocked` by the side each blocks. Ruby, Sapphire and
## Emerald add the two-sided rows and the secret base's breakable door.
const BLOCKED_SIDES: Dictionary = {
	Direction.SOUTH: [0x33, 0x36, 0x37], Direction.NORTH: [0x32, 0x34, 0x35],
	Direction.WEST: [0x31, 0x35, 0x37], Direction.EAST: [0x30, 0x34, 0x36],
}
const HOENN_BLOCKED_SIDES: Dictionary = {
	Direction.SOUTH: [0xC0], Direction.NORTH: [0xC0],
	Direction.WEST: [0xC1, 0xBE], Direction.EAST: [0xC1, 0xBE],
}
const OPPOSITE: Array[int] = [Direction.NONE, Direction.NORTH, Direction.SOUTH, Direction.EAST, Direction.WEST]
## FireRed and LeafGreen's `OBJ_EVENT_GFX_CUT_TREE` and `ROCK_SMASH_ROCK`, which
## `ShouldInitObjectEventStateFromTemplate` holds back near a connection, and the
## temporary flags it may set to keep them hidden.
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
	var single_movement_active: bool = false
	var held_movement_active: bool = false
	var held_movement_finished: bool = false
	var movement_action: int = -1
	var movement_frame: int = 0
	var movement_state: int = 0
	var direction_sequence_index: int = 0
	var movement_delay: int = 0
	var pixel_position := Vector2i.ZERO
	var jump_y: int = 0
	var ground_on_spawn: bool = true
	var player_copyable_movement: int = 0


var random_seed: int = 0
var random_word: Callable = _random
var _player_dashing: bool = false
var camera: Gen3FieldCamera
var events: Gen3EventData
var objects: Array[ObjectEvent] = []
## `gSaveBlock1Ptr->objectEventTemplates` for the camera's map.
var templates: Array = []
var _frlg: bool = false
var _ranged := PackedByteArray()
var _facing := PackedByteArray()
var _blocked: Dictionary = {}
var _motions: Dictionary = {}


func _init(field_camera: Gen3FieldCamera, event_data: Gen3EventData) -> void:
	camera = field_camera
	events = event_data
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
	load_templates()


## `LoadObjEventTemplatesFromHeader`. FireRed and LeafGreen copy a clone's
## target in its place, keeping the clone's id, position and kind.
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


## `UpdateObjectEventsForCameraUpdate` after [method Gen3FieldCamera.move]. A
## crossing first does what `LoadMapFromCameraTransition` does to objects: the
## new map's templates, `ClearTempFieldEventData`, then every object shifted by
## `gCamera`.
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
			object.active = false


## `InitObjectEventStateFromTemplate`: the slot it fills, or -1 when the object
## is already out or no slot is free. A FireRed or LeafGreen clone spawns as its
## target, identity included, at the clone's position.
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


## `GetObjectEventIdByXY` / `GetObjectEventIdByPosition`: current cell; elevation <= 0 matches any.
func at_position(at: Vector2i, elevation: int = -1) -> int:
	for slot: int in COUNT:
		var object: ObjectEvent = objects[slot]
		if object.active and object.current == at and (elevation <= 0
				or object.current_elevation == 0 or object.current_elevation == elevation):
			return slot
	return -1


## `ShouldInitObjectEventStateFromTemplate`. A clone is tested at its own
## layout position; the obstacle test reads the target's.
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


## `TemplateIsObstacleAndWithinView`: false for a clone obstacle less than
## nine columns and seven rows from the focus.
func _obstacle_in_view_ok(at: Vector2i) -> bool:
	var pos: Vector2i = camera.pos
	if (pos.x < at.x and pos.x + Gen3MapGrid.MAP_OFFSET + 1 < at.x) \
			or (pos.x >= at.x and pos.x - (Gen3MapGrid.MAP_OFFSET + 1) > at.x):
		return true
	return at.y < pos.y - (Gen3MapGrid.MAP_OFFSET - 1) or at.y > pos.y + Gen3MapGrid.MAP_OFFSET - 1


## `GetCollisionAtCoords`; direction is not NONE. FRLG's nine-bit
## behavior narrows at the u8 side predicates.
func collision_at(object: ObjectEvent, x: int, y: int, direction: int) -> int:
	var grid: Gen3MapGrid = camera.grid
	if _outside_range(object, x, y):
		return Collision.OUTSIDE_RANGE
	if grid.collision_at(x, y) != 0 or grid.border_id_at(x, y) == Gen3MapGrid.Connection.INVALID \
			or object.current_behavior in _blocked[direction] \
			or (grid.behavior_at(x, y) & 0xFF) in _blocked[OPPOSITE[direction]] \
			or (object.tracked_by_camera and not camera.can_move(direction)):
		return Collision.IMPASSABLE
	if _elevation_mismatch(object.current_elevation, x, y):
		return Collision.ELEVATION_MISMATCH
	if _object_at(object, x, y):
		return Collision.OBJECT_EVENT
	return Collision.NONE


## `IsCoordOutsideObjectEventMovementRange`; a zero range is unbounded.
func _outside_range(object: ObjectEvent, x: int, y: int) -> bool:
	return (object.movement_range.x != 0 and absi(x - object.initial.x) > object.movement_range.x) \
		or (object.movement_range.y != 0 and absi(y - object.initial.y) > object.movement_range.y)


## `IsElevationMismatchAt`: elevations 0 and 15 match anything.
func _elevation_mismatch(elevation: int, x: int, y: int) -> bool:
	var map_elevation: int = camera.grid.elevation_at(x, y)
	return elevation != 0 and map_elevation != 0 and map_elevation != ELEVATION_MULTI_LEVEL \
		and map_elevation != elevation


## `DoesObjectCollideWithObjectAt`: another active object on or leaving the
## cell, at a compatible elevation.
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
	for row: Array in INSTANT_MOTIONS:
		_motions[int(row[1 if _frlg else 0])] = [int(row[2]), 0, int(row[3])] + row.slice(4)
	var emotes: Array = [0, 33, 46, 66, 64] if _frlg else [0, 33, 46]
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


## `ObjectEventSetHeldMovement`: true refuses; completion does not clear the hold.
func set_held_movement(object: ObjectEvent, action: int) -> bool:
	if not object.active or movement_overridden(object) or not _motions.has(action):
		return true
	object.frozen = false
	object.movement_action = action
	object.held_movement_active = true
	object.held_movement_finished = false
	object.movement_frame = 0
	return false


static func held_movement_status(object: ObjectEvent) -> int:
	return int(object.held_movement_finished) if object.held_movement_active else 16


static func clear_held_movement(object: ObjectEvent) -> void:
	object.movement_action = -1
	object.held_movement_active = false
	object.held_movement_finished = false
	object.movement_frame = 0
	object.movement_state = 0


static func clear_held_movement_if_finished(object: ObjectEvent) -> int:
	var status: int = held_movement_status(object)
	if status == 1:
		clear_held_movement(object)
	return status


static func movement_overridden(object: ObjectEvent) -> bool:
	return object.single_movement_active or object.held_movement_active


## `FreezeObjectEvents` skips player/held actions; unfreezing visits every active slot.
func freeze_except_player() -> void:
	for object: ObjectEvent in objects:
		if object.active and not object.is_player and not object.held_movement_active:
			object.frozen = true


func unfreeze_all() -> void:
	for object: ObjectEvent in objects:
		if object.active:
			object.frozen = false


## `RemoveObjectEventByLocalIdAndMap` sets the template's hide flag. The
## current map's mutable templates precede another map's header templates.
func remove(local_id: int, number: int, group: int) -> void:
	for object: ObjectEvent in objects:
		if object.active and object.local_id == local_id and object.map_number == number and object.map_group == group:
			events.flag_set(int(_template_by_id(local_id, number, group).get("flag", 0)))
			object.active = false
			return


func _template_by_id(local_id: int, number: int, group: int) -> Dictionary:
	var rows: Array = templates if number == camera.number and group == camera.group \
		else camera.data.world_map_events(group, number).get("objects", [])
	for row: Dictionary in rows:
		if int(row["local_id"]) == local_id:
			return row
	return {}


## FRLG's `HandleBoulderFallThroughHole` and
## `HandleBoulderActivateVictoryRoadSwitch`. Reveal flags use the template's
## u16 trainer field, not the object's truncated trainer type. Switches ignore
## elevation and variable gates and visit all coordinate rows in order.
func boulder_landing(object: ObjectEvent) -> Array:
	var requests: Array = []
	if not _frlg:
		return requests
	var behavior: int = camera.grid.behavior_at(object.current.x, object.current.y)
	if behavior == 0x66:
		var template: Dictionary = _template_by_id(object.local_id, camera.number, camera.group)
		remove(object.local_id, camera.number, camera.group)
		events.flag_clear(int(template.get("trainer_type", 0)))
		requests.append({"kind": "sound", "name": "fall"})
	if behavior == 0x20:
		for row: Dictionary in camera.data.world_map_events(camera.group, camera.number).get("coords", []):
			if Vector2i(int(row["x"]), int(row["y"])) + Vector2i.ONE * Gen3MapGrid.MAP_OFFSET == object.current:
				requests.append({"kind": "script", "offset": int(row["script_offset"])})
	return requests


## `UpdateObjectEventCurrentMovement`: holds bypass freezing/collision; running input gates trainer reactions.
func step_movements(player_dashing: bool = false) -> Array:
	_player_dashing = player_dashing
	var requests: Array = []
	for slot: int in COUNT:
		var object: ObjectEvent = objects[slot]
		if not object.active:
			continue
		if object.ground_on_spawn:
			_ground(object, slot, "spawn", requests)
			object.ground_on_spawn = false
		if object.held_movement_active and not object.held_movement_finished:
			object.held_movement_finished = _advance_motion(object, slot, requests)
		elif not object.held_movement_active and not object.frozen:
			_step_autonomous(object, slot, requests)
	return requests


func _advance_motion(object: ObjectEvent, slot: int, requests: Array) -> bool:
	var row: Array = _motions[object.movement_action]
	var motion: int = int(row[0])
	var direction: int = int(row[1])
	var parameter: int = int(row[2])
	if object.movement_frame == 0:
		_start_motion(object, motion, direction, parameter, slot, requests)
		_start_instant_motion(object, row, slot, requests)
	match motion:
		Motion.WALK:
			var pixels: Array = STEP_PIXELS[parameter]
			object.pixel_position += Gen3FieldCamera.DIRECTIONS[direction] * int(pixels[object.movement_frame % pixels.size()])
			object.movement_frame += 1
			if object.movement_frame == STEP_FRAMES[parameter]:
				_finish_motion(object, slot, requests)
			return object.movement_frame == STEP_FRAMES[parameter]
		Motion.JUMP:
			return _advance_jump(object, parameter, slot, requests)
		Motion.IN_PLACE, Motion.DELAY:
			object.movement_frame += 1
			return object.movement_frame == parameter
	return true


func _start_motion(object: ObjectEvent, motion: int, direction: int, parameter: int,
		slot: int, requests: Array) -> void:
	if direction != 0:
		set_direction(object, direction)
	match motion:
		Motion.FACE:
			_shift_coords(object, object.current)
		Motion.WALK:
			_shift_coords(object, object.current + Gen3FieldCamera.DIRECTIONS[direction])
			_ground(object, slot, "begin_step", requests)
		Motion.JUMP:
			var displacement: int = 1 if parameter in [Jump.FAR, Jump.SPECIAL, Jump.NORMAL] else 0
			_shift_coords(object, object.current + Gen3FieldCamera.DIRECTIONS[direction] * displacement)
			_ground(object, slot, "begin_step", requests)
		Motion.LOCK:
			object.facing_locked = true
		Motion.UNLOCK:
			object.facing_locked = false


func _start_instant_motion(object: ObjectEvent, row: Array, slot: int, requests: Array) -> void:
	match int(row[0]):
		Motion.CONTEXT_FACE:
			var direction: int = _context_facing(object, int(row[2]))
			if direction >= 0:
				set_direction(object, direction)
				_shift_coords(object, object.current)
		Motion.SET_FLAG:
			match int(row[2]):
				ObjectFlag.LANDING_EFFECT:
					object.disable_jump_landing_effect = bool(row[3])
				ObjectFlag.INVISIBLE:
					object.invisible = bool(row[3])
				ObjectFlag.FIXED_PRIORITY:
					object.fixed_priority = bool(row[3])
		Motion.EMOTE:
			requests.append({"kind": "field_effect", "effect_id": int(row[2]), "object_id": slot,
				"local_id": object.local_id, "map_number": object.map_number, "map_group": object.map_group})


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


func _advance_jump(object: ObjectEvent, parameter: int, slot: int, requests: Array) -> bool:
	var special: bool = parameter == Jump.SPECIAL
	var duration: int = 32 if parameter == Jump.FAR or special else 16
	var shift: int = 1 if parameter == Jump.FAR or special else 0
	if parameter in [Jump.FAR, Jump.SPECIAL, Jump.NORMAL] and (not special or object.movement_frame % 2 == 0):
		object.pixel_position += Gen3FieldCamera.DIRECTIONS[object.movement_direction]
	object.jump_y = int(JUMP_Y[1 if parameter in [Jump.NORMAL, Jump.TURN] else 0][object.movement_frame >> shift])
	object.movement_frame += 1
	if object.movement_frame == duration / 2:
		if parameter == Jump.FAR:
			_shift_coords(object, object.current + Gen3FieldCamera.DIRECTIONS[object.movement_direction])
			_ground(object, slot, "begin_step", requests)
		elif parameter == Jump.TURN:
			set_direction(object, OPPOSITE[object.movement_direction])
	if object.movement_frame == duration:
		object.jump_y = 0
		_finish_motion(object, slot, requests)
	return object.movement_frame == duration


func _finish_motion(object: ObjectEvent, slot: int, requests: Array) -> void:
	_shift_coords(object, object.current)
	_ground(object, slot, "finish_step", requests)


static func _shift_coords(object: ObjectEvent, at: Vector2i) -> void:
	object.previous = object.current
	object.current = Vector2i(wrapi(at.x, -32768, 32768), wrapi(at.y, -32768, 32768))


func _ground(object: ObjectEvent, slot: int, kind: String, requests: Array) -> void:
	update_elevation(object)
	object.current_behavior = camera.grid.behavior_at(object.current.x, object.current.y)
	object.previous_behavior = camera.grid.behavior_at(object.previous.x, object.previous.y)
	requests.append({"kind": kind, "object_id": slot})


func _step_autonomous(object: ObjectEvent, slot: int, requests: Array) -> void:
	var type: int = object.movement_type
	if type >= 2 and type <= 6:
		_step_wander(object, slot, requests)
	elif type == 1 or (type >= 0xD and type <= 0x16):
		_step_random_facing(object, slot, requests)
	elif type in [0x17, 0x18]:
		_step_rotation(object, slot, requests)
	elif type >= 0x19 and type <= 0x34:
		_step_patrol(object, slot, requests)
	elif (type >= 7 and type <= 10) or type == 0x4C:
		_step_stationary(object, slot, requests)
	elif (type >= 0x40 and type <= 0x4B) or (not _frlg and type >= 0x4D and type <= 0x50):
		_step_in_place(object, slot, requests)


func _set_single_movement(object: ObjectEvent, action: int) -> void:
	object.movement_action = action
	object.movement_frame = 0


func _exec_single_movement(object: ObjectEvent, slot: int, requests: Array) -> bool:
	if not _advance_motion(object, slot, requests):
		return false
	object.movement_action = -1
	object.movement_frame = 0
	return true


func _step_stationary(object: ObjectEvent, slot: int, requests: Array) -> void:
	if object.movement_state == 0:
		clear_held_movement(object)
		object.single_movement_active = false
		_set_single_movement(object, maxi(object.facing - 1, 0))
		if object.movement_type == 0x4C:
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
		_set_single_movement(object, base + (8 if _frlg else 0) + maxi(object.facing - 1, 0))
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
		_set_single_movement(object, base + maxi((object.facing if blocked else object.movement_direction) - 1, 0))
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


## `random.c`'s LCG; [member random_word] also accepts a shared host stream.
func _random() -> int:
	random_seed = (random_seed * 0x41C64E6D + 0x6073) & 0xFFFFFFFF
	return random_seed >> 16


func _start_facing(object: ObjectEvent) -> void:
	_set_single_movement(object, maxi(object.facing - 1, 0))
	object.movement_state = 2


func _choose_delay(object: ObjectEvent) -> void:
	var index: int = int(random_word.call()) & 3
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
		var direction: int = int(directions[int(random_word.call()) & (directions.size() - 1)])
		set_direction(object, direction)
		if _collision_in_direction(object) != Collision.NONE:
			object.movement_state = 1
			_step_wander(object, slot, requests)
			return
		_set_single_movement(object, 0x08 + (8 if _frlg else 0) + direction - 1)
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
		direction = int(directions[int(random_word.call()) & (directions.size() - 1)])
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
		_set_single_movement(object, maxi(object.facing - 1, 0))
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
