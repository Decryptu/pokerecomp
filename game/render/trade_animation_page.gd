class_name Gen2TradeAnimationPage
extends RefCounted

## `TradeAnimation`'s screen: [Gen2TradeAnimation] owns the two maps, the scroll,
## the window and the sprite structs, and this turns a tile code into pixels.
## Three sheets feed one code: the frontpic below the trade sheet's first tile,
## the sheet's own 49, and the font, its two arrow codes replaced.

const TILE: int = Gen2Tiles.TILE_WIDTH
const WIDTH: int = Gen2Screen.WIDTH
const HEIGHT: int = Gen2Screen.HEIGHT
const MAP_COLUMNS: int = Gen2TradeAnimation.MAP_COLUMNS
const MAP_ROWS: int = Gen2TradeAnimation.MAP_ROWS
const PIC_TILES: int = Gen2TradeAnimation.PIC_TILES

const OAM_ORIGIN := Vector2i(8, 16)
const SHADOW_OAM_SPRITES: int = Gen2TradeAnimation.SHADOW_OAM_SPRITES

const ATTR_PALETTE: int = 0x07
const ATTR_XFLIP: int = 0x20
const ATTR_YFLIP: int = 0x40
const ATTR_PRIORITY: int = 0x80

const OBJECT_FIRST_TILE: int = Gen2TradeAnimation.DICT_DEFAULT_TILE

## What each `vTiles0` load puts where, off `OBJECT_FIRST_TILE`. The bubble's
## load lands over the ball's, which is why the two never appear together.
const BALL_SHEETS: Array[Array] = [
	["ball", 0x00, 6], ["poof", 0x06, 12], ["cable", 0x12, 2],
]
const BUBBLE_SHEETS: Array[Array] = [["icon", 0x00, 8], ["bubble", 0x10, 4]]

