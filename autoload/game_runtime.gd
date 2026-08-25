class_name Gen2GameRuntime
extends Node

## Runtime selection shared by the launcher and screens opened from it.
##
## Cartridge bytes and decoded data stay owned by their existing layers. The
## selected save is the exception: it is mutable, and every screen has to see the
## same instance. Re-reading the slot per call handed a battle result, a party
## transaction and a world snapshot three different saves, and only the last
## write survived. The slot is loaded once and kept until the selection changes
## or a caller asks for it from disk again.

var selected_game_id: StringName = &""
var selected_save_slot: int = -1

## The new game the intro is running for, before it exists on disk.
##
## `NewGame` reaches `InitializeWorld` only after `PlayerProfileSetup` and
## `OakSpeech` have both returned, so there is nothing to write until the intro
## finishes. The launcher stages the slot and the slot's own label here, the
## intro screen adds the trainer name and gender the cartridge asks for, and
## only then is a save built and written. Abandoning the intro leaves no file.
var pending_new_game_slot: int = -1
var pending_new_game_label: String = ""

## The autoload, cached after the first lookup.
static var _instance: Gen2GameRuntime = null


## The live runtime, or null outside a scene tree that has one.
##
## Named relative to the root rather than as `/root/GameRuntime`, and reached
## through this rather than through the `GameRuntime` global, for the reason
## [method Gen2InputRuntime.instance] gives: a script handed to `-s` compiles
## before the autoloads exist, so a screen naming the global by identifier fails
## to compile at all and takes every tool that loads it down with it.
static func instance() -> Gen2GameRuntime:
	if _instance == null:
		var loop: SceneTree = Engine.get_main_loop() as SceneTree
		if loop != null:
			_instance = loop.root.get_node_or_null(^"GameRuntime") as Gen2GameRuntime
	return _instance


## The selected cache, or the first imported one when nothing is selected, which
## is what a development screen opened outside the launcher wants.
static func data_or_any() -> GameData:
	var runtime: Gen2GameRuntime = instance()
	if runtime != null and runtime.has_selected_game():
		return runtime.selected_data()
	return GameData.open_any()


## The selected slot's save, or null when there is no runtime or no slot.
static func selected_save_or_null() -> Gen2SaveData:
	var runtime: Gen2GameRuntime = instance()
	if runtime == null or not runtime.has_selected_save_slot():
		return null
	return runtime.selected_save()


## Stages a new game for [method take_pending_new_game] to pick up.
func begin_new_game(game_id: StringName, slot: int, label: String) -> void:
	selected_game_id = game_id
	pending_new_game_slot = slot
	pending_new_game_label = label


## The staged slot and label, cleared as it is handed over so a second read
## cannot start the intro again.
func take_pending_new_game() -> Dictionary:
	var out: Dictionary = {"slot": pending_new_game_slot, "label": pending_new_game_label}
	pending_new_game_slot = -1
	pending_new_game_label = ""
	return out

var _save: Gen2SaveData = null
var _save_key: String = ""
var _loaded_mods: Array = []
## The lower display and whatever puts it on real hardware. Both null on a
## machine with one screen, which is every desktop and most phones.
var _second_screen: Gen2SecondScreen = null
var _second_screen_host: Gen2SecondScreenHost = null


## Loads installed mods before any screen exists.
##
## A mod registers what it provides and returns, so this must happen before the
## first screen asks the host: a renderer registered after the overworld was
## built would not be offered until the next map. It also means a broken mod is
## reported while there is still a launcher to report it in.
func _ready() -> void:
	apply_display_options(Gen2OptionsStore.current())
	_attach_second_screen()
	load_mods()


## Brings the lower display up for the whole process rather than for the world.
##
## Here rather than in [Gen2WorldScreen] because a handheld with two panels has
## two panels in the launcher as well, and a black one reads as a fault. The
## screen shows the project's own mark until a world is handed to it and again
## when that world closes; [method set_second_screen_world] is the one way it
## changes hands.
##
## Refused on anything but a player's own launch, for the reason
## [method apply_display_options] gives: a check or a screenshot driver must not
## open a window of its own.
func _attach_second_screen() -> void:
	if not is_player_launch():
		return
	var view := Gen2SecondScreen.new()
	view.name = "SecondScreen"
	add_child(view)
	var host: Gen2SecondScreenHost = Gen2SecondScreenHost.attach(
		view, Gen2OptionsStore.current().second_screen
	)
	if host == null:
		Gen2Screen.drop(view)
		return
	add_child(host)
	_second_screen = view
	_second_screen_host = host


