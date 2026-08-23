class_name Gen2LauncherFilePicker
extends FileDialog

## The one file picker every launcher dialog is built from. Any new file-picking
## UI goes through [method Gen2LauncherUI.file_picker] rather than building its
## own, and shows it with [method show_picker] rather than [method
## Window.popup_centered].
##
## Three ways a platform offers a file, in the order they are preferred:
##
## 1. The engine's own native dialog, asked for with `use_native_dialog`. Windows,
##    macOS, Linux and Android all answer, and Android's grants access to the one
##    file chosen, which is why the app declares no storage permission.
## 2. The `NativeFilePicker` singleton from `ios/plugins/file_picker`, for iOS,
##    where `DisplayServerIOS` implements no `file_dialog_show` and so the engine
##    has no system picker to offer. It hands back a file already copied into the
##    app's own storage, so what a caller reads is an ordinary path.
## 3. The engine's built-in browser, for anything left. Rooted at the app's own
##    data where the filesystem is sandboxed, since every path outside it is one
##    [FileAccess] would then be refused.

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
