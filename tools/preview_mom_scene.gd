extends SceneTree

## `MeetMomRightScript` through the world screen, frame by frame.
##   Godot --headless --path . -s res://tools/preview_mom_scene.gd -- <game> [png] [frame]
## The story walker proves the script's results, never that the presentation runs,
## and a run that moves a checkpoint exits non-zero. Crystal triggers on the coord
## events at (8,4) and (9,4), Gold and Silver `sdefer` it from the map entry, and
## `MomScript` is then talked to from the cell the scene left free.

const WINDOW_SIZE := Vector2i(Gen2Screen.WIDTH, Gen2Screen.HEIGHT)
const FRAME: float = 1.0 / 59.7275
const TRACE_FRAMES: int = 4000

## The frame the emote, Mom's first drawn step, the text box and the script's own
## `end` land on. `showemote EMOTE_SHOCK, MOM1, 15` is 30 frames and the walk is
## `MomWalksToPlayerMovement`, both counted in overworld passes.
const CHECKPOINTS: Dictionary = {
	&"crystal": {&"emote": 17, &"walk": 46, &"text": 77, &"done": 1921},
	&"gold": {&"emote": 17, &"walk": 47, &"text": 143, &"done": 2051},
	&"silver": {&"emote": 17, &"walk": 47, &"text": 143, &"done": 2051},
}

## The five boxes the scene asks over, in order and the same on all three.
## `SetDayOfWeek` draws its own; the rest are a `writetext`'s last page.
const QUESTIONS: Array[String] = [
	"What day is it?",
	" SUNDAY, is it?",
	"Is it Daylight\nSaving Time now?",
	" 6:00 AM DST,\nis that OK?",
	"know how to use\nthe PHONE?",
]

## Who looks at whom at the text: Crystal's `turnobject PLAYER, LEFT` and Mom's
## `turn_head RIGHT` against pokegold's `turnobject ..., UP`.
const FACINGS_AT_TEXT: Dictionary = {
	&"crystal": {&"player": Gen2WorldSprite.FACING_LEFT, &"mom": Gen2WorldSprite.FACING_RIGHT},
	&"gold": {&"player": Gen2WorldSprite.FACING_DOWN, &"mom": Gen2WorldSprite.FACING_UP},
	&"silver": {&"player": Gen2WorldSprite.FACING_DOWN, &"mom": Gen2WorldSprite.FACING_UP},
}
const FACING_NAMES: Array[String] = ["down", "up", "left", "right"]

const MUSIC_CHANNELS: int = 3

const PLAYERS_HOUSE_1F: int = 6
const MOM_OBJECT: int = 0
const APPROACH_CELL := Vector2i(9, 3)
const TRIGGER_CELL := Vector2i(9, 4)
## Where `MomScript` is talked to once the scene has finished: her walk back
## leaves her on (7,4) on Crystal and (7,3) on pokegold.
const TALK_CELLS: Dictionary = {
	&"crystal": Vector2i(8, 4), &"gold": Vector2i(8, 3), &"silver": Vector2i(8, 3),
}
const MOM_FACING_AT_TALK: int = Gen2WorldSprite.FACING_RIGHT

var _game: StringName = &""
var _screen: Gen2WorldScreen = null
var _output_path: String = ""
var _capture_frame: int = TRACE_FRAMES
var _frames: int = 0
var _started: bool = false
var _talk_frame: int = -1
var _talk_facing: int = -1
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
	## The trace owns the clock: host frames of its own move every row by one.
	_screen.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(_screen)
	current_scene = _screen


## One row per source frame, so a gap is a run of frames rather than a hole.
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
		"player_facing": world.player_drawn_facing(),
		"mom_facing": mom.facing if mom != null else -1,
		"emote": mom != null and mom.emote_visible,
		"text": _screen._text_box != null and _screen._text_box.visible,
		"channels": _screen._audio_player.audio_status()["active_channels"],
		"prompt": _screen._script_prompt,
		"asking": _asking(world),
	}


