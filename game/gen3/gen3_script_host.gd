class_name Gen3ScriptHost
extends RefCounted

const FRAME_TABLE: int = 2
const KEY_BITS: Array[int] = [0, 64, 128, 32, 16, 1, 2, 8, 4] # PokeButton id to GBA joypad bit.

var warps := Gen3Warp.new()
var warp_pending: bool = false
var _warp_reset_avatar: bool = false
var context: Gen3ScriptContext
var avatar: Gen3PlayerAvatar
var objects: Gen3ObjectEvents
var selected_slot: int = -1
var message_visible: bool = false
var message_running: bool = false
var _wait: String = ""
var _lock_task: bool = false
var _player_frozen: bool = false
var _selected_frozen: bool = false
var _moving_id: int = 0
var _wait_map := Vector2i.ZERO
var _movements: Dictionary = {}
var _output: Array[Dictionary] = []
var _foreground_active: bool = false
var _executing: Gen3ScriptContext


func _init(player: Gen3PlayerAvatar) -> void:
	avatar = player
	objects = player.objects
	context = Gen3ScriptContext.new(objects.camera.data, objects.events)
	warps.location = Gen3Warp.record(objects.camera.group, objects.camera.number, -1,
		avatar.object().current.x - Gen3MapGrid.MAP_OFFSET, avatar.object().current.y - Gen3MapGrid.MAP_OFFSET)


func start(at: int, selected: int = -1) -> void:
	selected_slot = selected
	_wait = ""
	context.start(at)
	_foreground_active = true
	objects.events.controls_locked = true


func resume() -> void:
	context.resume()
	if context.state == Gen3ScriptContext.State.RUNNING:
		objects.events.controls_locked = true


func finish_message() -> void:
	message_running = false


func try_frame_script() -> bool:
	if objects.events.controls_locked or context.state != Gen3ScriptContext.State.STOPPED:
		return false
	if not context.start_map_script(objects.camera.group, objects.camera.number, FRAME_TABLE):
		return false
	selected_slot = -1
	_wait = ""
	_foreground_active = true
	objects.events.controls_locked = true
	return true


func run_map_script(type: int) -> Array[Dictionary]: # script.c::RunScriptImmediately has a separate context and no frame tasks.
	if type == FRAME_TABLE:
		return []
	_output = []
	var immediate := Gen3ScriptContext.new(objects.camera.data, objects.events)
	if not immediate.start_map_script(objects.camera.group, objects.camera.number, type):
		return []
	return _run_immediate(immediate)


func _run_immediate(immediate: Gen3ScriptContext) -> Array[Dictionary]:
	_executing = immediate
	for iteration: int in 10000:
		_collect(immediate.tick(10000, false, _command))
		if immediate.state in [Gen3ScriptContext.State.STOPPED, Gen3ScriptContext.State.FAULT]:
			return _output
		if immediate.state in [Gen3ScriptContext.State.NATIVE_WAIT, Gen3ScriptContext.State.WAITING]:
			immediate.fail(immediate.offset, "immediate_script_wait")
			_collect([immediate.error])
			return _output
	immediate.fail(immediate.offset, "instruction_budget")
	_collect([immediate.error])
	return _output


func tick(pressed: int = PokeButton.NONE) -> Array[Dictionary]:
	_output = []
	_executing = context
	var native_complete: bool = _native_complete(pressed)
	if not warp_pending: # Gen3Script.WARPS ends the cached graph; map loading replaces this context.
		_collect(context.tick(10000, native_complete, _command))
	if _foreground_active and context.state in [Gen3ScriptContext.State.STOPPED, Gen3ScriptContext.State.FAULT]:
		objects.events.controls_locked = warp_pending
		_foreground_active = false
	_step_movements()
	_step_lock_task()
	return _output


