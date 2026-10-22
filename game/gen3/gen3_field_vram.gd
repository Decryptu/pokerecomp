class_name Gen3FieldVram
extends RefCounted

## The field's background tiles and palettes: `CopyMapTilesetsToVram` and `LoadMapTilesetPalettes` for a map's
## tileset pair, the copies `UpdateTilesetAnimations` queues each frame, and the three background layers
## `DrawMetatile` fills, composed into pixels with the object sprites between them.

const TILE_COUNT: int = 1024
const PALETTE_COUNT: int = 16
## `DrawMetatile`'s BG3 word under a normal-layer metatile: tile $14, palette 3.
const NORMAL_UNDERLAY: int = 0x3014
## `METATILE_LAYER_TYPE_NORMAL`, `_COVERED` and `_SPLIT`; any other value writes no layer at all.
const LAYER_TYPES: int = 3

var tiles := PackedByteArray()
var palettes := PackedByteArray()
var _frames: Array = []
var _animation: Dictionary = {}


static func load(primary: Dictionary, secondary: Dictionary) -> Gen3FieldVram:
	var vram := Gen3FieldVram.new()
	vram.tiles.resize(TILE_COUNT * GbaTiles.TILE_BYTES)
	vram.palettes.resize(PALETTE_COUNT * 32)
	for tileset: Dictionary in [primary, secondary]:
		_copy(vram.tiles, int(tileset["tile_offset"]) * GbaTiles.TILE_BYTES, tileset["tiles"]["bytes"])
		_copy(vram.palettes, int(tileset["palette_offset"]) * 32, tileset["palettes"]["bytes"])
		vram._frames.append(tileset["animation"].get("frames", {}))
	# LoadTilesetPalette writes RGB_BLACK over the primary's first colour, the backdrop.
	vram.palettes.encode_u16(0, 0)
	vram._animation = Gen3TilesetAnims.start(primary["animation"], secondary["animation"])
	return vram


## One `UpdateTilesetAnimations` frame's copies.
func step() -> void:
	for copy: Dictionary in Gen3TilesetAnims.step(_animation):
		var key: String = str(copy["frame"])
		var frames: Dictionary = _frames[0] if _frames[0].has(key) else _frames[1]
		var bytes: PackedByteArray = frames[key]["bytes"].slice(0, int(copy["bytes"]))
		if copy.has("palette"):
			_copy(palettes, int(copy["palette"]) * 32, bytes)
		else:
			_copy(tiles, int(copy["tile"]) * GbaTiles.TILE_BYTES, bytes)


func _color(index: int) -> Color:
	return PokePalette.from_packed(palettes.decode_u16(index * 2))


## Every cell of [param cells] (backup-map coordinates) as pixels, 16 per cell.
func draw(grid: Gen3MapGrid, cells: Rect2i) -> Image:
	return draw_screen(grid, cells.position * 16, cells.size * 16)


## [param size] pixels from backup pixel [param origin]: BG3, BG2 and BG1 (priorities 3 to 1) and the
## [Gen3ObjectSprites] [param oam]. The first entry with a pixel owns it, over each layer at its priority or
## below.
func draw_screen(grid: Gen3MapGrid, origin: Vector2i, size: Vector2i, oam: Array = [],
		obj_palettes := PackedByteArray()) -> Image:
	var layers: Array[Image] = []
	for layer: int in 3:
		layers.append(Image.create(size.x, size.y, false, Image.FORMAT_RGBA8))
	var first := Vector2i(floori(origin.x / 16.0), floori(origin.y / 16.0))
	var last := Vector2i(floori((origin.x + size.x - 1) / 16.0), floori((origin.y + size.y - 1) / 16.0))
	for y: int in range(first.y, last.y + 1):
		for x: int in range(first.x, last.x + 1):
			var layer_type: int = grid.layer_type_at(x, y)
			if layer_type < LAYER_TYPES:
				_draw_metatile(layers, Vector2i(x, y) * 16 - origin, grid.metatile(grid.metatile_id_at(x, y)), layer_type)
	var sprites: Array[Image] = _draw_oam(oam, size, obj_palettes)
	var image: Image = Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	image.fill(_color(0))
	var whole := Rect2i(Vector2i.ZERO, size)
	for priority: int in [3, 2, 1, 0]:
		if priority > 0:
			image.blend_rect(layers[3 - priority], whole, Vector2i.ZERO)
		image.blend_rect(sprites[priority], whole, Vector2i.ZERO)
	return image