## The `spriteanimoam` rows the movie names, in [Gen2TradeAnimation]'s order.
## A part is (dy, dx, tile, attributes), the order `dbsprite` emits.
const OAM_SETS: Array[Dictionary] = [
	{"vtile": 0x00, "parts": [  # 0: TRADE_POKE_BALL_1 (TradePokeBall1, 4)
		[-8, -8, 0x00, 0x80], [-8, 0, 0x00, 0xA0], [0, -8, 0x01, 0x80],
		[0, 0, 0x01, 0xA0],
	]},
	{"vtile": 0x02, "parts": [  # 1: TRADE_POKE_BALL_2 (MagnetTrainRed, 4)
		[-8, -8, 0x00, 0x80], [-8, 0, 0x01, 0x80], [0, -8, 0x02, 0x80],
		[0, 0, 0x03, 0x80],
	]},
	{"vtile": 0x06, "parts": [  # 2: TRADE_POOF_1 (TradePoofBubble, 16)
		[-16, -16, 0x00, 0x00], [-16, -8, 0x01, 0x00], [-8, -16, 0x02, 0x00],
		[-8, -8, 0x03, 0x00], [-16, 0, 0x01, 0x20], [-16, 8, 0x00, 0x20],
		[-8, 0, 0x03, 0x20], [-8, 8, 0x02, 0x20], [0, -16, 0x02, 0x40],
		[0, -8, 0x03, 0x40], [8, -16, 0x00, 0x40], [8, -8, 0x01, 0x40],
		[0, 0, 0x03, 0x60], [0, 8, 0x02, 0x60], [8, 0, 0x01, 0x60],
		[8, 8, 0x00, 0x60],
	]},
	{"vtile": 0x0A, "parts": [  # 3: TRADE_POOF_2 (TradePoofBubble, 16)
		[-16, -16, 0x00, 0x00], [-16, -8, 0x01, 0x00], [-8, -16, 0x02, 0x00],
		[-8, -8, 0x03, 0x00], [-16, 0, 0x01, 0x20], [-16, 8, 0x00, 0x20],
		[-8, 0, 0x03, 0x20], [-8, 8, 0x02, 0x20], [0, -16, 0x02, 0x40],
		[0, -8, 0x03, 0x40], [8, -16, 0x00, 0x40], [8, -8, 0x01, 0x40],
		[0, 0, 0x03, 0x60], [0, 8, 0x02, 0x60], [8, 0, 0x01, 0x60],
		[8, 8, 0x00, 0x60],
	]},
	{"vtile": 0x0E, "parts": [  # 4: TRADE_POOF_3 (TradePoofBubble, 16)
		[-16, -16, 0x00, 0x00], [-16, -8, 0x01, 0x00], [-8, -16, 0x02, 0x00],
		[-8, -8, 0x03, 0x00], [-16, 0, 0x01, 0x20], [-16, 8, 0x00, 0x20],
		[-8, 0, 0x03, 0x20], [-8, 8, 0x02, 0x20], [0, -16, 0x02, 0x40],
		[0, -8, 0x03, 0x40], [8, -16, 0x00, 0x40], [8, -8, 0x01, 0x40],
		[0, 0, 0x03, 0x60], [0, 8, 0x02, 0x60], [8, 0, 0x01, 0x60],
		[8, 8, 0x00, 0x60],
	]},
	{"vtile": 0x12, "parts": [  # 5: TRADE_TUBE_BULGE_1 (TradeTubeBulge, 4)
		[-8, -8, 0x00, 0x07], [-8, 0, 0x00, 0x27], [0, -8, 0x00, 0x47],
		[0, 0, 0x00, 0x67],
	]},
	{"vtile": 0x13, "parts": [  # 6: TRADE_TUBE_BULGE_2 (TradeTubeBulge, 4)
		[-8, -8, 0x00, 0x07], [-8, 0, 0x00, 0x27], [0, -8, 0x00, 0x47],
		[0, 0, 0x00, 0x67],
	]},
	{"vtile": 0x00, "parts": [  # 7: TRADEMON_ICON_1 (RedWalk, 4)
		[-8, -8, 0x00, 0x00], [-8, 0, 0x01, 0x00], [0, -8, 0x02, 0x00],
		[0, 0, 0x03, 0x00],
	]},
	{"vtile": 0x04, "parts": [  # 8: TRADEMON_ICON_2 (RedWalk, 4)
		[-8, -8, 0x00, 0x00], [-8, 0, 0x01, 0x00], [0, -8, 0x02, 0x00],
		[0, 0, 0x03, 0x00],
	]},
	{"vtile": 0x10, "parts": [  # 9: TRADEMON_BUBBLE (TradePoofBubble, 16)
		[-16, -16, 0x00, 0x00], [-16, -8, 0x01, 0x00], [-8, -16, 0x02, 0x00],
		[-8, -8, 0x03, 0x00], [-16, 0, 0x01, 0x20], [-16, 8, 0x00, 0x20],
		[-8, 0, 0x03, 0x20], [-8, 8, 0x02, 0x20], [0, -16, 0x02, 0x40],
		[0, -8, 0x03, 0x40], [8, -16, 0x00, 0x40], [8, -8, 0x01, 0x40],
		[0, 0, 0x03, 0x60], [0, 8, 0x02, 0x60], [8, 0, 0x01, 0x60],
		[8, 8, 0x00, 0x60],
	]},
]

var frame_style: int = 0

var _data: GameData = null
var _font: Gen2Font = null
var _sheet: PackedByteArray = PackedByteArray()
var _arrows: Dictionary = {}
var _objects: Dictionary = {}
var _icon_species: int = -1
var _icon: PackedByteArray = PackedByteArray()
var _tiles: Dictionary = {}


