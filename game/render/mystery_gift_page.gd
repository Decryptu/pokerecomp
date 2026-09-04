class_name Gen2MysteryGiftPage
extends RefCounted

## `InitMysteryGiftLayout` and the boxes `DoMysteryGift` prints over it. Two
## screens under one name: Crystal builds its frame out of one sixty-seven tile
## run and colours it with two palettes, and Gold and Silver build theirs out of
## three runs and one palette. Neither has a stored tilemap, so the screen is the
## routine's own `hlcoord` writes transcribed rather than a map read out of the
## dump, and drawing is a walk over [constant CRYSTAL_LAYOUT] and
## [constant GS_LAYOUT]. Node-free.

const TILE: int = Gen2Font.TILE
const COLUMNS: int = 20
const ROWS: int = 18
const WIDTH: int = COLUMNS * TILE
const HEIGHT: int = ROWS * TILE

## `ClearBox`'s own fill, which is the blank the font already draws.
const BLANK_CODE: int = 0x7F

## The three shapes a `.Load*` helper writes. `gfx` steps the tile number and
## the other two repeat it, which is the difference between a run of art and a
## run of one border tile.
const RUN_GFX: StringName = &"gfx"
const RUN_ROW: StringName = &"row"
const RUN_COLUMN: StringName = &"column"

## `DoMysteryGift`'s own `hlcoord 3, 8`, a `PlaceString` straight into the box
## `InitMysteryGiftLayout` cleared in the middle.
const PROMPT_AT: Vector2i = Vector2i(3, 8)

## Every box the routine ends on goes through `PrintText`, which is
## `SpeechTextbox` over whatever is on screen and then `PrintTextboxTextAt` at
## its inner corner. `hlcoord 2, 8` a line above the jump is dead: `.LinkCanceled`
## and its seven neighbours load `hl` again before `PrintText` reads it.
const MESSAGE_BOX_AT: Vector2i = Vector2i(0, 12)
const MESSAGE_BOX_SIZE: Vector2i = Vector2i(20, 6)
const MESSAGE_AT: Vector2i = Vector2i(1, 14)
## `TEXTBOX_INNERW` and the two lines under `TEXTBOX_INNERY`, which is what a
## box shows before it waits to be advanced.
const MESSAGE_COLUMNS: int = 18
const MESSAGE_ROWS: int = 2

## `InitMysteryGiftLayout`, Crystal's: the screen fill, the box it clears in the
## middle, and then every write in the routine's order. A later row overwrites
## an earlier one, which is what the routine does too.
const CRYSTAL_LAYOUT: Dictionary = {
	"fill": 0x42,
	"clear": [Vector2i(3, 7), Vector2i(15, 9)],
	"runs": [
		[Vector2i(0, 0), 0x00, RUN_GFX, 2],
		[Vector2i(0, 1), 0x02, RUN_GFX, 2],
		[Vector2i(7, 1), 0x12, RUN_GFX, 5],
		[Vector2i(2, 2), 0x17, RUN_GFX, 16],
		[Vector2i(2, 3), 0x27, RUN_GFX, 16],
		[Vector2i(9, 4), 0x37, RUN_GFX, 2],
		[Vector2i(1, 2), 0x04, RUN_ROW, 1],
		[Vector2i(1, 3), 0x05, RUN_COLUMN, 14],
		[Vector2i(18, 5), 0x09, RUN_COLUMN, 11],
		[Vector2i(2, 5), 0x0B, RUN_ROW, 16],
		[Vector2i(2, 16), 0x07, RUN_ROW, 16],
		[Vector2i(2, 5), 0x0D, RUN_GFX, 5],
		[Vector2i(7, 5), 0x0C, RUN_ROW, 1],
		[Vector2i(18, 5), 0x0A, RUN_ROW, 1],
		[Vector2i(18, 16), 0x08, RUN_ROW, 1],
		[Vector2i(1, 16), 0x06, RUN_ROW, 1],
		[Vector2i(2, 6), 0x3A, RUN_ROW, 16],
		[Vector2i(2, 15), 0x40, RUN_ROW, 16],
		[Vector2i(2, 6), 0x3C, RUN_COLUMN, 9],
		[Vector2i(17, 6), 0x3E, RUN_COLUMN, 9],
		[Vector2i(2, 6), 0x39, RUN_ROW, 1],
		[Vector2i(17, 6), 0x3B, RUN_ROW, 1],
		[Vector2i(2, 15), 0x3F, RUN_ROW, 1],
		[Vector2i(17, 15), 0x41, RUN_ROW, 1],
	],
	## `_CGB_MysteryGift`'s own `FillBoxCGB` calls over a wiped attrmap: every
	## cell is palette 0 and these five boxes are palette 1.
	"attributes": [
		[Vector2i(3, 7), Vector2i(14, 8)],
		[Vector2i(1, 5), Vector2i(18, 1)],
		[Vector2i(1, 16), Vector2i(18, 1)],
		[Vector2i(0, 0), Vector2i(2, 17)],
		[Vector2i(18, 5), Vector2i(1, 12)],
	],
}

