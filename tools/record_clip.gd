extends SceneTree

## Records one clip to a video, for a trailer rather than for a check. Godot's
## Movie Maker is what makes it reproducible: `--write-movie` pins the frame delta,
## so the world spends exactly one hardware frame per recorded frame. Nothing here
## steps the screen by hand for that reason: the game runs its ordinary `_process`,
## mods included, and only the buttons are scripted. [constant USAGE] is every key.
##
##   Godot --path . --mods --write-movie /tmp/clip.avi --fixed-fps 60 \
##     -s res://tools/record_clip.gd -- <game> <group> <map> [key=value ...]

## Only for a run with no window to ask, which is every headless one.
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

## What `progress=` names. `badges` and `caught` are the two a mod's reading is
## built on; the other two are the start menu's own gates, so a run eight badges
## in has the rows one really would.
const PROGRESS_KEYS: Array[String] = [
	"badges", "caught", "pokedex", "pokegear", "spent",
]

## Which screen the clip is shot on.
const SCREEN_WORLD: StringName = &"world"
const SCREEN_SAVES: StringName = &"saves"

## The party a clip carries when no `party=` names one: six healthy level 40s,
## which is what the follower mod draws from and what a battle opens on.
const DEFAULT_PARTY: Array[int] = [160, 157, 154, 26, 197, 130]
const DEFAULT_PARTY_LEVEL: int = 40

var _screen: Gen2WorldScreen = null
## The launcher page a `screen=saves` clip is shot on, and null for a world one.
var _page: Control = null
## The frame Movie Maker writes, which is the window as the engine started it.
## Read before anything here resizes anything.
var _frame_size: Vector2i = DEFAULT_WINDOW
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
var _facing: int = -1
var _hour: int = -1
var _seed: int = 1
var _mash: String = ""
var _kind: StringName = SCREEN_WORLD
var _challenge: StringName = Gen2Rules.CHALLENGE_VANILLA
## Each member as `{species, level, shiny, hp, brink}`, or empty for the default
## six.
var _party: Array[Dictionary] = []
## Bag contents as item number to count.
var _items: Dictionary = {}
## `progress=`, as name to amount.
var _progress: Dictionary = {}
## `flags=`, the event flags the run has already set.
var _flags: Array[int] = []
## The last line `probe=trace` printed, so only a change is printed.
var _traced: String = ""
## Frames spent before the clip proper, which the video is trimmed by. Raised
## for a clip waiting on something the map spends on its own clock rather than on
## a button: the visible-encounter mod's shiny sparkle is one, and it runs for
## about seventy frames every six hundred, so a clip that wants it starts a
## little before one of those.  is where the number is read off.
var _warmup: int = WARMUP_FRAMES
## The frame the screen was built on, which every count below is relative to.
var _built_at: int = 0
## Whether the screen has been built, which `_page` being set cannot answer for a
## build that failed.
var _built: bool = false
## Whether this clip holds a direction at all, which is what [method
## _input_arrived] can check for.
var _holds_scripted: bool = false
## `Engine.get_frames_drawn()` when the clip proper started, which is what
## [method _every_frame_drawn] measures the video against.
var _drawn_at_start: int = 0
## Whether `text=auto` is on: an A press whenever the box wants one.
var _auto_text: bool = false
## `read=` and `beat=`, the two gaps above.
var _read_gap: int = TEXT_GAP
var _beat_gap: int = STATE_GAP
## `at=` entries still waiting for their state, in the order they were written.
var _waits: Array[Dictionary] = []
## `always=` entries, state to action, none of which is ever spent.
var _always: Dictionary = {}
## The world frame before which nothing scripted by state may be spent, so two
## presses a viewer has to follow are a beat apart rather than on one frame.
var _state_ready: int = 0


