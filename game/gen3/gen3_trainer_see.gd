class_name Gen3TrainerSee
extends RefCounted

## `trainer_see.c`: sighting, approach and buried reveals; [method run_tasks] is their `RunTasks` share. Battle
## setup and the scripts around the approach stay with hosts, which read [member approaching].

enum TrainerType { NONE, NORMAL, SEE_ALL_DIRECTIONS, BURIED }
## `sTrainerSeeFuncList`; the last three are FireRed/LeafGreen's camera scroll.
enum See { IDLE, EXCLAMATION, EXCLAMATION_WAIT, MOVE_TO_PLAYER, PLAYER_FACE, PLAYER_FACE_WAIT,
	REVEAL_DISGUISE, REVEAL_DISGUISE_WAIT, REVEAL_BURIED, BURIED_POP_OUT, BURIED_JUMP,
	REVEAL_BURIED_WAIT, CAMERA_SPAWN, CAMERA_UP, CAMERA_DOWN }
const TRAINER_FLAGS_START: int = 0x500
## Emerald's TRAINER_BATTLE_DOUBLE, CONTINUE_SCRIPT_DOUBLE and REMATCH_DOUBLE; FRLG checks only the first.
const DOUBLE_MODES: Array[int] = [4, 6, 7]
## FRLG spawns this invisible youngster for the camera to follow up to a trainer above the view.
const LOCALID_CAMERA: int = 127
const CAMERA_GRAPHICS: int = 18
const CAMERA_MOVEMENT_TYPE: int = 7
const CAMERA_ELEVATION: int = 3
## `MOVEMENT_ACTION_*` families, Hoenn then FireRed/LeafGreen.
const FACE: Array[int] = [0x00, 0x00]
const WALK: Array[int] = [0x08, 0x10]
const WALK_FAST: Array[int] = [0x15, 0x1D]
const FACE_PLAYER: Array[int] = [0x3E, 0x4A]
const JUMP_IN_PLACE: Array[int] = [0x46, 0x52]
const REVEAL_TRAINER: Array[int] = [0x59, 0x67]

var objects: Gen3ObjectEvents
var avatar: Gen3PlayerAvatar
## `gApproachingTrainers`: slot, script offset (-1 for Trainer Hill's shared script) and sight distance.
var approaching: Array[Dictionary] = []
## Emerald's `gApproachingTrainerId` and `gTrainerApproachedPlayer`.
var approaching_id: int = 0
var approached_player: bool = false
var _tasks: Array[Dictionary] = []
var _funcs: Array[Callable] = []
var _frlg: bool = false
var _game: StringName


func _init(field_objects: Gen3ObjectEvents, player_avatar: Gen3PlayerAvatar) -> void:
	objects = field_objects
	avatar = player_avatar
	_game = objects.camera.data.id
	_frlg = _game in [RomRegistry.FIRERED, RomRegistry.LEAFGREEN]
	_funcs.assign([_idle, _exclamation, _wait_exclamation, _move_to_player, _player_face, _player_face_wait,
		_reveal_disguise, _wait_disguise, _reveal_buried, _pop_out_of_ash, _jump_out_of_ash,
		_wait_buried, _camera_spawn, _camera_up, _camera_down])


## `CheckForTrainersWantingBattle` (Ruby's `CheckTrainers`): an approach task for each trainer that sees the
## player. Emerald keeps looking for a second while the party has two usable Pokémon. [param facility_flag]
## answers Emerald's Battle Pyramid and Trainer Hill trainer flags by slot.
func check_trainers(two_usable_mons: bool = true, facility_flag: Callable = Callable()) -> bool:
	approaching.clear()
	approaching_id = 0
	for slot: int in Gen3ObjectEvents.COUNT:
		var object: Gen3ObjectEvents.ObjectEvent = objects.objects[slot]
		if not object.active or object.trainer_type not in [TrainerType.NORMAL, TrainerType.BURIED]:
			continue
		var found: int = _check_trainer(slot, two_usable_mons, facility_flag)
		if found > 0 and (_game != RomRegistry.EMERALD or found == 2 or approaching.size() > 1
				or not two_usable_mons):
			break
	approached_player = not approaching.is_empty()
	return approached_player


