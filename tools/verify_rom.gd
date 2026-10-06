extends SceneTree

## Runs the import gate against a real cartridge without adding one to the repo.
##   Godot --headless --path . -s res://tools/verify_rom.gd -- [file-or-dir ...]
## Defaults to res://roms, the gitignored drop folder; absolute host paths work
## too. Exits 0 only if every candidate verified as a supported cartridge.

const DEFAULT_DIR: String = "res://roms"


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.is_empty():
		args = PackedStringArray([DEFAULT_DIR])

	var paths: PackedStringArray = []
	for raw: String in args:
		# A bare "roms" is the obvious thing to type, so resolve it against the
		# project rather than the shell's working directory.
		var arg: String = raw if raw.contains("://") or raw.begins_with("/") else "res://" + raw
		if DirAccess.dir_exists_absolute(arg):
			paths.append_array(RomVerifier.candidates_in(arg))
		else:
			paths.append(arg)

	if paths.is_empty():
		push_error("No candidate files found.")
		quit(1)
		return

	var failures: int = 0
	for path: String in paths:
		var result: Dictionary = RomVerifier.identify(path)
		var ok: bool = result["status"] == RomVerifier.Status.OK
		if not ok:
			failures += 1
		print("%s  %s\n    %s  %s" % [
			"PASS" if ok else "FAIL",
			path.get_file(),
			result["sha1"] if not result["sha1"].is_empty() else "-".repeat(40),
			result["message"],
		])

	print("\n%d/%d verified." % [paths.size() - failures, paths.size()])
	quit(1 if failures > 0 else 0)
