class_name Gen2MagnetTrainPage
extends RefCounted

## `DrawMagnetTrain` and `SetMagnetTrainPals`: the ride's 32x18 background map,
## read one scanline at a time through [method Gen2MagnetTrain.line_offsets]. The
## tiles are whatever the station left in VRAM, so this draws with the live
## tileset strip; only the palettes are the scene's own.

const TILE: int = PokeTiles.TILE_WIDTH
const WIDTH: int = Gen2Screen.WIDTH
const HEIGHT: int = Gen2Screen.HEIGHT
const MAP_COLUMNS: int = 32
const MAP_ROWS: int = 18
const MAP_WIDTH: int = MAP_COLUMNS * TILE

const OAM_ORIGIN := Vector2i(8, 16)
const SPRITE_TILES: int = 4

## `SetMagnetTrainPals`' first three `ByteFill`s, as (first row, rows, palette).
const PALETTE_BANDS: Array[Array] = [
	[0, 4, 2], [4, 10, 0], [14, 4, 2],
]
const WINDOW_ROW: int = 8
const WINDOW_COLUMN: int = 7
const WINDOW_CELLS: int = 6
const PAL_BG_YELLOW: int = 4

var player_pixels: int = 0

var _words := PackedInt32Array()
var _indices := PackedByteArray()
var _sprite: Gen2WorldSprite = null
var _sprite_strip := PackedByteArray()
var _sprite_table := PackedInt32Array()


static func create(
	data: GameData, tileset: Gen2WorldTileset, time_of_day: int, female: bool
) -> Gen2MagnetTrainPage:
	if data == null or tileset == null or not data.has_magnet_train():
		return null
	var strip: PackedByteArray = data.world_tileset_indices(tileset.number)
	if strip.size() < tileset.tile_count * PokeTiles.TILE_PIXELS:
		return null
	var page := Gen2MagnetTrainPage.new()
	page._sprite = data.overworld_sprite(
		Gen2WorldSprite.player_normal_sprite(female)
	)
	if page._sprite == null:
		return null
	page._sprite_strip = data.overworld_sprite_indices(page._sprite.number)
	page._sprite_table = Gen2PicImage.lookup(
		data.overworld_sprite_palette(
			Gen2WorldSprite.player_palette(female), time_of_day
		), true
	)
	page._build_map(data, tileset, strip, time_of_day)
	return page


func draw(movie: Gen2MagnetTrain) -> Image:
	var pixels: PackedInt32Array = Gen2PicImage.canvas(WIDTH, HEIGHT)
	if movie == null or _words.is_empty():
		return Gen2PicImage.canvas_image(pixels, WIDTH, HEIGHT)
	var lines: PackedInt32Array = movie.line_offsets()
	for y: int in HEIGHT:
		var offset: int = lines[y] & (MAP_WIDTH - 1)
		var from: int = y * MAP_WIDTH
		var to: int = y * WIDTH
		for x: int in WIDTH:
			pixels[to + x] = _words[from + ((x + offset) & (MAP_WIDTH - 1))]
	player_pixels = 0
	_draw_player(pixels, movie, lines)
	return Gen2PicImage.canvas_image(pixels, WIDTH, HEIGHT)


## The one sprite anim the scene owns. Every part carries `OAM_PRIO`.
func _draw_player(
	pixels: PackedInt32Array, movie: Gen2MagnetTrain, lines: PackedInt32Array
) -> void:
	var frame: int = movie.player_frame()
	if frame < 0 or _sprite_table.is_empty():
		return
	## `dbsprite -1, -1` through `dbsprite 0, 0`, so the struct's own coordinate
	## is the bottom-right part.
	var at: Vector2i = movie.player_at() - OAM_ORIGIN - Vector2i(TILE, TILE)
	var first: int = _sprite.frame_tile_offset(Gen2WorldSprite.FACING_DOWN, frame)
	var mirrored: bool = Gen2WorldSprite.frame_is_mirrored(
		Gen2WorldSprite.FACING_DOWN, frame
	)
	for part: int in SPRITE_TILES:
		var column: int = part & 1
		var tile: int = first + (part ^ (1 if mirrored else 0))
		_blit_part(
			pixels, lines, _sprite_strip, _sprite.tiles, tile, mirrored,
			at + Vector2i(column * TILE, (part >> 1) * TILE)
		)


