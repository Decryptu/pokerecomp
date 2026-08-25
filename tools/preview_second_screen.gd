extends SceneTree

## Photographs the lower display against a real cache.
##
##   Godot --path . -s res://tools/preview_second_screen.gd -- <game> <out.png> [tab] [progress] [panel]
##
## `tab` is one of `pokedex`, `pokemon`, `pack`, `pokegear`, `player`, or `all`
## to write one file per open tab with the tab's name before the extension.
## `progress` is how far the run has got, which is the only thing that decides
## which tabs exist: `start` is a player who has just left their bedroom,
## `starter` has Elm's Pokemon, `gear` has the Pokegear and the MAP card, and
## `full` has everything the START menu can offer. `panel` is a lower display's
## own pixel size, `WIDTHxHEIGHT`, which chooses the canvas the way a real one
## would; the default is the AYN Thor's 1240x1080.
##
## The picture written is the canvas itself, one file pixel per hardware pixel,
## so a diff against it is exact. Look at it with an image viewer that does not
## smooth.
##
## Opens a window: a [SubViewport] needs a rendering device.

const WINDOW_SIZE := Vector2i(640, 480)
const FRAMES_BEFORE_CAPTURE: int = 8
const DEFAULT_PANEL := Vector2i(1240, 1080)

## `data/maps/spawn_points.asm`'s `spawn NEW_BARK_TOWN, 13, 6`, which is where a
## run starts and so where the region map's cursor honestly sits.
const MAP_GROUP: int = 24
const MAP_NUMBER: int = 4
const START_CELL := Vector2i(13, 6)

const TABS: Array[StringName] = [
	Gen2WorldStartMenu.ITEM_POKEDEX,
	Gen2WorldStartMenu.ITEM_POKEMON,
	Gen2WorldStartMenu.ITEM_PACK,
	Gen2WorldStartMenu.ITEM_POKEGEAR,
	Gen2WorldStartMenu.ITEM_PLAYER,
]

## What each progress step has, as the engine flags [Gen2WorldStartMenu] gates
## on plus whether Elm has handed over a starter.
const PROGRESS: Dictionary = {
	&"start": {"party": false, "flags": []},
	&"starter": {"party": true, "flags": []},
	&"gear": {"party": true, "flags": [
		Gen2WorldStartMenu.ENGINE_POKEGEAR, Gen2WorldState.ENGINE_MAP_CARD,
	]},
	&"full": {"party": true, "flags": [
		Gen2WorldStartMenu.ENGINE_POKEGEAR, Gen2WorldStartMenu.ENGINE_POKEDEX,
		Gen2WorldState.ENGINE_MAP_CARD, Gen2WorldState.ENGINE_PHONE_CARD,
		Gen2WorldState.ENGINE_RADIO_CARD,
	]},
}

## A pocket with something in it, so the pack tab is a listing rather than one
## CANCEL row: a Potion, a Poke Ball, the Bicycle and TM01.
const ITEMS: Dictionary = {0x12: 5, 0x04: 10, 0x07: 1, 0xBF: 1}

var _output_path: String = ""
var _tab: StringName = &"all"
var _progress: StringName = &"full"
var _panel: Vector2i = DEFAULT_PANEL
var _view: Gen2SecondScreen = null
var _frames: int = 0
var _written: int = 0
## The tabs still to photograph, the one whose page is drawn but not yet copied,
## and how many frames are left before it is.
var _pending: Array = []
var _armed: StringName = &""
var _wait: int = 0


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error(
			"Usage: preview_second_screen.gd -- <game> <out.png> [tab] [progress] [panel]"
		)
		quit(1)
		return
	var game: StringName = StringName(args[0])
	_output_path = args[1]
	if Gen2ToolPath.refuses(_output_path):
		quit(2)
		return
	if args.size() > 2:
		_tab = StringName(args[2])
	if args.size() > 3:
		_progress = StringName(args[3])
	if args.size() > 4:
		var parts: PackedStringArray = args[4].split("x")
		if parts.size() == 2:
			_panel = Vector2i(int(parts[0]), int(parts[1]))
	if not PROGRESS.has(_progress):
		push_error("Unknown progress %s; one of %s" % [_progress, PROGRESS.keys()])
		quit(1)
		return

	var sha1: String = RomRegistry.sha1_for(game)
	var directory: String = RomCache.directory_for(game, sha1) if not sha1.is_empty() else ""
	if directory.is_empty() or not RomCache.is_usable(directory):
		push_error("No cache for %s. Run tools/import_rom.gd first." % game)
		quit(1)
		return
	var data: GameData = GameData.open_directory(directory)

	var step: Dictionary = PROGRESS[_progress]
	var state := Gen2WorldState.new({}, {}, ITEMS.duplicate(), {0: 3000})
	for flag: int in (step["flags"] as Array):
		state.set_engine_flag(flag, true)
	var world: Gen2WorldAPI = Gen2WorldAPI.open(
		data, MAP_GROUP, MAP_NUMBER, START_CELL, state
	)
	var save: Gen2SaveData = Gen2SaveStore.create_development_save(data, 0)
	if bool(step["party"]):
		world.set_party_summary(
			save.party.size(), false, _species(save), [], [], _eggs(save)
		)
	else:
		save.party = []
		world.set_party_summary(0, false)

	root.set_content_scale_size(WINDOW_SIZE)
	root.size = WINDOW_SIZE
	_view = Gen2SecondScreen.new()
	_view.canvas_size = Gen2SecondScreenHost.canvas_for(_panel)
	root.add_child(_view)
	_view.size = Vector2(_view.canvas_size)
	_view.set_world(data, world, save)
	_pending = [_tab] if _tab != &"all" else TABS.duplicate()
	current_scene = _view


static func _species(save: Gen2SaveData) -> Array[int]:
	var out: Array[int] = []
	for member: Gen2SaveMon in save.party:
		out.append(member.species)
	return out


static func _eggs(save: Gen2SaveData) -> Array:
	var out: Array = []
	for member: Gen2SaveMon in save.party:
		out.append(member.is_egg)
	return out


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < FRAMES_BEFORE_CAPTURE:
		return false
	if _wait > 0:
		_wait -= 1
		return false
	if not _armed.is_empty():
		_capture(_armed)
		_armed = &""
	if _pending.is_empty():
		if _written == 0:
			push_error("No tab was open at progress %s." % _progress)
			quit(1)
			return true
		quit(0)
		return true
	var kind: StringName = StringName(_pending.pop_front())
	if _view.select_tab(kind):
		_armed = kind
		## The page is built now and the viewport carries it a frame later, which
		## is what every capture in this directory waits for.
		_wait = 2
	return false


func _capture(kind: StringName) -> void:
	var picture: Image = _view.frame()
	if picture == null:
		return
	var path: String = _output_path
	if _tab == &"all":
		path = "%s_%s.%s" % [
			_output_path.get_basename(), kind, _output_path.get_extension()
		]
	picture.save_png(path)
	print("%s  %dx%d" % [path, picture.get_width(), picture.get_height()])
	_written += 1
