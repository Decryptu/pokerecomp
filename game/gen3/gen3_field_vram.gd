class_name Gen3FieldVram
extends RefCounted

## The field's background tiles and palettes: `CopyMapTilesetsToVram` and `LoadMapTilesetPalettes` for a map's tileset
## pair into VRAM and [member palette], the copies `UpdateTilesetAnimations` queues each frame, and the three background
## layers `DrawMetatile` fills, composed into pixels from the faded colours with the object sprites between them.

const TILE_COUNT: int = 1024
const PALETTE_COUNT: int = 16
## `DrawMetatile`'s BG3 word under a normal-layer metatile: tile $14, palette 3.
const NORMAL_UNDERLAY: int = 0x3014
## `METATILE_LAYER_TYPE_NORMAL`, `_COVERED` and `_SPLIT`; any other value writes no layer at all.
const LAYER_TYPES: int = 3
const TILE_RECT := Rect2i(0, 0, 8, 8)
const CELL_RECT := Rect2i(0, 0, 16, 16)
const BLANK_TILE: PackedByteArray = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
const BG0_CACHE_LIMIT: int = 2048
const TEXEL_CACHE_LIMIT: int = 2048
const KEEP: int = -1

static var _channels := PackedInt32Array()
static var _levels := PackedByteArray()
static var _texels: Dictionary = {}

var tiles := PackedByteArray()
var palette: Gen3Palette
var door_cells: Dictionary = {} # `DrawDoorMetatileAt`'s bottom-layer words by backup cell; [Gen3FieldDoor] owns them.
var _frames: Array = []
var _animation: Dictionary = {}
var _layers: Array[Image] = []
var _drawn_colors := PackedByteArray()
var _drawn_tiles := PackedByteArray()
var _tile_images: Dictionary = {}
var _cell_images: Dictionary = {}
var _bg0_images: Dictionary = {}


## [param palettes] is the field's palette RAM, which the object sprites and the weather share.
static func load(primary: Dictionary, secondary: Dictionary, palettes: Gen3Palette = null) -> Gen3FieldVram:
	var vram := Gen3FieldVram.new()
	vram.palette = palettes if palettes != null else Gen3Palette.new()
	vram.tiles.resize(TILE_COUNT * GbaTiles.TILE_BYTES)
	for tileset: Dictionary in [primary, secondary]:
		_copy(vram.tiles, int(tileset["tile_offset"]) * GbaTiles.TILE_BYTES, tileset["tiles"]["bytes"])
		var colors: PackedByteArray = tileset["palettes"]["bytes"]
		vram.palette.load(colors.slice(0, (PALETTE_COUNT - int(tileset["palette_offset"])) * 32),
			int(tileset["palette_offset"]) * 16)
		vram._frames.append(tileset["animation"].get("frames", {}))
	# LoadTilesetPalette writes RGB_BLACK over the primary's first colour, the backdrop.
	vram.palette.load(PackedByteArray([0, 0]), 0)
	vram._animation = Gen3TilesetAnims.start(primary["animation"], secondary["animation"])
	return vram


## One `UpdateTilesetAnimations` frame's copies; Battle Dome's palette lands unfaded under the running fade.
func step() -> void:
	for copy: Dictionary in Gen3TilesetAnims.step(_animation):
		var key: String = str(copy["frame"])
		var frames: Dictionary = _frames[0] if _frames[0].has(key) else _frames[1]
		var bytes: PackedByteArray = frames[key]["bytes"].slice(0, int(copy["bytes"]))
		if copy.has("palette"):
			var at: int = int(copy["palette"]) * 16
			_copy(palette.unfaded, at * 2, bytes)
			palette.blend(at, 16, palette.fade_y, palette.fade_color & 0x7FFF)
		else:
			_copy(tiles, int(copy["tile"]) * GbaTiles.TILE_BYTES, bytes)


func write_tiles(tile: int, bytes: PackedByteArray) -> void:
	_copy(tiles, tile * GbaTiles.TILE_BYTES, bytes)


## Every cell of [param cells] (backup-map coordinates) as pixels, 16 per cell.
func draw(grid: Gen3MapGrid, cells: Rect2i) -> Image:
	return draw_screen(grid, cells.position * 16, cells.size * 16)