func step(held: Array[int] = [], pressed: Array[int] = []) -> Array: # overworld.c::DoCB1_Overworld then OverworldBasic.
	var requests: Array = []
	avatar.update_tile_state()
	var interacting: bool = false
	if not objects.events.controls_locked and not _try_field_event(requests):
		var held_keys: int = _keys(held)
		interacting = _try_direction_warp(held_keys, false, requests)
		if not interacting and PokeButton.A in pressed and avatar.accepts_field_buttons():
			interacting = interact()
		if not interacting:
			interacting = _try_direction_warp(held_keys, true, requests)
		if not interacting:
			requests.append_array(avatar.step(Gen3Bike.dpad_direction(held_keys), _keys(pressed), held_keys))
	var button: int = PokeButton.A if PokeButton.A in pressed else (PokeButton.B if PokeButton.B in pressed else PokeButton.NONE)
	requests.append_array(tick(button))
	requests.append_array(avatar.step_movement_tasks())
	requests.append_array(objects.step_movements(avatar.flags & Gen3PlayerAvatar.Flag.DASH != 0,
		avatar.tile_state == Gen3PlayerAvatar.Tile.CENTER))
	var output: Array = []
	for request: Dictionary in requests:
		match String(request["kind"]):
			"script_enable": resume()
			"script": start(int(request["offset"]), selected_slot)
			_: output.append(request)
	return output


func _try_field_event(requests: Array) -> bool:
	objects.events.var_set(0x800F, 0)
	selected_slot = -1
	if try_frame_script():
		return true
	if avatar.tile_state != Gen3PlayerAvatar.Tile.CENTER or avatar.running_state != Gen3PlayerAvatar.Running.MOVING or avatar.on_forced_tile():
		return false
	if _try_coord_event(requests):
		return true
	var player: Gen3ObjectEvents.ObjectEvent = avatar.object()
	var behavior: int = objects.camera.grid.behavior_at(player.current.x, player.current.y) & 0xFF
	if behavior in [0x60, 0x61, 0x69, 0x6A, 0x6B]:
		return _try_warp(player.current, player.previous_elevation, "escalator" if behavior in [0x6A, 0x6B] else "warp", requests)
	return false


func _front_elevation() -> int:
	var player: Gen3ObjectEvents.ObjectEvent = avatar.object()
	return player.previous_elevation if objects.camera.grid.elevation_at(player.current.x, player.current.y) != 0 else 0


func _try_direction_warp(held: int, door: bool, requests: Array) -> bool:
	if avatar.tile_state == Gen3PlayerAvatar.Tile.TRANSITION or avatar.tile_state == Gen3PlayerAvatar.Tile.CENTER and avatar.on_forced_tile():
		return false
	var player: Gen3ObjectEvents.ObjectEvent = avatar.object()
	var direction: int = Gen3Bike.dpad_direction(held)
	if direction == 0 or direction != player.facing:
		return false
	var at: Vector2i = player.current + (Gen3FieldCamera.DIRECTIONS[direction] if door else Vector2i.ZERO)
	var behavior: int = objects.camera.grid.behavior_at(at.x, at.y) & 0xFF
	if door:
		if direction != Gen3ObjectEvents.Direction.NORTH or behavior != 0x69:
			return false
	else:
		var behaviors: Array = [[], [0x65], [0x64], [0x63], [0x62]]
		if not avatar.frlg:
			behaviors[1].append_array([0x6D, 0x1C])
			behaviors[2].append(0x1B)
		if behavior not in behaviors[direction]:
			return false
	return _try_warp(at, _front_elevation() if door else player.previous_elevation, "door" if door else "warp", requests)


func _try_warp(at: Vector2i, elevation: int, mode: String, requests: Array) -> bool:
	var rows: Array = objects.camera.data.world_map_events(objects.camera.group, objects.camera.number).get("warps", [])
	for index: int in rows.size():
		var row: Dictionary = rows[index]
		if Vector2i(int(row["x"]), int(row["y"])) + Vector2i.ONE * Gen3MapGrid.MAP_OFFSET != at or int(row["elevation"]) not in [0, elevation]:
			continue
		if not warps.from_event(objects.camera.data, objects.camera.group, objects.camera.number, index, at - Vector2i.ONE * Gen3MapGrid.MAP_OFFSET):
			return false
		_output = []
		_begin_warp(mode, false)
		requests.append_array(_output)
		return true
	return false


func _events_at(kind: String, at: Vector2i, elevation: int) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for row: Dictionary in objects.camera.data.world_map_events(objects.camera.group, objects.camera.number).get(kind, []):
		if Vector2i(int(row["x"]), int(row["y"])) + Vector2i.ONE * Gen3MapGrid.MAP_OFFSET == at and int(row["elevation"]) in [0, elevation]:
			found.append(row)
	return found


