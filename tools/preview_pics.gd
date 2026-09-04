extends SceneTree

## Renders an imported pic atlas or tile sheet to a PNG so it can be looked at.
##   Godot --headless --path . -s res://tools/preview_pics.gd -- <game> <out.png> [what] [--shiny]
## The cache stores colour indices rather than pixels, with a palette applied at
## draw time so shiny is free; this applies one, which is the only way to tell a
## correct decode from a plausible wrong one. The font comes out folded to sixteen
## tiles a row, the shape the charmap describes.

const ATLASES: PackedStringArray = [
	"front", "back", "unown_front", "unown_back", "trainers", "player_back",
]
const SHEETS: PackedStringArray = [
	"font", "frames", "battle_font", "enemy_hud", "player_hud", "exp_bar",
]

## Tiles per row when a strip is folded for viewing.
const SHEET_COLUMNS: int = 16


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var shiny: bool = args.has("--shiny")

	var positional: PackedStringArray = []
	for arg: String in args:
		if not arg.begins_with("--"):
			positional.append(arg)

	if positional.size() < 2:
		push_error("Usage: <game> <out.png> [%s|%s] [--shiny]" % [
			"|".join(ATLASES), "|".join(SHEETS),
		])
		quit(1)
		return

	var game: StringName = StringName(positional[0])
	var out_path: String = positional[1]
	if PokeToolPath.refuses(out_path):
		quit(2)
		return
	var atlas_name: String = positional[2] if positional.size() > 2 else "front"

	var directory: String = _find_cache(game)
	if directory.is_empty():
		push_error("No cache for %s. Run tools/import_rom.gd first." % game)
		quit(1)
		return

	var _manifest: Dictionary = RomCache.read_manifest(directory)
	var atlases: Dictionary = _manifest.get("atlases", {})
	var sheets: Dictionary = _manifest.get("tiles", {})

	var image: Image = null
	if sheets.has(atlas_name):
		image = _render_sheet(directory, sheets[atlas_name], atlas_name)
	elif atlases.has(atlas_name):
		image = _render(directory, _manifest, atlases[atlas_name], atlas_name, shiny)
	else:
		push_error("Nothing named %s in this cache." % atlas_name)
		quit(1)
		return

	if image == null:
		quit(1)
		return

	if image.save_png(out_path) != OK:
		push_error("Could not write %s." % out_path)
		quit(1)
		return

	print("%s %s%s -> %s (%dx%d)" % [
		game, atlas_name, " shiny" if shiny else "", out_path,
		image.get_width(), image.get_height(),
	])
	quit(0)


func _find_cache(game: StringName) -> String:
	var sha1: String = RomRegistry.sha1_for(game)
	if sha1.is_empty():
		return ""
	var directory: String = RomCache.directory_for(game, sha1)
	return directory if RomCache.is_usable(directory) else ""


## A tile strip, folded into rows of [constant SHEET_COLUMNS] tiles. There is no
## palette to choose: a sheet has none of its own, so it is drawn in the greys a
## Game Boy would have shown before a palette was applied.
func _render_sheet(directory: String, sheet: Dictionary, name: String) -> Image:
	var indices: PackedByteArray = RomCache.read_indices(RomCache.tile_path(directory, name))
	var strip_width: int = int(sheet["width"])
	var tiles: int = int(sheet["tiles"])
	if indices.size() != strip_width * int(sheet["height"]):
		push_error("%s holds %d bytes, expected %d." % [
			name, indices.size(), strip_width * int(sheet["height"]),
		])
		return null

	var columns: int = mini(SHEET_COLUMNS, tiles)
	var rows: int = ceili(float(tiles) / columns)
	var width: int = columns * PokeTiles.TILE_WIDTH
	var folded: PackedByteArray = PackedByteArray()
	folded.resize(width * rows * PokeTiles.TILE_HEIGHT)

	for tile: int in tiles:
		@warning_ignore("integer_division")
		var at_y: int = (tile / columns) * PokeTiles.TILE_HEIGHT
		var at_x: int = (tile % columns) * PokeTiles.TILE_WIDTH
		for y: int in PokeTiles.TILE_HEIGHT:
			var from: int = y * strip_width + tile * PokeTiles.TILE_WIDTH
			var to: int = (at_y + y) * width + at_x
			for x: int in PokeTiles.TILE_WIDTH:
				folded[to + x] = indices[from + x]

	return Gen2PicImage.from_indices(
		folded, width, rows * PokeTiles.TILE_HEIGHT,
		PokePalette.pic_palette(PackedColorArray([
			Color(0.66, 0.66, 0.66), Color(0.33, 0.33, 0.33),
		]))
	)


func _render(
	directory: String, _manifest: Dictionary, atlas: Dictionary, name: String, shiny: bool
) -> Image:
	var indices: PackedByteArray = RomCache.read_indices(RomCache.pic_path(directory, name))
	var width: int = int(atlas["width"])
	var height: int = int(atlas["height"])
	if indices.size() != width * height:
		push_error("%s holds %d bytes, expected %d." % [name, indices.size(), width * height])
		return null

	var cell: int = int(atlas["cell"])
	var columns: int = int(atlas["columns"])
	var palettes: Array = _palettes(directory, name, shiny)
	if palettes.is_empty():
		push_error("No palettes for %s." % name)
		return null

	var image: Image = Image.create_empty(width, height, false, Image.FORMAT_RGBA8)
	for y: int in height:
		for x: int in width:
			var slot: int = (y / cell) * columns + (x / cell)
			var palette: PackedColorArray = palettes[mini(slot, palettes.size() - 1)]
			image.set_pixel(x, y, palette[indices[y * width + x]])

	return image


## One palette per cell of an atlas, in slot order.
## The kinds of atlas are indexed differently: a species atlas by species, the
## trainer atlas by class, and Unown's by letter form, all twenty-six of which
## are the one species and so share its colours. A Generation 1 cartridge names
## no colours for a trainer or a back pic, so those come out in Game Boy greys.
func _palettes(directory: String, name: String, shiny: bool) -> Array:
	var out: Array = []
	var key: String = "shiny" if shiny else "normal"

	if name == "player_back":
		return [_palette_of([])]

	if name == "trainers":
		for entry: Dictionary in RomCache.read_json(RomCache.trainers_path(directory)):
			out.append(_palette_of(entry.get("palette", [])))
		return out

	var species: Array = RomCache.read_json(RomCache.species_path(directory))
	if name.begins_with("unown"):
		var unown: Dictionary = species[Gen2Layout.UNOWN_SPECIES - 1]
		for form: int in Gen2Layout.UNOWN_FORMS:
			out.append(_palette_of(unown["palette"][key]))
		return out

	for entry: Dictionary in species:
		var palette: Dictionary = entry["palette"]
		out.append(_palette_of(palette.get("colors", palette.get(key, []))))
	return out


static func _palette_of(packed: Variant) -> PackedColorArray:
	var colors: Array = packed as Array if packed is Array else []
	if colors.size() >= PokePalette.COLORS_PER_PIC:
		var out: PackedColorArray = PackedColorArray()
		for value: Variant in colors:
			out.append(PokePalette.from_packed(int(value)))
		return out
	if colors.size() < 2:
		return PokePalette.pic_palette(PackedColorArray([
			Color(0.66, 0.66, 0.66), Color(0.33, 0.33, 0.33),
		]))
	return PokePalette.pic_palette(PackedColorArray([
		PokePalette.from_packed(int(colors[0])),
		PokePalette.from_packed(int(colors[1])),
	]))
