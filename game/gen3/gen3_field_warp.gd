class_name Gen3FieldWarp
extends RefCounted # Ruby's `field_fadetransition.c`, FRLG's and Emerald's `field_screen_effect.c`: the tasks leaving and entering a map. BGMusicStopped waits on nothing yet.

enum Task { NONE, ENTER_DOOR, LEAVE, EXIT_DOOR, EXIT_NON_ANIM_DOOR, EXIT_NON_DOOR }

const MAP_TYPE_UNDERGROUND: int = 4
const WHITE_FADE_DELAY: int = 8
const FRLG_DOOR_FADE_DELAY: int = 3
const FRLG_DOOR_OPEN_DELAY: int = 25
const FRLG_DOOR_CLOSE_DELAY: int = 14
const SOUNDS: Dictionary = {"warp": "exit", "teleport": "warp_in", "warpteleport": "warp_in", "mossdeep_gym": "warp_in",
	"warpmossdeepgym": "warp_in"} # What each `Do*Warp` plays; a mode absent here plays none.
const WHITE_MODES: Array[String] = ["warpwhitefade"]

var task: int = Task.NONE
var _state: int = 0
var _timer: int = 0
var _timer_b: int = 0
var _door := Vector2i.ZERO
var _from_white: bool = false
var _screen: Gen3FieldScreen


func _init(screen: Gen3FieldScreen) -> void:
	_screen = screen


func active() -> bool:
	return task != Task.NONE


func begin(request: Dictionary, requests: Array) -> void: # The host's `warp` request: the `Do*Warp` its mode names. Modes without their own presentation fade as `DoDiveWarp` does.
	var mode: String = request["mode"]
	_from_white = mode in WHITE_MODES
	_state = 0
	_timer = 0
	_timer_b = 0
	if mode in ["door", "warpdoor"]:
		task = Task.ENTER_DOOR
		return
	if _from_white:
		_screen.weather.fade_screen(Gen3FieldWeather.Fade.TO_WHITE, WHITE_FADE_DELAY)
	else:
		_fade_out()
	if SOUNDS.has(mode):
		requests.append({"kind": "sound", "name": SOUNDS[mode]})
	task = Task.LEAVE


func step(requests: Array) -> void:
	match task:
		Task.ENTER_DOOR: _enter_door(requests)
		Task.LEAVE: _leave()
		Task.EXIT_DOOR: _exit_door()
		Task.EXIT_NON_ANIM_DOOR: _exit_non_anim_door()
		Task.EXIT_NON_DOOR: _exit_non_door()


func arrive() -> void: # FieldCB_DefaultWarpExit and FieldCB_WarpExitFadeFromWhite, on a map that just loaded.
	var host: Gen3ScriptHost = _screen.host
	var player: Gen3ObjectEvents.ObjectEvent = host.avatar.object()
	var behavior: int = host.objects.camera.grid.behavior_at(player.current.x, player.current.y) & 0xFF
	_state = 0
	_timer = 0
	_timer_b = 0
	host.objects.events.controls_locked = true
	if host.input.is_door(behavior):
		task = Task.EXIT_DOOR
		if host.avatar.frlg:
			_screen.vram.palette.faded.fill(_fill_color())
			return
	elif host.input.is_non_anim_door(behavior):
		task = Task.EXIT_NON_ANIM_DOOR
	else:
		task = Task.EXIT_NON_DOOR
	_fade_in(WHITE_FADE_DELAY if _from_white else 0)


func _fade_out() -> void: # WarpFadeOutScreen: into a cave is to white.
	var data: GameData = _screen.data
	var camera: Gen3FieldCamera = _screen.host.objects.camera
	var target: Dictionary = _screen.host.warps.destination
	var to_type: int = int(data.world_map_header(int(target["group"]), int(target["number"])).get("map_type", 0))
	var entering: bool = _enters_cave(int(camera.header.get("map_type", 0)), to_type)
	_screen.weather.fade_screen(Gen3FieldWeather.Fade.TO_WHITE if entering else Gen3FieldWeather.Fade.TO_BLACK, 0)


func _fade_in(delay: int) -> void: # WarpFadeInScreen: out of a cave is from white.
	var white: bool = _from_white or _leaves_cave()
	_screen.vram.palette.faded.fill(_fill_color())
	_screen.weather.fade_screen(Gen3FieldWeather.Fade.FROM_WHITE if white else Gen3FieldWeather.Fade.FROM_BLACK, delay)


func _fill_color() -> int: # FillPalBufferWhite is 0xFFFF, so bytes do.
	return 0xFF if _from_white or _leaves_cave() else 0


func _leaves_cave() -> bool:
	var camera: Gen3FieldCamera = _screen.host.objects.camera
	var last: Dictionary = _screen.host.warps.last
	if last.is_empty():
		return false
	var from_type: int = int(_screen.data.world_map_header(int(last["group"]), int(last["number"])).get("map_type", 0))
	return from_type == MAP_TYPE_UNDERGROUND and int(camera.header.get("map_type", 0)) in Gen3FieldInput.MAP_TYPES_ABOVE_CAVES


