extends SceneTree

## What a drawn frame costs, per screen, in milliseconds.
##
##   Godot --path . -s res://tools/profile.gd -- [subject ...] [game] [frames]
##   Godot --path . -s res://tools/profile.gd -- all crystal 900
##
## Not a check and not a preview: `tools/checks/` runs headless under
## `validate.gd` and answers right or wrong, and a `preview_*.gd` photographs one
## frame. Neither can say what sixty of them cost, which is the only question
## that decides whether a weaker machine holds its frame rate.
##
## A real window, vsync off and no frame cap, so the number is the whole frame:
## the screen's own hardware pass, whatever it rebuilds, and the draw. Every
## subject is driven by counted `advance_frame()` calls with the node's own
## `_process` off, so one drawn frame is one hardware frame whatever the host
## does, and two runs compare.
##
## The number is this machine's. What carries across machines is the ratio
## between two runs of the same subject, which is what an optimisation is
## measured by.

const WINDOW_SIZE := Vector2i(1152, 648)
## Frames spent before the first one is timed: a screen builds its textures on
## the frame it is opened, and that is a load cost rather than a frame cost.
const WARMUP_FRAMES: int = 60
const DEFAULT_FRAMES: int = 600
## A run that fights takes several battles' worth of frames to be worth reading.
const BATTLE_FRAMES: int = 1200
## The hardware's own frame. A subject over this on this machine cannot hold
## sixty on any machine.
const HARDWARE_FRAME_MS: float = 1000.0 / 60.0
## Fixed, so two runs of a subject walk the same map and roll the same wilds.
const PROFILE_SEED: int = 20260823

## Every subject, in the order `all` runs them. Each names the method that opens
## it; the method answers a node to add and a [Callable] that spends one hardware
## frame on it.
const SUBJECTS: Array[StringName] = [
	&"opening",
	&"title",
	&"overworld",
	&"overworld_framed",
	&"battle",
	&"start_menu",
	&"pack",
]

var _data: GameData = null
var _rows: Array[Dictionary] = []


func _initialize() -> void:
	root.set_content_scale_size(WINDOW_SIZE)
	root.size = WINDOW_SIZE
	# The cap and the sync are what the number would otherwise be: a subject
	# under a 60 Hz sync measures the monitor.
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	# Every subject runs on the defaults rather than on whatever the owner of
	# this machine last chose, so two runs on two machines are the same run.
	Gen2OptionsStore.use_test_path()
	_run.call_deferred()


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var game: StringName = &"crystal"
	var frames: int = DEFAULT_FRAMES
	var wanted: Array[StringName] = []
	for argument: String in args:
		if argument.is_valid_int():
			frames = maxi(1, int(argument))
		elif argument == "all":
			wanted.append_array(SUBJECTS)
		elif SUBJECTS.has(StringName(argument)):
			wanted.append(StringName(argument))
		else:
			game = StringName(argument)
	if wanted.is_empty():
		wanted = SUBJECTS.duplicate()

	_data = GameData.open(game)
	if _data == null:
		printerr("No cache for %s. Import roms/%s.gbc first." % [game, game])
		quit(1)
		return

	for subject: StringName in wanted:
		await _measure(subject, frames)
	_report(game)
	quit(0)


## One subject: open it, spend [constant WARMUP_FRAMES] untimed, then time each
## of [param frames] drawn frames end to end.
func _measure(subject: StringName, frames: int) -> void:
	var opened: Dictionary = await call(&"_open_%s" % subject)
	if opened.is_empty():
		_rows.append({"subject": subject, "skipped": true})
		return
	var node: Node = opened["node"]
	var step: Callable = opened["step"]
	var count: int = int(opened.get("frames", frames))

	# Re-asserted per subject: opening one goes through the game's own runtime,
	# and a cap or a sync put back there would make every row the monitor's.
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var samples := PackedFloat64Array()
	for index: int in WARMUP_FRAMES + count:
		var started: int = Time.get_ticks_usec()
		step.call()
		await process_frame
		if index >= WARMUP_FRAMES:
			samples.append(float(Time.get_ticks_usec() - started) / 1000.0)
	_rows.append(_summary(subject, samples))

	root.remove_child(node)
	node.queue_free()
	# The next subject starts from an empty tree rather than from whatever the
	# last one left in flight.
	await process_frame


func _summary(subject: StringName, samples: PackedFloat64Array) -> Dictionary:
	var sorted := PackedFloat64Array(samples)
	sorted.sort()
	var total: float = 0.0
	var over: int = 0
	for sample: float in samples:
		total += sample
		if sample > HARDWARE_FRAME_MS:
			over += 1
	var count: int = samples.size()
	return {
		"subject": subject,
		"frames": count,
		"mean": total / float(count),
		"median": sorted[count / 2],
		"p95": sorted[mini(int(float(count) * 0.95), count - 1)],
		"max": sorted[count - 1],
		"over": over,
	}


func _report(game: StringName) -> void:
	print("%s, %s, vsync %d, cap %d" % [
		game, OS.get_model_name(),
		DisplayServer.window_get_vsync_mode(), Engine.max_fps,
	])
	print("%-20s %7s %8s %8s %8s %8s %7s" % [
		"subject", "frames", "mean", "median", "p95", "max", "over"
	])
	for row: Dictionary in _rows:
		if bool(row.get("skipped", false)):
			print("%-20s %7s" % [row["subject"], "skipped"])
			continue
		print("%-20s %7d %8.3f %8.3f %8.3f %8.3f %7d" % [
			row["subject"], row["frames"], row["mean"], row["median"],
			row["p95"], row["max"], row["over"],
		])


