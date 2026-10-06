class_name RomVerifier
extends RefCounted

## Identifies a user-supplied dump by SHA-1 against [RomRegistry], node-free and
## reading no content. The importer that follows may assume a verified hash.

enum Status {
	OK,
	NOT_FOUND,
	WRONG_SIZE,
	UNKNOWN_ROM,
}

## Read in chunks so a dump is never held in memory just to be hashed.
const CHUNK_SIZE: int = 65536


static func sha1_of_file(path: String) -> String:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""

	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA1) != OK:
		return ""

	var remaining: int = file.get_length()
	while remaining > 0:
		var chunk: PackedByteArray = file.get_buffer(mini(CHUNK_SIZE, remaining))
		if chunk.is_empty():
			break
		context.update(chunk)
		remaining -= chunk.size()

	return context.finish().hex_encode()


## Identifies a candidate ROM.
## Returns { status, sha1, id, title, revision, message }. Callers should look
## at [code]status[/code]; [code]message[/code] is a ready-to-show string.
static func identify(path: String) -> Dictionary:
	var result: Dictionary = {
		"status": Status.NOT_FOUND,
		"sha1": "",
		"id": &"",
		"title": "",
		"revision": "",
		"message": "",
	}

	if not FileAccess.file_exists(path):
		result["message"] = "No file at %s" % path
		return result

	# Cheap rejection before hashing: any length outside
	# [constant RomRegistry.SIZES] is a wrong, headered or trimmed file.
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		result["message"] = "Could not open %s" % path
		return result
	var size: int = file.get_length()
	file.close()

	if not RomRegistry.is_known_size(size):
		result["status"] = Status.WRONG_SIZE
		result["message"] = (
			"That file is %d bytes; a supported cartridge is %s."
			% [size, " or ".join(_size_list())]
		)
		return result

	var sha1: String = sha1_of_file(path)
	result["sha1"] = sha1

	var row: Dictionary = RomRegistry.lookup(sha1)
	if row.is_empty():
		result["status"] = Status.UNKNOWN_ROM
		result["message"] = (
			"Unrecognised ROM (sha1 %s). pokerecomp supports %s."
			% [sha1, RomRegistry.titles_of(RomRegistry.offered(false))]
		)
		return result

	result["status"] = Status.OK
	result["id"] = row["id"]
	result["title"] = row["title"]
	result["revision"] = row["revision"]
	result["message"] = "%s (%s)" % [row["title"], row["revision"]]
	return result


static func is_valid(path: String) -> bool:
	return identify(path)["status"] == Status.OK


static func _size_list() -> PackedStringArray:
	var out: PackedStringArray = []
	for size: int in RomRegistry.SIZES.values():
		out.append("%d bytes" % size)
	return out



## The files in [param dir_path] with a dump's extension, sorted.
static func candidates_in(dir_path: String) -> PackedStringArray:
	var out: PackedStringArray = []
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return out
	dir.list_dir_begin()
	var name: String = dir.get_next()
	while name != "":
		if not dir.current_is_dir() and RomRegistry.EXTENSIONS.has(name.get_extension().to_lower()):
			out.append("%s/%s" % [dir_path, name])
		name = dir.get_next()
	dir.list_dir_end()
	out.sort()
	return out
