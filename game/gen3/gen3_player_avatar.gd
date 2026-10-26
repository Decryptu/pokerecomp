class_name Gen3PlayerAvatar
extends RefCounted

## `field_player_avatar.c`: initialization, state transitions and queries, collision decisions, Strength, the surf
## mount and dismount tasks and rotating-gate puzzles; `field_effect.c`'s field-move and Waterfall tasks.

enum Flag { ON_FOOT = 1, MACH_BIKE = 2, ACRO_BIKE = 4, SURFING = 8,
	UNDERWATER = 16, CONTROLLABLE = 32, FORCED_MOVE = 64, DASH = 128 }
enum State { NORMAL, MACH_BIKE, ACRO_BIKE, SURFING, UNDERWATER, FIELD_MOVE, FISHING, WATERING, VS_SEEKER }
enum Collision { NONE, OUTSIDE_RANGE, IMPASSABLE, ELEVATION_MISMATCH, OBJECT_EVENT,
	STOP_SURFING, LEDGE_JUMP, PUSHED_BOULDER, DIRECTIONAL_STAIR_WARP, WHEELIE_HOP,
	ISOLATED_VERTICAL_RAIL, ISOLATED_HORIZONTAL_RAIL, VERTICAL_RAIL, HORIZONTAL_RAIL,
	ROTATING_GATE = 8 }
enum Task { NONE, PUSH_WAIT, PUSH_MOVE, SURF_WAIT, SURF_JUMP, MOUNT_INIT, MOUNT_POSE, MOUNT_SHOW_MON, MOUNT_JUMP,
	MOUNT_END, MOVE_INIT, MOVE_POSE, MOVE_SHOW_MON, MOVE_RUN, WATERFALL_SHOW_MON, WATERFALL_WAIT, WATERFALL_RIDE }
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
var prevent_step: bool = false
var task: Task = Task.NONE
var _task_direction: int = 0
var _boulder_id: int = -1
var _shown_mon: Array = []
var _mount_cell: Vector2i = Vector2i.ZERO
var _field_move: int = 0
var _frlg: bool = false
var _gate_map: String = ""
var _gates: Array = []


## `InitPlayerAvatar`, reserved before map objects; null on a full pool or a duplicate, which the cartridge overruns.
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


func track_camera() -> void:
	object().tracked_by_camera = true


func graphics_for(state: int) -> int:
	if _frlg:
		return int(FRLG_GRAPHICS[state][gender]) if FRLG_GRAPHICS.has(state) else -1
	return int(HOENN_GRAPHICS[state][gender]) if state >= 0 and state < HOENN_GRAPHICS.size() else -1


func set_state_mask(mask: int) -> void:
	flags = ((flags & (Flag.DASH | Flag.FORCED_MOVE | Flag.CONTROLLABLE)) | mask) & 0xFF


## `SetPlayerAvatarTransitionFlags`, run by `InitObjectEventsLocal` after [method open]. The bikes' riding state and
## the Acro Bike's bumpy-slope hop await the bike model; FRLG's surf transition skips a player already surfing.
func transition(transition_flags: int) -> void:
	var player: Gen3ObjectEvents.ObjectEvent = object()
	for state: int in State.FIELD_MOVE + 1:
		if not transition_flags & (1 << state):
			continue
		if state == State.FIELD_MOVE:
			flags |= Flag.CONTROLLABLE
			continue
		var shown: int = State.MACH_BIKE if _frlg and state == State.ACRO_BIKE else state
		if _frlg and (state == State.UNDERWATER or (state == State.SURFING and flags & Flag.SURFING)):
			continue
		objects.set_graphics_id(player, graphics_for(shown))
		Gen3ObjectEvents.turn(player, player.movement_direction)
		set_state_mask(STATE_FLAGS[shown])
		if state == State.SURFING:
			player.field_effect_sprite = objects.start_surf_blob(object_id, player.current)
			set_surf_bob(Gen3ObjectEvents.Bob.PLAYER_AND_MON)
		elif state == State.UNDERWATER:
			player.field_effect_sprite = objects.start_underwater_bob(object_id)


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
	if _frlg and ((direction == Gen3ObjectEvents.Direction.WEST and behavior in [0x6D, 0x6F])
			or (direction == Gen3ObjectEvents.Direction.EAST and behavior in [0x6C, 0x6E])):
		return _result(Collision.DIRECTIONAL_STAIR_WARP)
	at += Gen3FieldCamera.DIRECTIONS[direction]
	return collision_at(object(), at, direction)


