extends SceneTree

## Imports a cartridge into the user:// cache, headlessly.
##   Godot --headless --path . -s res://tools/import_rom.gd -- [file-or-dir ...]
## Defaults to res://roms. Exits 0 only if every candidate imported. --verify
## stops after the layout check; --dev takes dev cartridges instead of skipping.

const DEFAULT_DIR: String = "res://roms"

var _dev: bool = false
var _skipped: int = 0


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var verify_only: bool = args.has("--verify")
	_dev = args.has("--dev")

	var inputs: PackedStringArray = []
	for arg: String in args:
		if not arg.begins_with("--"):
			inputs.append(arg)
	if inputs.is_empty():
		inputs = PackedStringArray([DEFAULT_DIR])

	var paths: PackedStringArray = []
	for raw: String in inputs:
		var path: String = raw if raw.contains("://") or raw.begins_with("/") else "res://" + raw
		if DirAccess.dir_exists_absolute(path):
			paths.append_array(RomVerifier.candidates_in(path))
		else:
			paths.append(path)

	if paths.is_empty():
		push_error("No candidate files found.")
		quit(1)
		return

	var failures: int = 0
	for path: String in paths:
		if not await _handle(path, verify_only):
			failures += 1

	print("\n%d/%d %s%s." % [
		paths.size() - failures - _skipped, paths.size() - _skipped,
		"verified" if verify_only else "imported",
		", %d dev cartridge%s skipped" % [_skipped, "" if _skipped == 1 else "s"] \
			if _skipped > 0 else "",
	])
	quit(1 if failures > 0 else 0)


func _handle(path: String, verify_only: bool) -> bool:
	var identity: Dictionary = RomVerifier.identify(path)
	if identity["status"] != RomVerifier.Status.OK:
		print("FAIL  %s\n    %s" % [path.get_file(), identity["message"]])
		return false
	if RomRegistry.is_dev(StringName(identity["id"])) and not _dev:
		print("SKIP  %s\n    %s is a dev cartridge; pass --dev." % [
			path.get_file(), identity["title"],
		])
		_skipped += 1
		return true

	var rom: RomFile = RomFile.open_verified(path)
	if rom == null:
		print("FAIL  %s\n    Could not read the file." % path.get_file())
		return false

	print("\n%s  %s" % [path.get_file(), identity["message"]])
	for line: String in RomImport.describe_header(rom):
		print("    %s" % line)

	var check: Dictionary = RomImport.verify_layout(rom)
	print("    layout: %s" % check["message"])
	if not check["ok"]:
		return false
	if verify_only:
		return true

	var result: Dictionary = await RomImport.import_rom(rom, _report)
	print("    %s" % result["message"])
	if result["ok"]:
		print("    cache: %s" % ProjectSettings.globalize_path(result["directory"]))
	return result["ok"]


func _report(stage: String, done: int, total: int) -> void:
	if done == total:
		print("    %s: %d/%d" % [stage, done, total])