## The same routine at Gold and Silver's own tile numbers. Their art is three
## runs loaded into vTiles2 at $00, $20 and $2f, plus the solid tile the
## routine byte-fills at $3d, which the importer lays out as one strip in that
## order so a code here indexes it directly.
const GS_LAYOUT: Dictionary = {
	"fill": 0x3D,
	"clear": [Vector2i(3, 7), Vector2i(15, 9)],
	"runs": [
		[Vector2i(0, 0), 0x1E, RUN_GFX, 2],
		[Vector2i(0, 1), 0x33, RUN_GFX, 2],
		[Vector2i(3, 1), 0x00, RUN_GFX, 15],
		[Vector2i(3, 2), 0x0F, RUN_GFX, 15],
		[Vector2i(8, 0), 0x20, RUN_GFX, 4],
		[Vector2i(9, 3), 0x24, RUN_GFX, 3],
		[Vector2i(9, 4), 0x27, RUN_ROW, 1],
		[Vector2i(1, 2), 0x2E, RUN_COLUMN, 15],
		[Vector2i(18, 5), 0x2A, RUN_COLUMN, 11],
		[Vector2i(2, 5), 0x28, RUN_ROW, 16],
		[Vector2i(2, 16), 0x2C, RUN_ROW, 16],
		[Vector2i(2, 5), 0x35, RUN_GFX, 4],
		[Vector2i(18, 5), 0x29, RUN_ROW, 1],
		[Vector2i(18, 16), 0x2B, RUN_ROW, 1],
		[Vector2i(1, 16), 0x2D, RUN_ROW, 1],
		[Vector2i(2, 6), 0x39, RUN_ROW, 16],
		[Vector2i(2, 15), 0x3B, RUN_ROW, 16],
		[Vector2i(2, 6), 0x3C, RUN_COLUMN, 9],
		[Vector2i(17, 6), 0x3A, RUN_COLUMN, 9],
		[Vector2i(2, 6), 0x2F, RUN_ROW, 1],
		[Vector2i(17, 6), 0x30, RUN_ROW, 1],
		[Vector2i(2, 15), 0x32, RUN_ROW, 1],
		[Vector2i(17, 15), 0x31, RUN_ROW, 1],
	],
	## `GS_CGB_MysteryGift` copies one palette and wipes the attrmap, so every
	## cell is palette 0.
	"attributes": [],
}

var font: Gen2Font = null
var palette: PackedColorArray = PackedColorArray()
var prompt: String = ""

var _tiles: PackedByteArray = PackedByteArray()
var _tile_count: int = 0
var _layout: Dictionary = {}


static func from_data(data: GameData) -> Gen2MysteryGiftPage:
	if data == null or not data.has_mystery_gift():
		return null
	var page := Gen2MysteryGiftPage.new()
	page.font = Gen2Font.from_data(data)
	page.palette = data.mystery_gift_palette()
	page.prompt = data.mystery_gift_prompt()
	page._tiles = data.mystery_gift_indices()
	if page.font == null or page.palette.is_empty() or page._tiles.is_empty():
		return null
	page._tile_count = page._tiles.size() / (TILE * TILE)
	## Two palettes is Crystal's `_CGB_MysteryGift`; one is Gold and Silver's.
	page._layout = CRYSTAL_LAYOUT if page.palette.size() > 4 else GS_LAYOUT
	return page


## The tilemap the routine leaves behind, as one row-major array of codes.
func tilemap() -> PackedByteArray:
	var map := PackedByteArray()
	map.resize(COLUMNS * ROWS)
	map.fill(int(_layout["fill"]))
	var clear: Array = _layout["clear"] as Array
	_fill(map, clear[0], clear[1], BLANK_CODE)
	for run: Array in _layout["runs"] as Array:
		var at: Vector2i = run[0]
		var code: int = int(run[1])
		var count: int = int(run[3])
		for step: int in count:
			var cell: Vector2i = (
				at + Vector2i(0, step) if run[2] == RUN_COLUMN
				else at + Vector2i(step, 0)
			)
			if cell.x < 0 or cell.x >= COLUMNS or cell.y < 0 or cell.y >= ROWS:
				continue
			map[cell.y * COLUMNS + cell.x] = (
				(code + step) & 0xFF if run[2] == RUN_GFX else code
			)
	return map


