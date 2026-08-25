extends SceneTree

## Records one overworld clip to a video, for a trailer rather than for a check.
##
## Godot's Movie Maker is what makes this reproducible: `--write-movie` pins the
## frame delta, so the world's own clock spends exactly one hardware frame per
## recorded frame and a clip is the same clip twice. Nothing here steps the
## screen by hand for that reason: the game runs its ordinary `_process`, mods
## included, and only the buttons are scripted.
##
##   Godot --path . --mods --write-movie /tmp/clip.avi --fixed-fps 60 \
##     -s res://tools/record_clip.gd -- <game> <group> <map> [key=value ...]
##
## The AVI is Motion JPEG with the game's own audio in it. What a trailer wants
## is the clip proper at 1080p, and `TRIM=<frame>` on stdout is where that
## starts: the mod load and the warm-up in front of it are as long as they are,
## so the number is printed rather than assumed. The nearest-neighbour step is
## what keeps the pixels square through a scale that is not a whole number:
##
##   ffmpeg -i clip.avi -vf "trim=start_frame=$TRIM,setpts=PTS-STARTPTS,\
##     scale=2304:1296:flags=neighbor,scale=1920:1080:flags=lanczos" \
##     -c:v libx264 -crf 18 -pix_fmt yuv420p -r 60 clip.mp4
##
## Keys, all optional:
##   cell=<x>,<y>   where the player stands when the map opens
##   hour=<0-23>    the clock the map is drawn on, which is its palette
##   view=<mod id>  a mod's renderer instead of the built-in one (`voxel3d`)
##   size=<W>x<H>   the size the game lays itself out for, 1280x720 by default.
##                  NOT the video's: Movie Maker fixes that at the project's own
##                  viewport before a line of this script runs.
##   seconds=<n>    how long the clip runs after the warm-up
##   seed=<n>       the run seed, which is what a mod's spawn plan is built from
##   hold=<dir>     a direction held for the whole clip: up, down, left, right
##   do=<frame>:<action>   one scripted action, repeatable
##
## Actions are a button name (`a`, `b`, `start`, `select`, `up`, `down`, `left`,
## `right`), `hold-<dir>` or `hold-none` to change what is held from that frame,
## `surf` to mount the water the player is facing, `battle` to start a wild
## fight, `menu-off` to close whatever is open, or `view-<mod id>` to switch the
## renderer on camera, cover and all. Frames are the world's own, counted from
## the first recorded one.
##
## A `probe=` records nothing and answers a question instead, which is how a clip
## is aimed before it is shot:
##   probe=map    an ASCII plan of the map: `.` land, `~` water, `#` blocked,
##                `o` an object standing on it, `@` the player's own cell
##   probe=walk   runs the clip's own buttons and prints the path the player
##                actually took, so a walk that hits a wall is seen before it is
##                recorded rather than after
##   probe=wilds  the wild population this `seed=` really puts on the map
##   probe=shiny  asks the installed visible-encounter providers for the plan
##                every seed would build on this map and prints the ones holding
##                a shiny, which is how a sparkle clip gets its `seed=`
##
## A `probe=` takes the same arguments as the clip it is aiming, and `cell=` is
## not optional among them: where the player stands is part of the context a
## spawn plan is built from, so a seed found from one cell puts its shiny
## somewhere else from another. `probe=wilds` is the check on that.

const DEFAULT_WINDOW := Vector2i(1280, 720)
## Frames spent before the clip proper: the map loads, a mod's renderer is
## chosen and its cover is settled. Trimmed off the video afterwards.
const WARMUP_FRAMES: int = 60

## How long the mod load may take before the screen is built without it. The
## clip is then the game without mods, which is a real answer for a run that
## passed no `--mods`.
const MOD_LOAD_FRAMES: int = 120
const DEFAULT_SECONDS: float = 6.0
const FRAMES_PER_SECOND: float = 60.0
## How many seeds `probe=shiny` tries before giving up. A shiny is one plan entry
## in 8192, and a plan holds up to `maximum` of them.
const PROBE_SEEDS: int = 20000

