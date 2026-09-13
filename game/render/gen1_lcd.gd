class_name Gen1Lcd
extends RefCounted

## The Game Boy's picture state: 384 tiles of VRAM, the two BG maps, forty OAM
## slots, `rLCDC`, the scroll and window registers and the DMG palettes.
## [method render] draws a frame a scanline at a time, as shades; the page
## colours them through the Super Game Boy block each cell sits in.

const WIDTH: int = 160
const HEIGHT: int = 144
const MAP_SIDE: int = 32
const MAP_BYTES: int = MAP_SIDE * MAP_SIDE
const TILE: int = PokeTiles.TILE_WIDTH
const TILE_PIXELS: int = PokeTiles.TILE_PIXELS
## `vChars0`, `vChars1` and `vChars2`: $8000 to $97FF is 384 tiles.
const TILE_COUNT: int = 384
const BLOCK_TILES: int = 128
## `LCDC_BLOCK21`'s tile 0, which is `vChars2`.
const SIGNED_BASE: int = 2 * BLOCK_TILES
const OAM_SLOTS: int = 40
const OAM_BYTES: int = 4
const OAM_X_OFFSET: int = 8
const OAM_Y_OFFSET: int = 16
const SPRITES_PER_LINE: int = 10
const WINDOW_X_OFFSET: int = 7

## `rLCDC` bits, from `constants/hardware.inc`.
const LCDC_ON: int = 1 << 7
const LCDC_WIN_MAP: int = 1 << 6
const LCDC_WINDOW: int = 1 << 5
const LCDC_BLOCKS: int = 1 << 4
const LCDC_BG_MAP: int = 1 << 3
const LCDC_OBJS: int = 1 << 1
const LCDC_BG: int = 1 << 0
## `LCDC_DEFAULT`, which `Init` writes and the title screen runs under.
const LCDC_DEFAULT: int = LCDC_ON | LCDC_WIN_MAP | LCDC_WINDOW | LCDC_OBJS | LCDC_BG

const OAM_PRIO: int = 1 << 7
const OAM_YFLIP: int = 1 << 6
const OAM_XFLIP: int = 1 << 5
const OAM_PAL1: int = 1 << 4

## Per-pixel colour indices, one byte each, tile after tile.
var tiles: PackedByteArray = PackedByteArray()
## `vBGMap0` and `vBGMap1`.
var maps: Array[PackedByteArray] = []
var oam: PackedByteArray = PackedByteArray()
var lcdc: int = LCDC_DEFAULT
var scx: int = 0
var scy: int = 0
var wy: int = 0
var wx: int = WINDOW_X_OFFSET
var bgp: int = 0
var obp0: int = 0
var obp1: int = 0
## A scroll register per scanline, -1 leaving the register alone.
var line_scx: PackedInt32Array = PackedInt32Array()
var line_scy: PackedInt32Array = PackedInt32Array()
## Lines an override lands late: 0 from an `rLY` poll, 1 from the `LCD` interrupt.
var line_lag: int = 0


func _init() -> void:
	tiles.resize(TILE_COUNT * TILE_PIXELS)
	var map0 := PackedByteArray()
	map0.resize(MAP_BYTES)
	var map1 := PackedByteArray()
	map1.resize(MAP_BYTES)
	maps = [map0, map1]
	oam.resize(OAM_SLOTS * OAM_BYTES)


func clear_vram() -> void:
	tiles.fill(0)
	maps[0].fill(0)
	maps[1].fill(0)


func clear_oam() -> void:
	oam.fill(0)


## [param count] tiles of a decoded strip into VRAM from tile [param at].
func load_tiles(at: int, strip: PackedByteArray, strip_tiles: int, first: int, count: int) -> void:
	var stride: int = strip_tiles * TILE
	if strip_tiles <= 0 or strip.size() < strip_tiles * TILE_PIXELS:
		return
	for index: int in count:
		var tile: int = at + index
		var source: int = first + index
		if tile < 0 or tile >= TILE_COUNT or source < 0 or source >= strip_tiles:
			continue
		for row: int in TILE:
			var from: int = row * stride + source * TILE
			var to: int = tile * TILE_PIXELS + row * TILE
			for column: int in TILE:
				tiles[to + column] = strip[from + column]


## One tile of one colour, which Yellow's intro writes by hand.
func fill_tile(at: int, index: int) -> void:
	if at < 0 or at >= TILE_COUNT:
		return
	for pixel: int in TILE_PIXELS:
		tiles[at * TILE_PIXELS + pixel] = index


func write_map(which: int, at: Vector2i, columns: int, rows: int, ids: PackedByteArray) -> void:
	var map: PackedByteArray = maps[which]
	for row: int in rows:
		var y: int = at.y + row
		if y < 0 or y >= MAP_SIDE:
			continue
		for column: int in columns:
			var x: int = at.x + column
			var source: int = row * columns + column
			if x < 0 or x >= MAP_SIDE or source >= ids.size():
				continue
			map[y * MAP_SIDE + x] = ids[source]


func fill_map(which: int, id: int) -> void:
	maps[which].fill(id)


func set_sprite(slot: int, y: int, x: int, tile: int, attributes: int) -> void:
	if slot < 0 or slot >= OAM_SLOTS:
		return
	var at: int = slot * OAM_BYTES
	oam[at] = y & 0xFF
	oam[at + 1] = x & 0xFF
	oam[at + 2] = tile & 0xFF
	oam[at + 3] = attributes & 0xFF


func sprite(slot: int) -> Dictionary:
	var at: int = slot * OAM_BYTES
	return {"y": oam[at], "x": oam[at + 1], "tile": oam[at + 2], "attributes": oam[at + 3]}


## The forty slots as `{ y, x, tile, attributes }`.
func shadow_oam() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for slot: int in OAM_SLOTS:
		out.append(sprite(slot))
	return out


