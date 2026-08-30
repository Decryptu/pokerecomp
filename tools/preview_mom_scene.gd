extends SceneTree

## Traces `MeetMomRightScript` through the world screen, frame by frame.
##
##   Godot --headless --path . -s res://tools/preview_mom_scene.gd -- <game> [png] [frame]
##
## The story walker proves the script's results, never that the presentation runs,
## and a run that moves a checkpoint exits non-zero. Crystal triggers on the coord
## events at (8,4) and (9,4); Gold and Silver `sdefer` it from the map entry.

const WINDOW_SIZE := Vector2i(Gen2Screen.WIDTH, Gen2Screen.HEIGHT)
const FRAME: float = 1.0 / 59.7275
## Long enough for the whole conversation, which the trace answers as it goes.
const TRACE_FRAMES: int = 4000

## The frame the emote, Mom's first drawn step, the text box and the script's own
## `end` each land on, per profile. Every interval between them is the source's:
## `showemote EMOTE_SHOCK, MOM1, 15` is 30 frames of emote, and the walk is
## `MomWalksToPlayerMovement`'s own steps, both counted in overworld passes.
const CHECKPOINTS: Dictionary = {
	&"crystal": {&"emote": 17, &"walk": 46, &"text": 77, &"done": 1909},
	&"gold": {&"emote": 17, &"walk": 47, &"text": 143, &"done": 2039},
	&"silver": {&"emote": 17, &"walk": 47, &"text": 143, &"done": 2039},
}

## Both pieces are `channel_count 3` on all three profiles, so a fourth music
## channel on is the town still playing under `playmusic MUSIC_MOM`.
const MUSIC_CHANNELS: int = 3

## `constants/map_constants.asm`, and `Gen2WorldSpawn`'s own group.
const PLAYERS_HOUSE_1F: int = 6
## `MomWalksToPlayerMovement` starts here, and the player is met at (9,4).
const MOM_OBJECT: int = 0
const APPROACH_CELL := Vector2i(9, 3)
const TRIGGER_CELL := Vector2i(9, 4)

var _game: StringName = &""
var _screen: Gen2WorldScreen = null
var _output_path: String = ""
var _capture_frame: int = TRACE_FRAMES
var _frames: int = 0
var _started: bool = false
var _trace: Array[Dictionary] = []


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("Usage: preview_mom_scene.gd -- <game> [out.png] [frame]")
		quit(1)
		return
	var game: StringName = StringName(args[0])
	_game = game
	if args.size() > 1:
		_output_path = args[1]
		if Gen2ToolPath.refuses(_output_path):
			quit(2)
			return
	if args.size() > 2:
		_capture_frame = maxi(1, int(args[2]))

	var sha1: String = RomRegistry.sha1_for(game)
	var directory: String = RomCache.directory_for(game, sha1) if not sha1.is_empty() else ""
	if directory.is_empty() or not RomCache.is_usable(directory):
		push_error("No cache for %s. Run tools/import_rom.gd first." % game)
		quit(1)
		return
	var data: GameData = GameData.open_directory(directory)

	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.set_content_scale_size(WINDOW_SIZE)

	var packed: PackedScene = load("res://game/world/world_screen.tscn")
	_screen = packed.instantiate() as Gen2WorldScreen
	_screen.map_group = Gen2WorldSpawn.NEW_BARK_GROUP
	_screen.map_number = PLAYERS_HOUSE_1F
	_screen.start_cell = APPROACH_CELL
	var world := Gen2WorldAPI.open(
		data, Gen2WorldSpawn.NEW_BARK_GROUP, PLAYERS_HOUSE_1F, APPROACH_CELL
	)
	var save := Gen2SaveStore.create_development_save(data, 0)
	save.world = world.snapshot()
	_screen.set_data(data)
	_screen.set_save(save)
	## The trace owns the clock. Without this the screen spends host frames of
	## its own before the trace starts, and the row an event lands on moves by
	## one from run to run.
	_screen.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(_screen)
	current_scene = _screen