## `DoTrainerApproach` (`EndTrainerApproach` before Emerald): the trainer's task starts and runs at once.
func start_approach() -> Array:
	var requests: Array = []
	var task: Dictionary = {}
	if _game == RomRegistry.EMERALD:
		task = approaching[approaching_id]["task"] if approaching_id < approaching.size() else {}
	else:
		for candidate: Dictionary in _tasks:
			if not candidate["buried"] and not candidate["ending"]:
				task = candidate
				break
	if not task.is_empty():
		task["followup"] = true
		task["func"] = See.EXCLAMATION
		_run(task, requests)
	return requests


## Emerald's `TryPrepareSecondApproachingTrainer`: true when the second trainer moves next, alone.
func prepare_second_trainer() -> bool:
	if approaching.size() != 2:
		return false
	if approaching_id != 0:
		approaching_id = 0
		return false
	approaching_id = 1
	objects.unfreeze_all()
	objects.freeze_except_player(int(approaching[1]["slot"]))
	return true


## Tasks by priority, buried reveals (0) before approaches (0x50), including reveals the last object callbacks
## queued. `script_enable` asks the waiting script to resume.
func run_tasks() -> Array:
	var requests: Array = []
	for slot: int in objects.buried_reveals:
		_tasks.insert(_tasks.filter(func(task: Dictionary) -> bool: return task["buried"]).size(),
			_task(slot, true, See.REVEAL_BURIED, 0))
	objects.buried_reveals.clear()
	for task: Dictionary in _tasks.duplicate():
		_run(task, requests)
	_tasks.assign(_tasks.filter(func(task: Dictionary) -> bool: return not task["destroyed"]))
	return requests


static func _task(slot: int, buried: bool, function: int, reach: int) -> Dictionary:
	return {"slot": slot, "buried": buried, "func": function, "range": reach, "followup": false,
		"ending": false, "destroyed": false, "started": false, "camera_steps": 0, "puff": {}}


func _check_trainer(slot: int, two_usable_mons: bool, facility_flag: Callable) -> int:
	var object: Gen3ObjectEvents.ObjectEvent = objects.objects[slot]
	var script: int = int(objects.template_by_id(object.local_id, object.map_number,
		object.map_group).get("script_offset", 0))
	var layout: int = int(objects.camera.header.get("layout_id", -1))
	var facility: bool = _game == RomRegistry.EMERALD \
		and layout in Gen3ObjectEvents.PYRAMID_LAYOUTS + Gen3ObjectEvents.TRAINER_HILL_LAYOUTS
	var head := PackedByteArray()
	if facility:
		if not facility_flag.is_valid() or facility_flag.call(slot):
			return 0
		script = -1 if layout in Gen3ObjectEvents.TRAINER_HILL_LAYOUTS else script
	else:
		head = _script_head(script)
		if head.size() < 4 or objects.events.flag_get(TRAINER_FLAGS_START + head.decode_u16(2)):
			return 0
	var distance: int = _approach_distance(object)
	if distance == 0:
		return 0
	var found: int = 1
	if not head.is_empty() and _game == RomRegistry.EMERALD and head[1] in DOUBLE_MODES:
		if not two_usable_mons:
			return 0
		found = 2
	elif not head.is_empty() and _frlg and head[1] == DOUBLE_MODES[0] and not two_usable_mons:
		return 0
	var task: Dictionary = _task(slot, false, See.IDLE, distance - 1)
	_tasks.append(task)
	approaching.append({"slot": slot, "script_offset": script, "radius": distance, "task": task})
	return found


## The trainer script's first bytes: `trainerbattle`, its mode and trainer id.
func _script_head(offset: int) -> PackedByteArray:
	var head := PackedByteArray()
	while head.size() < 4:
		var record: Dictionary = objects.camera.data.world_script_instruction(offset)
		if record.is_empty():
			break
		head.append_array(PackedByteArray(record["bytes"]))
		offset = int(record["next_offset"])
	return head