## The world the lower display mirrors, or nothing for the launcher's own mark.
## Called by the screen that owns a world when it is built and again when it goes.
func set_second_screen_world(
	data: GameData, world: Gen2WorldAPI, save: Gen2SaveData
) -> void:
	if _second_screen != null:
		_second_screen.set_world(data, world, save)


## The lower display, or null on a machine with one screen. For a caller that has
## to photograph it.
func second_screen() -> Gen2SecondScreen:
	return _second_screen


## Follows the world without the world having to say so: the gates are three
## numbers and [method Gen2SecondScreen.refresh] does nothing on a frame where
## none of them moved.
func _process(_delta: float) -> void:
	if _second_screen != null:
		_second_screen.refresh()


## Puts the app block's window and frame-rate settings into the engine.
##
## The settings page calls this after every change, the way it calls
## [method Gen2InputRuntime.apply_options] for the control scheme; nothing else
## needs to. Refused on anything but a player's own launch: a headless check or a
## `-s` tool would otherwise be capped at whatever frame rate the developer last
## chose, and a screenshot driver would take the window with it. GAME SPEED is
## not here: it reaches the game through [Gen2WorldAnimation.FrameClock], which
## is what keeps it off the audio driver.
static func apply_display_options(options: Gen2Options) -> void:
	if options == null or not is_player_launch():
		return
	Engine.max_fps = maxi(options.max_fps, 0)
	var mode: DisplayServer.WindowMode = DisplayServer.WINDOW_MODE_WINDOWED
	var borderless: bool = false
	match options.video_mode:
		&"fullscreen":
			mode = DisplayServer.WINDOW_MODE_FULLSCREEN
		&"borderless":
			mode = DisplayServer.WINDOW_MODE_FULLSCREEN
			borderless = true
	DisplayServer.window_set_mode(mode)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, borderless)


## Discovers and runs every mod under [constant Gen2ModHost.ROOT], returning the
## ids that loaded. The directory is created when it is absent so a player has
## somewhere to put one without being told the path.
##
## [param game_id] is the cartridge a mod's `games` declaration is checked
## against. Empty at boot, because the launcher lists what is installed before a
## cartridge is chosen and an unrestricted list is the honest answer there.
func load_mods(game_id: StringName = &"") -> Array:
	if not DirAccess.dir_exists_absolute(Gen2ModHost.ROOT):
		DirAccess.make_dir_recursive_absolute(Gen2ModHost.ROOT)
	var host: Gen2ModHost = Gen2ModHost.instance()
	host.set_target_game(game_id)
	host.discover()
	if not mods_are_allowed():
		_loaded_mods = []
		if not host.manifests().is_empty():
			print("Mods: %d installed, none loaded. Pass --mods to run them." % [
				host.manifests().size()
			])
		return _loaded_mods
	_loaded_mods = host.load_discovered()
	# A mod registers its own controls inside its entry script, which is after the
	# options were applied, so the InputMap gets them now rather than never.
	var input: Gen2InputRuntime = Gen2InputRuntime.instance()
	if input != null:
		input.install_mod_actions()
	for failure: Dictionary in host.failures():
		push_warning("Mod %s was not loaded: %s (%s)" % [
			failure.get("directory", failure.get("id", "?")),
			failure.get("reason", "unknown"), failure.get("detail", ""),
		])
	return _loaded_mods


## Whether this process runs the mods it finds.
##
## A headless run or one driving a `-s` tool script is a check, a test tier or a
## screenshot, and a mod that swaps the renderer or shuffles a table changes what
## those measure without saying so anywhere in their output. Such a run discovers
## mods, so a list is still right, and loads none unless `--mods` is passed. A
## player's own launch is neither, so what they switched on in the launcher is
## what runs.
static func mods_are_allowed() -> bool:
	var args: PackedStringArray = OS.get_cmdline_args()
	if args.has("--mods") or OS.get_cmdline_user_args().has("--mods"):
		return true
	return is_player_launch()


## Whether this process is a player running the game rather than a check, a test
## tier, a screenshot driver or a replay. See [method mods_are_allowed] for what
## rides on the distinction.
static func is_player_launch() -> bool:
	var args: PackedStringArray = OS.get_cmdline_args()
	return not (
		DisplayServer.get_name() == "headless"
		or args.has("-s") or args.has("--script")
	)