static func _enters_cave(from_type: int, to_type: int) -> bool: # fldeff_flash.c's sTransitionTypes.
	return to_type == MAP_TYPE_UNDERGROUND and from_type in Gen3FieldInput.MAP_TYPES_ABOVE_CAVES


func _leave() -> void: # Task_WarpAndLoadMap, or FRLG's Task_Teleport2Warp.
	match _state:
		0:
			_screen.host.objects.freeze_except_player()
			_state = 1
		1:
			if not _screen.vram.palette.fade_active:
				_state = 2
		2:
			task = Task.NONE
			_screen.load_warp()
			arrive()


func _enter_door(requests: Array) -> void: # Task_DoDoorWarp.
	var host: Gen3ScriptHost = _screen.host
	var player: Gen3ObjectEvents.ObjectEvent = host.avatar.object()
	match _state:
		0:
			host.objects.freeze_except_player()
			_door = player.current + Vector2i.UP
			requests.append({"kind": "sound", "name": _screen.doors.sound(_door)})
			_screen.doors.open(_door)
			_state = 1
		1:
			if not _screen.doors.running:
				if player.held_movement_active:
					Gen3ObjectEvents.clear_held_movement(player)
				host.objects.set_held_movement(player, host.avatar.action(&"walk_normal", Gen3ObjectEvents.Direction.NORTH))
				_state = 2
		2:
			if host.avatar.tile_state != Gen3PlayerAvatar.Tile.TRANSITION:
				_screen.doors.close(_door)
				Gen3ObjectEvents.clear_held_movement_if_finished(player)
				player.invisible = true
				_state = 3
		3:
			if not _screen.doors.running:
				_state = 4
		4:
			_fade_out()
			_state = 0
			task = Task.LEAVE


func _exit_door() -> void:
	if _screen.host.avatar.frlg:
		_exit_door_frlg()
		return
	var host: Gen3ScriptHost = _screen.host
	var player: Gen3ObjectEvents.ObjectEvent = host.avatar.object()
	match _state:
		0:
			player.invisible = true
			host.objects.freeze_except_player()
			_door = player.current
			_screen.doors.set_opened(_door)
			_state = 1
		1:
			if _faded_in():
				_walk_out(player, Gen3ObjectEvents.Direction.SOUTH)
				_state = 2
		2:
			if host.avatar.tile_state != Gen3PlayerAvatar.Tile.TRANSITION:
				_screen.doors.close(_door)
				Gen3ObjectEvents.clear_held_movement_if_finished(player)
				_state = 3
		3:
			if not _screen.doors.running:
				host.objects.unfreeze_all()
				_state = 4
		4:
			_finish()


func _exit_door_frlg() -> void: # FRLG's Task_ExitDoor opens the door after the fade starts and starts closing it 14 frames into the walk.
	var host: Gen3ScriptHost = _screen.host
	var player: Gen3ObjectEvents.ObjectEvent = host.avatar.object()
	match _state:
		0:
			player.invisible = true
			host.objects.freeze_except_player()
			_fade_in(FRLG_DOOR_FADE_DELAY)
			_state = 1
		1:
			_timer += 1
			if _timer == FRLG_DOOR_OPEN_DELAY:
				_door = player.current
				_screen.request({"kind": "sound", "name": _screen.doors.sound(_door)})
				_screen.doors.open(_door)
				_state = 2
		2:
			if not _screen.doors.running:
				_walk_out(player, Gen3ObjectEvents.Direction.SOUTH)
				_state = 3
		3:
			_timer_b += 1
			if _timer_b == FRLG_DOOR_CLOSE_DELAY:
				_screen.doors.close(_door)
				_state = 4
		4:
			if _faded_in() and host.avatar.tile_state != Gen3PlayerAvatar.Tile.TRANSITION and not _screen.doors.running:
				Gen3ObjectEvents.clear_held_movement_if_finished(player)
				_state = 5
		5:
			host.objects.unfreeze_all()
			_finish()


func _exit_non_anim_door() -> void:
	var host: Gen3ScriptHost = _screen.host
	var player: Gen3ObjectEvents.ObjectEvent = host.avatar.object()
	match _state:
		0:
			player.invisible = true
			host.objects.freeze_except_player()
			_state = 1
		1:
			if _faded_in():
				_walk_out(player, player.facing)
				_state = 2
		2:
			if host.avatar.tile_state != Gen3PlayerAvatar.Tile.TRANSITION:
				host.objects.unfreeze_all()
				_state = 3
		3:
			_finish()


func _exit_non_door() -> void:
	match _state:
		0:
			_screen.host.objects.freeze_except_player()
			_state = 1
		1:
			if _faded_in():
				_screen.host.objects.unfreeze_all()
				_finish()


func _walk_out(player: Gen3ObjectEvents.ObjectEvent, direction: int) -> void:
	var host: Gen3ScriptHost = _screen.host
	player.invisible = false
	host.objects.set_held_movement(player, host.avatar.action(&"walk_normal", direction))


func _faded_in() -> bool: # WaitForWeatherFadeIn.
	return _screen.weather.is_not_fading_in()


func _finish() -> void:
	task = Task.NONE
	_screen.host.objects.events.controls_locked = false