static func from_data(data: GameData) -> Gen2TradeAnimationPage:
	if data == null or not data.has_trade_anim():
		return null
	var page := Gen2TradeAnimationPage.new()
	page._font = Gen2Font.from_data(data)
	if page._font == null:
		return null
	page._data = data
	page._sheet = data.tile_indices("trade_anim_game_boy_cable")
	page._arrows = {
		RomLayout.TRADE_ANIM_RIGHT_ARROW_CODE: data.tile_indices("trade_anim_arrow_right"),
		RomLayout.TRADE_ANIM_LEFT_ARROW_CODE: data.tile_indices("trade_anim_arrow_left"),
	}
	for name: String in ["ball", "poof", "cable", "bubble"]:
		page._objects[name] = data.tile_indices("trade_anim_%s" % name)
	return page


func draw(movie: Gen2TradeAnimation) -> Image:
	var pixels: PackedInt32Array = Gen2PicImage.canvas(WIDTH, HEIGHT)
	if movie == null:
		return Gen2PicImage.canvas_image(pixels, WIDTH, HEIGHT)
	_tiles.clear()
	var behind: PackedByteArray = PackedByteArray()
	behind.resize(WIDTH * HEIGHT)
	_draw_background(pixels, movie, behind)
	_draw_window(pixels, movie, behind)
	var taken := PackedByteArray()
	taken.resize(WIDTH * HEIGHT)
	for entry: Dictionary in shadow_oam(movie):
		_draw_sprite(pixels, movie, entry, behind, taken)
	return Gen2PicImage.canvas_image(pixels, WIDTH, HEIGHT)


## Every live struct expanded into shadow OAM, in struct order, so a trace of it
## compares to a cartridge's buffer line for line.
func shadow_oam(movie: Gen2TradeAnimation) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if movie == null:
		return out
	for sprite: Dictionary in movie.sprites():
		var index: int = int(sprite["set"])
		if index < 0 or index >= OAM_SETS.size():
			continue
		var ordering: Dictionary = OAM_SETS[index]
		var at: Vector2i = sprite["at"]
		var flip_x: bool = bool(sprite["flip_x"])
		for part: Array in ordering["parts"]:
			if out.size() >= SHADOW_OAM_SPRITES:
				return out
			var dx: int = int(part[1])
			var attrs: int = int(part[3])
			# `AddOrSubtractX`: a flipped frameset turns a part's own offset into
			# -8 - offset before it is added.
			if flip_x:
				dx = -TILE - dx
			out.append({
				"y": (at.y + int(part[0])) & 0xFF,
				"x": (at.x + dx) & 0xFF,
				"tile": (int(sprite["vtile"]) + int(ordering["vtile"]) + int(part[2])) & 0xFF,
				"palette": attrs & ATTR_PALETTE,
				"flip_x": bool(attrs & ATTR_XFLIP) != flip_x,
				"flip_y": bool(attrs & ATTR_YFLIP),
				"priority": bool(attrs & ATTR_PRIORITY),
			})
	return out


## `vBGMap0` through `hSCX`, a byte, so the sampling wraps. [param behind] is what
## an `OAM_PRIO` sprite is drawn against.
func _draw_background(
	pixels: PackedInt32Array, movie: Gen2TradeAnimation, behind: PackedByteArray
) -> void:
	var table: PackedInt32Array = _background_lookup(movie)
	var map: PackedByteArray = movie.bg_map()
	var scx: int = movie.scroll_x()
	for y: int in HEIGHT:
		@warning_ignore("integer_division")
		var row: int = (y / TILE) % MAP_ROWS
		var in_tile_y: int = (y % TILE) * TILE
		var line: int = y * WIDTH
		var x: int = 0
		while x < WIDTH:
			var map_x: int = (x + scx) & 0xFF
			var in_tile_x: int = map_x % TILE
			var run: int = mini(TILE - in_tile_x, WIDTH - x)
			@warning_ignore("integer_division")
			var column: int = (map_x / TILE) % MAP_COLUMNS
			var tile: PackedByteArray = _code_tile(
				movie, int(map[row * MAP_COLUMNS + column])
			)
			for step: int in run:
				var pixel: int = tile[in_tile_y + in_tile_x + step]
				behind[line + x + step] = pixel
				pixels[line + x + step] = table[pixel]
			x += run