## `SplashScreen` from its first frame: the copyright, the GameFreak logo and
## whichever intro movie the cache carries. Restarted when it runs out, since the
## movie is shorter than a long run and a finished screen costs nothing.
func _open_opening() -> Dictionary:
	var screen := Gen2SplashScreen.new()
	if not screen.open(_data):
		screen.free()
		return {}
	root.add_child(screen)
	screen.set_process(false)
	await process_frame
	return {
		"node": screen,
		"step": func() -> void:
			if screen.visible_image() == &"":
				screen.open(_data)
			screen.advance_frames(1),
	}


## The same screen held on `TitleScreenMain`, which is the one phase of the
## opening a player can sit in.
func _open_title() -> Dictionary:
	var screen := Gen2SplashScreen.new()
	if not screen.open(_data):
		screen.free()
		return {}
	root.add_child(screen)
	screen.set_process(false)
	await process_frame
	var guard: int = 0
	while screen.visible_image() != &"title" and guard < 20000:
		screen.advance_frames(1)
		guard += 1
	if screen.visible_image() != &"title":
		root.remove_child(screen)
		screen.free()
		return {}
	return {"node": screen, "step": func() -> void: screen.advance_frames(1)}


func _open_overworld(fill: bool = true) -> Dictionary:
	## SCREEN FILL is on by default, so the wide buffer is the ordinary case and
	## the 160x144 one is what a player who turned it off gets. Set on the shared
	## object rather than saved: the store is pointed at its own file below, and
	## a measurement has no business rewriting what the player chose.
	Gen2OptionsStore.current().screen_fill = fill
	var packed: PackedScene = load("res://game/world/world_screen.tscn")
	var screen: Gen2WorldScreen = packed.instantiate() as Gen2WorldScreen
	var save: Gen2SaveData = Gen2SaveStore.create_development_save(_data, 0)
	if save == null:
		screen.free()
		return {}
	save.run_seed = PROFILE_SEED
	save.world = Gen2WorldSpawn.new_game_snapshot(_data)
	screen.set_data(_data)
	screen.set_save(save)
	screen.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(screen)
	await process_frame
	if screen._world == null:
		root.remove_child(screen)
		screen.free()
		return {}
	screen.set_process(false)
	## Walked rather than stood still: a standing player redraws nothing, and
	## what a map costs is the camera moving over it. The turn every two seconds
	## keeps the walk on the spawn map.
	var log_lines: Array = []
	for frame: int in WARMUP_FRAMES + BATTLE_FRAMES:
		@warning_ignore("integer_division")
		var leg: int = (frame / 120) % 4
		log_lines.append({
			"frame": frame, "kind": "hold",
			"button": [Gen2Button.DOWN, Gen2Button.RIGHT, Gen2Button.UP, Gen2Button.LEFT][leg],
		})
	screen.replay_input(log_lines)
	return {"node": screen, "step": func() -> void: screen.advance_frame()}


func _open_overworld_framed() -> Dictionary:
	return await _open_overworld(false)


## `DoBattle` from the menu on: the turn is retaken whenever the fight settles,
## so the run measures animations, the HP bars and the boxes rather than a menu
## sitting still.
func _open_battle() -> Dictionary:
	var packed: PackedScene = load("res://game/battle/battle_screen.tscn")
	var screen: Gen2BattleScreen = packed.instantiate() as Gen2BattleScreen
	screen.set_data(_data)
	root.add_child(screen)
	screen.set_process(false)
	await process_frame
	screen.show_matchup(16, 155, 20, 20)
	return {
		"node": screen,
		"frames": BATTLE_FRAMES,
		"step": func() -> void:
			screen.set_process(false)
			if screen._audio_player != null:
				screen._audio_player.stop_all()
			if screen.frames_running():
				screen.advance_frame()
				return
			if screen.entrance_running() \
				or bool(screen.battle_snapshot()["awaits_press"]):
				screen.finish()
				screen.advance()
				return
			screen.take_turn_with(0, 0),
	}


## `StartMenu` over the map, which is the menu a player opens most.
func _open_start_menu() -> Dictionary:
	return await _open_world_menu(Gen2Button.START)


## The pack, which draws a list, an item's own picture and the map behind it.
func _open_pack() -> Dictionary:
	var opened: Dictionary = await _open_world_menu(Gen2Button.START)
	if opened.is_empty():
		return {}
	var screen: Gen2WorldScreen = opened["node"]
	## Down to PACK and A, on the pass the menu reads a press on.
	for button: int in [Gen2Button.DOWN, Gen2Button.A]:
		screen.press_button(button)
		for _frame: int in 16:
			screen.advance_frame()
	return opened


func _open_world_menu(button: int) -> Dictionary:
	var opened: Dictionary = await _open_overworld()
	if opened.is_empty():
		return {}
	var screen: Gen2WorldScreen = opened["node"]
	screen.replay_input([])
	screen.press_button(button)
	for _frame: int in 32:
		screen.advance_frame()
	return opened