var _screen: Gen2WorldScreen = null
var _window: Vector2i = DEFAULT_WINDOW
var _view: StringName = &""
var _restore_view: StringName = &""
var _hold: int = Gen2Button.NONE
var _frames: int = 0
var _length: int = int(DEFAULT_SECONDS * FRAMES_PER_SECOND)
var _actions: Dictionary = {}
var _probe: StringName = &""
var _failed: bool = false
## The world's own frame number when the clip proper starts. Every scripted
## frame is counted from it, so a `do=` lands on the hardware frame it names
## whatever the warm-up cost.
var _base: int = -1
## The scripted frames still to run, lowest first.
var _pending: Array[int] = []
## Every distinct cell the player stood on, for `probe=walk`.
var _path: Array[Vector2i] = []
## Whether the mod's renderer asked for by `view=` is the one being drawn.
var _chosen: bool = false
var _game: StringName = &""
var _map := Vector2i.ZERO
var _cell := Vector2i(-1, -1)
var _hour: int = -1
var _seed: int = 1
## Frames spent before the clip proper, which the video is trimmed by. Raised
## for a clip waiting on something the map spends on its own clock rather than on
## a button: the visible-encounter mod's shiny sparkle is one, and it runs for
## about seventy frames every six hundred, so a clip that wants it starts a
## little before one of those.  is where the number is read off.
var _warmup: int = WARMUP_FRAMES
## The frame the screen was built on, which every count below is relative to.
var _built_at: int = 0


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() < 3:
		push_error("Usage: record_clip.gd -- <game> <group> <map> [key=value ...]")
		_quit_failed()
		return

	var cell := Vector2i(-1, -1)
	var hour: int = -1
	var seed_value: int = 1
	for extra: String in args.slice(3):
		var key: String = extra.get_slice("=", 0)
		var value: String = extra.substr(key.length() + 1)
		match key:
			"cell":
				cell = Vector2i(int(value.get_slice(",", 0)), int(value.get_slice(",", 1)))
			"hour":
				hour = int(value)
			"view":
				_view = StringName(value)
			"size":
				_window = Vector2i(int(value.get_slice("x", 0)), int(value.get_slice("x", 1)))
			"seconds":
				_length = int(maxf(0.1, float(value)) * FRAMES_PER_SECOND)
			"seed":
				seed_value = int(value)
			"hold":
				_hold = _direction(value)
			"do":
				_add_action(int(value.get_slice(":", 0)), value.substr(value.find(":") + 1))
			"warmup":
				_warmup = maxi(2, int(value))
			"probe":
				_probe = StringName(value)
			_:
				push_error("Unknown option: %s" % extra)
				_quit_failed()
				return

	_game = StringName(args[0])
	_map = Vector2i(int(args[1]), int(args[2]))
	_cell = cell
	_hour = hour
	_seed = seed_value


## Whether the mods are still loading, which the screen has to be built after.
##
## `GameRuntime` loads them from its own `_ready`, and that has not run while
## `_initialize` runs nor on the first frame after it. A screen built before it
## has no follower walking behind the player and no wild Pokemon on the map, and
## which of those a clip caught was a race. Waited out rather than loaded again
## here: a second `load_mods` registers every mod twice, and `reload_mods` runs
## the save lifecycle, which is what puts a development run's randomizer over a
## clip that never asked for one.
func _waiting_for_mods() -> bool:
	if _frames > MOD_LOAD_FRAMES or not Gen2GameRuntime.mods_are_allowed():
		return false
	return Gen2ModHost.instance().loaded_mods().is_empty()