const USAGE: String = """
Keys, all optional:
  screen=<world|saves>  which screen the clip is shot on. `world` is the game
				 and is the default; `saves` is the launcher's save page,
				 where a run's challenge is chosen. The group and map are
                 ignored by `saves` and still have to be given.
  cell=<x>,<y>   where the player stands when the map opens
  facing=<dir>   which way the player faces when it opens: up, down, left,
				 right. Untouched by default, which is the map's own answer.
  hour=<0-23>    the clock the map is drawn on, which is its palette
  view=<mod id>  a mod's renderer instead of the built-in one (`voxel3d`)
  size=<W>x<H>   the size the game lays itself out for. The video's own size
				 by default, which is the one size that costs nothing: Movie
				 Maker fixes the frame at the project's own viewport before a
                 line of this script runs, and a layout of any other size is
				 scaled into it, which is what makes a launcher page's text
				 soft. Give this only to shoot a shape the frame is not, a
				 portrait phone being the one that earns it: `--resolution`
				 moves the window on the desktop and not the frame.
  seconds=<n>    how long the clip runs after the warm-up
  seed=<n>       the run seed, which is what a mod's spawn plan is built from
  hold=<dir>     a direction held for the whole clip: up, down, left, right
  challenge=<c>  the challenge the recording run is played under: vanilla,
                 hard or nuzlocke. What `Gen2Rules` gives a real run, so a
				 Nuzlocke clip meets the Nuzlocke's own rules.
  party=<spec>   the party the clip plays with, `species:level` per member
				 separated by commas, six at most. Each may carry `shiny`,
				 `hp<n>` for a member standing at that many hit points, and
				 `brink` for one a single point of experience short of its
				 next level. Six healthy level 40s by default.
  items=<spec>   items in the bag, `item:count` separated by commas. A capture
				 clip needs its own balls: 5 is a POKE BALL.
  progress=<spec>  how far along the run is, `badges:8,caught:120`. What a mod
				 reading [Gen2ModProgress] answers about, so a clip of a list
				 a run fills in is shot part way through one rather than at
				 nothing. `badges` is the first n in source order and `caught`
				 the first n species numbers; `pokedex:1` and `pokegear:1` are
				 the start menu's own two gates. `spent:1` is a Nuzlocke whose
                 area has already given up its one encounter, which is what a
                 clip of the refusal starts from.
  flags=<n>[,<n>]  event flags the run has already set, by their index in
                 `constants/event_flags.asm`. What puts a script on the branch
                 a clip wants: 8 is `EVENT_GOT_TM31_MUD_SLAP`, which takes the
                 TM speech off the end of the Violet Gym badge.
  text=auto      an A press whenever the box is waiting for one, which is a
				 player reading. A battle's own text is as long as its text is
				 and no frame number can be worked out in advance, so a clip
				 that has to reach a menu says this rather than counting.
  read=<frames>  how long a finished page is left standing before `text=auto`
				 turns it. The default is [constant TEXT_GAP], which is a
				 viewer's reading speed rather than a player's.
  beat=<frames>  the same between one `at=` or `always=` action and the next,
				 which is how long a chosen menu row is seen before it is
				 pressed. The default is [constant STATE_GAP].
  at=<state>:<action>  one action, performed the first time the screen reaches
				 that state: `menu` is the battle's FIGHT/PKMN/PACK/RUN,
                 `move` its move list, `pack` the pack it opens, `capture` the
                 ball selector, `switch` the party list, `ask` the nickname
                 question a catch reaches, `name` the keyboard behind it and
                 `map` the overworld with no battle over it. Repeatable, and they are
                 spent in the order they are written, a beat apart. What aims
                 a press at a menu rather than at a frame.
  always=<state>:<action>  the same, but never spent: it answers that state
                 every time the screen reaches it, once the `at=` queue has
                 nothing waiting for it. `always=menu:a always=move:a` is a
                 player fighting with the first move for as many turns as the
                 fight lasts, which is not a number a clip can know.
  mash=<first>:<every>[:<last>]  an A press every `every` frames from `first`,
                 which is a player holding a battle or a script along. Runs to
                 the end of the clip unless `last` says otherwise, and adds to
                 whatever `do=` already asked for.
  do=<frame>:<action>   one scripted action, repeatable

World actions are a button name (`a`, `b`, `start`, `select`, `up`, `down`,
`left`, `right`), `hold-<dir>` or `hold-none` to change what is held from that
frame, `surf` to mount the water the player is facing, `battle` to start a
wild fight, `meet` to face the nearest wild a mod has drawn on the map and
fight THAT one, `meet-shiny` for the nearest one that is shiny,
`wild-<species>-<level>[-shiny]` to start one against a named Pokemon that is
on no map, `menu-off` to close whatever is open, `text-off` and `text-on` to
stop and restart `text=auto` so the last line of a clip is left up rather
than turned, or `view-<mod id>` to switch
the renderer on camera, cover and all. Frames are the world's own, counted
from the first recorded one.

Save-screen actions are `new-slot` to open the new-game form on the first
free slot, `slot-<n>` to select one, `name-<text>` to type a save name, and
`focus-<label>` and `click-<label>` for one of the page's own buttons, found
by the words on it. The focus ring is what a viewer follows, so a click is
worth a `focus-` a moment before it.

A `probe=` records nothing and answers a question instead, which is how a clip
is aimed before it is shot:
  probe=map    an ASCII plan of the map: `.` land, `~` water, `#` blocked,
			   `o` an object standing on it, `@` the player's own cell
  probe=walk   runs the clip's own buttons and prints the path the player
               actually took, so a walk that hits a wall is seen before it is
               recorded rather than after
  probe=wilds  the wild population this `seed=` really puts on the map
  probe=shiny  asks the installed visible-encounter providers for the plan
               every seed would build on this map and prints the ones holding
               a shiny, which is how a sparkle clip gets its `seed=`
  probe=menu   the start menu's own rows in order, which is how many DOWN
			   presses a mod's row costs: a mod adds one and the count moves
  probe=trace  runs the clip's own buttons and prints the frame every visible
			   thing changed on: the text on screen, the battle's menu and
               whether it is waiting for a press. A clip that has to land a
               press on a menu is aimed with this and shot afterwards

A `probe=` takes the same arguments as the clip it is aiming, and `cell=` is
not optional among them: where the player stands is part of the context a
spawn plan is built from, so a seed found from one cell puts its shiny
somewhere else from another. `probe=wilds` is the check on that.
"""