func _blit_part(
	pixels: PackedInt32Array, lines: PackedInt32Array, strip: PackedByteArray,
	strip_tiles: int, tile: int, flip_x: bool, at: Vector2i
) -> void:
	if strip_tiles <= 0 or tile < 0 or tile >= strip_tiles:
		return
	var stride: int = strip_tiles * TILE
	for row: int in TILE:
		var y: int = at.y + row
		if y < 0 or y >= HEIGHT:
			continue
		var offset: int = lines[y] & (MAP_WIDTH - 1)
		for step: int in TILE:
			var x: int = at.x + step
			if x < 0 or x >= WIDTH:
				continue
			var from: int = row * stride + tile * TILE \
				+ ((TILE - 1 - step) if flip_x else step)
			if from >= strip.size():
				continue
			var index: int = strip[from]
			if index == Gen2PicImage.TRANSPARENT_INDEX:
				continue
			if _indices[y * MAP_WIDTH + ((x + offset) & (MAP_WIDTH - 1))] != 0:
				continue
			pixels[y * WIDTH + x] = _sprite_table[index]
			player_pixels += 1


## `DrawMagnetTrain`: the 2x18 strip repeated across the map, then the train.
func _build_map(
	data: GameData, tileset: Gen2WorldTileset, strip: PackedByteArray,
	time_of_day: int
) -> void:
	var codes: PackedByteArray = _tilemap(data)
	var tables: Array = _palette_tables(data, time_of_day)
	_words = Gen2PicImage.canvas(MAP_WIDTH, MAP_ROWS * TILE)
	_indices = PackedByteArray()
	_indices.resize(MAP_WIDTH * MAP_ROWS * TILE)
	for row: int in MAP_ROWS:
		for column: int in MAP_COLUMNS:
			var cell: int = row * MAP_COLUMNS + column
			Gen2PicImage.blit_tile(
				_words, MAP_WIDTH, MAP_ROWS * TILE, strip, tileset.tile_count,
				int(codes[cell]), column * TILE, row * TILE,
				tables[_palette_of(row, column)]
			)
			_copy_indices(strip, tileset.tile_count, int(codes[cell]), column, row)


static func _tilemap(data: GameData) -> PackedByteArray:
	var bg: PackedByteArray = data.magnet_train_tilemap("bg")
	var fg: PackedByteArray = data.magnet_train_tilemap("fg")
	var out := PackedByteArray()
	out.resize(MAP_COLUMNS * MAP_ROWS)
	var columns: int = Gen2Layout.MAGNET_TRAIN_BG_COLUMNS
	for row: int in MAP_ROWS:
		for column: int in MAP_COLUMNS:
			out[row * MAP_COLUMNS + column] = bg[row * columns + (column % columns)]
	for row: int in Gen2Layout.MAGNET_TRAIN_FG_ROWS:
		for column: int in Gen2Layout.MAGNET_TRAIN_FG_COLUMNS:
			out[(Gen2Layout.MAGNET_TRAIN_FG_ROW + row) * MAP_COLUMNS + column] = \
				fg[row * Gen2Layout.MAGNET_TRAIN_FG_COLUMNS + column]
	return out


static func _palette_of(row: int, column: int) -> int:
	if row == WINDOW_ROW and column >= WINDOW_COLUMN \
		and column < WINDOW_COLUMN + WINDOW_CELLS:
		return PAL_BG_YELLOW
	for band: Array in PALETTE_BANDS:
		if row >= int(band[0]) and row < int(band[0]) + int(band[1]):
			return int(band[2])
	return 0


static func _palette_tables(data: GameData, time_of_day: int) -> Array:
	var slots: Array = Gen2WorldPalette.palette_slots(
		Gen2WorldPalette.ENVIRONMENT_TOWN, time_of_day
	)
	var out: Array = []
	for slot: Variant in slots:
		out.append(Gen2PicImage.lookup(data.world_palette(int(slot))))
	return out


func _copy_indices(
	strip: PackedByteArray, strip_tiles: int, tile: int, column: int, row: int
) -> void:
	if tile < 0 or tile >= strip_tiles:
		return
	var stride: int = strip_tiles * TILE
	for y: int in TILE:
		var from: int = y * stride + tile * TILE
		if from + TILE > strip.size():
			return
		var to: int = (row * TILE + y) * MAP_WIDTH + column * TILE
		for x: int in TILE:
			_indices[to + x] = strip[from + x]