func _try_coord_event(requests: Array) -> bool: # field_control_avatar.c::TryRunCoordEventScript; immediate rows continue the search.
	var player: Gen3ObjectEvents.ObjectEvent = avatar.object()
	for row: Dictionary in _events_at("coords", player.current, player.previous_elevation):
		var at: int = int(row["script_offset"])
		var trigger: int = int(row["variable"])
		if at == 0:
			var weather: Dictionary = {1: 1, 2: 2, 3: 3, 4: 4, 5: 5, 6: 6, 7: 9, 8: 7, 9: 8, 10: 11, 11: 12, 20: 20, 21: 21}
			if weather.has(trigger):
				requests.append({"kind": "weather", "weather": weather[trigger]})
		elif trigger == 0:
			_output = []
			var immediate := Gen3ScriptContext.new(objects.camera.data, objects.events)
			immediate.start(at)
			requests.append_array(_run_immediate(immediate))
		elif objects.events.var_get(trigger) == (int(row["value"]) & 0xFF):
			start(at)
			return true
	return false


func interact() -> bool:
	if _interact_object():
		return true
	var player: Gen3ObjectEvents.ObjectEvent = avatar.object()
	var direction: int = player.facing
	if objects.events.controls_locked or direction < 1 or direction > 4:
		return false
	var elevation: int = _front_elevation()
	var rows: Array[Dictionary] = _events_at("backgrounds", player.current + Gen3FieldCamera.DIRECTIONS[direction], elevation)
	if rows.is_empty():
		return false
	var row: Dictionary = rows[0] # GetBackgroundEventAtPosition selects the first row, even when its facing check fails.
	var kind: int = int(row["kind"])
	if kind in [5, 6, 7, 8] or kind >= 1 and kind <= 4 and direction != [0, 2, 1, 4, 3][kind]:
		return false
	var at: int = int(row.get("script_offset", 0))
	if at <= 0:
		return false
	objects.events.var_set(0x800C, direction)
	start(at)
	return true


func _interact_object() -> bool: # field_control_avatar.c::GetInteractedObjectEventScript, including a counter's second cell.
	var player: Gen3ObjectEvents.ObjectEvent = avatar.object()
	var direction: int = player.facing
	if objects.events.controls_locked or direction < 1 or direction > 4:
		return false
	var at: Vector2i = player.current + Gen3FieldCamera.DIRECTIONS[direction]
	var elevation: int = _front_elevation()
	var slot: int = objects.at_position(at, elevation)
	if slot < 0 or objects.objects[slot].is_player:
		if objects.camera.grid.behavior_at(at.x, at.y) & 0xFF != 0x80:
			return false
		at += Gen3FieldCamera.DIRECTIONS[direction]
		slot = objects.at_position(at, elevation)
		if slot < 0 or objects.objects[slot].is_player:
			return false
	var object: Gen3ObjectEvents.ObjectEvent = objects.objects[slot]
	objects.events.var_set(0x800F, object.local_id)
	objects.events.var_set(0x800C, direction)
	var at_script: int = int(objects.template_by_id(object.local_id, object.map_number, object.map_group).get("script_offset", 0))
	if at_script <= 0:
		return false
	start(at_script, slot)
	return true


static func _keys(buttons: Array[int]) -> int:
	var keys: int = 0
	for button: int in buttons:
		if button >= 0 and button < KEY_BITS.size():
			keys |= KEY_BITS[button]
	return keys


func _collect(events: Array[Dictionary]) -> void:
	for event: Dictionary in events:
		if event["type"] != "script_command":
			var request: Dictionary = event.duplicate(true)
			request["kind"] = request["type"]
			request.erase("type")
			_output.append(request)


