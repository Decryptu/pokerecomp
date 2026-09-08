extends SceneTree

## Captures the new-game opening screens against a real cache.
##   Godot --path . -s res://tools/preview_intro.gd -- <game> <out.png> [what] [steps] [WxH]

## Captured at hardware resolution, so a frame here compares to an emulator
## frame pixel for pixel rather than by eye.
const WINDOW_SIZE := Vector2i(Gen2Screen.WIDTH, Gen2Screen.HEIGHT)
const SCREEN_SCENE: String = "res://game/render/gen2_screen.tscn"
const FRAMES_BEFORE_CAPTURE: int = 6
## The copyright half in front of the GameFreak animation: `DelayFrames 10`, the
## screen for a hundred, and the frame `SplashScreen` clears it on.
const PRESENTS_FIRST_FRAME: int = Gen2BootCinema.COPYRIGHT_PRELUDE_FRAMES \
	+ Gen2BootCinema.COPYRIGHT_HOLD_FRAMES
## Enough frames for the copyright, the GameFreak logo and both intro movies,
## which `title` spends before it is on the screen it was asked for.
const TITLE_GUARD: int = 20000
const NAME_MENU_GUARD: int = 200
const NEW_GAME_GUARD: int = 400
const PRESET_ROW: int = 1
const SAVE_ROOT: String = "user://preview_intro_slots"

var _output_path: String = ""
var _what: String = "gender"
var _steps: Array[Vector2i] = [Vector2i.ZERO]
var _at: int = 0
var _screen: Control = null
## The window to photograph in; the hardware's own unless a caller names one.
var _window: Vector2i = WINDOW_SIZE
var _elapsed: int = 0
var _presses_run: int = 0
var _frames_run: int = 0


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error(
			"Usage: preview_intro.gd -- <game> <out.png> "
			+ "[copyright|presents|title|gender|clock|speech|name_menu|naming|shrink]"
			+ " [step] [WxH]"
		)
		quit(1)
		return
	var game: StringName = StringName(args[0])
	_output_path = args[1]
	if PokeToolPath.refuses(_output_path):
		quit(2)
		return
	if args.size() > 2:
		_what = args[2]
	if args.size() > 4:
		var shape: PackedStringArray = args[4].split("x", false)
		if shape.size() == 2:
			_window = Vector2i(maxi(int(shape[0]), 1), maxi(int(shape[1]), 1))
	if args.size() > 3:
		_steps = []
		for value: String in args[3].split(","):
			# `presses+frames`, so a beat can be reached by button and then
			# stepped a frame at a time through the animation it starts.
			var parts: PackedStringArray = value.split("+")
			_steps.append(Vector2i(
				maxi(int(parts[0]), 0), maxi(int(parts[1]), 0) if parts.size() > 1 else 0
			))

	var directory: String = _find_cache(game)
	if directory.is_empty():
		push_error("No cache for %s. Run tools/import_rom.gd first." % game)
		quit(1)
		return
	var data: GameData = GameData.open_directory(directory)
	if data == null:
		push_error("Could not open the cache for %s." % game)
		quit(1)
		return

	# CONTENT_SCALE_MODE_VIEWPORT makes the root viewport exactly the size asked
	# for, so the captured texture is the hardware frame rather than a magnified
	# window, or the window shape being photographed whatever the display allows.
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP \
		if _window == WINDOW_SIZE else Window.CONTENT_SCALE_ASPECT_IGNORE
	root.set_content_scale_size(_window)
	if _what == "new_game":
		_run_new_game(data)
		return
	_screen = _build(data)
	if _screen == null:
		quit(1)
		return
	if _window == WINDOW_SIZE:
		# The window is already one hardware screen across, so the sub-screens
		# are added to it directly rather than through [Gen2Screen]'s scaling
		# viewport.
		root.add_child(_screen)
		current_scene = _screen
		return
	var host: Gen2Screen = (load(SCREEN_SCENE) as PackedScene).instantiate()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(host)
	current_scene = host
	# Deferred: `_initialize` runs before the tree serves a frame, so the screen
	# has not built the layer a sub-screen goes on yet.
	host.display.call_deferred(_screen)


