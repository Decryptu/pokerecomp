class_name Gen2ModInstaller
extends RefCounted

## Installs a mod from a `.zip` into [constant Gen2ModHost.ROOT]. The only way a
## mod gets onto disk, whichever way the player found it: a file they picked, one
## they dropped on the window, or one downloaded from an index. So a listing buys
## a mod no trust picking the same file by hand would not.

## A single mod's uncompressed size. Above the voxel example and far below what
## fills a phone, so a broken archive stops here rather than at the filesystem.
const MAX_UNCOMPRESSED_BYTES: int = 64 * 1024 * 1024
## Refuses an archive that would take longer to unpack than a player will wait.
const MAX_ENTRIES: int = 2048
## Local PK magic. A sidecar or a truncated download is not a zip, and saying so
## beats an opaque failure from the reader.
const ZIP_MAGIC: Array[int] = [0x50, 0x4B]
## The tree macOS zips beside what was selected. It belongs to no mod.
const MACOS_SIDECAR: String = "__MACOSX"


## Where a staged download lands: [ZIPReader] takes a path, so bytes from the
## network become a file first.
static func staging_path() -> String:
	return "user://mod_import_staging.zip"


## The prefix inside [param paths] that holds the manifest, as { ok, prefix }.
##
## Empty when the manifest is at the archive root, else the one top-level folder
## holding one. A folder holding none is not a mod and does not count, which is
## what macOS zips beside the mod; two that do are refused. Pure, so the rule is
## testable without an archive.
static func locate_root(paths: PackedStringArray) -> Dictionary:
	var holds_manifest: Array[String] = []
	for path: String in paths:
		if path == PokeModManifest.FILENAME:
			return {"ok": true, "prefix": ""}
		var separator: int = path.find("/")
		if separator <= 0:
			continue
		var top: String = path.substr(0, separator)
		if path.substr(separator + 1) == PokeModManifest.FILENAME \
			and not holds_manifest.has(top):
			holds_manifest.append(top)
	if holds_manifest.size() == 1:
		return {"ok": true, "prefix": holds_manifest[0]}
	if holds_manifest.size() > 1:
		return {
			"ok": false,
			"reason": &"archive_holds_more_than_one_folder",
			"detail": ", ".join(holds_manifest),
		}
	return {
		"ok": false, "reason": &"archive_has_no_manifest", "detail": _manifests_found(paths)
	}


## The JSON filenames where a manifest would be. A foreign mod carries one under
## its own name, and saying which beats saying only that mod.json is missing.
static func _manifests_found(paths: PackedStringArray) -> String:
	var found: Array[String] = []
	for path: String in paths:
		var name: String = path.get_file()
		if name.ends_with(".json") and path.count("/") <= 1 and not found.has(name):
			found.append(name)
	found.sort()
	return ", ".join(found)


## True when [param entry] is part of the mod at [param prefix]; anything else is
## passed over rather than written.
static func belongs_to_mod(entry: String, prefix: String) -> bool:
	if entry.begins_with("%s/" % MACOS_SIDECAR):
		return false
	return prefix.is_empty() or entry.begins_with("%s/" % prefix)


## True when [param entry] stays inside the mod directory once [param prefix] is
## removed. A zip may name any path it likes, including one that climbs out with
## `..` or starts at the filesystem root. The manifest's own entry check refuses
## the same shapes; this refuses them earlier, before anything is read.
static func is_safe_entry(entry: String, prefix: String) -> bool:
	var relative: String = entry
	if not prefix.is_empty():
		if not entry.begins_with("%s/" % prefix):
			return false
		relative = entry.substr(prefix.length() + 1)
	if relative.is_empty():
		return false
	if relative.begins_with("/") or relative.contains("\\") or relative.contains(":"):
		return false
	for part: String in relative.split("/"):
		if part == ".." or part == ".":
			return false
	return true


## Installs the archive at [param path].
##
## [param replace] allows an already-installed id to be overwritten, which an
## update does and a first install does not. [param expect_id] refuses an archive
## whose manifest names a different mod, so a download resolved from an index
## cannot quietly deliver something else.
static func install_zip(
	path: String,
	replace: bool = false,
	expect_id: StringName = &"",
	root: String = Gen2ModHost.ROOT,
) -> Dictionary:
	if not FileAccess.file_exists(path):
		return _refuse(&"archive_not_found", path)
	if not _looks_like_zip(path):
		return _refuse(&"not_a_zip", path)

	var reader := ZIPReader.new()
	if reader.open(path) != OK:
		return _refuse(&"archive_unreadable", path)
	var entries: PackedStringArray = reader.get_files()
	if entries.size() > MAX_ENTRIES:
		reader.close()
		return _refuse(&"archive_too_many_entries", str(entries.size()))

	var located: Dictionary = locate_root(entries)
	if not bool(located.get("ok", false)):
		reader.close()
		return _refuse(
			StringName(located.get("reason", &"archive_has_no_manifest")),
			String(located.get("detail", "")),
		)
	var prefix: String = String(located["prefix"])

	var manifest_entry: String = PokeModManifest.FILENAME
	if not prefix.is_empty():
		manifest_entry = "%s/%s" % [prefix, PokeModManifest.FILENAME]
	var raw: String = reader.read_file(manifest_entry).get_string_from_utf8()
	var parsed: Variant = JSON.parse_string(raw)
	if not parsed is Dictionary:
		reader.close()
		return _refuse(&"invalid_manifest", manifest_entry)

	var read: Dictionary = PokeModManifest.from_dictionary(parsed as Dictionary, root)
	if not bool(read.get("ok", false)):
		reader.close()
		return _refuse(
			StringName(read.get("reason", &"invalid_manifest")), String(read.get("detail", ""))
		)
	var manifest: PokeModManifest = read["manifest"]
	if not expect_id.is_empty() and manifest.id != expect_id:
		reader.close()
		return _refuse(&"unexpected_mod_id", "%s, expected %s" % [manifest.id, expect_id])

	var destination: String = "%s/%s" % [root, manifest.id]
	var existed: bool = DirAccess.dir_exists_absolute(destination)
	if existed and not replace:
		reader.close()
		return _refuse(&"already_installed", String(manifest.id))

	var plan: Dictionary = _plan(reader, entries, prefix)
	if not bool(plan.get("ok", false)):
		reader.close()
		return plan
	var planned: Array[String] = plan["planned"]
	if planned.is_empty():
		reader.close()
		return _refuse(&"archive_is_empty", path)

	# Only now is anything written, the old tree first so no dropped file survives.
	if existed:
		_remove_tree(destination)
	var written: Dictionary = _extract(reader, planned, prefix, destination)
	reader.close()
	if not bool(written.get("ok", false)):
		_remove_tree(destination)
		return written
	return {
		"ok": true,
		"id": manifest.id,
		"name": manifest.name,
		"version": manifest.version,
		"directory": destination,
		"replaced": existed,
		"files": planned.size(),
	}