## One row per source frame, so a gap in the presentation is a run of frames
## with nothing happening rather than a missing event.
func _sample() -> Dictionary:
	var world: Gen2WorldAPI = _screen._world
	var mom: Gen2WorldObject = null
	for object: Gen2WorldObject in world.visible_objects():
		if object.index == MOM_OBJECT:
			mom = object
	return {
		"frame": _frames,
		"script_busy": world.script_busy(),
		"waiting_input": world.script_input_waiting(),
		"player": world.player_cell,
		"mom": mom.cell if mom != null else Vector2i(-1, -1),
		"mom_offset": mom.step_offset_cells() if mom != null else Vector2.ZERO,
		"emote": mom != null and mom.emote_visible,
		"text": _screen._text_box != null and _screen._text_box.visible,
		"channels": _screen._audio_player.audio_status()["active_channels"],
		"prompt": _screen._script_prompt,
	}


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 3:
		# The development caption and hint are drawn over a 160x144 window, so a
		# capture of the game itself loses them. Done from here because the
		# screen's own nodes are not resolved until it has run a frame.
		for label: StringName in [&"Caption", &"Hint"]:
			var node: CanvasItem = _screen.get_node_or_null(NodePath(label)) as CanvasItem
			if node != null:
				node.visible = false
		return false
	if not _started:
		_started = true
		_screen.move_player(Vector2i(0, 1))
	if not _trace.is_empty() and bool(_trace[-1]["waiting_input"]):
		# Every question answered YES, the way the other preview drivers do.
		_screen.press_button(Gen2Button.A)
	_screen._process(FRAME)
	_trace.append(_sample())
	if _frames == _capture_frame and not _output_path.is_empty():
		var image: Image = Gen2ToolPath.capture(root)
		if image == null:
			quit(1)
			return true
		image.save_png(_output_path)
		print("Wrote %s at frame %d" % [_output_path, _frames])
	if _frames < maxi(TRACE_FRAMES, _capture_frame):
		return false
	_report()
	quit(0 if _checkpoints_hold() else 1)
	return true


## The first frame each of the three checkpoints appears on, against the pinned
## row. Reported as a line per checkpoint so a shift names itself.
func _checkpoints_hold() -> bool:
	var expected: Dictionary = CHECKPOINTS.get(_game, {})
	if expected.is_empty():
		print("no pinned checkpoints for %s" % _game)
		return true
	var held: bool = true
	for name: StringName in [&"emote", &"walk", &"text", &"done"]:
		var at: int = _first_frame(name)
		var want: int = int(expected[name])
		if at != want:
			printerr("%s %s first appears on frame %d, not %d" % [_game, name, at, want])
			held = false
	held = _channels_hold() and held
	print("%s checkpoints %s" % [_game, "hold" if held else "MOVED"])
	return held


func _channels_hold() -> bool:
	for row: Dictionary in _trace:
		var music: Array = (row["channels"] as Array).filter(
			func(channel: int) -> bool: return channel <= Gen2SoundEngine.NUM_MUSIC_CHANNELS
		)
		if music.size() <= MUSIC_CHANNELS:
			continue
		printerr("%s frame %d has %s on for a three-channel piece" % [
			_game, row["frame"], music,
		])
		return false
	return true


func _first_frame(name: StringName) -> int:
	var after: int = _first_frame(&"text") if name == &"done" else -1
	for row: Dictionary in _trace:
		var showing: bool = false
		match name:
			&"emote": showing = bool(row["emote"])
			&"walk": showing = row["mom_offset"] != Vector2.ZERO
			&"text": showing = bool(row["text"])
			_: showing = int(row["frame"]) > after and not bool(row["script_busy"])
		if showing:
			return int(row["frame"])
	return -1


## Prints only where something changed, which is what makes a stall readable.
func _report() -> void:
	var last: Dictionary = {}
	var changes: int = 0
	for row: Dictionary in _trace:
		var without: Dictionary = row.duplicate()
		without.erase("frame")
		if without == last:
			continue
		last = without
		changes += 1
		print("f%4d  script %s  input %s  player %s  mom %s%s%s  text %s  chan %s  %s" % [
			row["frame"],
			"busy" if row["script_busy"] else "idle",
			"wait" if row["waiting_input"] else "-   ",
			row["player"], row["mom"],
			" stepping" if row["mom_offset"] != Vector2.ZERO else "",
			" emote" if row["emote"] else "",
			"up" if row["text"] else "-",
			row["channels"],
			row["prompt"],
		])
	print("%d frames, %d changes" % [_trace.size(), changes])
