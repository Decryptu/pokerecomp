class_name Gen2LauncherFilePicker
extends FileDialog

## The one file picker every launcher dialog is built from, reached through
## [method Gen2LauncherUI.file_picker] and shown with [method show_picker]. Three
## ways a platform offers a file, in the order they are preferred: the engine's
## own native dialog, which Windows, macOS, Linux and Android all answer and whose
## Android grant covers the one file chosen; the `NativeFilePicker` singleton for
## iOS, where `DisplayServerIOS` implements no `file_dialog_show`, which hands back
## a file already copied into app storage; and the built-in browser for anything
## left, rooted per [method _pointerless_start_dir].

## The plugin's singleton, present only on a build that carries it.
const NATIVE_SINGLETON: StringName = &"NativeFilePicker"

var _native: Object = null


static func create(
	palette: Gen2LauncherTheme,
	title_text: String,
	picker_mode: FileDialog.FileMode,
	patterns: PackedStringArray,
) -> Gen2LauncherFilePicker:
	var dialog := Gen2LauncherFilePicker.new()
	dialog.file_mode = picker_mode
	dialog.filters = patterns
	dialog.title = title_text
	dialog.use_native_dialog = true
	dialog.theme = palette.control_theme()
	# The plugin opens files; naming one that does not exist yet is a different
	# controller and a different flow, so a save keeps the engine's own path.
	if picker_mode == FileDialog.FILE_MODE_OPEN_FILE \
		and Engine.has_singleton(NATIVE_SINGLETON):
		dialog._native = Engine.get_singleton(NATIVE_SINGLETON)
	dialog.access = (
		FileDialog.ACCESS_FILESYSTEM if dialog._can_browse_freely() else FileDialog.ACCESS_USERDATA
	)
	return dialog


## Points the browser at [method _pointerless_start_dir] before it is shown.
##
## Set here rather than in [method create]: the dialog is built once at startup
## and reaches its directory through a `chdir`, which only holds once it is in
## the tree. A volume that refuses its name with the trailing slash is tried
## without one, and a refusal leaves the engine's own answer in place.
func _open_where_a_pad_can_reach() -> void:
	if access != FileDialog.ACCESS_FILESYSTEM:
		return
	var start: String = _pointerless_start_dir()
	if start.is_empty():
		return
	# Every time, not only the first: the dialog remembers where it was left, and
	# a machine that cannot climb back up would be stuck wherever it last went.
	current_dir = start
	if not current_dir.begins_with(start):
		current_dir = start.trim_suffix("/")


## Where the engine's own browser should open on a machine with no pointer, or
## an empty string where it should keep the engine's answer.
##
## The browser's file list takes the d-pad and descends fine, but its path field
## is a [LineEdit] and eats left and right, so the toolbar's "up" button behind
## it cannot be reached: a console can walk down the tree and never back up.
## Starting at the top of the volume means it never has to. The app's own data
## sits several levels down, which is exactly the corner it cannot climb out of.
static func _pointerless_start_dir() -> String:
	if DisplayServer.has_feature(DisplayServer.FEATURE_MOUSE):
		return ""
	return volume_root(OS.get_data_dir())


## The top of the volume [param path] is on, as a directory a browser can open.
##
## `/` on anything Unix-shaped. Horizon names a volume with a colon and mounts
## each one at its own root, so the SD card is `sdmc:/` and there is nothing
## above it.
static func volume_root(path: String) -> String:
	var root: String = path
	while true:
		var parent: String = root.get_base_dir()
		if parent.is_empty() or parent == root:
			break
		root = parent
	if root.is_empty():
		return ""
	return root + "/" if root.ends_with(":") else root


## Whether the browser in 3. above would list anything the app may then open. A
## sandboxed platform reaching this far has only its own data to offer.
func _can_browse_freely() -> bool:
	if _native != null:
		return true
	return (
		DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG_FILE)
		or not OS.has_feature("mobile")
	)


## Asks for a file. [signal FileDialog.file_selected] carries the answer and
## [signal FileDialog.canceled] the refusal, whichever of the three presented it.
func show_picker(fallback_size: Vector2i) -> void:
	if _native == null:
		_open_where_a_pad_can_reach()
		popup_centered(fallback_size)
		return
	# One singleton serves every picker on screen, and a request left outstanding
	# by a backgrounded app would otherwise still be listening when the next one
	# is answered. Only the picker being shown is connected to it.
	for connection: Dictionary in _native.file_selected.get_connections():
		_native.file_selected.disconnect(connection["callable"])
	for connection: Dictionary in _native.canceled.get_connections():
		_native.canceled.disconnect(connection["callable"])
	_native.file_selected.connect(_on_native_selected)
	_native.canceled.connect(_on_native_cancelled)
	_native.open_file(title, extensions())


## The bare extensions in [member FileDialog.filters], whose entries look like
## `*.gbc, *.gb ; Game Boy cartridge`. Empty means every file.
func extensions() -> PackedStringArray:
	var out := PackedStringArray()
	for entry: String in filters:
		for pattern: String in entry.get_slice(";", 0).split(","):
			var extension: String = pattern.strip_edges().trim_prefix("*").trim_prefix(".")
			if not extension.is_empty() and extension != "*" and not out.has(extension):
				out.append(extension)
	return out


# The singleton is one object shared by every picker on screen, so each listens
# only while its own request is outstanding.
func _on_native_selected(path: String) -> void:
	_release_native()
	file_selected.emit(path)


func _on_native_cancelled() -> void:
	_release_native()
	canceled.emit()


func _release_native() -> void:
	if _native == null:
		return
	if _native.file_selected.is_connected(_on_native_selected):
		_native.file_selected.disconnect(_on_native_selected)
		_native.canceled.disconnect(_on_native_cancelled)
