@tool
class_name Gen2EditorWarnings
extends RefCounted

## The GDScript analyser's warnings for a named script, read without a person
## driving editor menus.
##
## The analyser runs inside the editor and reports nowhere else: no CLI mode
## prints its warnings, `--check-only` suppresses them, and a running game prints
## none. Opening a script in the editor's own script editor analyses it on the
## spot, and the panel beside it is the answer. That is the only way to ask about
## a named file and get an answer about that file, which is what makes silence
## mean "clean" rather than "never read".
##
## It reports [b]the first warning in each script and no more[/b]. The panel
## holds one entry however many the script has, which is the engine's behaviour
## and not a limit here; a fix loop still converges, because the next warning
## appears once the first is gone.
##
## `tools/dump_editor_errors.gd` is the other half and is not this: it writes out
## the Debugger panel's whole list for a session, engine errors included, which
## is how a running game's `user://` scripts have always been seen.

## `ScriptTextEditor._update_warnings`' own row: an `[Ignore]` link, then
## `Line N (CODE):` and the message.
const PANEL_LINE: String = "Line "
## Frames spent per script before its panel is read. The editor validates on
## idle, so the panel is a frame or two behind `edit_script`.
const PANEL_SETTLE_FRAMES: int = 4


## Opens each of [param paths] in the script editor and answers what the panel
## says about it, as `{ file, line, code, message }`.
##
## A directory is walked for the `.gd` files under it. `user://` is reached the
## same way `res://` is, which matters because a mod's scripts live there and are
## the ones no editor scan ever sees.
##
## [param analysed] is filled with the files actually opened, so a caller can say
## what its silence covers: a script the analyser never read is silent for the
## same reason a clean one is, and that is what made the panel unusable as a
## check.
static func analyse(
	paths: PackedStringArray, tree: SceneTree, analysed: PackedStringArray
) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var seen: Dictionary = {}
	for path: String in paths:
		for script_path: String in scripts_under(path):
			if seen.has(script_path):
				continue
			seen[script_path] = true
			analysed.append(script_path)
			var row: Dictionary = await _analyse_one(script_path, tree)
			if not row.is_empty():
				rows.append(row)
	return rows


static func _analyse_one(path: String, tree: SceneTree) -> Dictionary:
	## Plain `load`, not `CACHE_MODE_IGNORE`: the analysis comes from opening the
	## script in the editor, and re-parsing under the cache reloads this very
	## file when the sweep reaches it, which corrupts the running frame.
	var script: Resource = load(path)
	if not script is Script:
		return {}
	EditorInterface.edit_script(script as Script)
	for _pass: int in PANEL_SETTLE_FRAMES:
		await tree.process_frame
	## The panel has to be the open tab's own. `edit_script` adds a tab and every
	## tab keeps its own warnings panel, so searching the whole editor finds the
	## first script that had any and reports its warning against every clean
	## script opened after it.
	var editor: ScriptEditorBase = EditorInterface.get_script_editor().get_current_editor()
	if editor == null:
		return {}
	var text: String = _panel_text(editor)
	if text.is_empty():
		return {}
	var row: Dictionary = _parse_panel(text)
	if row.is_empty():
		return {}
	row["file"] = path
	return row


## `Line 6 (UNUSED_VARIABLE):The local variable "lid" is ...`, which is what the
## panel writes once the `[Ignore]` link in front of it is stripped.
static func _parse_panel(text: String) -> Dictionary:
	var at: int = text.find(PANEL_LINE)
	var open: int = text.find(" (", at)
	var close: int = text.find("):", open)
	if at < 0 or open < 0 or close < 0:
		return {}
	return {
		"line": int(text.substr(at + PANEL_LINE.length(), open - at - PANEL_LINE.length())),
		"code": text.substr(open + 2, close - open - 2),
		"message": text.substr(close + 2).strip_edges(),
	}


## The open tab's warnings panel, which is the one [RichTextLabel] under it whose
## text is a `Line N (CODE):` row.
static func _panel_text(node: Node) -> String:
	if node is RichTextLabel:
		var text: String = (node as RichTextLabel).get_parsed_text()
		if text.contains(PANEL_LINE) and text.contains("):"):
			return text
	for child: Node in node.get_children(true):
		var found: String = _panel_text(child)
		if not found.is_empty():
			return found
	return ""


## Every `.gd` file at or under [param path], which may be a file or a
## directory, `res://` or `user://`.
static func scripts_under(path: String) -> PackedStringArray:
	var out := PackedStringArray()
	if path.get_extension() == "gd":
		if FileAccess.file_exists(path):
			out.append(path)
		return out
	var directory: DirAccess = DirAccess.open(path)
	if directory == null:
		return out
	directory.list_dir_begin()
	var entry: String = directory.get_next()
	while entry != "":
		var child: String = path.path_join(entry)
		if directory.current_is_dir():
			if not entry.begins_with("."):
				out.append_array(scripts_under(child))
		elif entry.get_extension() == "gd":
			out.append(child)
		entry = directory.get_next()
	directory.list_dir_end()
	out.sort()
	return out


## How many of each warning code, which is the number a session is green on.
static func tally(rows: Array[Dictionary]) -> Dictionary:
	var codes: Dictionary = {}
	for row: Dictionary in rows:
		var code: String = String(row.get("code", ""))
		codes[code] = int(codes.get(code, 0)) + 1
	return codes
