class_name Gen3FieldScreen
extends RefCounted # `overworld.c`'s field frame around [Gen3ScriptHost]: it answers the requests it can and returns those only a screen above it can: battles, the START menu, sounds.

const SIZE := Vector2i(240, 160)
const HOST_FINISHED: Array[String] = ["waitse", "waitfanfare", "waitmoncry", "fadeoutbgm", "hidemonpic"] # No GBA audio or pic windows yet.
const FADES: Array[String] = ["fadescreen", "fadescreenspeed", "fadescreenswapbuffers"]
const DOOR_COMMANDS: Array[String] = ["opendoor", "closedoor", "setdooropen", "setdoorclosed"]

var data: GameData
var host: Gen3ScriptHost
var vram: Gen3FieldVram
var weather: Gen3FieldWeather
var doors: Gen3FieldDoor
var warp: Gen3FieldWarp
var message: Gen3FieldMessage
var menu: Gen3FieldMenu
var _keys_held: bool = false
var _keys_pressed: bool = false
var _pressed: Array[int] = []
var _waiting: Callable = Callable()
var _requests: Array = []


static func open(game: GameData, group: int, number: int, at: Vector2i, direction: int = 1, gender: int = 0,
		flags: int = Gen3PlayerAvatar.Flag.ON_FOOT, forced_weather: int = -1) -> Gen3FieldScreen: # Standing on layout cell [param at]; null where the player cannot stand.
	var camera: Gen3FieldCamera = Gen3FieldCamera.open(game, group, number, at)
	if camera == null:
		return null
	var screen := Gen3FieldScreen.new()
	screen.data = game
	screen.vram = Gen3FieldVram.load(camera.grid.primary, camera.grid.secondary)
	var events := Gen3EventData.new(game.id)
	var objects := Gen3ObjectEvents.new(camera, events, screen.vram.palette)
	screen.weather = Gen3FieldWeather.new(game, screen.vram.palette, events)
	objects.sprites.weather = screen.weather
	screen.weather.sprites.camera = camera
	if forced_weather < 0:
		screen.weather.set_saved_from_header(camera.header)
	else:
		screen.weather.set_saved(forced_weather)
	screen.weather.start()
	screen.weather.resume_paused()
	var avatar := Gen3PlayerAvatar.open(objects, at + Vector2i.ONE * Gen3MapGrid.MAP_OFFSET, direction, gender)
	if avatar == null:
		return null
	avatar.transition(flags)
	avatar.track_camera()
	objects.spawn_in_view()
	screen.host = Gen3ScriptHost.new(avatar)
	screen.host.field_tasks = screen._run_tasks
	screen.warp = Gen3FieldWarp.new(screen)
	screen.message = Gen3FieldMessage.new(game.world_text_box(), screen.host.input.engine, screen.vram.palette)
	screen.menu = Gen3FieldMenu.new(screen.message, screen.host.input.engine)
	screen.doors = Gen3FieldDoor.new(camera, screen.vram, screen.host.input, events)
	screen.vram.palette.faded.fill(0) # FieldCB_FadeTryShowMapPopup's FadeInFromBlack.
	screen.weather.fade_screen(Gen3FieldWeather.Fade.FROM_BLACK, 0)
	return screen


func frame(held: Array[int] = [], pressed: Array[int] = []) -> Array: # One frame: `CB1_Overworld`, then `OverworldBasic` and VBlank's palette transfer. What the field could not answer returns.
	var avatar: Gen3PlayerAvatar = host.avatar
	var previous: Vector2i = avatar.object().pixel_position
	_keys_held = PokeButton.A in held or PokeButton.B in held
	_keys_pressed = PokeButton.A in pressed or PokeButton.B in pressed
	_pressed = pressed
	var out: Array = _answer(host.step(held, pressed))
	out.append_array(_requests)
	_requests.clear()
	var camera: Gen3FieldCamera = host.objects.camera
	if host.avatar == avatar and camera.update(avatar.object().pixel_position - previous) != Vector2i.ZERO:
		host.objects.follow_camera()
	if camera.crossed:
		_cross_connection()
	weather.sprites.animate(camera.sprite_coord_offset())
	vram.palette.update_fade()
	vram.step()
	vram.palette.transfer()
	return out


