@tool
extends EditorPlugin

## Reads the GDScript analyser without a person driving editor menus.
##
##   Godot --headless --editor --path . -- --warning-scan [path ...]
##
## Prints one line per warning as `file:line CODE message`, a tally per code and
## how many scripts it analysed, then quits: 0 when there were none, 1 when there
## were. The paths may be files or directories, `res://` or `user://`, and
## default to [constant DEFAULT_PATHS].
##
## Silence is an answer only because the paths are explicit and the count of
## analysed scripts is printed beside the warnings. That is the difference
## between "nothing is wrong" and "nothing was read", which is what made the
## editor's panel unusable as a check.
##
## It reports the first warning in each script and no more; see
## [Gen2EditorWarnings] for why, and re-run after a fix to see the next.
##
## Without the flag the plugin does nothing at all, so an ordinary editor session
## is untouched by it.
##
## A full sweep takes a few minutes and about three gigabytes: `edit_script` adds a tab
## per script and the editor exposes no way to close one. Name a directory rather
## than sweeping everything when only part of the tree moved.

const FLAG: String = "--warning-scan"
## The project's own script trees. `mods` is the shipped examples; a player's
## installed mods live under `user://mods` and are named on the command line.
const DEFAULT_PATHS: Array[String] = [
	"res://game", "res://tools", "res://tests", "res://autoload", "res://mods",
	"res://addons/warning_scan",
]
## Frames spent letting the editor finish opening before the scan starts. The
## filesystem scan is awaited properly below; these are for the docks.
const SETTLE_FRAMES: int = 4


func _enter_tree() -> void:
	if not OS.get_cmdline_user_args().has(FLAG):
		return
	_scan.call_deferred()


func _scan() -> void:
	for _pass: int in SETTLE_FRAMES:
		await get_tree().process_frame
	var filesystem: EditorFileSystem = EditorInterface.get_resource_filesystem()
	while filesystem.is_scanning():
		await get_tree().process_frame

	var analysed := PackedStringArray()
	var rows: Array[Dictionary] = await Gen2EditorWarnings.analyse(
		_requested_paths(), get_tree(), analysed
	)
	for row: Dictionary in rows:
		print("%s:%d %s %s" % [row["file"], row["line"], row["code"], row["message"]])
	var codes: Dictionary = Gen2EditorWarnings.tally(rows)
	for code: Variant in codes:
		print("  %s %d" % [code, int(codes[code])])
	print("%d warnings in %d analysed scripts" % [rows.size(), analysed.size()])
	get_tree().quit(1 if not rows.is_empty() else 0)


func _requested_paths() -> PackedStringArray:
	var out := PackedStringArray()
	for argument: String in OS.get_cmdline_user_args():
		if argument != FLAG and not argument.begins_with("--"):
			out.append(argument)
	if out.is_empty():
		out.append_array(DEFAULT_PATHS)
	return out
