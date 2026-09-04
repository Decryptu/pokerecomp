class_name PokeCartridgeArt
extends RefCounted

## A picture the player put on a cartridge in place of the shipped shell. Under
## `user://`, beside the saves and for their reason: an update never touches it.
## What is stored is never the chosen file: it is decoded, measured, shrunk and
## written back out as a PNG this project encoded.

const ROOT: String = "user://cartridge_art"

## Refused before it is decoded, or read into memory at all.
const MAX_SOURCE_BYTES: int = 12 * 1024 * 1024
## Refused rather than shrunk: past this it is a panorama or a decompression bomb.
const MAX_SOURCE_PIXELS: int = 64 * 1024 * 1024
## The shipped shells are 1058 by 1201: larger is scaled down once, here, rather
## than by the renderer on every frame of the carousel.
const STORED_SIDE: int = 1201

## The extension is the chooser's guess at their own file; these are the file.
const SIGNATURES: Array = [
	[[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A], &"png"],
	[[0x52, 0x49, 0x46, 0x46], &"webp"],
	[[0xFF, 0xD8, 0xFF], &"jpg"],
]

## Keyed by content, as [PokeModArt]'s is: the shelf rebuilds on any change.
static var _textures: Dictionary = {}


static func path_for(game_id: StringName, directory: String = ROOT) -> String:
	return "%s/%s.png" % [directory, game_id]


static func has_custom_art(game_id: StringName, directory: String = ROOT) -> bool:
	return FileAccess.file_exists(path_for(game_id, directory))


## Null when there is none, and when a stored file will not decode: that costs
## the shipped shell rather than an empty bay.
static func texture_for(game_id: StringName, directory: String = ROOT) -> Texture2D:
	var path: String = path_for(game_id, directory)
	if not FileAccess.file_exists(path):
		return null
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	var key: String = _digest(bytes)
	if _textures.has(key):
		return _textures[key]
	var image: Image = _decoded(bytes)
	if image == null:
		return null
	var texture: Texture2D = ImageTexture.create_from_image(image)
	_textures[key] = texture
	return texture


static func adopt(
	game_id: StringName, source: String, directory: String = ROOT
) -> Dictionary:
	if String(game_id).is_empty():
		return {"ok": false, "reason": &"unknown_cartridge"}
	if not FileAccess.file_exists(source):
		return {"ok": false, "reason": &"missing_file"}
	var file: FileAccess = FileAccess.open(source, FileAccess.READ)
	if file == null:
		return {"ok": false, "reason": &"unreadable_file"}
	# Measured before it is read: a file past the ceiling never reaches memory.
	var size: int = file.get_length()
	if size > MAX_SOURCE_BYTES:
		return {"ok": false, "reason": &"file_too_large"}
	var bytes: PackedByteArray = file.get_buffer(size)
	var image: Image = _decoded(bytes)
	if image == null:
		return {"ok": false, "reason": &"not_an_image"}
	if image.get_width() * image.get_height() > MAX_SOURCE_PIXELS:
		return {"ok": false, "reason": &"image_too_large"}
	return _store(game_id, _fitted(image), directory)


static func revert(game_id: StringName, directory: String = ROOT) -> bool:
	var path: String = path_for(game_id, directory)
	if not FileAccess.file_exists(path):
		return false
	return DirAccess.remove_absolute(path) == OK


## The reasons above as sentences, so every caller refuses in the same words.
static func refusal_text(reason: StringName) -> String:
	match reason:
		&"missing_file", &"unreadable_file":
			return "That file could not be read."
		&"file_too_large":
			return "Cartridge art has to be under %d MB." % (MAX_SOURCE_BYTES / 1024 / 1024)
		&"not_an_image":
			return "That is not a PNG, WebP or JPEG image."
		&"image_too_large":
			return "That image has too many pixels to be a cartridge label."
		&"unknown_cartridge":
			return "No cartridge was chosen."
	return "That picture could not be used."


## Scaled to fit the shell's box, never up: a 32x32 sprite stays 32x32.
static func _fitted(image: Image) -> Image:
	var side: int = maxi(image.get_width(), image.get_height())
	if side <= STORED_SIDE or side <= 0:
		return image
	var ratio: float = float(STORED_SIDE) / float(side)
	image.resize(
		maxi(1, int(image.get_width() * ratio)), maxi(1, int(image.get_height() * ratio)),
		Image.INTERPOLATE_LANCZOS
	)
	return image


static func _store(game_id: StringName, image: Image, directory: String) -> Dictionary:
	if DirAccess.make_dir_recursive_absolute(directory) != OK \
			and not DirAccess.dir_exists_absolute(directory):
		return {"ok": false, "reason": &"unwritable_directory"}
	image.convert(Image.FORMAT_RGBA8)
	if image.save_png(path_for(game_id, directory)) != OK:
		return {"ok": false, "reason": &"unwritable_directory"}
	return {"ok": true, "id": game_id}


static func _decoded(bytes: PackedByteArray) -> Image:
	if bytes.is_empty() or bytes.size() > MAX_SOURCE_BYTES:
		return null
	var image := Image.new()
	var loaded: int = FAILED
	for row: Array in SIGNATURES:
		var magic := PackedByteArray(row[0] as Array)
		if bytes.slice(0, magic.size()) != magic:
			continue
		match StringName(row[1]):
			&"png":
				loaded = image.load_png_from_buffer(bytes)
			&"webp":
				loaded = image.load_webp_from_buffer(bytes)
			&"jpg":
				loaded = image.load_jpg_from_buffer(bytes)
		break
	return null if loaded != OK or image.is_empty() else image


static func _digest(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()
