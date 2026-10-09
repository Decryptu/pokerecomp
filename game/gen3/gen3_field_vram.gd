class_name Gen3FieldVram
extends RefCounted

## The field's background tiles and palettes: `CopyMapTilesetsToVram` and
## `LoadMapTilesetPalettes` for a map's tileset pair, the copies
## `UpdateTilesetAnimations` queues each frame, and the three background layers
## `DrawMetatile` fills, composed into pixels.

const TILE_COUNT: int = 1024
const PALETTE_COUNT: int = 16
## `DrawMetatile`'s BG3 word under a normal-layer metatile: tile $14, palette 3.
const NORMAL_UNDERLAY: int = 0x3014
## `METATILE_LAYER_TYPE_NORMAL`, `_COVERED` and `_SPLIT`; any other value
## writes no layer at all.
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
	var image: Image = Image.create(cells.size.x * 16, cells.size.y * 16, false, Image.FORMAT_RGBA8)
	image.fill(_color(0))
	for y: int in cells.size.y:
		for x: int in cells.size.x:
			var cell := Vector2i(cells.position.x + x, cells.position.y + y)
			_draw_metatile(image, Vector2i(x, y) * 16, grid.metatile(grid.metatile_id_at(cell.x, cell.y)),
				grid.layer_type_at(cell.x, cell.y))
	return image


## `DrawMetatile`'s BG3, BG2 and BG1 words, bottom first. The covered and split
## types put a zero word, which is tile 0 rather than nothing, on the layer
## they leave empty.
func _draw_metatile(image: Image, origin: Vector2i, metatile: Dictionary, layer_type: int) -> void:
	if metatile.is_empty() or layer_type >= LAYER_TYPES:
		return
	for slot: int in 4:
		var at: Vector2i = origin + Vector2i(slot % 2, slot / 2) * 8
		var bottom: int = entry(metatile["tiles"][slot])
		var top: int = entry(metatile["tiles"][slot + 4])
		var words: Array = [[NORMAL_UNDERLAY, bottom, top], [bottom, top, 0], [bottom, 0, top]][layer_type]
		for word: int in words:
			_draw_tile(image, at, word)


## A metatile slot as the tilemap word it is on the cartridge.
static func entry(tile: Dictionary) -> int:
	return int(tile["tile"]) | (0x400 if tile["flip_x"] else 0) | (0x800 if tile["flip_y"] else 0) \
		| (int(tile["palette"]) << 12)


## One tilemap word's 8x8 tile; colour 0 is transparent.
func _draw_tile(image: Image, origin: Vector2i, word: int) -> void:
	var at: int = (word & 0x3FF) * GbaTiles.TILE_BYTES
	var palette: int = (word >> 12) * 16
	for y: int in 8:
		for x: int in 8:
			var from_x: int = 7 - x if word & 0x400 else x
			var from_y: int = 7 - y if word & 0x800 else y
			var index: int = (tiles[at + from_y * 4 + from_x / 2] >> ((from_x % 2) * 4)) & 15
			if index != 0:
				image.set_pixel(origin.x + x, origin.y + y, _color(palette + index))


static func _copy(target: PackedByteArray, at: int, bytes: PackedByteArray) -> void:
	for index: int in mini(bytes.size(), target.size() - at):
		target[at + index] = bytes[index]