func _draw_window(
	pixels: PackedInt32Array, movie: Gen2TradeAnimation, behind: PackedByteArray
) -> void:
	var at: Vector2i = movie.window()
	var left: int = at.x - 7
	if at.y >= HEIGHT or left >= WIDTH:
		return
	var table: PackedInt32Array = _background_lookup(movie)
	var map: PackedByteArray = movie.window_map()
	for y: int in range(maxi(at.y, 0), HEIGHT):
		var within_y: int = y - at.y
		@warning_ignore("integer_division")
		var row: int = within_y / TILE
		if row >= MAP_ROWS:
			break
		var in_tile_y: int = (within_y % TILE) * TILE
		for x: int in range(maxi(left, 0), WIDTH):
			var within_x: int = x - left
			@warning_ignore("integer_division")
			var column: int = within_x / TILE
			if column >= MAP_COLUMNS:
				break
			var tile: PackedByteArray = _code_tile(
				movie, int(map[row * MAP_COLUMNS + column])
			)
			var pixel: int = tile[in_tile_y + within_x % TILE]
			behind[y * WIDTH + x] = pixel
			pixels[y * WIDTH + x] = table[pixel]


func _background_lookup(movie: Gen2TradeAnimation) -> PackedInt32Array:
	var colors: PackedColorArray = _data.trade_anim_palette("tube") \
		if movie.tube_palette() else movie.frontpic_palette()
	if colors.size() < Gen2Palette.COLORS_PER_PIC:
		colors = Gen2Palette.pic_palette(PackedColorArray([Color.WHITE, Color.BLACK]))
	return Gen2PicImage.lookup(_dmg_ordered(colors, movie.background_palette_index()))


static func _dmg_ordered(colors: PackedColorArray, order: int) -> PackedColorArray:
	var out := PackedColorArray()
	for index: int in colors.size():
		out.append(colors[(order >> (index * 2)) & 0x3])
	return out


func _code_tile(movie: Gen2TradeAnimation, code: int) -> PackedByteArray:
	if _tiles.has(code):
		return _tiles[code]
	var tile: PackedByteArray = _build_code_tile(movie, code)
	_tiles[code] = tile
	return tile


func _build_code_tile(movie: Gen2TradeAnimation, code: int) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(TILE * TILE)
	var first: int = RomLayout.TRADE_ANIM_SHEET_FIRST_TILE
	if code < first:
		_copy_frontpic_tile(out, movie, code)
		return out
	if code < first + RomLayout.TRADE_ANIM_SHEET_TILES:
		_copy_strip_tile(out, _sheet, code - first)
		return out
	if _arrows.has(code):
		_copy_strip_tile(out, _arrows[code], 0)
		return out
	## `Textbox`'s six border codes come off `Frames`, not the font's own run.
	if code >= RomLayout.FRAME_FIRST_CODE \
		and code < RomLayout.FRAME_FIRST_CODE + RomLayout.FRAME_TILES:
		_font.draw_frame_code(frame_style, code, out, TILE, 0, 0)
		return out
	_font.draw_code(code, out, TILE, 0, 0, Gen2Text.FONT_BATTLE_EXTRA)
	return out


static func _copy_strip_tile(out: PackedByteArray, strip: PackedByteArray, tile: int) -> void:
	if strip.is_empty():
		return
	@warning_ignore("integer_division")
	var width: int = strip.size() / TILE
	if tile < 0 or (tile + 1) * TILE > width:
		return
	for row: int in TILE:
		for column: int in TILE:
			out[row * TILE + column] = strip[row * width + tile * TILE + column]