## `GetTrainerApproachDistance`: a normal trainer looks only where it faces.
func _approach_distance(object: Gen3ObjectEvents.ObjectEvent) -> int:
	if object.trainer_type == TrainerType.NORMAL:
		return _clear_path(object, _sight(object, object.facing), object.facing)
	for direction: int in range(Gen3ObjectEvents.Direction.SOUTH, Gen3ObjectEvents.Direction.EAST + 1):
		var distance: int = _clear_path(object, _sight(object, direction), direction)
		if distance != 0:
			return distance
	return 0


## `GetTrainerApproachDistance{South,North,West,East}` to the player's destination. FRLG's south sight needs a
## free slot for the camera past three.
func _sight(object: Gen3ObjectEvents.ObjectEvent, direction: int) -> int:
	var player: Vector2i = avatar.object().current
	var reach: int = object.trainer_range
	var at: Vector2i = object.current
	var distance: int = 0
	match direction:
		Gen3ObjectEvents.Direction.SOUTH:
			distance = player.y - at.y if at.x == player.x else 0
		Gen3ObjectEvents.Direction.NORTH:
			distance = at.y - player.y if at.x == player.x else 0
		Gen3ObjectEvents.Direction.WEST:
			distance = at.x - player.x if at.y == player.y else 0
		Gen3ObjectEvents.Direction.EAST:
			distance = player.x - at.x if at.y == player.y else 0
	if distance <= 0 or distance > reach:
		return 0
	if _frlg and direction == Gen3ObjectEvents.Direction.SOUTH and reach > 3 \
			and objects.objects.all(func(other: Gen3ObjectEvents.ObjectEvent) -> bool: return other.active):
		return 0
	return distance


## `CheckPathBetweenTrainerAndPlayer`: the cells short of the player, then the player's cell with the
## trainer's range cleared. Emerald starts past the trainer and ignores only an out-of-range bit; Ruby and
## FRLG include the trainer's own cell, and Ruby's mask blocks on nothing but that bit.
func _clear_path(object: Gen3ObjectEvents.ObjectEvent, distance: int, direction: int) -> int:
	if distance == 0:
		return 0
	var step: Vector2i = Gen3FieldCamera.DIRECTIONS[direction]
	var at: Vector2i = object.current
	var checks: int = distance
	if _game == RomRegistry.EMERALD:
		at = _wrap(at + step)
		checks -= 1
	var mask: int = 1 if _game in [RomRegistry.RUBY, RomRegistry.SAPPHIRE] else ~1
	for index: int in checks:
		if objects.collision_flags_at(object, at.x, at.y, direction) & mask:
			return 0
		at = _wrap(at + step)
	var movement_range: Vector2i = object.movement_range
	object.movement_range = Vector2i.ZERO
	var collision: int = objects.collision_at(object, at.x, at.y, direction)
	object.movement_range = movement_range
	return distance if collision == Gen3ObjectEvents.Collision.OBJECT_EVENT else 0


static func _wrap(at: Vector2i) -> Vector2i:
	return Vector2i(wrapi(at.x, -32768, 32768), wrapi(at.y, -32768, 32768))


func _action(family: Array[int], direction: int = 0) -> int:
	return Gen3ObjectEvents.direction_action(family[int(_frlg)], direction)


static func _ready(object: Gen3ObjectEvents.ObjectEvent) -> bool:
	return not Gen3ObjectEvents.movement_overridden(object) \
		or Gen3ObjectEvents.clear_held_movement_if_finished(object) != 0


## `Task_RunTrainerSeeFuncList`, or for a reveal `Task_SetBuriedTrainerMovement`, one `sTrainerSeeFuncList2` step a frame.
func _run(task: Dictionary, requests: Array) -> void:
	var object: Gen3ObjectEvents.ObjectEvent = objects.objects[int(task["slot"])]
	if task["buried"]:
		_run_buried(task, object, requests)
	elif task["ending"]:
		task["destroyed"] = true
		requests.append({"kind": "script_enable"})
	elif not object.active:
		task["ending"] = task["followup"]
	else:
		while _funcs[int(task["func"])].call(task, object, requests):
			pass


