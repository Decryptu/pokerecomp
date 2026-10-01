class_name Gen2WorldServicePage
extends RefCounted

## The cartridge-sized menus hosted by the overworld service dispatcher. The
## caller supplies the imported rows; this page owns only MenuTextbox geometry.

const TILE: int = Gen2Font.TILE
const MESSAGE_BOX := Rect2i(0, 12, 20, 6)
## A backdrop layer that blanks the screen, as `ClearPCItemScreen` and
## `BillsPC_ClearTilemap` do. Without one the layers stand over the map.
const CLEAR_SCREEN: Dictionary = {"clear": true}

var font: Gen2Font = null
var menu: Gen2MenuPage = null
## `PokeballTileGraphics`' first tile, which `BillsPCMenu` copies to `$78` and
## `DisplayChangeBoxMenu` puts beside a box that is not empty. Null on a cache
## with no such sheet, which is every Generation 2 one.
var ball: Image = null
## Four box colours, black on white when empty: a Pokegear call's are the card's.
var palette: PackedColorArray = PackedColorArray()


static func from_data(data: GameData) -> Gen2WorldServicePage:
	var out := Gen2WorldServicePage.new()
	out.font = Gen2Font.from_data(data)
	out.menu = Gen2MenuPage.from_data(data)
	out.ball = _ball_tile(data)
	return out if out.font != null and out.menu != null else null


static func _ball_tile(data: GameData) -> Image:
	var sheet: Dictionary = data.tile_sheet("battle_balls")
	var indices: PackedByteArray = data.tile_indices("battle_balls")
	if sheet.is_empty() or indices.is_empty():
		return null
	var strip: Image = Gen2PicImage.from_indices(
		indices, int(sheet.get("width", 0)), PokeTiles.TILE_HEIGHT,
		PokePalette.pic_palette(PackedColorArray([Color.WHITE, Color.BLACK]))
	)
	return null if strip == null else strip.get_region(
		Rect2i(0, 0, PokeTiles.TILE_WIDTH, PokeTiles.TILE_HEIGHT)
	)


## `MenuTextbox` over the map and the windows [param backdrop] stacks in order:
## [constant CLEAR_SCREEN], notes and `{menu, rows, cursor, extras}` menus, arrow
## hollow. Empty [param rows] draws no box. [param message] is a string or a
## printing [Gen2TextBox]; [param note] is `{rect, lines}`, each line `{text, at}`
## from its own corner; [param message_box] is [constant MESSAGE_BOX] but for
## `_ChangeBox`'s `hlcoord 0, 14`; [param marks] are pokeball tiles on the menu.
func render(title: String, prompt: String, rows: Array, cursor: int,
		message: Variant = "", box: Gen2MenuBox = null,
		note: Dictionary = {}, message_box: Rect2i = MESSAGE_BOX,
		marks: Array = [], backdrop: Array = []) -> Image:
	var image := Image.create_empty(
		Gen2Screen.WIDTH, Gen2Screen.HEIGHT, false, Image.FORMAT_RGBA8
	)
	for layer: Dictionary in backdrop:
		if layer.has("clear"):
			image.fill(_colors()[0])
		elif layer.has("menu"):
			var under: Gen2MenuBox = layer["menu"]
			_blit(image, menu.render(
				under, layer["rows"], int(layer["cursor"]), "", 0, layer.get("extras", []),
				palette, bool(layer.get("hollow", true))
			), under.border_position())
		else:
			_draw_note(image, layer)
	var over: bool = box != null and box.over_textbox
	if not over:
		_draw_menu(image, rows, cursor, box, marks)
	var printing: Gen2TextBox = message as Gen2TextBox if message is Gen2TextBox else null
	var words: String = "" if printing != null else String(message)
	for fallback: String in [prompt, title]:
		if words.is_empty() and printing == null:
			words = fallback
	if printing != null or not words.is_empty():
		var indices := PackedByteArray()
		indices.resize(Gen2Screen.WIDTH * message_box.size.y * TILE)
		if printing != null:
			printing.compose(indices, Gen2Screen.WIDTH, Vector2i.ZERO)
		else:
			_draw_message(indices, words, message_box)
		var part: Image = Gen2PicImage.from_indices(
			indices, Gen2Screen.WIDTH, message_box.size.y * TILE, _colors()
		)
		image.blit_rect(
			part, Rect2i(Vector2i.ZERO, part.get_size()), message_box.position * TILE
		)
	## `BillsPCMenu` puts its BOX No. panel over the speech box's right half.
	if over:
		_draw_menu(image, rows, cursor, box, marks)
	if not note.is_empty():
		_draw_note(image, note)
	return image