func _build(data: GameData) -> Control:
	if _what in ["copyright", "presents", "title"]:
		var splash := Gen2SplashScreen.new()
		if not splash.open(data):
			push_error("This cache carries no copyright screen.")
			splash.free()
			return null
		return splash
	if _what == "gender":
		var gender := Gen2GenderScreen.new()
		if not gender.open(data):
			push_error("This cartridge has no gender screen.")
			gender.free()
			return null
		return gender
	if _what == "clock":
		var clock := Gen2ClockSetScreen.new()
		if not clock.open(data):
			push_error("This cache carries no clock font.")
			clock.free()
			return null
		return clock
	var speech := Gen2OakSpeechScreen.new()
	if not speech.open(data, Gen2SaveData.GENDER_MALE):
		push_error("This cache carries no intro text.")
		speech.free()
		return null
	return speech


## Runs the screen forward to [param step]: `x` A presses, each with the queued
## `DelayFrames` run spent in front of it, then `y` raw source frames. On the
## gender screen `x` is cursor moves instead; in `speech` mode it is frames, so
## the opening fades can be stepped through without a press.
func _drive(step: Vector2i) -> void:
	if _what in ["copyright", "presents", "title"]:
		# `SplashScreen` reads no button over the copyright, so both halves of a
		# step are frames: the screen appears on the tenth and is cleared a
		# hundred later, and the GameFreak animation runs straight on from there.
		# `presents` counts from the frame that animation starts on, and `title`
		# from the first frame `TitleScreenMain` is up.
		var splash: Gen2SplashScreen = _screen as Gen2SplashScreen
		if _what == "title":
			while splash.visible_image() != &"title" and _frames_run < TITLE_GUARD:
				splash.advance_frames(1)
				_frames_run += 1
			_frames_run = 0
		var offset: int = PRESENTS_FIRST_FRAME if _what == "presents" else 0
		while _frames_run < offset + step.x + step.y:
			splash.advance_frames(1)
			_frames_run += 1
		return
	if _what == "gender":
		for _press: int in step.x - _presses_run:
			_screen.handle_button(PokeButton.DOWN)
		_presses_run = step.x
		return
	if _what == "clock":
		# `x` is A presses and `y` raw frames after them, so a fade or a
		# `DelayFrames` run can be photographed partway as well as settled.
		var clock: Gen2ClockSetScreen = _screen as Gen2ClockSetScreen
		while _presses_run < step.x:
			_settle_frames(clock)
			clock.handle_button(PokeButton.A)
			_presses_run += 1
			_frames_run = 0
		clock.advance_frames(maxi(step.y - _frames_run, 0))
		_frames_run = maxi(step.y, _frames_run)
		return
	var speech: Gen2OakSpeechScreen = _screen as Gen2OakSpeechScreen
	if _what == "speech":
		while _frames_run < step.x:
			speech.advance_frames(1)
			_frames_run += 1
		return
	if _what in ["name_menu", "naming", "shrink"]:
		_press_until(speech, speech.choosing_name if _what != "shrink" \
			else func() -> bool: return speech.beat_index() >= speech.beat_count())
		if _what == "naming":
			speech.handle_button(PokeButton.A)
			_settle_frames(speech)
		for _press: int in step.x:
			speech.handle_button(PokeButton.DOWN)
		speech.advance_frames(step.y)
		return
	while _presses_run < step.x:
		_settle_frames(speech)
		speech.handle_button(PokeButton.A)
		_presses_run += 1
		_frames_run = 0
	# Both halves of a step are absolute, so steps given in order photograph a
	# run of frames rather than compounding.
	speech.advance_frames(maxi(step.y - _frames_run, 0))
	_frames_run = maxi(step.y, _frames_run)


func _press_until(speech: Gen2OakSpeechScreen, reached: Callable) -> void:
	for _press: int in NAME_MENU_GUARD:
		if bool(reached.call()):
			return
		_settle_frames(speech)
		if bool(reached.call()):
			return
		speech.handle_button(PokeButton.A)


## Spends whatever `DelayFrames` run or printing text a screen is standing in.
func _settle_frames(screen: Node) -> void:
	for _pass: int in 40:
		var owed: int = int(screen.call(&"animation_frames_left"))
		if owed == 0:
			return
		screen.call(&"advance_frames", owed)