func _run_buried(task: Dictionary, object: Gen3ObjectEvents.ObjectEvent, requests: Array) -> void:
	if not task["started"]:
		Gen3ObjectEvents.clear_held_movement(object)
		task["started"] = true
	_funcs[int(task["func"])].call(task, object, requests)
	if int(task["func"]) == See.REVEAL_BURIED_WAIT and not objects.field_effect_active(Gen3ObjectEvents.ASH_PUFF):
		var type: int = Gen3ObjectEvents.TRAINER_FACING_TYPES[object.facing]
		Gen3ObjectEvents.set_trainer_movement_type(object, type)
		objects.override_template_movement_type(object, type)
		task["destroyed"] = true
	else:
		object.held_movement_finished = false


func _idle(_task_data: Dictionary, _object: Gen3ObjectEvents.ObjectEvent, _requests: Array) -> bool:
	return false


func _exclamation(task: Dictionary, object: Gen3ObjectEvents.ObjectEvent, requests: Array) -> bool:
	if _frlg and object.facing == Gen3ObjectEvents.Direction.SOUTH and int(task["range"]) > 2:
		task["func"] = See.CAMERA_SPAWN
		return true
	objects.start_effect_sprite(object, int(task["slot"]), Gen3ObjectEvents.EXCLAMATION_MARK_ICON,
		Gen3ObjectEvents.ICON_PASSES, true, requests)
	objects.set_held_movement(object, _action(FACE, object.facing))
	task["func"] = See.EXCLAMATION_WAIT
	return true


func _wait_exclamation(task: Dictionary, object: Gen3ObjectEvents.ObjectEvent, _requests: Array) -> bool:
	if objects.field_effect_active(Gen3ObjectEvents.EXCLAMATION_MARK_ICON):
		return false
	task["func"] = See.MOVE_TO_PLAYER
	if object.movement_type in [0x39, 0x3A]:
		task["func"] = See.REVEAL_DISGUISE
	if object.movement_type == Gen3ObjectEvents.MOVEMENT_TYPE_BURIED:
		task["func"] = See.REVEAL_BURIED
	return true


func _move_to_player(task: Dictionary, object: Gen3ObjectEvents.ObjectEvent, _requests: Array) -> bool:
	if _ready(object):
		if int(task["range"]) != 0:
			objects.set_held_movement(object, _action(WALK, object.facing))
			task["range"] = int(task["range"]) - 1
		else:
			objects.set_held_movement(object, _action(FACE_PLAYER))
			task["func"] = See.PLAYER_FACE
	return false


## The trainer keeps its facing in its saved template; FRLG leaves the player's facing.
func _player_face(task: Dictionary, object: Gen3ObjectEvents.ObjectEvent, _requests: Array) -> bool:
	if not _ready(object):
		return false
	var type: int = Gen3ObjectEvents.TRAINER_FACING_TYPES[object.facing]
	Gen3ObjectEvents.set_trainer_movement_type(object, type)
	objects.override_template_movement_type(object, type)
	objects.override_template_coords(object)
	if not _ready(avatar.object()):
		return false
	avatar.cancel_forced_movement()
	if not _frlg:
		objects.set_held_movement(avatar.object(), _action(FACE, Gen3ObjectEvents.OPPOSITE[object.facing]))
	task["func"] = See.PLAYER_FACE_WAIT
	return false


func _player_face_wait(task: Dictionary, _object: Gen3ObjectEvents.ObjectEvent, _requests: Array) -> bool:
	if _ready(avatar.object()):
		task["ending"] = true
	return false


func _reveal_disguise(task: Dictionary, object: Gen3ObjectEvents.ObjectEvent, _requests: Array) -> bool:
	if _ready(object):
		objects.set_held_movement(object, _action(REVEAL_TRAINER))
		task["func"] = See.REVEAL_DISGUISE_WAIT
	return false


func _wait_disguise(task: Dictionary, object: Gen3ObjectEvents.ObjectEvent, _requests: Array) -> bool:
	if Gen3ObjectEvents.clear_held_movement_if_finished(object) != 0:
		task["func"] = See.MOVE_TO_PLAYER
	return false


func _reveal_buried(task: Dictionary, object: Gen3ObjectEvents.ObjectEvent, _requests: Array) -> bool:
	if _ready(object):
		objects.set_held_movement(object, _action(FACE_PLAYER))
		task["func"] = See.BURIED_POP_OUT
	return false


