class_name Gen2UnownPrinterPage
extends RefCounted

## `_UnownPrinter`, the ALPH RUINS STAMP browser, and the page `PrintUnownStamp`
## builds out of it: three `Textbox`es, three strings and one Unown frontpic. The
## menu's PRINT and CANCEL rows are printed as the two gender signs because
## `Request1bpp` has just overwritten those font tiles with a bold A and a bold B,
## so the two codes are drawn from `UnownDexATile` rather than from the font.
## Node-free: the image is the whole product.

const TILE: int = Gen2Font.TILE
const COLUMNS: int = 20
const ROWS: int = 18
const WIDTH: int = COLUMNS * TILE
const HEIGHT: int = ROWS * TILE

## The routine's own three boxes, as `Textbox` takes them: the top coordinate
## and the interior's rows and columns, which frame two more of each.
const BOXES: Array[Array] = [
	[Vector2i(0, 0), Vector2i(18, 3)],
	[Vector2i(0, 5), Vector2i(7, 7)],
	[Vector2i(0, 14), Vector2i(18, 2)],
]
const TITLE_AT: Vector2i = Vector2i(1, 2)
const TITLE: String = " ALPH RUINS STAMP"
const PROMPT_AT: Vector2i = Vector2i(1, 16)
const PROMPT: String = "Do what?"
const MENU_AT: Vector2i = Vector2i(10, 6)
const MENU: Array[String] = ["♂ PRINT", "♀ CANCEL", "← PREVIOUS", "→ NEXT"]
## `hlcoord 1, 6` with `lb bc, 7, 7`, and `UnownDexVacantString` in the middle of
## the same block when the browser is on the empty slot.
const PIC_AT: Vector2i = Vector2i(1, 6)
const VACANT_AT: Vector2i = Vector2i(1, 9)
const VACANT: String = "VACANT"
## `PlaceUnownPrinterFrontpic`: the whole screen blanked and the rotated stamp
## at `hlcoord 7, 11`.
const STAMP_AT: Vector2i = Vector2i(7, 11)
## `NUM_UNOWN`, and the slot past the last letter, which is the vacant one.
const LETTERS: int = 26
const SLOTS: int = LETTERS + 1

## `UNOWNSTAMP_BOLD_A` and `UNOWNSTAMP_BOLD_B`, the two codes the glyphs are
## requested into.
const BOLD_CODES: Array[int] = [0xEF, 0xF5]

var font: Gen2Font = null
var palette: PackedColorArray = PackedColorArray()

var _data: GameData = null
var _glyphs: PackedByteArray = PackedByteArray()


static func from_data(data: GameData) -> Gen2UnownPrinterPage:
	if data == null:
		return null
	var page := Gen2UnownPrinterPage.new()
	page.font = Gen2Font.from_data(data)
	page.palette = data.palette(RomLayout.UNOWN_SPECIES, false)
	page._data = data
	page._glyphs = data.tile_indices("unown_printer_glyphs")
	if page.font == null or page.palette.size() < 4 or page._glyphs.is_empty():
		return null
	return page


## The browser on [param slot], which is a letter under [constant LETTERS] and
## the vacant page at it.
func render(slot: int) -> Image:
	var indices := PackedByteArray()
	indices.resize(WIDTH * HEIGHT)
	for box: Array in BOXES:
		_box(indices, box[0], box[1])
	_text(indices, TITLE, TITLE_AT)
	_text(indices, PROMPT, PROMPT_AT)
	for row: int in MENU.size():
		_text(indices, MENU[row], MENU_AT + Vector2i(0, row * 2))
	if slot >= LETTERS:
		_text(indices, VACANT, VACANT_AT)
		return Gen2PicImage.from_indices(indices, WIDTH, HEIGHT, palette)
	var image: Image = Gen2PicImage.from_indices(indices, WIDTH, HEIGHT, palette)
	_blend_pic(image, slot, PIC_AT, false)
	return image