## The screen, built once the mods are in.
func _build() -> void:
	## The mods, before the screen and against this cartridge. `GameRuntime`
	## loads them from its own `_ready`, but a `-s` driver cannot depend on
	## having run after that: a screen built first has no follower walking
	## behind the player and no wild Pokemon on the map, and which of those a
	## clip caught was a race.
	var data: GameData = GameData.open(_game)
	if data == null:
		push_error("No cache for %s. Import roms/%s.gbc first." % [_game, _game])
		_quit_failed()
		return

	DisplayServer.window_set_size(_window)
	root.set_content_scale_size(_window)
	root.size = _window
	var packed: PackedScene = load("res://game/world/world_screen.tscn")
	_screen = packed.instantiate() as Gen2WorldScreen
	_screen.map_group = _map.x
	_screen.map_number = _map.y
	if _cell.x >= 0:
		_screen.start_cell = _cell
	if _hour >= 0:
		_screen.hour = _hour
	_screen.encounter_seed = _seed
	_screen.set_data(data)
	## Never the player's own slot: a world writes its run seed back to whatever
	## save it opened, and a trailer must not touch a save file.
	var save: Gen2SaveData = _recording_save(data)
	if save == null:
		push_error("Could not build the recording save for %s." % _game)
		_quit_failed()
		return
	_screen.set_save(save)
	root.add_child(_screen)
	current_scene = _screen


## A save that can carry every clip: six healthy Pokemon, which is what the
## follower mod draws from and what a battle opens on. No badge is set here; the
## `surf` action goes through `Gen2WorldScreen.preview_surf`, which grants the
## one its own field move needs.
func _recording_save(data: GameData) -> Gen2SaveData:
	var members: Array = []
	for species: int in [160, 157, 154, 26, 197, 130]:
		var mon: Gen2BattleMon = Gen2BattleMon.create(
			data, species, 40, data.moves_at_level(species, 40)
		)
		if mon != null:
			members.append(mon)
	var save: Gen2SaveData = Gen2SaveBattleAdapter.from_battle_party(
		data.id, data.sha1, 0, Gen2Party.create(members), "GOLD"
	)
	return save


func _add_action(frame: int, action: String) -> void:
	var at: Array = _actions.get(frame, [])
	at.append(action)
	_actions[frame] = at


func _direction(name: String) -> int:
	match name:
		"up": return Gen2Button.UP
		"down": return Gen2Button.DOWN
		"left": return Gen2Button.LEFT
		"right": return Gen2Button.RIGHT
	return Gen2Button.NONE


func _process(_delta: float) -> bool:
	if _failed:
		return true
	_frames += 1
	if _screen == null:
		if _waiting_for_mods():
			return false
		_build()
		_built_at = _frames
		return _failed
	if _frames == _built_at + 1:
		_open()
	## Every count here is measured from the frame the screen was built on, not
	## from the first frame of the run: the mod load in front of it is as long as
	## it is, and a count that ignored it would open a screen that is not there.
	if not _view.is_empty() and not _chosen and _frames > _built_at:
		_choose_view()
	if _frames - _built_at < _warmup:
		return false
	if _frames - _built_at == _warmup and _probe in [&"shiny", &"map", &"wilds"]:
		if _probe == &"shiny":
			_run_shiny_probe()
		elif _probe == &"wilds":
			_print_wilds()
		else:
			_print_map()
		_restore_selected_view()
		quit(0)
		return true
	if _base < 0:
		_start()
	var at: int = _world_frame() - _base
	## A host frame can carry more than one hardware frame, so the scripted ones
	## are drained up to `at` rather than matched against it.
	while not _pending.is_empty() and _pending[0] <= at:
		for action: String in _actions.get(_pending[0], []) as Array:
			_perform(action)
		_pending.remove_at(0)
	if _probe == &"walk":
		var cell: Vector2i = (_screen.get("_world") as Gen2WorldAPI).player_cell
		if _path.is_empty() or _path[-1] != cell:
			_path.append(cell)
	if at >= _length:
		if _probe == &"walk":
			_print_path()
		_restore_selected_view()
		quit(0)
		return true
	return false


