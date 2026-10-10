class_name Gen3ObjectEvents
extends RefCounted

## `gObjectEvents` and the save block's object templates (`event_object_movement.c`):
## spawning the templates in view, removing objects that leave it, following the
## camera across a map connection, and `GetCollisionAtCoords`. Coordinates are
## the backup map's. Sprites, movement and the player avatar are not modeled, nor
## are the templates the Battle Pyramid and Trainer Hill write over a floor's.

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
## A cleared template slot past the map's own.
const EMPTY_TEMPLATE: Dictionary = {
	"local_id": 0, "graphics_id": 0, "kind": 0, "x": 0, "y": 0, "elevation": 0, "movement_type": 0,
	"movement_range_x": 0, "movement_range_y": 0, "trainer_type": 0,
	"trainer_sight_or_berry_tree_id": 0, "script_offset": 0, "flag": 0,
}

enum Collision { NONE, OUTSIDE_RANGE, IMPASSABLE, ELEVATION_MISMATCH, OBJECT_EVENT }
enum Direction { NONE, SOUTH, NORTH, WEST, EAST }

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
	var current_behavior: int = 0
	var previous_behavior: int = 0
	var previous_movement_direction: int = 0


var camera: Gen3FieldCamera
var events: Gen3EventData
var objects: Array[ObjectEvent] = []
## `gSaveBlock1Ptr->objectEventTemplates` for the camera's map.
var templates: Array = []
var _frlg: bool = false
var _ranged := PackedByteArray()
var _facing := PackedByteArray()
var _blocked: Dictionary = {}


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


## `RemoveObjectEventsOutsideView`: an object stays while it or its spawn
## point is in view.
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
	object.current_elevation = int(template["elevation"]) & 0xF
	object.previous_elevation = object.current_elevation
	object.movement_range = Vector2i(int(template["movement_range_x"]), int(template["movement_range_y"]))
	object.trainer_type = int(template["trainer_type"]) & 0xFF
	object.trainer_range = int(template["trainer_sight_or_berry_tree_id"]) & 0xFF
	# SetObjectEventDirection keeps the cleared facing as the previous direction.
	object.facing = _facing[object.movement_type]
	object.movement_direction = object.facing
	if object.graphics_id >= OBJ_EVENT_GFX_VARS:
		object.graphics_id = events.var_get(VAR_OBJ_GFX_ID_0 + object.graphics_id - OBJ_EVENT_GFX_VARS) & 0xFF
	if _ranged[object.movement_type]:
		object.movement_range = object.movement_range.max(Vector2i.ONE)
	objects[slot] = object
	return slot


## `GetAvailableObjectEventId`: the first free slot, unless one already holds
## this object. A match is only looked for among active slots.
func _available_slot(local_id: int, number: int, group: int) -> int:
	var free: int = -1
	for slot: int in COUNT:
		var object: ObjectEvent = objects[slot]
		if not object.active:
			free = slot if free < 0 else free
		elif object.local_id == local_id and object.map_number == number and object.map_group == group:
			return -1
	return free


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


## `GetCollisionAtCoords` for [param object] stepping onto ([param x], [param y])
## in [param direction], a [enum Direction] other than NONE.
func collision_at(object: ObjectEvent, x: int, y: int, direction: int) -> int:
	var grid: Gen3MapGrid = camera.grid
	if _outside_range(object, x, y):
		return Collision.OUTSIDE_RANGE
	if grid.collision_at(x, y) != 0 or grid.border_id_at(x, y) == Gen3MapGrid.Connection.INVALID \
			or object.current_behavior in _blocked[direction] \
			or grid.behavior_at(x, y) in _blocked[OPPOSITE[direction]] \
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


## `ObjectEventUpdateElevation`: none while either cell is multi-level; a
## transition elevation (0) is not kept as the previous one.
func update_elevation(object: ObjectEvent) -> void:
	var elevation: int = camera.grid.elevation_at(object.current.x, object.current.y)
	if elevation == ELEVATION_MULTI_LEVEL \
			or camera.grid.elevation_at(object.previous.x, object.previous.y) == ELEVATION_MULTI_LEVEL:
		return
	object.current_elevation = elevation
	if elevation != 0:
		object.previous_elevation = elevation