static func _copy_frontpic_tile(
	out: PackedByteArray, movie: Gen2TradeAnimation, code: int
) -> void:
	var pic: PackedByteArray = movie.frontpic_pixels()
	var box: PackedByteArray = movie.frontpic_box()
	var side: int = PIC_TILES * TILE
	if pic.size() < side * side or code >= box.size():
		return
	@warning_ignore("integer_division")
	var stride: int = pic.size() / side
	var tile: int = int(box[code])
	@warning_ignore("integer_division")
	var at_x: int = (tile / PIC_TILES) * TILE
	var at_y: int = (tile % PIC_TILES) * TILE
	if at_x + TILE > stride:
		return
	for row: int in TILE:
		for column: int in TILE:
			out[row * TILE + column] = pic[(at_y + row) * stride + at_x + column]


func _draw_sprite(
	pixels: PackedInt32Array, movie: Gen2TradeAnimation, entry: Dictionary,
	behind: PackedByteArray, taken: PackedByteArray
) -> void:
	var located: Dictionary = _object_tile(movie, int(entry["tile"]))
	if located.is_empty():
		return
	var colors: PackedColorArray = _object_palette(movie, int(entry["palette"]))
	if colors.size() < Gen2Palette.COLORS_PER_PIC:
		return
	var table: PackedInt32Array = Gen2PicImage.lookup(colors)
	var at := Vector2i(int(entry["x"]) - OAM_ORIGIN.x, int(entry["y"]) - OAM_ORIGIN.y)
	var priority: bool = bool(entry["priority"])
	for row: int in TILE:
		var y: int = at.y + row
		if y < 0 or y >= HEIGHT:
			continue
		for column: int in TILE:
			var x: int = at.x + column
			if x < 0 or x >= WIDTH:
				continue
			var pixel: int = _strip_pixel(
				located["strip"], int(located["tile"]), column, row,
				bool(entry["flip_x"]), bool(entry["flip_y"])
			)
			if pixel == Gen2PicImage.TRANSPARENT_INDEX:
				continue
			var offset: int = y * WIDTH + x
			if taken[offset] != 0:
				continue
			taken[offset] = 1
			if priority and behind[offset] != Gen2PicImage.TRANSPARENT_INDEX:
				continue
			pixels[offset] = table[pixel]


func _object_palette(movie: Gen2TradeAnimation, palette: int) -> PackedColorArray:
	if palette == 7:
		return _data.trade_anim_palette("tube")
	return _dmg_ordered(
		_data.party_menu_icon_palette(0), movie.object_palette_index()
	)


func _object_tile(movie: Gen2TradeAnimation, tile: int) -> Dictionary:
	var bubble: bool = movie.object_sheet() == &"bubble"
	for row: Array in (BUBBLE_SHEETS if bubble else BALL_SHEETS):
		var first: int = OBJECT_FIRST_TILE + int(row[1])
		if tile < first or tile >= first + int(row[2]):
			continue
		if String(row[0]) == "icon":
			return {"strip": _icon_strip(movie), "tile": tile - first}
		return {"strip": _objects[String(row[0])], "tile": tile - first}
	return {}


func _icon_strip(movie: Gen2TradeAnimation) -> PackedByteArray:
	var species: int = movie.icon_species()
	if species != _icon_species:
		_icon_species = species
		_icon = _data.species_icon_indices(species, species == Gen2TradeAnimation.EGG)
	return _icon


static func _strip_pixel(
	strip: PackedByteArray, tile: int, x: int, y: int, flip_x: bool, flip_y: bool
) -> int:
	if strip.is_empty():
		return 0
	@warning_ignore("integer_division")
	var width: int = strip.size() / TILE
	var column: int = tile * TILE + ((TILE - 1 - x) if flip_x else x)
	var row: int = (TILE - 1 - y) if flip_y else y
	if column < 0 or column >= width:
		return 0
	return strip[row * width + column]
