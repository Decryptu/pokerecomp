extends SceneTree

## Captures the naming screen against a real imported cache, which is what makes it
## worth looking at: the keyboard, the border, the two entry markers and the cursor
## bracket are all cartridge graphics rather than stand-ins.
##
##   Godot --path . -s res://tools/preview_naming_screen.gd -- crystal /tmp/name.png [presses]
##
## A `mail` argument opens `_ComposeMailMessage`, a `rival` one NAME_RIVAL.
## [presses] is a button script: `r`, `l`, `u`, `d`, `a`, `b`, `s` and `c`.

const WINDOW_SIZE := Vector2i(1152, 648)
const SETTLE_FRAMES: int = 8

const BUTTONS: Dictionary = {
	"u": Gen2Button.UP,
	"d": Gen2Button.DOWN,
	"l": Gen2Button.LEFT,
	"r": Gen2Button.RIGHT,
	"a": Gen2Button.A,
	"b": Gen2Button.B,
	"s": Gen2Button.START,
	"c": Gen2Button.SELECT,
}

var _screen: Gen2NamingScreenScreen = null
var _output_path: String = ""
var _frames: int = 0


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error("Usage: preview_naming_screen.gd -- <game> <output.png> [presses]")
		quit(1)
		return
	_output_path = args[1]
	if Gen2ToolPath.refuses(_output_path):
		quit(2)
		return

	var data: GameData = GameData.open(StringName(args[0]))
	if data == null:
		push_error("No cache for %s. Import roms/%s.gbc first." % [args[0], args[0]])
		quit(1)
		return

	root.set_content_scale_size(WINDOW_SIZE)
	root.size = WINDOW_SIZE
	var mail: bool = args.has("mail")
	var prompt: String = Gen2NamingScreenScreen.PROMPT_RIVAL if args.has("rival") \
		else Gen2NamingScreenScreen.PROMPT_PLAYER
	_screen = Gen2NamingScreenScreen.new()
	if not _screen.open(
		data, "" if mail else prompt,
		Gen2NamingScreenScreen.KIND_MAIL if mail else Gen2NamingScreenScreen.KIND_PLAYER
	):
		push_error("The %s cache carries no naming screen data." % args[0])
		quit(1)
		return
	_screen.scale = Vector2(4, 4)
	root.add_child(_screen)
	current_scene = _screen

	var presses: String = args[2] \
		if args.size() > 2 and args[2] not in ["mail", "rival"] else ""
	for key: String in presses:
		if BUTTONS.has(key):
			_screen.handle_button(int(BUTTONS[key]))


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < SETTLE_FRAMES:
		return false
	var image: Image = Gen2ToolPath.capture(root)
	if image == null:
		quit(1)
		return true
	if image.save_png(_output_path) != OK:
		push_error("Could not write %s" % _output_path)
		quit(1)
		return true
	print("Wrote %s (%dx%d), entry \"%s\"" % [
		_output_path, image.get_width(), image.get_height(), _screen.model().stored_name(),
	])
	quit(0)
	return true