## The mod's renderer, once it is registered. Refused only when the warm-up ran
## out, since that is the point at which it is not coming.
func _choose_view() -> void:
	var chosen: Dictionary = _screen.select_view(_view)
	if bool(chosen.get("ok", false)):
		_chosen = true
		_screen.settle_view_cover()
		return
	if _frames - _built_at < _warmup - 1:
		return
	push_error("View %s unavailable: %s. Did you pass --mods?" % [
		_view, chosen.get("reason", "unknown")
	])
	_quit_failed()


func _world_frame() -> int:
	var world: Gen2WorldAPI = _screen.get("_world")
	return world.frame_number if world != null else 0


## The clip proper: the button log is handed over now rather than in [method
## _open], because the frames it names are counted from this frame and the
## warm-up's length in hardware frames is not known until it is over.
func _start() -> void:
	## The NEXT hardware frame, not this one: `advance_frame` counts before it
	## reads the replay, so an entry named for the frame already spent is never
	## applied and `do=0:<button>` was dropped in silence.
	_base = _world_frame() + 1
	## The recorded frame the clip proper starts on, which is what the video is
	## trimmed to. Printed rather than assumed: the mod load in front of it is
	## as long as it is, and a caller cannot know that in advance.
	print("TRIM=%d" % _frames)
	for frame: int in _actions:
		_pending.append(frame)
	_pending.sort()
	_screen.replay_input(_input_log())


## The frame after the screen was built: the readout off, and the view the
## installation was on remembered, whether or not this run changes it.
func _open() -> void:
	## The map and cell readout and the shortcut legend are scaffolding drawn
	## over the screen, and a trailer is the game and nothing else.
	_screen.hide_debug_readout()
	_restore_view = Gen2ModHost.instance().selected_view()



## Every held frame and every press, as `Gen2WorldScreen.replay_input` entries.
func _input_log() -> Array:
	var entries: Array = []
	var held: int = _hold
	for frame: int in _length + 1:
		for action: String in _actions.get(frame, []) as Array:
			if action == "hold-none":
				held = Gen2Button.NONE
			elif action.begins_with("hold-"):
				held = _direction(action.trim_prefix("hold-"))
			else:
				var button: int = _button(action)
				if button != Gen2Button.NONE:
					entries.append({
						"frame": _base + frame, "kind": "press", "button": button,
					})
		if held != Gen2Button.NONE:
			entries.append({"frame": _base + frame, "kind": "hold", "button": held})
	return entries


## The actions that are not a button. Everything a button can do is left to the
## log above, so the two never disagree about which frame something lands on.
func _perform(action: String) -> void:
	match action:
		"surf":
			_screen.preview_surf()
			_screen.preview_surf_use()
			_screen.preview_surf_use()
		"battle":
			_screen.preview_battle_request()
		"menu-off":
			_screen.press_button(Gen2Button.B)
		_:
			## `view-<id>`: the live renderer switch, cover and all, which is the
			## one thing here worth filming rather than settling.
			if action.begins_with("view-"):
				_screen.select_view(StringName(action.trim_prefix("view-")))


func _button(action: String) -> int:
	match action:
		"a": return Gen2Button.A
		"b": return Gen2Button.B
		"start": return Gen2Button.START
		"select": return Gen2Button.SELECT
	return _direction(action)