## [param size] pixels from backup pixel [param origin]: BG3 to BG1 and [param oam], first pixel owning it at
## its priority or below. The field's BLDCNT names no first target, so only semi-transparent sprites blend, by
## [param bldalpha], with the BG under them. [param overlay] is [method Gen3FieldMoveMon.screen]'s BG0 and windows.
func draw_screen(grid: Gen3MapGrid, origin: Vector2i, size: Vector2i, oam: Array = [], bldalpha: int = 0,
		overlay: Dictionary = {}) -> Image:
	_sync_caches()
	var layers: Array[Image] = _cleared_layers(size)
	var first := Vector2i(floori(origin.x / 16.0), floori(origin.y / 16.0))
	var last := Vector2i(floori((origin.x + size.x - 1) / 16.0), floori((origin.y + size.y - 1) / 16.0))
	for y: int in range(first.y, last.y + 1):
		for x: int in range(first.x, last.x + 1):
			var cell := Vector2i(x, y)
			var layer_type: int = grid.layer_type_at(x, y)
			if door_cells.has(cell):
				_draw_door(layers[0], cell * 16 - origin, door_cells[cell])
			elif layer_type < LAYER_TYPES:
				_draw_metatile(layers, cell * 16 - origin, grid, grid.metatile_id_at(x, y), layer_type)
	if overlay.has("bg0_map"):
		_draw_bg0(layers[3], overlay)
	var sprites: Dictionary = _draw_oam(oam, size, palette)
	_mask_windows(layers, sprites, size, overlay)
	var screen: Image = Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	screen.fill(PokePalette.from_packed(palette.faded_color(0)))
	var whole := Rect2i(Vector2i.ZERO, size)
	for layer: Image in layers:
		screen.blit_rect_mask(layer, layer, whole, Vector2i.ZERO)
	var pixels: PackedInt32Array = sprites["pixels"]
	if pixels.is_empty():
		return screen
	var bytes: PackedByteArray = screen.get_data()
	var by_priority: Array[PackedByteArray] = [layers[3].get_data(), layers[2].get_data(), layers[1].get_data(),
		layers[0].get_data()]
	var weights := Vector2i(mini(bldalpha & 0x1F, 16), mini((bldalpha >> 8) & 0x1F, 16))
	for pixel: int in pixels:
		var color: int = _compose(by_priority, sprites, pixel, weights)
		if color != KEEP:
			bytes.encode_u32(pixel * 4, color)
	return Image.create_from_data(size.x, size.y, false, Image.FORMAT_RGBA8, bytes)


static func _compose(layers: Array[PackedByteArray], sprites: Dictionary, pixel: int, weights: Vector2i) -> int: # One sprite pixel as RGBA bytes, or [constant KEEP] behind a BG; [param layers] is by BG priority, and a semi-transparent sprite blends with the first BG it covers.
	var owner: int = sprites["priority"][pixel]
	if owner < 0:
		return KEEP
	var alpha_at: int = pixel * 4 + 3
	for priority: int in owner:
		if layers[priority][alpha_at] != 0:
			return KEEP
	var top: int = sprites["color"][pixel]
	if sprites["blend"][pixel]:
		for priority: int in range(owner, 4):
			var layer: PackedByteArray = layers[priority]
			if layer[alpha_at] != 0:
				var under: int = _five(layer[alpha_at - 3]) | _five(layer[alpha_at - 2]) << 5 | _five(layer[alpha_at - 1]) << 10
				return rgba(_alpha(top, under, weights))
	return rgba(top)


static func rgba(color: int) -> int: # A BGR555 colour as the little-endian bytes `PokePalette.from_packed` stores.
	if _channels.is_empty():
		for level: int in 32:
			_channels.append(PokePalette.from_packed(level).r8)
			_levels.resize(256)
			_levels[_channels[level]] = level
	return _channels[color & 31] | _channels[(color >> 5) & 31] << 8 | _channels[(color >> 10) & 31] << 16 | 0xFF000000


static func _five(byte: int) -> int:
	return _levels[byte]