## The screen as DMG shades, a byte a pixel; an LCD that is off is white.
func render() -> PackedByteArray:
	var shades := PackedByteArray()
	shades.resize(WIDTH * HEIGHT)
	if lcdc & LCDC_ON == 0:
		return shades
	var background := PackedByteArray()
	background.resize(WIDTH * HEIGHT)
	var bg_shades: PackedByteArray = _palette_shades(bgp)
	var window_line: int = 0
	for y: int in HEIGHT:
		var row: int = y * WIDTH
		var line_x: int = _line_value(line_scx, y - line_lag, scx)
		var line_y: int = _line_value(line_scy, y - line_lag, scy)
		if lcdc & LCDC_BG:
			_render_map_line(background, row, _bg_map(), line_x, line_y + y)
		if lcdc & LCDC_WINDOW and y >= wy and wx - WINDOW_X_OFFSET < WIDTH:
			_render_window_line(background, row, window_line)
			window_line += 1
		for x: int in WIDTH:
			shades[row + x] = bg_shades[background[row + x]]
	if lcdc & LCDC_OBJS:
		_render_objects(shades, background)
	return shades


## The override a line is drawn with, or the register when none stands.
static func _line_value(overrides: PackedInt32Array, line: int, register: int) -> int:
	if line < 0 or line >= overrides.size() or overrides[line] < 0:
		return register
	return overrides[line]


func _bg_map() -> PackedByteArray:
	return maps[1] if lcdc & LCDC_BG_MAP else maps[0]


func _window_map() -> PackedByteArray:
	return maps[1] if lcdc & LCDC_WIN_MAP else maps[0]


## One background line, wrapping the map both ways.
func _render_map_line(
	target: PackedByteArray, row: int, map: PackedByteArray, from_x: int, map_y: int
) -> void:
	var y: int = map_y & 0xFF
	var map_row: int = (y >> 3) * MAP_SIDE
	var tile_row: int = (y & 7) * TILE
	var x: int = 0
	while x < WIDTH:
		var map_x: int = (from_x + x) & 0xFF
		var tile: int = _bg_tile(map[map_row + (map_x >> 3)]) * TILE_PIXELS + tile_row
		var column: int = map_x & 7
		while column < TILE and x < WIDTH:
			target[row + x] = tiles[tile + column]
			column += 1
			x += 1


func _render_window_line(target: PackedByteArray, row: int, window_line: int) -> void:
	var map: PackedByteArray = _window_map()
	var map_row: int = ((window_line >> 3) & (MAP_SIDE - 1)) * MAP_SIDE
	var tile_row: int = (window_line & 7) * TILE
	var left: int = wx - WINDOW_X_OFFSET
	var x: int = maxi(left, 0)
	while x < WIDTH:
		var window_x: int = x - left
		var tile: int = _bg_tile(map[map_row + ((window_x >> 3) & (MAP_SIDE - 1))]) \
			* TILE_PIXELS + tile_row
		target[row + x] = tiles[tile + (window_x & 7)]
		x += 1


func _bg_tile(id: int) -> int:
	if lcdc & LCDC_BLOCKS:
		return id
	return id if id >= BLOCK_TILES else SIGNED_BASE + id


## Ten objects a line in OAM order, the lowest X in front, `OAM_PRIO` behind
## any background colour but 0.
func _render_objects(shades: PackedByteArray, background: PackedByteArray) -> void:
	var palettes: Array[PackedByteArray] = [_palette_shades(obp0), _palette_shades(obp1)]
	for y: int in HEIGHT:
		var line: Array[int] = _objects_on_line(y)
		var taken := PackedByteArray()
		taken.resize(WIDTH)
		for slot: int in line:
			_render_object_line(shades, background, taken, slot, y, palettes)


func _objects_on_line(y: int) -> Array[int]:
	var found: Array[int] = []
	for slot: int in OAM_SLOTS:
		var top: int = oam[slot * OAM_BYTES] - OAM_Y_OFFSET
		if y >= top and y < top + TILE:
			found.append(slot)
			if found.size() == SPRITES_PER_LINE:
				break
	found.sort_custom(func(a: int, b: int) -> bool:
		var ax: int = oam[a * OAM_BYTES + 1]
		var bx: int = oam[b * OAM_BYTES + 1]
		return ax < bx if ax != bx else a < b
	)
	return found


func _render_object_line(
	shades: PackedByteArray, background: PackedByteArray, taken: PackedByteArray,
	slot: int, y: int, palettes: Array[PackedByteArray]
) -> void:
	var at: int = slot * OAM_BYTES
	var left: int = oam[at + 1] - OAM_X_OFFSET
	var attributes: int = oam[at + 3]
	var tile_row: int = y - (oam[at] - OAM_Y_OFFSET)
	if attributes & OAM_YFLIP:
		tile_row = TILE - 1 - tile_row
	var tile: int = oam[at + 2] * TILE_PIXELS + tile_row * TILE
	var palette: PackedByteArray = palettes[1 if attributes & OAM_PAL1 else 0]
	var behind: bool = attributes & OAM_PRIO != 0
	var row: int = y * WIDTH
	for column: int in TILE:
		var x: int = left + column
		if x < 0 or x >= WIDTH or taken[x] != 0:
			continue
		var index: int = tiles[
			tile + ((TILE - 1 - column) if attributes & OAM_XFLIP else column)
		]
		if index == 0:
			continue
		taken[x] = 1
		if behind and background[row + x] != 0:
			continue
		shades[row + x] = palette[index]


static func _palette_shades(byte: int) -> PackedByteArray:
	var out := PackedByteArray()
	for index: int in 4:
		out.append((byte >> (index * 2)) & 3)
	return out
