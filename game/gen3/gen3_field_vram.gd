class_name Gen3FieldVram
extends RefCounted

## The field's background tiles and palettes: `CopyMapTilesetsToVram` and `LoadMapTilesetPalettes` for a map's
## tileset pair into VRAM and [member palette], the copies `UpdateTilesetAnimations` queues each frame, and the
## three background layers `DrawMetatile` fills, composed into pixels from the faded colours with the object
## sprites between them.

const TILE_COUNT: int = 1024
const PALETTE_COUNT: int = 16
## `DrawMetatile`'s BG3 word under a normal-layer metatile: tile $14, palette 3.
const NORMAL_UNDERLAY: int = 0x3014
## `METATILE_LAYER_TYPE_NORMAL`, `_COVERED` and `_SPLIT`; any other value writes no layer at all.
const LAYER_TYPES: int = 3

var tiles := PackedByteArray()
var palette: Gen3Palette
var _frames: Array = []
var _animation: Dictionary = {}


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


## One `UpdateTilesetAnimations` frame's copies. Battle Dome's palette goes into the unfaded colours and is
## blended with the running fade (`BlendAnimPalette_BattleDome_FloorLights`).
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


## Every cell of [param cells] (backup-map coordinates) as pixels, 16 per cell.
func draw(grid: Gen3MapGrid, cells: Rect2i) -> Image:
	return draw_screen(grid, cells.position * 16, cells.size * 16)


## [param size] pixels from backup pixel [param origin]: BG3, BG2 and BG1 (priorities 3 to 1) and the
## [Gen3ObjectSprites] [param oam]. The first entry with a pixel owns it, over each layer at its priority or
## below. The field's BLDCNT (`gOverworldBackgroundLayerFlags[1..3]`, `BLDCNT_TGT2_OBJ`, alpha blend) names no
## first target, so only a semi-transparent sprite's pixel blends, by [param bldalpha], with the BG layer under
## it; over the backdrop it draws as it is.
func draw_screen(grid: Gen3MapGrid, origin: Vector2i, size: Vector2i, oam: Array = [], bldalpha: int = 0) -> Image:
	var layers: Array[PackedInt32Array] = []
	for layer: int in 3:
		var pixels := PackedInt32Array()
		pixels.resize(size.x * size.y)
		pixels.fill(-1)
		layers.append(pixels)
	var first := Vector2i(floori(origin.x / 16.0), floori(origin.y / 16.0))
	var last := Vector2i(floori((origin.x + size.x - 1) / 16.0), floori((origin.y + size.y - 1) / 16.0))
	for y: int in range(first.y, last.y + 1):
		for x: int in range(first.x, last.x + 1):
			var layer_type: int = grid.layer_type_at(x, y)
			if layer_type < LAYER_TYPES:
				_draw_metatile(layers, size, Vector2i(x, y) * 16 - origin,
					grid.metatile(grid.metatile_id_at(x, y)), layer_type)
	var sprites: Dictionary = _draw_oam(oam, size, palette)
	var weights := Vector2i(mini(bldalpha & 0x1F, 16), mini((bldalpha >> 8) & 0x1F, 16))
	var backdrop: int = palette.faded_color(0)
	var image: Image = Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	for pixel: int in size.x * size.y:
		var color: int = _compose(layers, sprites, pixel, backdrop, weights)
		image.set_pixel(pixel % size.x, pixel / size.x, PokePalette.from_packed(color))
	return image


## One pixel: the sprite over the BG layers at its priority or below, then the top two layers' blend.
static func _compose(layers: Array[PackedInt32Array], sprites: Dictionary, pixel: int, backdrop: int,
		weights: Vector2i) -> int:
	var obj_priority: int = sprites["priority"][pixel]
	var top: int = -1
	for priority: int in [0, 1, 2, 3]:
		if priority == obj_priority:
			top = sprites["color"][pixel]
			if not sprites["blend"][pixel]:
				return top
		if priority > 0 and layers[3 - priority][pixel] >= 0:
			if top < 0:
				return layers[3 - priority][pixel]
			return _alpha(top, layers[3 - priority][pixel], weights)
	return top if top >= 0 else backdrop


