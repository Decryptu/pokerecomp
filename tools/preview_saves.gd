extends SceneTree

## Photographs a window-resolution save-section screen for a cached cartridge.
##
##   Godot --path . -s res://tools/preview_saves.gd -- <out.png> [light|dark] [WxH] [page]
##
## [page] is `saves`, `new`, `party`, `boxes` or `editor`, the pages the save
## slots lead to. They are one command because they are one section and share
## this harness; each is its own scene, and `new` is the slot list with the
## new-game form open on a free slot.
##
## The size is what says whether a page is responsive, so it is an argument
## rather than a constant: a phone portrait and a desktop window are the same
## command twice.

var _output: String = ""
var _frames: int = 0
var _screen: Node = null
var _open_new_game: bool = false


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_output = args[0]
	if Gen2ToolPath.refuses(_output):
		quit(2)
		return
	var mode: String = args[1] if args.size() > 1 else "light"
	var options: Gen2Options = Gen2OptionsStore.current()
	options.ui_theme = StringName(mode)
	var window: Vector2i = Vector2i(1280, 800)
	if args.size() > 2:
		var parts: PackedStringArray = args[2].split("x")
		if parts.size() == 2 and parts[0].is_valid_int() and parts[1].is_valid_int():
			window = Vector2i(int(parts[0]), int(parts[1]))
	DisplayServer.window_set_size(window)
	root.set_content_scale_size(window)
	root.size = window
	# Autoloads are not global identifiers inside a tool script, and an absolute
	# path does not resolve from outside the running scene, so the runtime is
	# found on the root by name.
	var runtime: Node = root.get_node_or_null(NodePath("GameRuntime"))
	for game_id: StringName in RomRegistry.ORDER:
		var data: GameData = GameData.open(game_id)
		if data != null:
			runtime.call("select_game", game_id)
			## The party, box and editor pages all read the runtime's selected
			## slot, so a page other than the slot list needs one chosen first.
			for row: Dictionary in Gen2SaveStore.slots_for(data.id, data.sha1, data):
				if runtime.call("select_save_slot", data.id, int(row["slot"])):
					break
			break
	var page: String = args[3] if args.size() > 3 else "saves"
	var scenes: Dictionary = {
		"saves": "res://game/save/save_screen.tscn",
		"new": "res://game/save/save_screen.tscn",
		"party": "res://game/save/party_screen.tscn",
		"boxes": "res://game/save/box_screen.tscn",
		"editor": "res://game/save/save_editor_screen.tscn",
	}
	if not scenes.has(page):
		push_error("Unknown page %s" % page)
		quit(2)
		return
	_screen = load(String(scenes[page])).instantiate()
	root.add_child(_screen)
	## `_ready` runs on the first frame rather than on `add_child` from here, so
	## the form is opened once the pane it lives in exists, which is the order a
	## press on "New slot" arrives in.
	_open_new_game = page == "new"


func _process(_delta: float) -> bool:
	_frames += 1
	if _open_new_game:
		_open_new_game = false
		_screen.call("open_new_slot")
	if _frames < 26:
		return false
	var image: Image = Gen2ToolPath.capture(root)
	if image == null:
		quit(1)
		return true
	image.save_png(_output)
	print("Wrote %s" % _output)
	quit()
	return true