func _command(event: Dictionary) -> void:
	var command: String = event["command"]
	if _executing != context and (command in Gen3ScriptContext.NATIVE_COMMANDS or command in Gen3ScriptContext.WARP_COMMANDS):
		_executing.fail(int(event["offset"]), "immediate_script_wait", event)
		return
	var operands: Array = event["operands"]
	if command in Gen3ScriptContext.WARP_COMMANDS or command.begins_with("set") and command.ends_with("warp"):
		_warp_command(event)
		return
	if command in Gen3ScriptContext.OBJECT_COMMANDS:
		_object_command(command, operands)
		return
	match command:
		"message", "messageautoscroll", "messageinstant", "pokenavcall":
			_show_message(event)
		"closemessage": _close_message()
		"waitmessage", "waitbuttonpress": _wait = command
		"lock", "lockall": _lock(command == "lock")
		"release", "releaseall": _release(command == "release")
		"faceplayer":
			if _selected() != null:
				objects.set_held_movement(_selected(), avatar.action(&"face", Gen3ObjectEvents.OPPOSITE[avatar.object().facing]))
		"turnobject":
			var target: Gen3ObjectEvents.ObjectEvent = _movement_object(objects.events.var_get(int(operands[0])) & 0xFF, Vector2i(objects.camera.group, objects.camera.number))
			if target != null:
				Gen3ObjectEvents.turn(target, int(operands[1]))
		"applymovement", "applymovementat", "applymovement_at":
			var map: Vector2i = _command_map(operands, 2)
			_moving_id = objects.events.var_get(int(operands[0])) & 0xFF
			_start_movement(_moving_id, map, int(operands[1]), event)
		"waitmovement", "waitmovementat", "waitmovement_at":
			var local_id: int = objects.events.var_get(int(operands[0])) & 0xFF
			if local_id != 0:
				_moving_id = local_id
			_wait_map = _command_map(operands, 1)
			_wait = "movement"


func _map_coords(operands: Array, at: int) -> Vector2i:
	var x: int = objects.events.var_get(int(operands[at]))
	var y: int = objects.events.var_get(int(operands[at + 1]))
	return Vector2i((x ^ 0x8000) - 0x8000, (y ^ 0x8000) - 0x8000)


func _object_command(command: String, operands: Array) -> void:
	if command == "setmetatile":
		var at: Vector2i = _map_coords(operands, 0) + Vector2i.ONE * Gen3MapGrid.MAP_OFFSET
		var tile: int = objects.events.var_get(int(operands[2]))
		if objects.events.var_get(int(operands[3])) != 0:
			tile |= Gen3MapGrid.COLLISION_MASK
		objects.camera.grid.set_metatile_id(at.x, at.y, tile)
		return
	if command == "getplayerxy":
		if avatar != null:
			var at: Vector2i = avatar.object().current - Vector2i.ONE * Gen3MapGrid.MAP_OFFSET
			objects.events.var_set(int(operands[0]), at.x)
			objects.events.var_set(int(operands[1]), at.y)
		return
	var local_id: int = objects.events.var_get(int(operands[0])) & 0xFF
	var map: Vector2i = _command_map(operands, 1) if command.ends_with("at") else Vector2i(objects.camera.group, objects.camera.number)
	var object: Gen3ObjectEvents.ObjectEvent = _movement_object(local_id, map)
	match command:
		"removeobject", "removeobjectat", "removeobject_at": objects.remove(local_id, map.y, map.x)
		"addobject", "addobjectat", "addobject_at":
			var template: Dictionary = objects.template_by_id(local_id, map.y, map.x)
			if not template.is_empty():
				objects.spawn(template, map.y, map.x)
		"setobjectxyperm": objects.set_template_coords(local_id, _map_coords(operands, 1))
		"setobjectmovementtype": objects.set_template_movement_type(local_id, int(operands[1]))
		"setobjectxy":
			if object != null:
				Gen3ObjectEvents.move_to_map_coords(object, _map_coords(operands, 1) + Vector2i.ONE * Gen3MapGrid.MAP_OFFSET)
		"copyobjectxytoperm":
			if object != null:
				objects.override_template_coords(object)
		"showobjectat", "hideobjectat":
			if object != null:
				object.invisible = command == "hideobjectat"


func _warp_command(event: Dictionary) -> void:
	var command: String = event["command"]
	var operands: Array = event["operands"]
	var target: Dictionary
	if command == "warphole":
		var at: Vector2i = avatar.object().current - Vector2i.ONE * Gen3MapGrid.MAP_OFFSET
		if int(operands[0]) == 0xFF and int(operands[1]) == 0xFF:
			target = warps.fall_destination(at)
		else:
			target = Gen3Warp.record(int(operands[0]), int(operands[1]), -1, at.x, at.y)
	else:
		target = Gen3Warp.record(int(operands[0]), int(operands[1]), int(operands[2]),
			objects.events.var_get(int(operands[3])), objects.events.var_get(int(operands[4])))
	match command:
		"setdynamicwarp": warps.dynamic = target
		"setdivewarp": warps.dive = target
		"setholewarp": warps.hole = target
		"setescapewarp": warps.escape = target
		"setwarp": warps.destination = target
		_:
			if target.is_empty() or objects.camera.data.world_map_header(int(target["group"]), int(target["number"])).is_empty():
				_executing.fail(int(event["offset"]), "missing_warp_map", event)
				return
			warps.destination = target
			_begin_warp(command, true)


