class_name Gen2OptionsStore
extends RefCounted

## Persistence for [Gen2Options], deliberately not the save store's checksummed
## container: [method Gen2Options.parse] clamps every field, so a damaged file
## costs a return to defaults.

const PATH: String = "user://options.json"
## Where a script run writes instead: GUT, `tools/validate.gd` and every other
## `-s` driver share `user://` with the game, and one that opened OPTION and
## pressed RIGHT rewrote the developer's own settings and key bindings.
const TEST_PATH: String = "user://options_test.json"

static var _cached: Gen2Options = null
static var _path: String = TEST_PATH if _runs_under_script() else PATH


## The file in use.
static func path() -> String:
	return _path


## Drops the shared object and points at [constant TEST_PATH], which a script
## run already does; it is how a test starts from a clean read.
static func use_test_path() -> void:
	_path = TEST_PATH
	_cached = null


static func _runs_under_script() -> bool:
	var args: PackedStringArray = OS.get_cmdline_args()
	return args.has("-s") or args.has("--script")


## The live options. Read once, then shared, so callers can hold the object and
## see later edits the way [Gen2SaveData] is shared through GameRuntime.
static func current() -> Gen2Options:
	if _cached == null:
		_cached = load_options()
	return _cached


static func load_options() -> Gen2Options:
	if not FileAccess.file_exists(_path):
		return Gen2Options.new()
	var file: FileAccess = FileAccess.open(_path, FileAccess.READ)
	if file == null:
		return Gen2Options.new()
	var text: String = file.get_as_text()
	file.close()
	# JSON.parse_string pushes an engine error on malformed input; a damaged
	# options file is an expected outcome here, not something to report.
	var json := JSON.new()
	if json.parse(text) != OK:
		return Gen2Options.new()
	return Gen2Options.parse(json.data)


static func save(options: Gen2Options) -> bool:
	var file: FileAccess = FileAccess.open(_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(options.to_dict(), "\t"))
	file.close()
	_cached = options
	return true