## The members to write, as { ok, planned }.
static func _plan(reader: ZIPReader, entries: PackedStringArray, prefix: String) -> Dictionary:
	var planned: Array[String] = []
	var total: int = 0
	for entry: String in entries:
		if entry.ends_with("/") or not belongs_to_mod(entry, prefix):
			continue
		if not is_safe_entry(entry, prefix):
			return _refuse(&"unsafe_archive_entry", entry)
		total += reader.read_file(entry).size()
		if total > MAX_UNCOMPRESSED_BYTES:
			return _refuse(&"archive_too_large", str(total))
		planned.append(entry)
	return {"ok": true, "planned": planned}


## Installs [param bytes], staging them where [ZIPReader] can open them. The
## staging file is removed whatever the outcome, so a failed download leaves none.
static func install_bytes(
	bytes: PackedByteArray,
	replace: bool = false,
	expect_id: StringName = &"",
	root: String = Gen2ModHost.ROOT,
) -> Dictionary:
	var staged: String = staging_path()
	var file: FileAccess = FileAccess.open(staged, FileAccess.WRITE)
	if file == null:
		return _refuse(&"could_not_stage_archive", staged)
	file.store_buffer(bytes)
	file.close()
	var result: Dictionary = install_zip(staged, replace, expect_id, root)
	DirAccess.remove_absolute(staged)
	return result


## Removes an installed mod. Returns ok even when it was already absent, so a
## caller cleaning up does not have to check first.
static func uninstall(id: StringName, root: String = Gen2ModHost.ROOT) -> Dictionary:
	if String(id).is_empty():
		return _refuse(&"invalid_id", String(id))
	var directory: String = "%s/%s" % [root, id]
	# Drop any off switch and any stored settings with the mod, so reinstalling it
	# does not find it silently disabled by a decision about a mod that is gone.
	Gen2ModState.forget(id)
	PokeModOptions.forget(id)
	if not DirAccess.dir_exists_absolute(directory):
		return {"ok": true, "id": id, "removed": false}
	_remove_tree(directory)
	return {"ok": true, "id": id, "removed": true}


static func _extract(
	reader: ZIPReader, planned: Array[String], prefix: String, destination: String
) -> Dictionary:
	if DirAccess.make_dir_recursive_absolute(destination) != OK:
		return _refuse(&"could_not_create_mod_directory", destination)
	for entry: String in planned:
		var relative: String = entry
		if not prefix.is_empty():
			relative = entry.substr(prefix.length() + 1)
		var target: String = "%s/%s" % [destination, relative]
		var parent: String = target.get_base_dir()
		if parent != destination and DirAccess.make_dir_recursive_absolute(parent) != OK:
			return _refuse(&"could_not_create_mod_directory", parent)
		var file: FileAccess = FileAccess.open(target, FileAccess.WRITE)
		if file == null:
			return _refuse(&"could_not_write_mod_file", target)
		file.store_buffer(reader.read_file(entry))
		file.close()
	return {"ok": true}


static func _remove_tree(path: String) -> void:
	var directory: DirAccess = DirAccess.open(path)
	if directory == null:
		return
	directory.list_dir_begin()
	var name: String = directory.get_next()
	while name != "":
		var child: String = "%s/%s" % [path, name]
		if directory.current_is_dir():
			_remove_tree(child)
		else:
			DirAccess.remove_absolute(child)
		name = directory.get_next()
	directory.list_dir_end()
	DirAccess.remove_absolute(path)


static func _looks_like_zip(path: String) -> bool:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var head: PackedByteArray = file.get_buffer(ZIP_MAGIC.size())
	file.close()
	if head.size() != ZIP_MAGIC.size():
		return false
	for index: int in ZIP_MAGIC.size():
		if head[index] != ZIP_MAGIC[index]:
			return false
	return true


static func _refuse(reason: StringName, detail: String) -> Dictionary:
	return {"ok": false, "reason": reason, "detail": detail}