func _pop_out_of_ash(task: Dictionary, object: Gen3ObjectEvents.ObjectEvent, requests: Array) -> bool:
	if Gen3ObjectEvents.held_movement_status(object) != 0:
		task["puff"] = objects.start_effect_sprite(object, int(task["slot"]), Gen3ObjectEvents.ASH_PUFF,
			-1, false, requests)
		if not task["puff"].is_empty():
			task["func"] = See.BURIED_JUMP
	return false


## The jump starts once the puff reaches its third cell (animCmdIndex 2).
func _jump_out_of_ash(task: Dictionary, object: Gen3ObjectEvents.ObjectEvent, _requests: Array) -> bool:
	if (task["puff"]["anim"] as Gen3SpriteAnim).cmd_index == 2:
		object.fixed_priority = false
		Gen3ObjectEvents.clear_held_movement_if_finished(object)
		objects.set_held_movement(object, _action(JUMP_IN_PLACE, object.facing))
		task["func"] = See.REVEAL_BURIED_WAIT
	return false


## The approach walks on; the reveal-only task's list stays on this step.
func _wait_buried(task: Dictionary, _object: Gen3ObjectEvents.ObjectEvent, _requests: Array) -> bool:
	if not objects.field_effect_active(Gen3ObjectEvents.ASH_PUFF):
		task["func"] = See.REVEAL_BURIED_WAIT if task["buried"] else See.MOVE_TO_PLAYER
	return false


## FRLG's `SpawnSpecialObjectEventParameterized` at the view focus; `camera_follow` asks the host's camera to follow.
func _camera_spawn(task: Dictionary, _object: Gen3ObjectEvents.ObjectEvent, requests: Array) -> bool:
	task["camera_steps"] = 0
	var template: Dictionary = Gen3ObjectEvents.EMPTY_TEMPLATE.duplicate()
	template.merge({"local_id": LOCALID_CAMERA, "graphics_id": CAMERA_GRAPHICS,
		"movement_type": CAMERA_MOVEMENT_TYPE, "elevation": CAMERA_ELEVATION,
		"x": objects.camera.pos.x, "y": objects.camera.pos.y}, true)
	var slot: int = objects.spawn(template, objects.camera.number, objects.camera.group)
	if slot >= 0:
		objects.objects[slot].invisible = true
		requests.append({"kind": "camera_follow", "object_id": slot})
	task["func"] = See.CAMERA_UP
	return false


func _camera_up(task: Dictionary, object: Gen3ObjectEvents.ObjectEvent, requests: Array) -> bool:
	var mover: Gen3ObjectEvents.ObjectEvent = _camera_object()
	if mover == null or not _ready(mover):
		return false
	if int(task["camera_steps"]) != int(task["range"]) - 1:
		objects.set_held_movement(mover, _action(WALK_FAST, Gen3ObjectEvents.Direction.NORTH))
		task["camera_steps"] = int(task["camera_steps"]) + 1
	else:
		objects.start_effect_sprite(object, int(task["slot"]), Gen3ObjectEvents.EXCLAMATION_MARK_ICON,
			Gen3ObjectEvents.ICON_PASSES, true, requests)
		task["camera_steps"] = 0
		task["func"] = See.CAMERA_DOWN
	return false


func _camera_down(task: Dictionary, _object: Gen3ObjectEvents.ObjectEvent, requests: Array) -> bool:
	var mover: Gen3ObjectEvents.ObjectEvent = _camera_object()
	if objects.field_effect_active(Gen3ObjectEvents.EXCLAMATION_MARK_ICON) or mover == null or not _ready(mover):
		return false
	if int(task["camera_steps"]) != int(task["range"]) - 1:
		objects.set_held_movement(mover, _action(WALK_FAST, Gen3ObjectEvents.Direction.SOUTH))
		task["camera_steps"] = int(task["camera_steps"]) + 1
	else:
		requests.append({"kind": "camera_follow", "object_id": avatar.object_id})
		objects.remove(LOCALID_CAMERA, objects.camera.number, objects.camera.group)
		task["camera_steps"] = 0
		task["func"] = See.EXCLAMATION_WAIT
	return false


func _camera_object() -> Gen3ObjectEvents.ObjectEvent:
	return objects.by_identity(LOCALID_CAMERA, objects.camera.number, objects.camera.group)