func _cleared_layers(size: Vector2i) -> Array[Image]:
	if _layers.is_empty() or _layers[0].get_size() != size:
		_layers.clear()
		for layer: int in 4:
			_layers.append(Image.create(size.x, size.y, false, Image.FORMAT_RGBA8))
	else:
		for layer: Image in _layers:
			layer.fill(Color(0, 0, 0, 0))
	return _layers


func _sync_caches() -> void: # Tile animations, doors and fades write VRAM and palette RAM without passing here, so a frame compares to find stale pictures.
	var colors: PackedByteArray = palette.faded.slice(0, Gen3Palette.OBJ_OFFSET * 2)
	if colors != _drawn_colors or tiles != _drawn_tiles:
		_drawn_colors = colors
		_drawn_tiles = tiles.duplicate()
		_tile_images.clear()
		_cell_images.clear()
		_bg0_images.clear()
	if _bg0_images.size() > BG0_CACHE_LIMIT:
		_bg0_images.clear()


func _draw_bg0(layer: Image, overlay: Dictionary) -> void:
	var words: PackedInt32Array = overlay["bg0_map"]
	var data: PackedByteArray = overlay["bg0_tiles"]
	var scroll: Vector2i = overlay["bg0_scroll"]
	var size: Vector2i = layer.get_size()
	for index: int in words.size():
		var image: Image = _bg0_tile(words[index], data)
		if image == null:
			continue
		var at := Vector2i((index % 32 * 8 - scroll.x) & 0xFF, (index / 32 * 8 - scroll.y) & 0xFF)
		for offset: Vector2i in [Vector2i.ZERO, Vector2i(-256, 0), Vector2i(0, -256), Vector2i(-256, -256)]:
			var place: Vector2i = at + offset
			if place.x < size.x and place.y < size.y and place.x > -8 and place.y > -8:
				layer.blit_rect(image, TILE_RECT, place)


func _bg0_tile(word: int, data: PackedByteArray) -> Image: # Null when the word draws nothing; text prints new tile bytes every frame, so those key it.
	var at: int = (word & 0x3FF) * GbaTiles.TILE_BYTES
	var bytes: PackedByteArray = data.slice(at, at + GbaTiles.TILE_BYTES)
	if bytes.size() < GbaTiles.TILE_BYTES or bytes == BLANK_TILE:
		return null
	var key: Array = [word & 0xFC00, bytes]
	if not _bg0_images.has(key):
		_bg0_images[key] = _decode_tile(bytes, 0, word)
	return _bg0_images[key]


func _decode_tile(bytes: PackedByteArray, at: int, word: int) -> Image: # 4bpp tile [param at] under [param word]'s flips and palette bank, colour 0 clear.
	var bank: int = (word >> 12) * 16
	var out := PackedByteArray()
	out.resize(64 * 4)
	for y: int in 8:
		for x: int in 8:
			var from_x: int = 7 - x if word & 0x400 else x
			var from_y: int = 7 - y if word & 0x800 else y
			var index: int = (bytes[at + from_y * 4 + from_x / 2] >> ((from_x % 2) * 4)) & 15
			if index != 0:
				out.encode_u32((y * 8 + x) * 4, rgba(palette.faded_color(bank + index)))
	return Image.create_from_data(8, 8, false, Image.FORMAT_RGBA8, out)


## WIN0 over WIN1 over WINOUT: a pixel keeps only the layers its region's WININ or WINOUT bits enable.
static func _mask_windows(layers: Array[Image], sprites: Dictionary, size: Vector2i, overlay: Dictionary) -> void:
	if not overlay.has("winin"):
		return
	var spans: Array[Vector4i] = []
	var edges: Array[int] = [0, size.x]
	for window: String in ["win0", "win1"]:
		var across: Vector2i = _window_span(int(overlay[window + "h"]), 240)
		var down: Vector2i = _window_span(int(overlay[window + "v"]), 160)
		spans.append(Vector4i(across.x, across.y, down.x, down.y))
		edges.append_array([clampi(across.x, 0, size.x), clampi(across.y, 0, size.x)])
	edges.sort()
	for y: int in size.y:
		for edge: int in edges.size() - 1:
			var left: int = edges[edge]
			if left == edges[edge + 1]:
				continue
			var bits: int = _window_bits(spans, overlay, left, y)
			for layer: int in 4:
				if not bits & (1 << (3 - layer)):
					layers[layer].fill_rect(Rect2i(left, y, edges[edge + 1] - left, 1), Color(0, 0, 0, 0))
	var priority: PackedInt32Array = sprites["priority"]
	for pixel: int in sprites["pixels"]:
		if not _window_bits(spans, overlay, pixel % size.x, pixel / size.x) & 0x10:
			priority[pixel] = -1