## `CheckForObjectEventCollision`. Emerald's static query skips dismounts, ledges and boulders. The input host
## consumes effects once to start tasks and update game statistics.
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
	if _frlg:
		return grid.terrain_at(at.x, at.y) == TERRAIN_WATER
	return grid.behavior_at(at.x, at.y) in HOENN_FISHABLE


static func _result(collision: int, requests: Array = []) -> Dictionary:
	return {"collision": collision, "requests": requests}


## `PlayerNotOnBikeCollide`'s collision branch starts its task at once; walks and stairs stay with the input host.
func begin_collision_movement(direction: int) -> Dictionary:
	if prevent_step:
		return _result(Collision.IMPASSABLE)
	var result: Dictionary = check_collision(direction)
	var requests: Array = result["requests"].duplicate()
	match int(result["collision"]):
		Collision.PUSHED_BOULDER:
			requests.clear()
			_boulder_id = int(result["requests"][0]["object_id"])
			_task_direction = direction
			prevent_step = true
			objects.events.controls_locked = true
			task = Task.PUSH_WAIT
		Collision.STOP_SURFING:
			requests.clear()
			_task_direction = direction
			prevent_step = true
			objects.events.controls_locked = true
			flags = (flags & ~Flag.SURFING) | Flag.ON_FOOT
			if _frlg:
				objects.freeze_except_player()
			requests.append({"kind": "restore_field_music"})
			task = Task.SURF_WAIT
			_start_dismount(requests)
		Collision.LEDGE_JUMP:
			requests.append({"kind": "sound", "name": "ledge"})
			if not Gen3ObjectEvents.movement_overridden(object()):
				object().player_copyable_movement = 8
				objects.set_held_movement(object(), Gen3ObjectEvents.direction_action(0x14 if _frlg else 0x0C, direction))
	result["requests"] = requests
	return result


## `RunTasks` precedes `AnimateSprites`: call this once per field frame, after [method Gen3TrainerSee.run_tasks],
## then [method Gen3ObjectEvents.step_movements]. The show-mon task, created after these, runs last.
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
	objects.field_move_mon.run_task()
	return requests


## `ForcedMovement_None`, behind `CancelPlayerForcedMovement`.
func cancel_forced_movement() -> void:
	if flags & Flag.FORCED_MOVE:
		object().facing_locked = false
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
	objects.set_held_movement(player, Gen3ObjectEvents.direction_action(0x25 if _frlg else 0x1D, _task_direction))
	objects.set_held_movement(boulder, Gen3ObjectEvents.direction_action(0x08 if _frlg else 0x04, _task_direction))
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
	objects.set_held_movement(object(), Gen3ObjectEvents.direction_action(0xA6 if _frlg else 0x3A, _task_direction))
	task = Task.SURF_JUMP


func _finish_dismount(requests: Array) -> void:
	if Gen3ObjectEvents.clear_held_movement_if_finished(object()) == 0:
		return
	objects.set_graphics_id(object(), graphics_for(State.NORMAL))
	objects.set_held_movement(object(), Gen3ObjectEvents.direction_action(0, object().facing))
	prevent_step = false
	objects.events.controls_locked = false
	if _frlg:
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
			objects.set_held_movement(player, Gen3ObjectEvents.direction_action(0x46 if _frlg else 0x3A,
				player.movement_direction))
			player.field_effect_sprite = objects.start_surf_blob(object_id, _mount_cell)
			task = Task.MOUNT_END
		Task.MOUNT_END:
			_finish_mount(requests)


## `SetPlayerAvatarFieldMove` (FRLG's `StartPlayerAvatarSummonMonForFieldMoveAnim`) held in its direction.
func _start_pose() -> void:
	objects.set_graphics_id(object(), graphics_for(State.FIELD_MOVE))
	object().anim.start(0)
	objects.set_held_movement(object(), 0x45 if _frlg else Gen3ObjectEvents.START_ANIM_IN_DIRECTION)


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
	objects.set_held_movement(object(), Gen3ObjectEvents.direction_action(0x08 if _frlg else 0x04,
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
	if _frlg:
		requests.append({"kind": "refresh_help_context"})
	task = Task.NONE


## `RotatingGate_InitPuzzle` resets bytes in temp vars; graphics initialization reloads without resetting them.
func load_rotating_gates(reset: bool = false) -> void:
	_gate_map = "%d:%d" % [objects.camera.group, objects.camera.number]
	_gates = []
	if _frlg:
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