func _initialize() -> void:
	## Movie Maker's frame is the PROJECT's viewport rather than the window, so
	## `--resolution` moves what is on the desktop and not what is written.
	var frame := Vector2i(
		int(ProjectSettings.get_setting("display/window/size/viewport_width", 0)),
		int(ProjectSettings.get_setting("display/window/size/viewport_height", 0))
	)
	if frame.x <= 0 or frame.y <= 0:
		frame = DisplayServer.window_get_size()
	if frame.x > 0 and frame.y > 0:
		_frame_size = frame
		_window = frame
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() < 3:
		push_error("Usage: record_clip.gd -- <game> <group> <map> [key=value ...]")
		print(USAGE)
		_quit_failed()
		return

	for extra: String in args.slice(3):
		var key: String = extra.get_slice("=", 0)
		var value: String = extra.substr(key.length() + 1)
		if _read_scalar_option(key, value) or _read_staging_option(key, value):
			continue
		push_error("Unknown option: %s" % extra)
		_quit_failed()
		return

	if _kind not in [SCREEN_WORLD, SCREEN_SAVES]:
		push_error("Unknown screen: %s" % _kind)
		_quit_failed()
		return
	if not Gen2Rules.CHALLENGES.has(_challenge):
		push_error("Unknown challenge: %s" % _challenge)
		_quit_failed()
		return

	## Expanded once the whole line is read, since its default last frame is
	## `seconds=`, which may be named after it.
	if not _mash.is_empty():
		_add_mash(_mash)
	_game = StringName(args[0])
	_map = Vector2i(int(args[1]), int(args[2]))


func _read_scalar_option(key: String, value: String) -> bool:
	match key:
		"cell":
			_cell = Vector2i(int(value.get_slice(",", 0)), int(value.get_slice(",", 1)))
		"facing":
			_facing = _facing_for(value)
		"hour":
			_hour = int(value)
		"view":
			_view = StringName(value)
		"size":
			_window = Vector2i(int(value.get_slice("x", 0)), int(value.get_slice("x", 1)))
		"seconds":
			_length = int(maxf(0.1, float(value)) * FRAMES_PER_SECOND)
		"seed":
			_seed = int(value)
		"hold":
			_hold = _direction(value)
		"screen":
			_kind = StringName(value)
		"challenge":
			_challenge = StringName(value)
		"read":
			_read_gap = maxi(int(value), 0)
		"beat":
			_beat_gap = maxi(int(value), 0)
		"text":
			_auto_text = value == "auto"
		"warmup":
			_warmup = maxi(2, int(value))
		"probe":
			_probe = StringName(value)
		_:
			return false
	return true


func _read_staging_option(key: String, value: String) -> bool:
	match key:
		"party":
			_party = _parse_party(value)
		"items":
			_items = _parse_items(value)
		"flags":
			for raw: String in value.split(",", false):
				_flags.append(int(raw))
		"progress":
			_progress = _parse_progress(value)
		"always":
			_always[StringName(value.get_slice(":", 0))] = \
				value.substr(value.find(":") + 1)
		"at":
			_waits.append({
				"state": StringName(value.get_slice(":", 0)),
				"action": value.substr(value.find(":") + 1),
			})
		"mash":
			_mash = value
		"do":
			_add_action(int(value.get_slice(":", 0)), value.substr(value.find(":") + 1))
		_:
			return false
	return true

