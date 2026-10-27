class_name Gen2LauncherFilePicker
extends FileDialog

## The one file picker every launcher dialog is built from, through
## [method Gen2LauncherUI.file_picker] and [method show_picker]. In order of
## preference: the engine's native dialog (Windows, macOS, Linux, Android, whose
## grant covers the one file chosen); the `NativeFilePicker` singleton for iOS,
## where `DisplayServerIOS` implements no `file_dialog_show`; [Gen2BrowseSheet]
## wherever there is no pointer or room; the engine's own browser for the rest.

## Where iOS's export sheet copied a save the app wrote; empty if it was closed.
signal handed_off(destination: String)

## The plugin's singleton, present only on a build that carries it.
const NATIVE_SINGLETON: StringName = &"NativeFilePicker"
const EXPORT_DIR: String = "user://exporting"
const SCREEN_MARGIN: int = 8

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
	if Engine.has_singleton(NATIVE_SINGLETON):
		var native: Object = Engine.get_singleton(NATIVE_SINGLETON)
		# A plugin built before export_file existed can still open, never save.
		if picker_mode == FileDialog.FILE_MODE_OPEN_FILE \
			or (picker_mode == FileDialog.FILE_MODE_SAVE_FILE and native.has_method(&"export_file")):
			dialog._native = native
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
		if uses_browse_sheet() or not _popup_on_screen(fallback_size):
			show_browse_sheet()
		return
	if file_mode == FileDialog.FILE_MODE_SAVE_FILE:
		_export_natively()
		return
	_listen_to_native()
	_native.open_file(title, extensions())


## The engine's browser fitted to the screen; false, unshown, when it cannot fit.
func _popup_on_screen(wanted: Vector2i) -> bool:
	if not is_embedded():
		popup_centered_clamped(wanted, 0.9)
		return true
	var room: Rect2i = Rect2i(get_parent().get_viewport().get_visible_rect())
	var title_height: int = get_theme_constant(&"title_height")
	var fitted := Vector2i(
		mini(wanted.x, room.size.x - 2 * SCREEN_MARGIN),
		mini(wanted.y, room.size.y - title_height - 2 * SCREEN_MARGIN),
	)
	popup(Rect2i(
		room.position + Vector2i(
			(room.size.x - fitted.x) / 2,
			title_height + (room.size.y - title_height - fitted.y) / 2,
		),
		fitted,
	))
	if size.x <= room.size.x and position.y + size.y <= room.end.y:
		return true
	hide()
	return false


## A caller that refused writes nothing and has already said why.
func _export_natively() -> void:
	_clear_exports()
	DirAccess.make_dir_recursive_absolute(EXPORT_DIR)
	var staged: String = EXPORT_DIR.path_join(
		current_file.get_file() if not current_file.get_file().is_empty() else "export"
	)
	file_selected.emit(staged)
	if not FileAccess.file_exists(staged):
		_clear_exports()
		return
	_listen_to_native()
	if _native.export_file(ProjectSettings.globalize_path(staged)) != OK:
		_on_native_cancelled()


static func _clear_exports() -> void:
	if not DirAccess.dir_exists_absolute(EXPORT_DIR):
		return
	for entry: String in DirAccess.get_files_at(EXPORT_DIR):
		DirAccess.remove_absolute(EXPORT_DIR.path_join(entry))
	DirAccess.remove_absolute(EXPORT_DIR)


# One singleton serves every picker, so only the one on screen listens to it.
func _listen_to_native() -> void:
	for connection: Dictionary in _native.file_selected.get_connections():
		_native.file_selected.disconnect(connection["callable"])
	for connection: Dictionary in _native.canceled.get_connections():
		_native.canceled.disconnect(connection["callable"])
	_native.file_selected.connect(_on_native_selected)
	_native.canceled.connect(_on_native_cancelled)


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
	if file_mode == FileDialog.FILE_MODE_SAVE_FILE:
		_clear_exports()
		handed_off.emit(path)
	else:
		file_selected.emit(path)


func _on_native_cancelled() -> void:
	_release_native()
	if file_mode == FileDialog.FILE_MODE_SAVE_FILE:
		_clear_exports()
		handed_off.emit("")
	else:
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


static func use_native_dialog_here() -> bool:
	return DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG_FILE)


func show_browse_sheet(dir: String = "") -> void:
	if not dir.is_empty():
		_last_dir = dir
	var host := get_parent() as Control
	if host == null:
		canceled.emit()
		return
	if _last_dir.is_empty():
		_last_dir = (
			OS.get_user_data_dir() if access == FileDialog.ACCESS_USERDATA
			else Gen2BrowseSheet.start_dir()
		)
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