## One capture per step, each after a fresh pair of rendered frames so the
## textures written this step have reached the window.
func _process(_delta: float) -> bool:
	if _screen == null:
		return false
	_elapsed += 1
	# Frames are spent by `steps`, not by the clock, so a given frame of a fade
	# comes out the same on every run. It has to be turned off from inside the
	# tree: a node with `_process` has it enabled again when it is added.
	_screen.set_process(false)
	if _elapsed < FRAMES_BEFORE_CAPTURE:
		return false
	if _at >= _steps.size():
		quit(0)
		return true
	if _elapsed == FRAMES_BEFORE_CAPTURE:
		_drive(_steps[_at])
		return false
	var image: Image = PokeToolPath.capture(root)
	if image == null:
		quit(1)
		return true
	var path: String = _output_path
	if _steps.size() > 1:
		path = "%s_%d_%d.%s" % [
			_output_path.get_basename(), _steps[_at].x, _steps[_at].y,
			_output_path.get_extension(),
		]
	var error: Error = image.save_png(path)
	if error != OK:
		push_error("Could not write %s (error %d)" % [path, error])
		quit(1)
		return true
	print("Wrote %s (%dx%d)" % [path, image.get_width(), image.get_height()])
	_at += 1
	_elapsed = FRAMES_BEFORE_CAPTURE - 1
	return false


func _run_new_game(data: GameData) -> void:
	Gen2SaveStore.use_root(SAVE_ROOT)
	var intro := Gen2IntroScreen.new()
	intro.finished.connect(_on_new_game_written.bind(data))
	intro.failed.connect(func(message: String) -> void:
		push_error("The new game did not finish: %s" % message)
		quit(1)
	)
	intro.begin(data, 0, "", false)
	root.add_child(intro)
	current_scene = intro
	await process_frame
	for _press: int in NEW_GAME_GUARD:
		if _at > 0:
			return
		_settle_frames(intro)
		var screen: Control = intro.current()
		if screen != null and bool(screen.call(&"choosing_name")):
			for _row: int in PRESET_ROW:
				intro.handle_button(PokeButton.DOWN)
		intro.handle_button(PokeButton.A)
	push_error("The opening did not reach its save in %d presses." % NEW_GAME_GUARD)
	quit(1)


func _on_new_game_written(save: Gen2SaveData, data: GameData) -> void:
	_at = 1
	var world: Gen2WorldSnapshot = save.world
	var warp: Dictionary = data.gen1_new_game_warp()
	var wanted: Dictionary = {
		"map": [world.map_id, Vector2i(0, int(warp["map"]))],
		"cell": [world.player_cell, Vector2i(int(warp["x"]), int(warp["y"]))],
		"money": [world.world_state.money(0), Gen2WorldSpawn.START_MONEY],
		"pc_items": [world.world_state.pc_items(), {Gen2WorldSpawn.GEN1_POTION: 1}],
		"bag": [world.world_state.items(), {}],
		"party": [save.party.size(), 0],
		"player": [save.player_name, data.gen1_default_names(false)[PRESET_ROW]],
		"rival": [world.gen1_rival_name, data.gen1_default_names(true)[PRESET_ROW]],
	}
	var failures: int = 0
	for field: String in wanted:
		var pair: Array = wanted[field]
		var ok: bool = pair[0] == pair[1]
		failures += 0 if ok else 1
		print("%-9s %-8s %s" % [field, "ok" if ok else "WRONG", pair[0]])
	var written: Dictionary = Gen2SaveStore.load_result(save.game_id, save.rom_sha1, 0, data)
	print("reopened  %s" % ("ok" if bool(written["ok"]) else String(written["message"])))
	Gen2SaveStore.use_root("")
	quit(1 if failures > 0 or not bool(written["ok"]) else 0)


func _find_cache(game: StringName) -> String:
	var sha1: String = RomRegistry.sha1_for(game)
	if sha1.is_empty():
		return ""
	var directory: String = RomCache.directory_for(game, sha1)
	return directory if RomCache.is_usable(directory) else ""