static func _window_bits(spans: Array[Vector4i], overlay: Dictionary, x: int, y: int) -> int:
	if _in_window(spans[0], x, y):
		return int(overlay["winin"]) & 0x1F
	if _in_window(spans[1], x, y):
		return (int(overlay["winin"]) >> 8) & 0x1F
	return int(overlay["winout"]) & 0x1F


## WINnH/WINnV as start and end, clamped as mGBA does: an end to the screen's edge, a start past both to 0.
static func _window_span(register: int, limit: int) -> Vector2i:
	var span := Vector2i((register >> 8) & 0xFF, register & 0xFF)
	if span.x > limit and span.x > span.y:
		span.x = 0
	if span.y > limit:
		span = Vector2i(mini(span.x, limit), limit)
	return span


static func _in_window(span: Vector4i, x: int, y: int) -> bool:
	return _in_span(x, span.x, span.y) and _in_span(y, span.z, span.w)


static func _in_span(at: int, start: int, end: int) -> bool:
	return at >= start and at < end if start <= end else at >= start or at < end


## The GBA's alpha blend: each channel's weighted sum in sixteenths, held at 31.
static func _alpha(first: int, second: int, weights: Vector2i) -> int:
	var out: int = 0
	for shift: int in [0, 5, 10]:
		var channel: int = (((first >> shift) & 31) * weights.x + ((second >> shift) & 31) * weights.y) >> 4
		out |= mini(channel, 31) << shift
	return out


## `DrawMetatile`'s BG3, BG2 and BG1 words into [param layers] in that order. The covered and split types put
## a zero word, which is tile 0 rather than nothing, on the layer they leave empty.
func _draw_metatile(layers: Array[Image], at: Vector2i, grid: Gen3MapGrid, id: int, layer_type: int) -> void:
	var key: int = id << 2 | layer_type
	if not _cell_images.has(key):
		_cell_images[key] = _cell_layers(grid.metatile(id), layer_type)
	var cell: Array = _cell_images[key]
	for layer: int in cell.size():
		if cell[layer] != null:
			layers[layer].blit_rect(cell[layer], CELL_RECT, at)


func _cell_layers(metatile: Dictionary, layer_type: int) -> Array:
	if metatile.is_empty():
		return []
	var words: Array = []
	for slot: int in 4:
		var bottom: int = entry(metatile["tiles"][slot])
		var top: int = entry(metatile["tiles"][slot + 4])
		words.append([[NORMAL_UNDERLAY, bottom, top], [bottom, top, 0], [bottom, 0, top]][layer_type])
	var out: Array = []
	for layer: int in 3:
		var image: Image = Image.create(16, 16, false, Image.FORMAT_RGBA8)
		for slot: int in 4:
			image.blit_rect(_tile_image(words[slot][layer]), TILE_RECT, Vector2i(slot % 2, slot / 2) * 8)
		out.append(null if image.is_invisible() else image)
	return out


func _draw_door(layer: Image, at: Vector2i, words: PackedInt32Array) -> void: # `METATILE_LAYER_TYPE_COVERED`, whose top layer is tile 0.
	for slot: int in 4:
		layer.blit_rect(_tile_image(words[slot]), TILE_RECT, at + Vector2i(slot % 2, slot / 2) * 8)


## A metatile slot as the tilemap word it is on the cartridge.
static func entry(tile: Dictionary) -> int:
	return int(tile["tile"]) | (0x400 if tile["flip_x"] else 0) | (0x800 if tile["flip_y"] else 0) \
		| (int(tile["palette"]) << 12)