func _begin_warp(mode: String, reset_avatar: bool) -> void:
	warp_pending = true
	_warp_reset_avatar = reset_avatar
	objects.events.controls_locked = true
	_output.append({"kind": "warp", "mode": mode, "destination": warps.destination.duplicate()})


func complete_warp() -> Array[Dictionary]:
	if not warp_pending:
		return []
	var data: GameData = objects.camera.data
	var at: Vector2i = warps.position(data)
	var camera: Gen3FieldCamera = Gen3FieldCamera.open(data, int(warps.destination["group"]), int(warps.destination["number"]), at)
	if camera == null:
		return [{"kind": "script_error", "reason": "missing_warp_map", "destination": warps.destination.duplicate()}]
	var events: Gen3EventData = objects.events
	var gender: int = avatar.gender
	var direction: int = Gen3ObjectEvents.Direction.SOUTH if _warp_reset_avatar else avatar.object().facing
	var state_mask: int = Gen3PlayerAvatar.Flag.ON_FOOT if _warp_reset_avatar else avatar.flags
	var palettes: Gen3Palette = objects.sprites.palette
	warps.location["x"] = avatar.object().current.x - Gen3MapGrid.MAP_OFFSET
	warps.location["y"] = avatar.object().current.y - Gen3MapGrid.MAP_OFFSET
	warps.commit()
	events.clear_temp()
	var next_grid: Gen3MapGrid = camera.grid
	camera.grid = objects.camera.grid
	objects.camera = camera
	objects.load_templates()
	context = Gen3ScriptContext.new(data, events)
	_foreground_active = false
	_wait = ""
	_lock_task = false
	_movements.clear()
	selected_slot = -1
	message_visible = false
	message_running = false
	var output: Array[Dictionary] = run_map_script(3)
	camera.grid = next_grid # overworld.c::LoadMapFromWarp runs ON_TRANSITION before InitMap/ON_LOAD.
	output.append_array(run_map_script(1))
	var templates: Array = objects.templates
	objects = Gen3ObjectEvents.new(camera, events, palettes)
	objects.templates = templates
	avatar = Gen3PlayerAvatar.open(objects, at + Vector2i.ONE * Gen3MapGrid.MAP_OFFSET, direction, gender)
	avatar.transition(state_mask & (Gen3PlayerAvatar.Flag.ON_FOOT | Gen3PlayerAvatar.Flag.MACH_BIKE | Gen3PlayerAvatar.Flag.ACRO_BIKE | Gen3PlayerAvatar.Flag.SURFING | Gen3PlayerAvatar.Flag.UNDERWATER))
	avatar.track_camera()
	objects.spawn_in_view()
	output.append_array(run_map_script(4))
	output.append_array(run_map_script(5))
	warp_pending = false
	events.controls_locked = false
	output.append({"kind": "map_loaded", "group": camera.group, "number": camera.number, "position": at})
	return output


func _command_map(operands: Array, at: int) -> Vector2i:
	return Vector2i(int(operands[at]), int(operands[at + 1])) if operands.size() > at else Vector2i(objects.camera.group, objects.camera.number)


func _show_message(event: Dictionary) -> void:
	if message_running and event["command"] != "messageinstant":
		return
	var pointer: int = int(event["operands"][0])
	var row: Dictionary = objects.camera.data.world_script_data("texts", Gen3Layout.rom_offset(pointer))
	if row.is_empty():
		_executing.fail(int(event["offset"]), "missing_text", event)
		return
	var bytes := PackedByteArray(row["bytes"])
	message_visible = true
	if event["command"] != "messageinstant":
		message_running = true
	_output.append({"kind": "message", "mode": event["command"], "bytes": bytes,
		"text": Gen3Text.decode_fixed(objects.events.game, bytes, 0, bytes.size())})