func picture() -> Image:
	var objects: Gen3ObjectEvents = host.objects
	var origin: Vector2i = objects.camera.screen_origin()
	var overlay: Dictionary = objects.field_move_mon.screen()
	return vram.draw_screen(objects.camera.grid, origin, SIZE, objects.sprites.oam(objects, origin), weather.bldalpha,
		overlay if not overlay.is_empty() else message.overlay())


func request(row: Dictionary) -> void: # A task's request for the next [method frame]'s return.
	_requests.append(row)


func load_warp() -> void: # `WarpIntoMap` and `CB2_LoadMap`'s steps: everything the map load resets, around the host's own.
	var palette: Gen3Palette = vram.palette
	palette.reset_fade()
	weather.task = Gen3FieldWeather.Task.NONE
	_waiting = Callable()
	message.hide()
	var loaded: Array[Dictionary] = host.complete_warp()
	var camera: Gen3FieldCamera = host.objects.camera
	vram = Gen3FieldVram.load(camera.grid.primary, camera.grid.secondary, palette)
	doors = Gen3FieldDoor.new(camera, vram, host.input, host.objects.events)
	weather.sprites.camera = camera
	_requests.append_array(_answer(loaded))


func _run_tasks(requests: Array) -> Array:
	var out: Array = _answer(requests)
	if not _waiting.is_null() and _waiting.call():
		_waiting = Callable()
		host.finish_wait()
	warp.step(out)
	if message.step(_keys_held, _keys_pressed, out):
		host.finish_message()
	var choice: int = menu.step(_pressed, out)
	if choice != Gen3FieldMenu.NOTHING:
		host.choose(choice)
	doors.step()
	weather.run_tasks()
	return out


func _cross_connection() -> void: # New tilesets and the door cells, which are BG tilemap writes the crossing's redraw replaces.
	var camera: Gen3FieldCamera = host.objects.camera
	vram.door_cells.clear()
	var palette: Gen3Palette = vram.palette
	vram = Gen3FieldVram.load(camera.grid.primary, camera.grid.secondary, palette)
	doors = Gen3FieldDoor.new(camera, vram, host.input, host.objects.events)


func _answer(requests: Array) -> Array:
	var out: Array = []
	for row: Dictionary in requests:
		if not _answered(row):
			out.append(row)
	return out


func _answered(row: Dictionary) -> bool:
	var kind: String = row["kind"]
	if kind == "warp":
		warp.begin(row, _requests)
	elif kind in HOST_FINISHED:
		host.finish_wait()
	elif kind in FADES:
		_fade(row)
	elif kind in DOOR_COMMANDS:
		_door(kind, row["operands"])
	elif kind == "message":
		message.show(Gen3Text.encode(row["text"]), row["mode"], int(row["color"]), host.signpost)
		if not message.printing:
			host.finish_message()
	elif kind == "close_message":
		message.hide()
	elif kind == "menu":
		menu.open(row)
	elif kind == "waitdooranim":
		_waiting = func() -> bool: return not doors.running
	elif kind == "waitfieldeffect":
		var effect: int = int(row["operands"][0])
		_waiting = func() -> bool: return not host.objects.field_effect_active(effect)
	else:
		return kind in ["map_loaded", "redraw_map"]
	return true


func _fade(row: Dictionary) -> void: # ScrCmd_fadescreen and its two kin hold on IsPaletteNotActive.
	var operands: Array = row["operands"]
	weather.fade_screen(int(operands[0]), int(operands[1]) if operands.size() > 1 else 0)
	_waiting = func() -> bool: return not vram.palette.fade_active


func _door(kind: String, operands: Array) -> void:
	var cell: Vector2i = Vector2i(int(operands[0]), int(operands[1])) + Vector2i.ONE * Gen3MapGrid.MAP_OFFSET
	match kind:
		"opendoor":
			_requests.append({"kind": "sound", "name": doors.sound(cell)})
			doors.open(cell)
		"closedoor": doors.close(cell)
		"setdooropen": doors.set_opened(cell)
		"setdoorclosed": doors.set_closed(cell)
