class_name Gen2BrowseSheet
extends Gen2LauncherSheet

## The launcher's own file browser, for a machine with no pointer. [FileDialog]'s
## is a pointer's browser: its path field is a [LineEdit] a d-pad cannot leave and
## whose editing kills the process on Horizon, and it descends on `item_activated`,
## which neither a pad nor Ryujinx's touch sends. Every row here is a button, and
## nothing on the card is editable.

signal chosen(path: String)

const MAX_ROWS: int = 400

var _dir: String = ""
var _extensions: PackedStringArray = PackedStringArray()
var _save_name: String = ""
var _list: VBoxContainer = null
var _where: Label = null
var _up: Gen2LauncherButton = null


static func browse(
	palette: Gen2LauncherTheme,
	title: String,
	dir: String,
	extensions: PackedStringArray,
	save_name: String = "",
) -> Gen2BrowseSheet:
	var sheet := Gen2BrowseSheet.new()
	sheet._theme = palette
	sheet._extensions = extensions
	sheet._save_name = save_name
	sheet._build(title)
	sheet._build_browser()
	sheet.go_to(dir)
	return sheet


static func start_dir() -> String:
	return volume_root(OS.get_data_dir())


## The top of the volume [param path] is on. Horizon names one with a colon and
## mounts it at its own root, so the SD card is `sdmc:/` and nothing is above it.
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


## The directory above [param dir], or an empty string at the top of a volume.
static func parent_of(dir: String) -> String:
	var root: String = volume_root(dir)
	if dir.trim_suffix("/") == root.trim_suffix("/"):
		return ""
	var up: String = dir.trim_suffix("/").get_base_dir()
	if up.is_empty():
		return root
	return up + "/" if up.ends_with(":") else up


## What [param dir] offers as rows of `{"name", "path", "directory"}`: directories
## first, each sorted, files kept to [param extensions] unless it is empty.
static func rows(dir: String, extensions: PackedStringArray) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not DirAccess.dir_exists_absolute(dir):
		return out
	var directories: PackedStringArray = DirAccess.get_directories_at(dir)
	directories.sort()
	for entry: String in directories:
		if entry.begins_with("."):
			continue
		out.append({"name": entry, "path": dir.path_join(entry), "directory": true})
	var files: PackedStringArray = DirAccess.get_files_at(dir)
	files.sort()
	for entry: String in files:
		if extensions.is_empty() or extensions.has(entry.get_extension().to_lower()):
			out.append({"name": entry, "path": dir.path_join(entry), "directory": false})
	return out


func directory() -> String:
	return _dir


func go_to(dir: String) -> void:
	if DirAccess.dir_exists_absolute(dir):
		_dir = dir
	elif _dir.is_empty():
		_dir = start_dir()
	_refresh()


func _build_browser() -> void:
	_where = Gen2LauncherUI.muted(_theme, "")
	_where.add_theme_color_override("font_color", _theme.faint)
	_where.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body().add_child(_where)
	_list = Gen2LauncherUI.column(Gen2LauncherUI.GAP_XS)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body().add_child(_list)
	_up = Gen2LauncherButton.create(_theme, "Up", Gen2LauncherButton.Variant.NEUTRAL, &"back")
	_up.pressed.connect(func() -> void: go_to(parent_of(_dir)))
	add_action(_up)
	if not _save_name.is_empty():
		var here: Gen2LauncherButton = Gen2LauncherButton.create(
			_theme, "Save here", Gen2LauncherButton.Variant.PRIMARY, &"save"
		)
		here.pressed.connect(func() -> void: _choose(_dir.path_join(_save_name)))
		add_action(here)


func _refresh() -> void:
	if _list == null:
		return
	Gen2Screen.drop_children(_list)
	_where.text = _dir
	_up.disabled = parent_of(_dir).is_empty()
	var listing: Array[Dictionary] = rows(_dir, _extensions)
	for row: Dictionary in listing.slice(0, MAX_ROWS):
		_list.add_child(_row_button(row))
	if listing.is_empty():
		_list.add_child(Gen2LauncherUI.muted(_theme, "Nothing here to open."))
	elif listing.size() > MAX_ROWS:
		_list.add_child(Gen2LauncherUI.muted(
			_theme, "%d more, not listed." % (listing.size() - MAX_ROWS)
		))
	_focus_first()


func _row_button(row: Dictionary) -> Gen2LauncherButton:
	var folder: bool = bool(row["directory"])
	var button: Gen2LauncherButton = Gen2LauncherButton.create(
		_theme,
		String(row["name"]),
		Gen2LauncherButton.Variant.QUIET,
		&"folder" if folder else &"save",
	)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.clip_text = true
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var path: String = String(row["path"])
	button.pressed.connect(func() -> void:
		if folder:
			go_to(path)
		else:
			_choose(path)
	)
	return button


func _first_focus() -> Control:
	var row: Control = Gen2FocusGuard.first_focusable(_list)
	return row if row != null else super()


## The list is rebuilt under the focus, so a descent leaves a pad on a freed row.
func _focus_first() -> void:
	if not is_inside_tree():
		return
	var first: Control = _first_focus()
	if first != null:
		first.grab_focus()


func _choose(path: String) -> void:
	chosen.emit(path)
	close()
