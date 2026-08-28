class_name Gen2WorldServicePage
extends RefCounted

## The cartridge-sized menus hosted by the overworld service dispatcher. The
## caller supplies the imported rows; this page owns only MenuTextbox geometry.

const TILE: int = Gen2Font.TILE
const MESSAGE_BOX := Rect2i(0, 12, 20, 6)

var font: Gen2Font = null
var menu: Gen2MenuPage = null


static func from_data(data: GameData) -> Gen2WorldServicePage:
	var out := Gen2WorldServicePage.new()
	out.font = Gen2Font.from_data(data)
	out.menu = Gen2MenuPage.from_data(data)
	return out if out.font != null and out.menu != null else null


## `MenuTextbox` over the map: every box here carries `MENU_BACKUP_TILES`, so the
## map stays visible around it. Empty [param rows] draws no box at all.
##
## [param note] is the box beside the list, `{rect, lines}` with each line
## `{text, at}` from its own corner. [param message_box] is
## [constant MESSAGE_BOX] everywhere but `_ChangeBox`'s `hlcoord 0, 14`.
func render(title: String, prompt: String, rows: Array, cursor: int,
		message: String = "", box: Gen2MenuBox = null,
		note: Dictionary = {}, message_box: Rect2i = MESSAGE_BOX) -> Image:
	var image := Image.create_empty(
		Gen2Screen.WIDTH, Gen2Screen.HEIGHT, false, Image.FORMAT_RGBA8
	)
	if not rows.is_empty() and box != null:
		_blit(image, menu.render(box, rows, cursor), box.border_position())
	if not note.is_empty():
		_draw_note(image, note)
	var words: String = message if not message.is_empty() else prompt
	if words.is_empty():
		words = title
	if not words.is_empty():
		var text_rows: int = (message_box.size.y - 2) / 2
		var pages: Array = Gen2TextLayout.lay_out(words, message_box.size.x - 2, text_rows)
		var lines: PackedStringArray = pages[0] if not pages.is_empty() else PackedStringArray()
		var indices := PackedByteArray()
		indices.resize(Gen2Screen.WIDTH * message_box.size.y * TILE)
		font.draw_box(Gen2OptionsStore.current().textbox_frame, indices,
			Gen2Screen.WIDTH, 0, 0, message_box.size.x, message_box.size.y)
		for row: int in mini(text_rows, lines.size()):
			font.draw_text(lines[row], indices, Gen2Screen.WIDTH, TILE, (2 + row * 2) * TILE)
		var part: Image = Gen2PicImage.from_indices(
			indices, Gen2Screen.WIDTH, message_box.size.y * TILE,
			Gen2Palette.pic_palette(PackedColorArray([Color.WHITE, Color.BLACK]))
		)
		image.blit_rect(
			part, Rect2i(Vector2i.ZERO, part.get_size()), message_box.position * TILE
		)
	return image



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
	var part: Image = Gen2PicImage.from_indices(
		indices, width, rect.size.y * TILE,
		Gen2Palette.pic_palette(PackedColorArray([Color.WHITE, Color.BLACK]))
	)
	image.blit_rect(part, Rect2i(Vector2i.ZERO, part.get_size()), rect.position * TILE)

func _blit(into: Image, part: Image, at: Vector2i) -> void:
	if part != null:
		into.blit_rect(part, Rect2i(Vector2i.ZERO, part.get_size()), at * TILE)