## Which palette each cell takes, which is what `FillBoxCGB` writes into the
## attrmap. All zero on Gold and Silver, whose layout copies one palette.
func attributes() -> PackedByteArray:
	var attrs := PackedByteArray()
	attrs.resize(COLUMNS * ROWS)
	attrs.fill(0)
	for box: Array in _layout["attributes"] as Array:
		_fill(attrs, box[0], box[1], 1)
	return attrs


## The screen with [param text] in the box `DoMysteryGift` prints into. Empty
## text is the prompt the screen opens on, which is the routine's own
## `.String_PressAToLink_BToCancel` and is drawn one column further in.
func render(text: String = "") -> Image:
	var indices := PackedByteArray()
	indices.resize(WIDTH * HEIGHT)
	var map: PackedByteArray = tilemap()
	for cell: int in map.size():
		_blit(indices, int(map[cell]), Vector2i(cell % COLUMNS, cell / COLUMNS))
	if text.is_empty():
		var line: int = 0
		for row: String in prompt.split("\n"):
			font.draw_text(
				row, indices, WIDTH, PROMPT_AT.x * TILE, (PROMPT_AT.y + line) * TILE
			)
			line += 1
	else:
		_draw_message(indices, text)
	return _compose(indices)


## `PrintText`: `SpeechTextbox` is `Textbox`, which clears its own interior
## before drawing the border, so the frame under it does not show through.
func _draw_message(indices: PackedByteArray, text: String) -> void:
	for row: int in MESSAGE_BOX_SIZE.y * TILE:
		var start: int = (MESSAGE_BOX_AT.y * TILE + row) * WIDTH \
			+ MESSAGE_BOX_AT.x * TILE
		for column: int in MESSAGE_BOX_SIZE.x * TILE:
			indices[start + column] = 0
	font.draw_box(
		Gen2OptionsStore.current().textbox_frame, indices, WIDTH,
		MESSAGE_BOX_AT.x * TILE, MESSAGE_BOX_AT.y * TILE,
		MESSAGE_BOX_SIZE.x, MESSAGE_BOX_SIZE.y
	)
	var line: int = 0
	for row: String in text.split("\n"):
		font.draw_text(
			row, indices, WIDTH, MESSAGE_AT.x * TILE, (MESSAGE_AT.y + line) * TILE
		)
		line += 1


## The two palettes over one index buffer. A cell's attribute picks which four
## colours its pixels are read through, which is what the CGB does with the
## attrmap and what one call to [method Gen2PicImage.from_indices] cannot do.
func _compose(indices: PackedByteArray) -> Image:
	if palette.size() <= 4:
		return Gen2PicImage.from_indices(indices, WIDTH, HEIGHT, palette)
	var attrs: PackedByteArray = attributes()
	var image: Image = Image.create_empty(WIDTH, HEIGHT, false, Image.FORMAT_RGBA8)
	for y: int in HEIGHT:
		var row: int = (y / TILE) * COLUMNS
		for x: int in WIDTH:
			var bank: int = int(attrs[row + x / TILE]) * 4
			image.set_pixel(x, y, palette[bank + (indices[y * WIDTH + x] & 3)])
	return image


static func _fill(
	into: PackedByteArray, at: Vector2i, size: Vector2i, value: int
) -> void:
	for row: int in size.y:
		for column: int in size.x:
			var cell: Vector2i = at + Vector2i(column, row)
			if cell.x < 0 or cell.x >= COLUMNS or cell.y < 0 or cell.y >= ROWS:
				continue
			into[cell.y * COLUMNS + cell.x] = value


func _blit(into: PackedByteArray, code: int, at: Vector2i) -> void:
	if code >= Gen2Layout.FONT_FIRST_CODE or code >= _tile_count:
		font.draw_code(code, into, WIDTH, at.x * TILE, at.y * TILE)
		return
	Gen2Font.blit_slot(
		_tiles, _tile_count * TILE, code, into, WIDTH, at.x * TILE, at.y * TILE
	)