## The installed visible-encounter providers, asked what they would build on this
## map for each seed in turn. The shiny test is `CheckShininess`: three DVs at
## ten and the attack mask.
func _run_shiny_probe() -> void:
	var host: Gen2ModHost = Gen2ModHost.instance()
	var providers: Array = host.visible_encounter_providers()
	var ids: Array = host.visible_encounter_ids()
	if providers.is_empty():
		push_error("No visible-encounter provider is registered. Did you pass --mods?")
		_quit_failed()
		return
	var encounters: Object = _screen.get("_encounters")
	var context: Dictionary = (encounters.get("_context") as Dictionary).duplicate(true)
	if context.is_empty():
		push_error("The map built no encounter context, so it has no wild table.")
		_quit_failed()
		return
	var found: int = 0
	for seed_value: int in range(1, PROBE_SEEDS):
		context["run_seed"] = seed_value
		for index: int in providers.size():
			## A FRESH provider per seed, rather than the live one asked twice.
			## A provider rebuilds its plan only when the context's `generation`
			## changes, and `generation` is mixed into the plan's own seed, so
			## bumping it to force a rebuild would answer about a map load that
			## never happens. A provider with no context yet plans on the first
			## ask, at the generation this map really is on.
			var probe: Object = (providers[index] as Object).get_script().new()
			if probe.has_method(&"configure"):
				probe.call("configure", host, ids[index])
			probe.call("set_context", context.duplicate(true))
			for raw: Variant in probe.call("encounters") as Array:
				var entry: Dictionary = raw
				if not _is_shiny(int(entry.get("dvs", 0))):
					continue
				print("seed=%d species=%d level=%d cell=%s" % [
					seed_value, int(entry.get("species", 0)),
					int(entry.get("level", 0)), entry.get("cell", Vector2i.ZERO),
				])
				found += 1
	if found == 0:
		print("No shiny in %d seeds on this map." % PROBE_SEEDS)
	_restore_selected_view()
	quit(0)


## The wild population this map really has under `seed=`, as the host validated
## it rather than as a provider offered it: an entry standing where the host
## refuses one is not on the map and would not be in the clip.
func _print_wilds() -> void:
	var encounters: Object = _screen.get("_encounters")
	for raw: Variant in encounters.call("entries"):
		var entry: Dictionary = raw
		var dvs: int = int(entry.get("dvs", 0))
		print("%s species=%d level=%d cell=%s%s" % [
			entry.get("id", ""), int(entry.get("species", 0)),
			int(entry.get("level", 0)), entry.get("cell", Vector2i.ZERO),
			"  SHINY" if _is_shiny(dvs) else "",
		])


## The map as its collision reads it, which is what a walk has to stay inside.
func _print_map() -> void:
	var world: Gen2WorldAPI = _screen.get("_world")
	var map: Gen2WorldMap = world.current_map
	print("%dx%d cells, player at %s" % [
		map.collision_width, map.collision_height, world.player_cell,
	])
	print("    " + _ruler(map.collision_width))
	for y: int in map.collision_height:
		var row: String = ""
		for x: int in map.collision_width:
			var cell := Vector2i(x, y)
			if cell == world.player_cell:
				row += "@"
			elif world.object_at(cell) != null:
				row += "o"
			else:
				match world.collision_permission_at(cell):
					Gen2WorldCollision.LAND_TILE: row += "."
					Gen2WorldCollision.WATER_TILE: row += "~"
					_: row += "#"
		print("%3d %s" % [y, row])


static func _ruler(width: int) -> String:
	var out: String = ""
	for x: int in width:
		out += str((x / 10) % 10) if x % 10 == 0 else " "
	return out


## Where the clip's own buttons actually took the player. A path that stops
## short of the frames it was given is a walk into a wall.
func _print_path() -> void:
	var steps: int = _path.size() - 1
	print("%d steps: %s -> %s" % [
		steps, _path[0] if not _path.is_empty() else Vector2i.ZERO,
		_path[-1] if not _path.is_empty() else Vector2i.ZERO,
	])
	var line: String = ""
	for cell: Vector2i in _path:
		line += "%s " % cell
	print(line)


static func _is_shiny(dvs: int) -> bool:
	if (dvs >> 8) & 0xf != 10 or (dvs >> 4) & 0xf != 10 or dvs & 0xf != 10:
		return false
	return ((dvs >> 12) & 0xf) in [2, 3, 6, 7, 10, 11, 14, 15]


## A view is chosen per installation and persisted, so a recording puts the
## player's own back rather than leaving them on a mod's renderer.
func _restore_selected_view() -> void:
	if _restore_view.is_empty():
		return
	Gen2ModHost.instance().select_view(_restore_view)


func _quit_failed() -> void:
	_failed = true
	quit(1)