## `DrawMetatile`'s BG3, BG2 and BG1 words into [param layers] in that order. The covered and split types put
## a zero word, which is tile 0 rather than nothing, on the layer they leave empty.
func _draw_metatile(layers: Array[Image], origin: Vector2i, metatile: Dictionary, layer_type: int) -> void:
	if metatile.is_empty():
		return
	for slot: int in 4:
		var at: Vector2i = origin + Vector2i(slot % 2, slot / 2) * 8
		var bottom: int = entry(metatile["tiles"][slot])
		var top: int = entry(metatile["tiles"][slot + 4])
		var words: Array = [[NORMAL_UNDERLAY, bottom, top], [bottom, top, 0], [bottom, 0, top]][layer_type]
		for layer: int in 3:
			_draw_tile(layers[layer], at, words[layer])


## A metatile slot as the tilemap word it is on the cartridge.
static func entry(tile: Dictionary) -> int:
	return int(tile["tile"]) | (0x400 if tile["flip_x"] else 0) | (0x800 if tile["flip_y"] else 0) \
		| (int(tile["palette"]) << 12)


## One tilemap word's 8x8 tile; colour 0 is transparent.
func _draw_tile(image: Image, origin: Vector2i, word: int) -> void:
	var bounds := Rect2i(Vector2i.ZERO, image.get_size())
	if not bounds.intersects(Rect2i(origin, Vector2i(8, 8))):
		return
	var at: int = (word & 0x3FF) * GbaTiles.TILE_BYTES
	var palette: int = (word >> 12) * 16
	for y: int in 8:
		for x: int in 8:
			var from_x: int = 7 - x if word & 0x400 else x
			var from_y: int = 7 - y if word & 0x800 else y
			var index: int = (tiles[at + from_y * 4 + from_x / 2] >> ((from_x % 2) * 4)) & 15
			if index != 0 and bounds.has_point(origin + Vector2i(x, y)):
				image.set_pixel(origin.x + x, origin.y + y, _color(palette + index))


## The OBJ layer by priority, drawn last entry first; OAM coordinates wrap at 512 across and 256 down.
static func _draw_oam(oam: Array, size: Vector2i, obj_palettes: PackedByteArray) -> Array[Image]:
	var out: Array[Image] = []
	for priority: int in 4:
		out.append(Image.create(size.x, size.y, false, Image.FORMAT_RGBA8))
	var owner := PackedInt32Array()
	owner.resize(size.x * size.y)
	owner.fill(-1)
	for index: int in range(oam.size() - 1, -1, -1):
		var sprite: Dictionary = oam[index]
		var dims: Vector2i = sprite["size"]
		var data: PackedByteArray = sprite["tiles"]
		for y: int in dims.y:
			var screen_y: int = (int(sprite["y"]) + y) & 0xFF
			for x: int in dims.x:
				var screen_x: int = (int(sprite["x"]) + x) & 0x1FF
				if screen_x >= size.x or screen_y >= size.y:
					continue
				var from_x: int = dims.x - 1 - x if sprite["flip"].x else x
				var from_y: int = dims.y - 1 - y if sprite["flip"].y else y
				var at: int = ((from_y / 8) * (dims.x / 8) + from_x / 8) * GbaTiles.TILE_BYTES \
					+ (from_y % 8) * 4 + (from_x % 8) / 2
				var color: int = (data[at] >> ((from_x % 2) * 4)) & 15 if at < data.size() else 0
				if color == 0:
					continue
				var pixel: int = screen_y * size.x + screen_x
				if owner[pixel] >= 0:
					out[owner[pixel]].set_pixel(screen_x, screen_y, Color(0, 0, 0, 0))
				owner[pixel] = int(sprite["priority"])
				var word: int = obj_palettes.decode_u16((int(sprite["palette"]) * 16 + color) * 2)
				out[owner[pixel]].set_pixel(screen_x, screen_y, PokePalette.from_packed(word))
	return out


static func _copy(target: PackedByteArray, at: int, bytes: PackedByteArray) -> void:
	for index: int in mini(bytes.size(), target.size() - at):
		target[at + index] = bytes[index]
