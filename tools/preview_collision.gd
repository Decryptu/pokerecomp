extends SceneTree

## Draws a whole map as the game draws it, with every walk cell's permission
## checkerboarded over the top: red for WALL, blue for WATER, nothing for LAND. For
## a report that a player can stand somewhere they should not. The art and the
## permission come from the same two sources the runtime reads, so a wall drawn
## without a red square is a real disagreement rather than a rendering offset.
## Objects are not drawn: this is the map's own answer.

## Generation 1 is named by one flat map id and draws in the four Game Boy greys,
## its colours being a Super Game Boy packet built from that id.
##   Godot --headless --path . -s res://tools/preview_collision.gd -- crystal 26 2 /tmp/route31.png
##   Godot --headless --path . -s res://tools/preview_collision.gd -- red 0 /tmp/pallet.png

const SCALE: int = 3
const WALL_TINT: Color = Color(1.0, 0.0, 0.0, 0.75)
const WATER_TINT: Color = Color(0.1, 0.3, 1.0, 0.35)
const CELL_PIXELS: int = Gen2Layout.MAP_BLOCK_CELL_WIDTH * PokeTiles.TILE_WIDTH
## The checker square, so the art underneath stays readable.
const CHECKER: int = 4


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() < 3:
		push_error("Usage: -s tools/preview_collision.gd -- <game> [group] <number> <output.png>")
		quit(1)
		return
	var out_path: String = args[args.size() - 1]
	if PokeToolPath.refuses(out_path):
		quit(2)
		return
	var data: GameData = GameData.open(StringName(args[0]))
	if data == null:
		push_error("No cache for %s. Import roms/%s first." % [args[0], args[0]])
		quit(1)
		return
	# A three-argument call is Generation 1's group 0.
	var group: int = int(args[1]) if args.size() > 3 else 0
	var number: int = int(args[args.size() - 2])

	var map: Gen2WorldMap = data.world_map(group, number)
	var tileset: Gen2WorldTileset = data.world_tileset(map.tileset) if map != null else null
	if map == null or tileset == null:
		push_error("No map %d/%d in %s." % [group, number, args[0]])
		quit(1)
		return

	var image: Image = _draw_map(data, map, tileset)
	_tint_permissions(image, map, tileset, data.generation)
	image.resize(image.get_width() * SCALE, image.get_height() * SCALE, Image.INTERPOLATE_NEAREST)
	if image.save_png(out_path) != OK:
		push_error("Could not write %s" % out_path)
		quit(1)
		return
	print("%s map %d/%d: %d by %d cells." % [
		args[0], group, number, map.collision_width, map.collision_height,
	])
	quit(0)


func _draw_map(data: GameData, map: Gen2WorldMap, tileset: Gen2WorldTileset) -> Image:
	var indices: PackedByteArray = data.map_tile_indices(map, tileset)
	var palettes: Array = _tile_palettes(data, map, tileset)
	var strip_width: int = tileset.tile_count * PokeTiles.TILE_WIDTH
	var image := Image.create(
		map.collision_width * CELL_PIXELS, map.collision_height * CELL_PIXELS,
		false, Image.FORMAT_RGBA8
	)
	for tile_y: int in map.height_blocks * Gen2Layout.MAP_BLOCK_TILE_WIDTH:
		for tile_x: int in map.width_blocks * Gen2Layout.MAP_BLOCK_TILE_WIDTH:
			@warning_ignore("integer_division")
			var block: int = map.block_at(
				tile_x / Gen2Layout.MAP_BLOCK_TILE_WIDTH, tile_y / Gen2Layout.MAP_BLOCK_TILE_WIDTH
			)
			var tile: int = tileset.tile_index(
				block,
				(tile_y % Gen2Layout.MAP_BLOCK_TILE_WIDTH) * Gen2Layout.MAP_BLOCK_TILE_WIDTH
				+ (tile_x % Gen2Layout.MAP_BLOCK_TILE_WIDTH)
			)
			var palette: PackedColorArray = palettes[tile] if tile < palettes.size() \
				else PackedColorArray()
			for y: int in PokeTiles.TILE_HEIGHT:
				for x: int in PokeTiles.TILE_WIDTH:
					var index: int = int(
						indices[y * strip_width + tile * PokeTiles.TILE_WIDTH + x]
					)
					image.set_pixel(
						tile_x * PokeTiles.TILE_WIDTH + x, tile_y * PokeTiles.TILE_HEIGHT + y,
						palette[index] if index < palette.size() else Color.MAGENTA
					)
	return image


## One palette per tile of the strip; Generation 1 assigns none, so all four
## greys.
func _tile_palettes(data: GameData, map: Gen2WorldMap, tileset: Gen2WorldTileset) -> Array:
	if data.generation == RomRegistry.GEN1:
		var greys: PackedColorArray = PokePalette.monochrome()
		var out: Array = []
		out.resize(tileset.tile_count)
		out.fill(greys)
		return out
	return Gen2WorldPalette.tile_palettes(
		data, map, tileset, Gen2WorldPalette.TIME_DAY, -1, -1
	)


func _tint_permissions(
	image: Image, map: Gen2WorldMap, tileset: Gen2WorldTileset, generation: int
) -> void:
	for cell_y: int in map.collision_height:
		for cell_x: int in map.collision_width:
			var code: int = map.collision_at(cell_x, cell_y)
			var tint: Color = _tint_for(code, tileset, generation)
			if tint.a == 0.0:
				continue
			for y: int in CELL_PIXELS:
				for x: int in CELL_PIXELS:
					if ((x / CHECKER) + (y / CHECKER)) % 2 != 0:
						continue
					var at := Vector2i(cell_x * CELL_PIXELS + x, cell_y * CELL_PIXELS + y)
					image.set_pixel(at.x, at.y, image.get_pixel(at.x, at.y).lerp(tint, tint.a))


## `_IsTilePassable` walks the tileset's list and `IsNextTileShoreOrWater` calls
## one tile water on a tileset that has any.
func _tint_for(code: int, tileset: Gen2WorldTileset, generation: int) -> Color:
	if generation == RomRegistry.GEN1:
		if tileset.water and code == Gen1Layout.WATER_TILE:
			return WATER_TINT
		return Color(0, 0, 0, 0) if tileset.tile_passable(code) else WALL_TINT
	var permission: int = Gen2WorldCollision.permission_for(code)
	if permission == Gen2WorldCollision.WALL_TILE:
		return WALL_TINT
	if permission == Gen2WorldCollision.WATER_TILE:
		return WATER_TINT
	return Color(0, 0, 0, 0)