## `PrintPCBox_Page1` with no printer: `PlacePrinterStatusString`'s box covers
## rows 5 to 16, leaving the border and `#MON LIST` around it.
func render_box_print(status: String) -> Image:
	var width: int = Gen2Screen.WIDTH
	var indices := PackedByteArray()
	indices.resize(width * Gen2Screen.HEIGHT)
	var style: int = Gen2OptionsStore.current().textbox_frame
	for column: int in Gen2PCBoxPage.COLUMNS:
		var code: int = Gen2Layout.FRAME_TOP_LEFT if column == 0 \
			else Gen2Layout.FRAME_TOP_RIGHT if column == Gen2PCBoxPage.COLUMNS - 1 \
			else Gen2Layout.FRAME_HORIZONTAL
		font.draw_frame_code(style, Gen2Layout.FRAME_FIRST_CODE + code, indices, width,
			column * TILE, 0)
	for row: int in range(1, Gen2PCBoxPage.ROWS):
		for column: int in [0, Gen2PCBoxPage.COLUMNS - 1]:
			font.draw_frame_code(style, Gen2Layout.FRAME_FIRST_CODE + Gen2Layout.FRAME_VERTICAL,
				indices, width, column * TILE, row * TILE)
	font.draw_text("#MON LIST", indices, width, 4 * TILE, 3 * TILE)
	var at: Vector2i = Gen2DiplomaPage.STATUS_BOX_AT
	font.draw_box(style, indices, width, at.x * TILE, at.y * TILE,
		Gen2DiplomaPage.STATUS_BOX_SIZE.x, Gen2DiplomaPage.STATUS_BOX_SIZE.y)
	var line: int = 0
	for row: String in status.split("\n"):
		var text_at: Vector2i = Gen2DiplomaPage.STATUS_TEXT_AT + Vector2i(0, line)
		font.draw_text(row, indices, width, text_at.x * TILE, text_at.y * TILE)
		line += 1
	var cancel: Vector2i = Gen2DiplomaPage.CANCEL_AT
	font.draw_text(Gen2DiplomaPage.CANCEL_STRING, indices, width, cancel.x * TILE, cancel.y * TILE)
	return Gen2PicImage.from_indices(indices, width, Gen2Screen.HEIGHT, _colors())


## A printed box left standing under the windows a routine opened after it, as
## a backdrop note: the first page of [param words], laid out as a message is.
static func textbox_note(words: String, message_box: Rect2i = MESSAGE_BOX) -> Dictionary:
	var text_rows: int = (message_box.size.y - 2) / 2
	var pages: Array = Gen2TextLayout.lay_out(words, message_box.size.x - 2, text_rows)
	var lines: PackedStringArray = pages[0] if not pages.is_empty() else PackedStringArray()
	var placed: Array = []
	for row: int in mini(text_rows, lines.size()):
		placed.append({"text": lines[row], "at": Vector2i(1, 2 + row * 2)})
	return {"rect": message_box, "lines": placed}


func _draw_message(indices: PackedByteArray, words: String, message_box: Rect2i) -> void:
	font.draw_box(Gen2OptionsStore.current().textbox_frame, indices,
		Gen2Screen.WIDTH, 0, 0, message_box.size.x, message_box.size.y)
	for line: Dictionary in textbox_note(words, message_box)["lines"] as Array:
		var at: Vector2i = line["at"]
		font.draw_text(String(line["text"]), indices, Gen2Screen.WIDTH, at.x * TILE, at.y * TILE)


func _draw_menu(
	image: Image, rows: Array, cursor: int, box: Gen2MenuBox, marks: Array
) -> void:
	if not rows.is_empty() and box != null:
		_blit(image, menu.render(box, rows, cursor, "", 0, [], palette), box.border_position())
	for at: Vector2i in marks:
		_blit(image, ball, at)


func _draw_note(image: Image, note: Dictionary) -> void:
	var rect: Rect2i = note.get("rect", Rect2i())
	if rect.size.x <= 0 or rect.size.y <= 0:
		return
	var width: int = rect.size.x * TILE
	var indices := PackedByteArray()
	indices.resize(width * rect.size.y * TILE)
	font.draw_box(Gen2OptionsStore.current().textbox_frame, indices,
		width, 0, 0, rect.size.x, rect.size.y)
	for line: Dictionary in note.get("lines", []) as Array:
		var at: Vector2i = line.get("at", Vector2i.ZERO)
		font.draw_text(String(line.get("text", "")), indices, width, at.x * TILE, at.y * TILE)
	var part: Image = Gen2PicImage.from_indices(indices, width, rect.size.y * TILE, _colors())
	image.blit_rect(part, Rect2i(Vector2i.ZERO, part.get_size()), rect.position * TILE)


func _colors() -> PackedColorArray:
	return palette if palette.size() >= 4 \
		else PokePalette.pic_palette(PackedColorArray([Color.WHITE, Color.BLACK]))


func _blit(into: Image, part: Image, at: Vector2i) -> void:
	if part != null:
		into.blit_rect(part, Rect2i(Vector2i.ZERO, part.get_size()), at * TILE)