## `PlaceUnownPrinterFrontpic`, which is what the printer is sent: the screen
## blanked and the stamp rotated a quarter turn clockwise. `RotateUnownFrontpic`
## does that twice over, once per tile with `.Rotate`'s bit walk and once over
## the 7x7 block with `UnownPrinter_GBPrinterRectangle`, which together are one
## rotation of the whole picture.
func render_stamp(slot: int) -> Image:
	var indices := PackedByteArray()
	indices.resize(WIDTH * HEIGHT)
	var image: Image = Gen2PicImage.from_indices(indices, WIDTH, HEIGHT, palette)
	if slot < LETTERS:
		_blend_pic(image, slot, STAMP_AT, true)
	return image


## `PlacePrinterStatusString`, the same box the diploma's printing loop stands
## under, drawn over whatever page is up.
func draw_status(image: Image, status: String) -> void:
	var indices := PackedByteArray()
	indices.resize(WIDTH * HEIGHT)
	_box(
		indices, Gen2DiplomaPage.STATUS_BOX_AT,
		Gen2DiplomaPage.STATUS_BOX_SIZE - Vector2i(2, 2)
	)
	var line: int = 0
	for row: String in status.split("\n"):
		_text(indices, row, Gen2DiplomaPage.STATUS_TEXT_AT + Vector2i(0, line))
		line += 1
	_text(indices, Gen2DiplomaPage.CANCEL_STRING, Gen2DiplomaPage.CANCEL_AT)
	var box: Image = Gen2PicImage.from_indices(indices, WIDTH, HEIGHT, palette)
	var region := Rect2i(
		Gen2DiplomaPage.STATUS_BOX_AT * TILE, Gen2DiplomaPage.STATUS_BOX_SIZE * TILE
	)
	image.blit_rect(
		box.get_region(region), Rect2i(Vector2i.ZERO, region.size), region.position
	)


func _blend_pic(image: Image, slot: int, at: Vector2i, rotated: bool) -> void:
	var pic: Dictionary = _data.unown_pic(slot)
	if pic.is_empty():
		return
	var cell: Dictionary = Gen2PicImage.atlas_cell(
		_data.atlas_indices(pic["atlas"]), _data.atlas(pic["atlas"]), pic
	)
	if cell.is_empty():
		return
	var width: int = int(cell["width"])
	var height: int = int(cell["height"])
	var pixels: PackedByteArray = cell["indices"]
	if rotated:
		pixels = _rotated(pixels, width, height)
		var swapped: int = width
		width = height
		height = swapped
	image.blend_rect(
		Gen2PicImage.from_indices(pixels, width, height, palette),
		Rect2i(Vector2i.ZERO, Vector2i(width, height)), at * TILE
	)


## A quarter turn clockwise: `dest(row, column) = source(height - 1 - column, row)`,
## which is what `.Rotate`'s own bit walk does inside a tile and what the
## rectangle table does to the tiles.
static func _rotated(pixels: PackedByteArray, width: int, height: int) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(width * height)
	for row: int in width:
		for column: int in height:
			out[row * height + column] = pixels[(height - 1 - column) * width + row]
	return out


## `Textbox`: the frame is two cells wider and taller than the interior it is
## given, and the interior is cleared before it is drawn.
func _box(indices: PackedByteArray, at: Vector2i, interior: Vector2i) -> void:
	font.draw_box(
		Gen2OptionsStore.current().textbox_frame, indices, WIDTH,
		at.x * TILE, at.y * TILE, interior.x + 2, interior.y + 2
	)


func _text(indices: PackedByteArray, text: String, at: Vector2i) -> void:
	var x: int = at.x * TILE
	for code: int in Gen2Text.encode(text):
		if code == Gen2Text.TERMINATOR:
			break
		if BOLD_CODES.has(code):
			Gen2Font.blit_slot(
				_glyphs, RomLayout.UNOWN_PRINTER_GLYPH_TILES * TILE,
				BOLD_CODES.find(code), indices, WIDTH, x, at.y * TILE
			)
		else:
			font.draw_code(code, indices, WIDTH, x, at.y * TILE)
		x += TILE