func _close_message() -> void:
	message_visible = false
	message_running = false
	_output.append({"kind": "close_message"})


func _selected() -> Gen3ObjectEvents.ObjectEvent:
	if selected_slot < 0 or selected_slot >= objects.objects.size():
		return null
	var object: Gen3ObjectEvents.ObjectEvent = objects.objects[selected_slot]
	return object if object.active else null


func _lock(with_selected: bool) -> void: # event_object_lock.c::FreezeObjects_WaitForPlayerAndSelected.
	var lock_selected: bool = with_selected and _selected() != null
	objects.freeze_except_player(selected_slot if lock_selected else -1)
	_player_frozen = false
	_selected_frozen = not lock_selected
	if lock_selected and not _selected().single_movement_active:
		Gen3ObjectEvents.freeze(_selected())
		_selected_frozen = true
	_lock_task = true
	_wait = "lock"


func _step_lock_task() -> void:
	if not _lock_task:
		return
	if not _player_frozen and avatar.tile_state != Gen3PlayerAvatar.Tile.TRANSITION:
		avatar.freeze_for_script()
		_player_frozen = true
	var selected: Gen3ObjectEvents.ObjectEvent = _selected()
	if not _selected_frozen and (selected == null or not selected.single_movement_active):
		if selected != null:
			Gen3ObjectEvents.freeze(selected)
		_selected_frozen = true
	if _player_frozen and _selected_frozen:
		_lock_task = false


func _release(with_selected: bool) -> void:
	_close_message()
	if with_selected and _selected() != null:
		Gen3ObjectEvents.clear_held_movement_if_finished(_selected())
	Gen3ObjectEvents.clear_held_movement_if_finished(avatar.object())
	for slot: int in _movements:
		Gen3ObjectEvents.unfreeze(objects.objects[slot])
	_movements.clear()
	objects.unfreeze_all()


func _native_complete(pressed: int) -> bool:
	if context.state != Gen3ScriptContext.State.NATIVE_WAIT:
		return false
	match _wait:
		"waitmessage": return not message_running
		"waitbuttonpress": return pressed in [PokeButton.A, PokeButton.B]
		"movement": return movement_finished(_moving_id, _wait_map)
		"lock":
			if not _lock_task:
				avatar.stop_for_script()
				return true
	return false


func _movement_object(local_id: int, map: Vector2i) -> Gen3ObjectEvents.ObjectEvent:
	if local_id == Gen3ObjectEvents.LOCALID_PLAYER:
		return avatar.object() if avatar != null else null
	return objects.by_identity(local_id, map.y, map.x)


func movement_finished(local_id: int, map: Vector2i) -> bool:
	var object: Gen3ObjectEvents.ObjectEvent = _movement_object(local_id, map)
	if object == null:
		return true
	var slot: int = objects.objects.find(object)
	return not _movements.has(slot) or bool(_movements[slot]["finished"])


func _start_movement(local_id: int, map: Vector2i, pointer: int, event: Dictionary) -> void:
	var object: Gen3ObjectEvents.ObjectEvent = _movement_object(local_id, map)
	if object == null:
		return
	var slot: int = objects.objects.find(object)
	if _movements.has(slot) and not bool(_movements[slot]["finished"]):
		return
	var row: Dictionary = objects.camera.data.world_script_data("movements", Gen3Layout.rom_offset(pointer))
	if row.is_empty():
		_executing.fail(int(event["offset"]), "missing_movement", event)
		return
	_movements[slot] = {"bytes": PackedByteArray(row["bytes"]), "at": 0, "finished": false}


func _step_movements() -> void: # script_movement.c::ScriptMovement_TakeStep; a finished slot stays reserved until release.
	for slot: int in _movements:
		var object: Gen3ObjectEvents.ObjectEvent = objects.objects[slot]
		var row: Dictionary = _movements[slot]
		if object.held_movement_active and Gen3ObjectEvents.clear_held_movement_if_finished(object) == 0:
			continue
		var bytes: PackedByteArray = row["bytes"]
		var action: int = bytes[int(row["at"])]
		if action == Gen3Script.MOVEMENT_STEP_END:
			row["finished"] = true
			Gen3ObjectEvents.freeze(object)
		elif not objects.set_held_movement(object, action):
			row["at"] = int(row["at"]) + 1