## The question a choice or a menu opens over: the map script's own last page.
func _asking(world: Gen2WorldAPI) -> String:
	var pending: Dictionary = world.pending_script_input()
	if StringName(pending.get("type", &"")) not in [&"choice", &"menu"]:
		return ""
	return String(pending.get("text", ""))


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
	# Before the press below, so a capture keeps the box that press would answer.
	if _frames == _capture_frame and not _output_path.is_empty():
		var image: Image = Gen2ToolPath.capture(root)
		if image == null:
			quit(1)
			return true
		image.save_png(_output_path)
		print("Wrote %s at frame %d" % [_output_path, _frames])
	if not _trace.is_empty() and bool(_trace[-1]["waiting_input"]):
		# Every question answered YES, the way the other preview drivers do.
		_screen.press_button(Gen2Button.A)
	elif not _trace.is_empty() and not bool(_trace[-1]["script_busy"]):
		_drive_talk()
	_screen._process(FRAME)
	_trace.append(_sample())
	if _talk_frame < 0 and _first_frame(&"done") >= 0 and bool(_trace[-1]["text"]):
		_talk_frame = _frames
		_talk_facing = int(_trace[-1]["mom_facing"])
	if _frames < maxi(TRACE_FRAMES, _capture_frame):
		return false
	_report()
	quit(0 if _checkpoints_hold() else 1)
	return true


func _drive_talk() -> void:
	var world: Gen2WorldAPI = _screen._world
	if _talk_frame >= 0 or _first_frame(&"text") < 0:
		return
	var target: Vector2i = TALK_CELLS.get(_game, Vector2i(8, 4))
	var step := Vector2i(signi(target.x - world.player_cell.x), 0)
	if step == Vector2i.ZERO:
		step = Vector2i(0, signi(target.y - world.player_cell.y))
	if step == Vector2i.ZERO and world.player_facing == Gen2WorldSprite.FACING_LEFT:
		_screen.press_button(Gen2Button.A)
		return
	_screen.move_player(step if step != Vector2i.ZERO else Vector2i(-1, 0))


## The first frame each checkpoint appears on, a line each so a shift names
## itself.
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
	held = _questions_hold() and held
	held = _facings_hold() and held
	held = _talk_facing_holds() and held
	held = _channels_hold() and held
	print("%s checkpoints %s" % [_game, "hold" if held else "MOVED"])
	return held


func _questions_hold() -> bool:
	var asked: Array[String] = _questions()
	if Array(asked) == Array(QUESTIONS):
		return true
	printerr("%s asks %s, not %s" % [
		_game, JSON.stringify(asked), JSON.stringify(QUESTIONS),
	])
	return false


func _facings_hold() -> bool:
	var expected: Dictionary = FACINGS_AT_TEXT.get(_game, {})
	var at: int = _first_frame(&"text")
	if expected.is_empty() or at < 0 or at >= _trace.size():
		return true
	var row: Dictionary = _trace[at]
	var held: bool = true
	for who: StringName in expected:
		var facing: int = int(row["%s_facing" % who])
		var want: int = int(expected[who])
		if facing == want:
			continue
		printerr("%s %s faces %s at the text, not %s" % [
			_game, who, _facing_name(facing), _facing_name(want),
		])
		held = false
	return held


## `MovementFunction_Standing`'s STEP_TYPE_RESTORE resets once and stands, so a
## standing object holds what `MomScript`'s own `faceplayer` gives it.
func _talk_facing_holds() -> bool:
	if _talk_frame < 0:
		printerr("%s never got MomScript's own box up" % _game)
		return false
	if _talk_facing == MOM_FACING_AT_TALK:
		return true
	printerr("%s faceplayer left Mom looking %s, not %s" % [
		_game, _facing_name(_talk_facing), _facing_name(MOM_FACING_AT_TALK),
	])
	return false


func _facing_name(facing: int) -> String:
	return FACING_NAMES[facing] if facing >= 0 and facing < FACING_NAMES.size() else "?"


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
		print("f%4d  script %s  input %s  player %s %s  mom %s %s%s%s  text %s  chan %s  %s" % [
			row["frame"],
			"busy" if row["script_busy"] else "idle",
			"wait" if row["waiting_input"] else "-   ",
			row["player"], _facing_name(int(row["player_facing"])),
			row["mom"], _facing_name(int(row["mom_facing"])),
			" stepping" if row["mom_offset"] != Vector2.ZERO else "",
			" emote" if row["emote"] else "",
			"up" if row["text"] else "-",
			row["channels"],
			row["prompt"],
		])
	print("%d frames, %d changes" % [_trace.size(), changes])
	for row: Dictionary in _trace:
		if not String(row["asking"]).is_empty() \
			and _first_asking(String(row["asking"])) == int(row["frame"]):
			print("  f%4d asks %s" % [row["frame"], JSON.stringify(row["asking"])])


func _first_asking(question: String) -> int:
	for row: Dictionary in _trace:
		if String(row["asking"]) == question:
			return int(row["frame"])
	return -1


func _questions() -> Array[String]:
	var out: Array[String] = []
	for row: Dictionary in _trace:
		var asking: String = String(row["asking"])
		if not asking.is_empty() and (out.is_empty() or out[out.size() - 1] != asking):
			out.append(asking)
	return out