func loaded_mods() -> Array:
	return _loaded_mods.duplicate()


func select_game(game_id: StringName) -> bool:
	if RomRegistry.sha1_for(game_id).is_empty():
		return false
	if selected_game_id != game_id:
		selected_save_slot = -1
		reload_selected_save()
	selected_game_id = game_id
	_retarget_mods(game_id)
	return true


## Reloads the mods a cartridge is entitled to, when the cartridge changes.
##
## Every mod's entry script runs again against a fresh host, because a `games`
## declaration decides what a mod may register at all and a registration made for
## the previous cartridge would outlive it. Reached only from
## [method select_game], which the launcher calls on Play and after an import,
## not while the player walks along the shelf.
func _retarget_mods(game_id: StringName) -> void:
	var host: Gen2ModHost = Gen2ModHost.instance()
	if host.target_game() == game_id:
		return
	if host.retarget_if_same_mod_set(game_id):
		return
	reload_mods(game_id)


## The same reload for a list that changed rather than a cartridge that did: a
## mod switched on or off, or one deleted. One rule covers both, so a switch
## applies where it was thrown instead of at the next launch.
func reload_mods(game_id: StringName = selected_game_id) -> Array:
	Gen2ModHost.reset()
	var loaded: Array = load_mods(game_id)
	## The reset dropped the old host's providers and its overlay with them, so
	## the freshly loaded ones are told which save is open rather than finding
	## out at the next slot change.
	_activate_mod_save()
	return loaded


func has_selected_game() -> bool:
	return not selected_game_id.is_empty()


func selected_data() -> GameData:
	if not has_selected_game():
		return null
	return GameData.open(selected_game_id)


func select_save_slot(game_id: StringName, slot: int) -> bool:
	if slot < 0 or slot >= Gen2SaveStore.MAX_SLOTS:
		return false
	if not select_game(game_id):
		return false
	if selected_save_slot != slot:
		reload_selected_save()
	selected_save_slot = slot
	_activate_mod_save()
	return true


func has_selected_save_slot() -> bool:
	return has_selected_game() and selected_save_slot >= 0


## The selected slot, loaded once and shared. Callers may mutate it and write it
## back through [Gen2SaveStore]; they are all holding the same save.
func selected_save() -> Gen2SaveData:
	if not has_selected_save_slot():
		return null
	var key: String = "%s:%d" % [selected_game_id, selected_save_slot]
	if _save != null and _save_key == key:
		return _save
	var data: GameData = selected_data()
	if data == null:
		return null
	var result: Dictionary = Gen2SaveStore.load_result(
		data.id, data.sha1, selected_save_slot, data
	)
	if not result["ok"]:
		return null
	_save = result["save"]
	_save_key = key
	return _save


## Drops the loaded save so the next read comes from disk again. For a caller
## that has just rewritten the slot behind this one's back, such as an original
## cartridge import.
func reload_selected_save() -> void:
	_save = null
	_save_key = ""


## Tells the mods that hold a run which save it is, before any screen reads
## `GameData`. Every slot change goes through here, including the one to no slot
## at all: a development run is null rather than an invented save, and a mod that
## patched for the last run has its contributions dropped either way.
func _activate_mod_save() -> void:
	Gen2ModHost.instance().activate_save(selected_save_or_null())
	_activate_rules(selected_save_or_null())


## Plays under the slot's own rules, not the installation's. A slot written before
## the block existed has none and adopts the installation once, here, which is the
## only place the two can honestly be reconciled; a run with no slot plays the
## settings screen's own set.
func _activate_rules(save: Gen2SaveData) -> void:
	var installed: Gen2Rules = Gen2OptionsStore.current().rules
	if save != null:
		if save.run_rules == null:
			save.run_rules = installed.duplicate_rules()
		installed = save.run_rules
	Gen2Rules.install(installed)


## A save that has just been made. The mods are told before it is written, so
## whatever a run is built from is in the file the player will load next time,
## and the rules it records are the ones it will always be played under.
func announce_new_save(save: Gen2SaveData) -> void:
	if save != null and save.run_rules == null:
		save.run_rules = Gen2OptionsStore.current().rules.duplicate_rules()
	Gen2ModHost.instance().created_save(save)
	Gen2ModHost.instance().activate_save(save)
	_activate_rules(save)