## `party=` as one member per comma. `species:level` and then any of `shiny`,
## `brink` and `hp<n>`, which are the three a clip has needed: a shiny to catch,
## a member one point short of the level it is filmed reaching, and one standing
## low enough to be knocked out on camera.
func _parse_party(spec: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for raw: String in spec.split(",", false):
		var fields: PackedStringArray = raw.split(":", false)
		if fields.size() < 2:
			push_error("A party member is species:level, not %s" % raw)
			_quit_failed()
			return []
		var member: Dictionary = {
			"species": int(fields[0]), "level": int(fields[1]),
			"shiny": false, "brink": false, "hp": -1,
		}
		for flag: String in Array(fields).slice(2):
			if flag == "shiny":
				member["shiny"] = true
			elif flag == "brink":
				member["brink"] = true
			elif flag.begins_with("hp"):
				member["hp"] = int(flag.trim_prefix("hp"))
			else:
				push_error("Unknown party flag: %s" % flag)
				_quit_failed()
				return []
		out.append(member)
	return out


## `progress=`, whose keys are the readings [Gen2ModProgress] carries rather than
## the flags behind them: a clip says how far along the run is and the world
## state is what answers for it.
func _parse_progress(spec: String) -> Dictionary:
	var out: Dictionary = {}
	for raw: String in spec.split(",", false):
		var pair: PackedStringArray = raw.split(":", false)
		if pair.size() != 2 or pair[0] not in PROGRESS_KEYS:
			push_error("Progress is one of %s, not %s" % [str(PROGRESS_KEYS), raw])
			_quit_failed()
			return {}
		out[pair[0]] = int(pair[1])
	return out


func _parse_items(spec: String) -> Dictionary:
	var out: Dictionary = {}
	for raw: String in spec.split(",", false):
		var pair: PackedStringArray = raw.split(":", false)
		if pair.size() != 2:
			push_error("An item is item:count, not %s" % raw)
			_quit_failed()
			return {}
		out[int(pair[0])] = int(pair[1])
	return out


## Whether the mods are still loading, which the screen has to be built after.
## `GameRuntime` loads them from its own `_ready`, and that has not run while
## `_initialize` runs nor on the first frame after it, so a screen built before it
## has no follower and no wild Pokemon on the map. Waited out rather than loaded
## again here: a second `load_mods` registers every mod twice, and `reload_mods`
## runs the save lifecycle, which puts a development run's randomizer over a clip
## that never asked for one.
func _waiting_for_mods() -> bool:
	if _frames > MOD_LOAD_FRAMES or not Gen2GameRuntime.mods_are_allowed():
		return false
	return Gen2ModHost.instance().loaded_mods().is_empty()


## The screen, built once the mods are in.
func _build() -> void:
	var data: GameData = GameData.open(_game)
	if data == null:
		push_error("No cache for %s. Import roms/%s.gbc first." % [_game, _game])
		_quit_failed()
		return

	## Read by `.claude/clip.sh`, which scales a hardware screen and a launcher
	## page differently: one is square pixels and the other is not.
	print("FRAME=%dx%d LAYOUT=%dx%d SCREEN=%s" % [
		_frame_size.x, _frame_size.y, _window.x, _window.y, _kind,
	])
	DisplayServer.window_set_size(_window)
	root.set_content_scale_size(_window)
	root.size = _window
	## In front of everything else and kept there, because the engine does not
	## DRAW an occluded window and Movie Maker writes a frame per drawn frame:
	## a window another one covered records the clip with most of its middle
	## missing, and the run reports no error at all. Costs the desktop the front
	## window for as long as the recording takes.
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
	DisplayServer.window_move_to_foreground()
	if _kind == SCREEN_SAVES:
		_build_saves(data)
		return
	_build_world(data)


## The launcher's save page, on the cartridge this clip names. It reads the
## installation's own slots, and nothing here writes one: the new-game form is
## opened and filled in, and `Gen2SaveScreen.create_new_game` is the button this
## never presses.
func _build_saves(data: GameData) -> void:
	var runtime: Node = root.get_node_or_null(NodePath("GameRuntime"))
	if runtime != null:
		runtime.call("select_game", data.id)
	var page: Node = load("res://game/save/save_screen.tscn").instantiate()
	page.call("set_data", data)
	root.add_child(page)
	current_scene = page as Node
	_page = page as Control


## The world screen, the recording save behind it and the mods told which save
## is being played.
func _build_world(data: GameData) -> void:
	## The mods, before the screen and against this cartridge. `GameRuntime`
	## loads them from its own `_ready`, but a `-s` driver cannot depend on
	## having run after that: a screen built first has no follower walking
	## behind the player and no wild Pokemon on the map, and which of those a
	## clip caught was a race.
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
	## The save lifecycle a real run spends, which nothing else here would: a
	## slot is chosen through `GameRuntime` and this driver has none, so without
	## this a mod holding per-save state is played with none of it. The
	## achievements mod is the visible case, and it is what a clip of one being
	## unlocked depends on.
	Gen2ModHost.instance().created_save(save)
	Gen2ModHost.instance().activate_save(save)
	root.add_child(_screen)
	current_scene = _screen
	_stock_bag()
	_seed_progress()


## `items=`, into the world's own bag. After the screen is in the tree, since the
## world it writes to is built from `_ready`.
func _stock_bag() -> void:
	if _items.is_empty():
		return
	var world: Gen2WorldAPI = _screen.get("_world")
	if world == null:
		push_error("The world was not built, so the bag could not be stocked.")
		_quit_failed()
		return
	var added: Dictionary = world.state.apply_changes({}, {}, {"items": _items})
	if not bool(added.get("ok", false)):
		push_error("The bag refused %s." % str(_items))
		_quit_failed()


## `progress=`, into the world state, which is what [Gen2ModProgress] reads for
## everything a save does not carry itself.
func _seed_progress() -> void:
	if _progress.is_empty() and _flags.is_empty():
		return
	var world: Gen2WorldAPI = _screen.get("_world")
	if world == null:
		push_error("The world was not built, so its progress could not be set.")
		_quit_failed()
		return
	for flag: int in _flags:
		world.state.set_event_flag(flag)
	var crystal: bool = Gen2WorldState.is_crystal_profile(world.data)
	for badge: int in int(_progress.get("badges", 0)):
		world.state.set_engine_flag(Gen2WorldState.badge_flag(badge, crystal))
	for species: int in range(1, int(_progress.get("caught", 0)) + 1):
		world.state.set_species_caught(species)
	if int(_progress.get("pokedex", 0)) > 0:
		world.state.set_engine_flag(
			Gen2WorldState.engine_flag(Gen2WorldStartMenu.ENGINE_POKEDEX, crystal)
		)
	if int(_progress.get("pokegear", 0)) > 0:
		world.state.set_engine_flag(
			Gen2WorldState.engine_flag(Gen2WorldStartMenu.ENGINE_POKEGEAR, crystal)
		)
	## The area this map belongs to, already spent. Species 0: what the run met
	## here is not part of the picture, only that it did.
	if int(_progress.get("spent", 0)) > 0:
		Gen2Nuzlocke.claim_area(
			_screen.active_save().nuzlocke, world.landmark_backup(), 0
		)


## A save that can carry every clip: the party `party=` names or six healthy
## level 40s, under the challenge `challenge=` names. No badge is set here; the
## `surf` action goes through `Gen2WorldScreen.preview_surf`, which grants the
## one its own field move needs.
func _recording_save(data: GameData) -> Gen2SaveData:
	var members: Array = []
	for member: Dictionary in _party_rows():
		var mon: Gen2BattleMon = Gen2BattleMon.create(
			data, int(member["species"]), int(member["level"]),
			data.moves_at_level(int(member["species"]), int(member["level"])),
			Gen2Stats.SHINY_DVS if bool(member["shiny"]) else Gen2BattleMon.PERFECT_DVS
		)
		if mon == null:
			push_error("No species %d in this cache." % int(member["species"]))
			return null
		## One point short of the next level, so the clip's own first knockout is
		## what carries it over rather than a grind nobody wants to watch.
		if bool(member["brink"]):
			mon.exp = maxi(
				Gen2Experience.total_exp_at(mon.growth_rate(), mon.level + 1) - 1, mon.exp
			)
		if int(member["hp"]) >= 0:
			mon.hp = clampi(int(member["hp"]), 0, mon.max_hp())
		members.append(mon)
	var save: Gen2SaveData = Gen2SaveBattleAdapter.from_battle_party(
		data.id, data.sha1, 0, Gen2Party.create(members), "GOLD"
	)
	if save == null:
		return null
	var rules := Gen2Rules.new()
	rules.challenge = _challenge
	save.run_rules = rules
	return save


func _party_rows() -> Array[Dictionary]:
	if not _party.is_empty():
		return _party
	var out: Array[Dictionary] = []
	for species: int in DEFAULT_PARTY:
		out.append({
			"species": species, "level": DEFAULT_PARTY_LEVEL,
			"shiny": false, "brink": false, "hp": -1,
		})
	return out


## `mash=`, as one A press per interval. Spelled here rather than as a hundred
## `do=` arguments: a battle is thirty boxes long and every one of them wants the
## same press.
func _add_mash(spec: String) -> void:
	var fields: PackedStringArray = spec.split(":", false)
	if fields.size() < 2:
		push_error("A mash is first:every[:last], not %s" % spec)
		_quit_failed()
		return
	var every: int = maxi(int(fields[1]), 1)
	var last: int = int(fields[2]) if fields.size() > 2 else _length
	var frame: int = int(fields[0])
	while frame <= last:
		_add_action(frame, "a")
		frame += every


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


func _facing_for(name: String) -> int:
	match name:
		"down": return Gen2WorldSprite.FACING_DOWN
		"up": return Gen2WorldSprite.FACING_UP
		"left": return Gen2WorldSprite.FACING_LEFT
		"right": return Gen2WorldSprite.FACING_RIGHT
	push_error("Unknown facing: %s" % name)
	_quit_failed()
	return -1


func _process(_delta: float) -> bool:
	if _failed:
		return true
	_frames += 1
	if not _built:
		if _waiting_for_mods():
			return false
		_build()
		_built_at = _frames
		_built = true
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
	if _frames - _built_at == _warmup and _probe in [&"shiny", &"map", &"wilds", &"menu"]:
		_answer_static_probe()
		_finish()
		quit(0)
		return true
	if _base < 0:
		_start()
	var at: int = _clip_frame() - _base
	## A host frame can carry more than one hardware frame, so the scripted ones
	## are drained up to `at` rather than matched against it.
	while not _pending.is_empty() and _pending[0] <= at:
		for action: String in _actions.get(_pending[0], []) as Array:
			_perform(action)
		_pending.remove_at(0)
	if _screen != null:
		_spend_by_state()
	if _probe == &"walk":
		var cell: Vector2i = (_screen.get("_world") as Gen2WorldAPI).player_cell
		if _path.is_empty() or _path[-1] != cell:
			_path.append(cell)
	if _probe == &"trace":
		_trace(at)
	if at >= _length:
		if _probe == &"walk":
			_print_path()
		_finish()
		quit(0 if _input_arrived() and _every_frame_drawn() else 1)
		return true
	return false


func _answer_static_probe() -> void:
	match _probe:
		&"shiny": _run_shiny_probe()
		&"wilds": _print_wilds()
		&"menu": _print_start_menu()
		_: _print_map()


## How long the clip waits between one action spent on a state and the next: a
## press a viewer is meant to follow lands a beat after the one before it rather
## than on the same frame. `beat=` moves it.
const STATE_GAP: int = 40
## The same for `text=auto`. A press while the page is still printing is spent and
## does nothing (`Gen2TextBox.advance`), so this is how long a FINISHED page is
## left standing, which is the one thing that decides whether a clip can be read.
## Three quarters of a second: shorter and the last words of a line are gone
## before a viewer reaches them. `read=` moves it.
const TEXT_GAP: int = 45


## `text=auto` and the `at=` queue, both of which watch the screen rather than
## the frame count. The text first: a menu is only reached once the box in front
## of it is done, so answering the box is what puts the next state on screen.
func _spend_by_state() -> void:
	## Counted in the world's own frames rather than the host's: a probe run
	## draws twice as often as it steps the world, and a gap measured in drawn
	## frames would put every press somewhere else in the clip it is aiming.
	var now: int = _clip_frame()
	if now < _state_ready:
		return
	var state: StringName = _screen_state()
	if _auto_text and state == &"text":
		_screen.press_button(Gen2Button.A)
		_state_ready = now + _read_gap
		return
	var action: String = ""
	if not _waits.is_empty() and StringName(_waits[0]["state"]) == state:
		action = String(_waits[0]["action"])
		_waits.remove_at(0)
	elif _always.has(state):
		action = String(_always[state])
	else:
		return
	var button: int = _button(action)
	if button != Gen2Button.NONE:
		_screen.press_button(button)
	else:
		_perform(action)
	_state_ready = now + _beat_gap


## What is on screen, as the vocabulary `at=` and `text=auto` are written in.
## A box waiting for a press wins over everything behind it, which is the order
## the player meets them in.
func _screen_state() -> StringName:
	var battle: Object = _screen.get("_battle_host")
	if battle == null:
		var world: Gen2WorldAPI = _screen.get("_world")
		if world != null and world.script_input_waiting():
			return &"text"
		var box: Object = _screen.get("_text_box")
		if box != null and bool(box.call("has_pages_left")) \
			and not bool(box.call("is_revealing")):
			return &"text"
		return &"map"
	## In front of the battle's own state: the nickname prompt stands over the
	## fight. Its two halves are two states, because a press means opposite
	## things in them: `ask` is the YES/NO, which only answers once its own text
	## has finished, and `name` is the keyboard behind it, which a Nuzlocke opens
	## with no question asked at all. Between the two it is `busy`, so nothing
	## answers a question that is still being printed.
	var prompt: Object = battle.get("_capture_nickname_host")
	if prompt != null:
		if bool(prompt.call("question_ready")):
			return &"ask"
		return &"name" if prompt.call("naming_screen") != null else &"busy"
	var shot: Dictionary = battle.call("battle_snapshot")
	## The three lists in front of the box, because each of them SAYS what it is
	## in the box itself: the pack, the ball selector and the switch list all
	## draw their prompt as a message, so a state read off `awaits_press` first
	## would call every one of them text and answer them with A.
	if bool(shot.get("capture_selecting", false)):
		return &"capture"
	if bool(battle.get("_pack_selecting")):
		return &"pack"
	## `OfferSwitch`'s question is two paragraphs and
	## `_answer_switch_offer_button` reads them before it answers anything, so a
	## NO pressed while a page is still owed is thrown away. The box itself is
	## what says which half of that it is in; `awaits_press` stays true across
	## both, and reading the state off it answered the question with YES.
	if String(shot.get("switch_stage", &"")) != "":
		return &"text" if _reading(battle, "_box") else &"switch"
	if bool(shot.get("awaits_press", false)):
		return &"text"
	match StringName(shot.get("menu_stage", &"")):
		&"main": return &"menu"
		&"move": return &"move"
	return &"busy"


## Whether the buttons this clip scripted reached the world. Holds are the half
## the world records, and they are also the half a stuck clip loses, so a clip
## that scripted one and consumed none is refused rather than written.
func _input_arrived() -> bool:
	if _screen == null or not _holds_scripted or _screen.input_recording().size() > 0:
		return true
	push_error("The scripted input never reached the world: the clip is the "
		+ "player standing still. Record it again.")
	return false


## The mod's renderer, once it is registered. Refused only when the warm-up ran
## out, since that is the point at which it is not coming.
func _choose_view() -> void:
	if _screen == null:
		return
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


## The frame a `do=` is counted in. The world's own where there is a world, and
## the recorded frame otherwise: a launcher page spends no hardware frames, and
## Movie Maker pins the two together anyway.
func _clip_frame() -> int:
	return _world_frame() if _screen != null else _frames


## Whether the video has a frame for every frame of the clip. Movie Maker writes
## one per DRAWN frame and this driver counts the ones it was called on, and a
## machine that is loaded enough drops the difference in silence: a nine-second
## clip comes out under one second long, with its whole middle missing, which
## looks exactly like a clip that was aimed wrong. Checked rather than watched
## for, the same way the scripted input is.
func _every_frame_drawn() -> bool:
	var drawn: int = Engine.get_frames_drawn() - _drawn_at_start
	if drawn >= _length:
		return true
	push_error(("The video is %d frames of the %d this clip spent: the machine "
		+ "dropped the rest. Record it again with less running.") % [drawn, _length])
	return false


## The clip proper: the button log is handed over now rather than in [method
## _open], because the frames it names are counted from this frame and the
## warm-up's length in hardware frames is not known until it is over.
func _start() -> void:
	## Never off a world that is not there yet. `_world_frame` answers zero for
	## one, and a base of zero names frames the world spent during the warm-up:
	## every entry is then already in the past and the clip comes out with the
	## player standing still, which is what a stuck clip every few runs was.
	if _screen != null and _screen.get("_world") == null:
		return
	## The NEXT hardware frame, not this one: `advance_frame` counts before it
	## reads the replay, so an entry named for the frame already spent is never
	## applied and `do=0:<button>` was dropped in silence.
	_base = _clip_frame() + 1
	_drawn_at_start = Engine.get_frames_drawn()
	## The recorded frame the clip proper starts on, which is what the video is
	## trimmed to. Printed rather than assumed: the mod load in front of it is
	## as long as it is, and a caller cannot know that in advance.
	print("TRIM=%d" % _frames)
	for frame: int in _actions:
		_pending.append(frame)
	_pending.sort()
	if _screen == null:
		return
	var log_entries: Array = _input_log()
	for entry: Dictionary in log_entries:
		if String(entry.get("kind", "")) == "hold":
			_holds_scripted = true
			break
	_screen.replay_input(log_entries)
	## What the world actually consumed, against what was handed to it. A clip
	## is minutes of machine time and its failure looks exactly like a clip of
	## somebody standing still, so it is checked rather than watched for.
	_screen.record_input()


## The frame after the screen was built: the readout off, the facing set, and
## the view the installation was on remembered, whether or not this run changes
## it.
func _open() -> void:
	_restore_view = Gen2ModHost.instance().selected_view()
	if _screen == null:
		return
	## The map and cell readout and the shortcut legend are scaffolding drawn
	## over the screen, and a trailer is the game and nothing else.
	_screen.hide_debug_readout()
	if _facing >= 0:
		var world: Gen2WorldAPI = _screen.get("_world")
		if world != null:
			world.player_facing = _facing


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
	if _screen == null:
		_perform_on_page(action)
		return
	match action:
		"surf":
			_screen.preview_surf()
			_screen.preview_surf_use()
			_screen.preview_surf_use()
		"battle":
			_screen.preview_battle_request()
		"meet":
			_meet_visible_encounter(false)
		"meet-shiny":
			_meet_visible_encounter(true)
		"menu-off":
			_screen.press_button(Gen2Button.B)
		"text-off":
			_auto_text = false
		"text-on":
			_auto_text = true
		_:
			if action.begins_with("wild-"):
				_perform_wild(action.trim_prefix("wild-"))
				return
			## `view-<id>`: the live renderer switch, cover and all, which is the
			## one thing here worth filming rather than settling.
			if action.begins_with("view-"):
				_screen.select_view(StringName(action.trim_prefix("view-")))


## The wild a provider has put on the map nearest the player, met the way walking
## onto it meets it. Faces the player at it first, since a clip of an encounter
## is a clip of the thing on screen.
##
## Not the same as `wild-`: that one invents a battle and the entry standing on
## the map is not part of it, so its Pokemon is still there afterwards however
## the fight ended.
func _meet_visible_encounter(shiny_only: bool) -> void:
	var encounters: Object = _screen.get("_encounters")
	var world: Gen2WorldAPI = _screen.get("_world")
	if encounters == null or world == null:
		push_error("meet needs a world with a visible-encounter provider on it.")
		_quit_failed()
		return
	var from: Vector2i = world.player_cell
	var nearest := Vector2i(-1, -1)
	var closest: int = 1 << 30
	for raw: Variant in encounters.call("entries"):
		var entry: Dictionary = raw
		if shiny_only and not _is_shiny(int(entry.get("dvs", 0))):
			continue
		var cell: Vector2i = entry["cell"]
		var away: int = absi(cell.x - from.x) + absi(cell.y - from.y)
		if away < closest:
			closest = away
			nearest = cell
	if nearest.x < 0:
		push_error("No %svisible encounter is on this map. Did you pass --mods?" % [
			"shiny " if shiny_only else "",
		])
		_quit_failed()
		return
	world.player_facing = _facing_towards(from, nearest)
	if not bool(_screen.preview_meet_visible_encounter(nearest)):
		push_error("The wild at %s refused to be met." % nearest)
		_quit_failed()


## Which way [param from] looks to see [param at]. The longer axis wins, which is
## what a player walking towards one would end up facing.
static func _facing_towards(from: Vector2i, at: Vector2i) -> int:
	var away: Vector2i = at - from
	if absi(away.x) >= absi(away.y):
		return Gen2WorldSprite.FACING_RIGHT if away.x >= 0 else Gen2WorldSprite.FACING_LEFT
	return Gen2WorldSprite.FACING_DOWN if away.y >= 0 else Gen2WorldSprite.FACING_UP


## `wild-<species>-<level>[-shiny]`, the one wild a clip has to name rather than
## roll: a red Gyarados is a scripted encounter on the cartridge and a rolled one
## is whatever the seed says.
func _perform_wild(spec: String) -> void:
	var fields: PackedStringArray = spec.split("-", false)
	if fields.size() < 2:
		push_error("A wild is wild-<species>-<level>[-shiny], not wild-%s" % spec)
		_quit_failed()
		return
	_screen.preview_battle_request(
		int(fields[0]), int(fields[1]),
		Gen2Battle.BATTLETYPE_FORCESHINY if Array(fields).has("shiny")
		else Gen2Battle.BATTLETYPE_NORMAL
	)


## The save page's own actions. Nothing here presses "Start game": the form is
## what this clip is about, and creating the save is the player's press.
func _perform_on_page(action: String) -> void:
	if action == "new-slot":
		if not bool(_page.call("open_new_slot")):
			push_error("Every slot on this cartridge is in use.")
			_quit_failed()
		return
	if action.begins_with("slot-"):
		_page.call("select_slot", int(action.trim_prefix("slot-")))
		return
	if action.begins_with("name-"):
		var input: LineEdit = _find_line_edit(_page)
		if input == null:
			push_error("No name field is on screen: open the form first.")
			_quit_failed()
			return
		input.text = action.trim_prefix("name-")
		return
	if action.begins_with("focus-"):
		_reach_button(action.trim_prefix("focus-"), false)
		return
	if action.begins_with("click-"):
		_reach_button(action.trim_prefix("click-"), true)
		return
	push_error("Unknown save-page action: %s" % action)
	_quit_failed()


## The button wearing [param label], focused and optionally pressed. The focus
## ring is the only cursor a recorded clip has, so it goes on the thing about to
## be pressed rather than being left where the page put it.
func _reach_button(label: String, press: bool) -> void:
	var button: Button = _find_button(_page, label)
	if button == null:
		push_error("No button says %s on this page." % label)
		_quit_failed()
		return
	button.grab_focus()
	if press:
		button.pressed.emit()


static func _find_button(node: Node, label: String) -> Button:
	var button: Button = node as Button
	if button != null and button.text == label:
		return button
	for child: Node in node.get_children():
		var found: Button = _find_button(child, label)
		if found != null:
			return found
	return null


static func _find_line_edit(node: Node) -> LineEdit:
	var input: LineEdit = node as LineEdit
	if input != null:
		return input
	for child: Node in node.get_children():
		var found: LineEdit = _find_line_edit(child)
		if found != null:
			return found
	return null


func _button(action: String) -> int:
	match action:
		"a": return Gen2Button.A
		"b": return Gen2Button.B
		"start": return Gen2Button.START
		"select": return Gen2Button.SELECT
	return _direction(action)


## Everything a viewer can see change, printed on the frame it changed. What
## aims a press at a menu: a battle's own opening is as long as its text is, and
## the frame the menu appears on is not a number anyone can work out in advance.
func _trace(at: int) -> void:
	var line: String = "waits=%d:%s %s" % [
		_waits.size(),
		_waits[0]["state"] if not _waits.is_empty() else &"-",
		_trace_line(),
	]
	if line == _traced:
		return
	_traced = line
	print("frame=%d recorded=%d %s" % [at, _frames, line])


func _trace_line() -> String:
	if _screen == null:
		return "focus=%s" % _focused_label()
	var world: Dictionary = _screen.world_snapshot()
	var text: String = " / ".join(Array(_text_box_lines()))
	var battle: Object = _screen.get("_battle_host")
	if battle == null:
		return "state=%s map text=%s prompt=%s %s" % [
			_screen_state(),
			text, world.get("script_prompt", ""), _overlay_state()
		]
	var shot: Dictionary = battle.call("battle_snapshot")
	return "state=%s battle menu=%s pos=%d press=%s capture=%s over=%s box=%s" % [
		_screen_state(), shot.get("menu_stage", &""), int(shot.get("menu_position", 0)),
		shot.get("awaits_press", false), shot.get("capture_selecting", false),
		shot.get("battle_over", false), " / ".join(Array(_box_lines(battle, "_box"))),
	]


## Which overlay owns the map, for the trace. A press that has to land on a menu
## row is aimed at the frame the menu opened on, and the banner a mod raises is
## in front of it for sixty passes.
func _overlay_state() -> String:
	var menu: Object = _screen.get("_start_menu_host")
	var page: Object = _screen.get("_mod_page_host")
	return "menu=%s page=%s sign=%s" % [
		menu.get("_menu").cursor if menu != null else -1,
		page != null,
		_screen.get("_map_name_sign") != null,
	]


## The line ON SCREEN rather than the message that was handed to the box: a
## faint and the Nuzlocke death behind it are two pages of one message, and only
## the box says which of them is up.
## Whether the box still owes letters or pages, which is what a question with
## more than one paragraph waits on before it will take an answer.
static func _reading(owner: Object, property: String) -> bool:
	var box: Object = owner.get(property)
	if box == null:
		return false
	return bool(box.call("is_revealing")) or bool(box.call("has_pages_left"))


static func _box_lines(owner: Object, property: String) -> PackedStringArray:
	var box: Object = owner.get(property)
	return box.call("text_lines") if box != null else PackedStringArray()


func _text_box_lines() -> PackedStringArray:
	return _box_lines(_screen, "_text_box")


func _focused_label() -> String:
	var focused: Control = _page.get_viewport().gui_get_focus_owner() if _page != null else null
	if focused == null:
		return "<none>"
	var button: Button = focused as Button
	if button != null and not button.text.is_empty():
		return button.text
	return String(focused.name)


## The start menu's own rows, in the order a DOWN press walks them. A mod row is
## registered rather than written here, so the count moves with what is installed
## and a clip that opens a mod's page is aimed with this rather than by guessing.
func _print_start_menu() -> void:
	_screen.preview_start_menu()
	var host: Object = _screen.get("_start_menu_host")
	var menu: Gen2WorldStartMenu = host.get("_menu") if host != null else null
	if menu == null:
		push_error("The start menu did not open.")
		_quit_failed()
		return
	var rows: Array = menu.items()
	for index: int in rows.size():
		var row: Dictionary = rows[index]
		print("%2d %s %s" % [index, row.get("kind", &""), row.get("label", "")])


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


## What the installation was on before the clip, put back: a view is chosen per
## installation and persisted, and a save this driver invented must not be left
## as the one the mods think is being played.
func _finish() -> void:
	if _screen != null:
		Gen2ModHost.instance().deactivate_save()
	if _restore_view.is_empty():
		return
	Gen2ModHost.instance().select_view(_restore_view)


func _quit_failed() -> void:
	_failed = true
	quit(1)
