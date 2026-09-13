class_name Gen1OpeningPage
extends RefCounted

## A Generation 1 opening's frame in colour: [Gen1Lcd]'s shades through the
## `ATTR_BLK` palette of the cell each pixel sits in, objects and all.

const CELLS_ACROSS: int = Gen1Lcd.WIDTH / Gen1Lcd.TILE
const CELLS_DOWN: int = Gen1Lcd.HEIGHT / Gen1Lcd.TILE
const ATTR_INSIDE: int = 1 << 0
const ATTR_LINE: int = 1 << 1
const ATTR_OUTSIDE: int = 1 << 2
const ATTR_PALETTE_BITS: int = 2
const ATTR_PALETTE_MASK: int = 3
const SHADES: int = 4
## The greys a Game Boy draws on its own.
const DMG_SHADES: PackedColorArray = [
	Color8(255, 255, 255), Color8(153, 153, 153), Color8(85, 85, 85), Color8(0, 0, 0),
]

var _data: GameData = null


## Null on a cache with no opening.
static func from_data(data: GameData) -> Gen1OpeningPage:
	if data == null or data.generation != RomRegistry.GEN1 or data.opening().is_empty():
		return null
	var out := Gen1OpeningPage.new()
	out._data = data
	return out


## The whole 160x144 screen for the frame [param opening] is on.
func draw(opening: Gen1Opening) -> Image:
	var shades: PackedByteArray = opening.lcd.render()
	var attributes: PackedByteArray = attribute_map(opening.blocks())
	var tables: Array[PackedInt32Array] = []
	for palette: Variant in opening.palettes():
		var colors := PackedColorArray()
		for packed: Variant in palette as Array:
			colors.append(PokePalette.from_packed(int(packed)))
		tables.append(Gen2PicImage.lookup(colors))
	while tables.size() < SHADES:
		tables.append(Gen2PicImage.lookup(DMG_SHADES))
	var pixels: PackedInt32Array = Gen2PicImage.canvas(Gen1Lcd.WIDTH, Gen1Lcd.HEIGHT)
	for y: int in Gen1Lcd.HEIGHT:
		var row: int = y * Gen1Lcd.WIDTH
		var cell_row: int = (y / Gen1Lcd.TILE) * CELLS_ACROSS
		for x: int in Gen1Lcd.WIDTH:
			var table: PackedInt32Array = tables[attributes[cell_row + x / Gen1Lcd.TILE]]
			pixels[row + x] = table[shades[row + x]]
	return Gen2PicImage.canvas_image(pixels, Gen1Lcd.WIDTH, Gen1Lcd.HEIGHT)


## The frame in the Game Boy's own greys, which a pixel diff compares.
func draw_shades(opening: Gen1Opening) -> Image:
	var shades: PackedByteArray = opening.lcd.render()
	return Gen2PicImage.from_indices(shades, Gen1Lcd.WIDTH, Gen1Lcd.HEIGHT, DMG_SHADES)


## `ATTR_BLK`'s rows onto the 20x18 cells: inside, line and outside as the
## control bits say, a lone inside or outside taking the line with it.
static func attribute_map(blocks: Array) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(CELLS_ACROSS * CELLS_DOWN)
	for block: Variant in blocks:
		var row: Array = block
		if row.size() < 6:
			continue
		var control: int = int(row[0])
		var palettes: int = int(row[1])
		var line_region: int = 1
		if control == ATTR_INSIDE or control == ATTR_OUTSIDE:
			line_region = 0 if control == ATTR_INSIDE else 2
			control |= ATTR_LINE
		for cell: int in out.size():
			var region: int = _region(cell % CELLS_ACROSS, cell / CELLS_ACROSS, row)
			if control & (1 << region) == 0:
				continue
			if region == 1:
				region = line_region
			out[cell] = (palettes >> (region * ATTR_PALETTE_BITS)) & ATTR_PALETTE_MASK
	return out


## 0 inside the box `row` spans, 1 on its line, 2 outside it.
static func _region(x: int, y: int, row: Array) -> int:
	if x < int(row[2]) or x > int(row[4]) or y < int(row[3]) or y > int(row[5]):
		return 2
	if x > int(row[2]) and x < int(row[4]) and y > int(row[3]) and y < int(row[5]):
		return 0
	return 1