func _tile_image(word: int) -> Image:
	if not _tile_images.has(word):
		_tile_images[word] = _decode_tile(tiles, (word & 0x3FF) * GbaTiles.TILE_BYTES, word)
	return _tile_images[word]


static func _draw_oam(oam: Array, size: Vector2i, colors: Gen3Palette) -> Dictionary: # The OBJ layer's colour, priority (-1 none) and semi-transparency per pixel, and the pixels it touches; the first entry owns a pixel, OAM wrapping 512x256.
	var color := PackedInt32Array()
	color.resize(size.x * size.y)
	var owner := PackedInt32Array()
	owner.resize(size.x * size.y)
	owner.fill(-1)
	var blend := PackedByteArray()
	blend.resize(size.x * size.y)
	var pixels := PackedInt32Array()
	pixels.resize(size.x * size.y)
	var touched: int = 0
	var faded: PackedByteArray = colors.faded
	for sprite: Dictionary in oam:
		var left: int = sprite["x"]
		var top: int = sprite["y"]
		var bank: int = (Gen3Palette.OBJ_OFFSET + int(sprite["palette"]) * 16) * 2
		var priority: int = sprite["priority"]
		var blended: int = int(sprite.get("blend", false))
		for texel: int in _opaque_texels(sprite):
			var screen_x: int = (left + (texel & 0x3FF)) & 0x1FF
			var screen_y: int = (top + ((texel >> 10) & 0x3FF)) & 0xFF
			if screen_x >= size.x or screen_y >= size.y:
				continue
			var pixel: int = screen_y * size.x + screen_x
			if owner[pixel] >= 0:
				continue
			owner[pixel] = priority
			blend[pixel] = blended
			color[pixel] = faded.decode_u16(bank + (texel >> 20) * 2)
			pixels[touched] = pixel
			touched += 1
	pixels.resize(touched)
	return {"color": color, "priority": owner, "blend": blend, "pixels": pixels}


static func _opaque_texels(sprite: Dictionary) -> PackedInt32Array: # Non-zero texels as x, y << 10 and colour index << 20, kept per picture; a matrix sprite's angle changes each frame, so those skip the cache.
	var data: PackedByteArray = sprite["tiles"]
	var matrix: bool = sprite.has("matrix")
	var key: Array = []
	if not matrix:
		key = [data, sprite["size"], bool(sprite["flip"].x), bool(sprite["flip"].y), sprite.get("double_size", false)]
		var cached: Variant = _texels.get(key)
		if cached != null:
			return cached
	var dims: Vector2i = sprite["size"] * (2 if sprite.get("double_size", false) else 1)
	var out := PackedInt32Array()
	for y: int in dims.y:
		for x: int in dims.x:
			var index: int = _sprite_color(sprite, Vector2i(x, y), data)
			if index != 0:
				out.append(x | y << 10 | index << 20)
	if not matrix:
		if _texels.size() > TEXEL_CACHE_LIMIT:
			_texels.clear()
		_texels[key] = out
	return out


static func _sprite_color(sprite: Dictionary, pixel: Vector2i, data: PackedByteArray) -> int:
	var dims: Vector2i = sprite["size"]
	var from := Vector2i(dims.x - 1 - pixel.x if sprite["flip"].x else pixel.x,
		dims.y - 1 - pixel.y if sprite["flip"].y else pixel.y)
	if sprite.has("matrix"):
		var matrix: Vector4i = sprite["matrix"]
		var center: Vector2i = pixel - dims / (1 if sprite.get("double_size", false) else 2)
		from = Vector2i((matrix.x * center.x + matrix.y * center.y) >> 8,
			(matrix.z * center.x + matrix.w * center.y) >> 8) + dims / 2
	if not Rect2i(Vector2i.ZERO, dims).has_point(from):
		return 0
	var at: int = ((from.y / 8) * (dims.x / 8) + from.x / 8) * GbaTiles.TILE_BYTES \
		+ (from.y % 8) * 4 + (from.x % 8) / 2
	return (data[at] >> ((from.x % 2) * 4)) & 15 if at < data.size() else 0


static func _copy(target: PackedByteArray, at: int, bytes: PackedByteArray) -> void:
	for index: int in mini(bytes.size(), target.size() - at):
		target[at + index] = bytes[index]