## The GBA's alpha blend: each channel's weighted sum in sixteenths, held at 31.
static func _alpha(first: int, second: int, weights: Vector2i) -> int:
	var out: int = 0
	for shift: int in [0, 5, 10]:
		var channel: int = (((first >> shift) & 31) * weights.x + ((second >> shift) & 31) * weights.y) >> 4
		out |= mini(channel, 31) << shift
	return out


## `DrawMetatile`'s BG3, BG2 and BG1 words into [param layers] in that order. The covered and split types put
## a zero word, which is tile 0 rather than nothing, on the layer they leave empty.
func _draw_metatile(layers: Array[PackedInt32Array], size: Vector2i, origin: Vector2i, metatile: Dictionary,
		layer_type: int) -> void:
	if metatile.is_empty():
		return
	for slot: int in 4:
		var at: Vector2i = origin + Vector2i(slot % 2, slot / 2) * 8
		var bottom: int = entry(metatile["tiles"][slot])
		var top: int = entry(metatile["tiles"][slot + 4])
		var words: Array = [[NORMAL_UNDERLAY, bottom, top], [bottom, top, 0], [bottom, 0, top]][layer_type]
		for layer: int in 3:
			_draw_tile(layers[layer], size, at, words[layer])


## A metatile slot as the tilemap word it is on the cartridge.
static func entry(tile: Dictionary) -> int:
	return int(tile["tile"]) | (0x400 if tile["flip_x"] else 0) | (0x800 if tile["flip_y"] else 0) \
		| (int(tile["palette"]) << 12)


## One tilemap word's 8x8 tile as faded colours; colour 0 is transparent.
func _draw_tile(layer: PackedInt32Array, size: Vector2i, origin: Vector2i, word: int) -> void:
	var bounds := Rect2i(Vector2i.ZERO, size)
	if not bounds.intersects(Rect2i(origin, Vector2i(8, 8))):
		return
	var at: int = (word & 0x3FF) * GbaTiles.TILE_BYTES
	var bank: int = (word >> 12) * 16
	for y: int in 8:
		for x: int in 8:
			var from_x: int = 7 - x if word & 0x400 else x
			var from_y: int = 7 - y if word & 0x800 else y
			var index: int = (tiles[at + from_y * 4 + from_x / 2] >> ((from_x % 2) * 4)) & 15
			if index != 0 and bounds.has_point(origin + Vector2i(x, y)):
				layer[(origin.y + y) * size.x + origin.x + x] = palette.faded_color(bank + index)


## The OBJ layer: each pixel's colour, priority (-1 for none) and semi-transparency, drawn last entry first so
## the first entry with a pixel owns it. OAM coordinates wrap at 512 across and 256 down.
static func _draw_oam(oam: Array, size: Vector2i, colors: Gen3Palette) -> Dictionary:
	var color := PackedInt32Array()
	color.resize(size.x * size.y)
	var owner := PackedInt32Array()
	owner.resize(size.x * size.y)
	owner.fill(-1)
	var blend := PackedByteArray()
	blend.resize(size.x * size.y)
	for index: int in range(oam.size() - 1, -1, -1):
		var sprite: Dictionary = oam[index]
		var dims: Vector2i = sprite["size"] * (2 if sprite.get("double_size", false) else 1)
		var data: PackedByteArray = sprite["tiles"]
		for y: int in dims.y:
			var screen_y: int = (int(sprite["y"]) + y) & 0xFF
			for x: int in dims.x:
				var screen_x: int = (int(sprite["x"]) + x) & 0x1FF
				if screen_x >= size.x or screen_y >= size.y:
					continue
				var index_color: int = _sprite_color(sprite, Vector2i(x, y), data)
				if index_color == 0:
					continue
				var pixel: int = screen_y * size.x + screen_x
				owner[pixel] = int(sprite["priority"])
				blend[pixel] = int(sprite.get("blend", false))
				color[pixel] = colors.faded_color(Gen3Palette.OBJ_OFFSET + int(sprite["palette"]) * 16 + index_color)
	return {"color": color, "priority": owner, "blend": blend}


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
