extends SceneTree

## Writes the 256x256 JPEG an NRO carries, out of the repository's own PNG.
##
##     Godot --headless --path . -s res://tools/make_nro_icon.gd -- <out.jpg>
##
## `elf2nro --icon=` takes a JPEG of exactly that size and nothing else, and the
## repository's icon is a 1024 PNG, so one is made from the other at package time
## rather than the same picture being committed twice. Godot does it rather than
## ImageMagick because Godot is already installed wherever this runs.

const SOURCE: String = "res://app_icon.png"
const SIDE: int = 256
## `elf2nro` reads the file as it is given, so the quality is this end's choice.
## 92 keeps the icon clean at the size hbmenu draws it and stays well under the
## NRO header's own room for it.
const QUALITY: float = 0.92


func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("Usage: make_nro_icon.gd -- <out.jpg>")
		quit(1)
		return
	var image: Image = _load()
	if image == null:
		push_error("%s could not be read" % SOURCE)
		quit(1)
		return
	## Exactly square, the way `-resize 256x256!` was: the source is square
	## already, so nothing is distorted and a source that stopped being square
	## would still produce a file the header accepts.
	image.resize(SIDE, SIDE, Image.INTERPOLATE_LANCZOS)
	## A JPEG has no alpha, and saving one straight from RGBA leaves the
	## transparent corners black on some decoders.
	image.convert(Image.FORMAT_RGB8)
	var error: int = image.save_jpg(args[0], QUALITY)
	if error != OK:
		push_error("could not write %s (error %d)" % [args[0], error])
		quit(1)
		return
	print("Wrote %s, %dx%d" % [args[0], SIDE, SIDE])
	quit()


## The imported texture where there is one, and the file itself where the
## project has not been imported: this runs on a release job either way round.
func _load() -> Image:
	if ResourceLoader.exists(SOURCE):
		var texture: Texture2D = load(SOURCE) as Texture2D
		if texture != null:
			return texture.get_image()
	return Image.load_from_file(ProjectSettings.globalize_path(SOURCE))
