class_name Gen2LauncherFilePicker
extends FileDialog

## The one file picker every launcher dialog is built from, reached through
## [method Gen2LauncherUI.file_picker] and shown with [method show_picker]. Four
## ways a platform offers a file, in the order they are preferred: the engine's
## native dialog, which Windows, macOS, Linux and Android answer and whose Android
## grant covers the one file chosen; the `NativeFilePicker` singleton for iOS,
## where `DisplayServerIOS` implements no `file_dialog_show`; [Gen2BrowseSheet]
## wherever there is no pointer; and the engine's own browser for the rest.

## The plugin's singleton, present only on a build that carries it.
const NATIVE_SINGLETON: StringName = &"NativeFilePicker"

var _native: Object = null
var _palette: Gen2LauncherTheme = null
## Where the sheet last was, shared so a second import starts where the first ended.
static var _last_dir: String = ""


static func create(
	palette: Gen2LauncherTheme,
	title_text: String,
	picker_mode: FileDialog.FileMode,
	patterns: PackedStringArray,
) -> Gen2LauncherFilePicker:
	var dialog := Gen2LauncherFilePicker.new()
	dialog._palette = palette
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


## Whether a browser would list anything the app may then open: a sandboxed
## platform reaching this far has only its own data.
func _can_browse_freely() -> bool:
	if _native != null:
		return true
	return use_native_dialog_here() or not OS.has_feature("mobile")


## Asks for a file. [signal FileDialog.file_selected] carries the answer and
## [signal FileDialog.canceled] the refusal, whichever of the four presented it.
func show_picker(fallback_size: Vector2i) -> void:
	if _native == null:
		if uses_browse_sheet():
			show_browse_sheet()
		else:
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


## Whether the launcher browses for the file itself: only where nothing else
## can, since a machine with no pointer cannot drive the engine's browser.
func uses_browse_sheet() -> bool:
	return (
		_native == null
		and access == FileDialog.ACCESS_FILESYSTEM
		and not use_native_dialog_here()
		and not DisplayServer.has_feature(DisplayServer.FEATURE_MOUSE)
	)


## Whether [member FileDialog.use_native_dialog] gets a dialog of the platform's own.
static func use_native_dialog_here() -> bool:
	return DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG_FILE)


## Shows the sheet over whatever screen added this picker. Public for the preview.
func show_browse_sheet(dir: String = "") -> void:
	if not dir.is_empty():
		_last_dir = dir
	var host := get_parent() as Control
	if host == null:
		canceled.emit()
		return
	if _last_dir.is_empty():
		_last_dir = Gen2BrowseSheet.start_dir()
	var sheet: Gen2BrowseSheet = Gen2BrowseSheet.browse(
		_palette, title, _last_dir, extensions(), current_file
	)
	# A chosen row closes the sheet, so the close is where the answer is counted.
	var answered: Array[bool] = [false]
	sheet.chosen.connect(func(path: String) -> void:
		answered[0] = true
		file_selected.emit(path)
	)
	sheet.closed.connect(func() -> void:
		_last_dir = sheet.directory()
		if not answered[0]:
			canceled.emit()
	)
	sheet.open(host)
