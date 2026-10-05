class_name Gen2MailScreen
extends Control

## `ReadAnyMail` (`engine/pokemon/mail_2.asm`), embedded like the Hall of Fame
## viewer: `.loop` reads A, B and START and returns on the first two.
## [Gen2MailPage] owns the picture. START is `PrintMailAndExit`, the Game Boy
## Printer, which has no transport here: `MUSIC_PRINTER` and PRINTER_ERROR_2 until B,
## then the map's music. (The cartridge also reloads the map there; not copied.)

signal closed()
signal music_requested(index: int)
signal map_music_requested()

## The screen has no field of its own: `ClearBGPalettes` and `DisableLCD` run
## before the type's graphics are loaded, so the surround is the mail's own
## background colour once `LoadMailPalettes` has run.
var _data: GameData = null
var _mail: Gen2SaveMail = null
var _page: Gen2MailPage = null
var _background: TextureRect = null
var _font: Gen2Font = null
var _printing: bool = false


func set_context(data: GameData, mail: Gen2SaveMail) -> void:
	_data = data
	_mail = mail
	_page = Gen2MailPage.from_data(data)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	size = Vector2(Gen2Screen.WIDTH, Gen2Screen.HEIGHT)
	if _page == null or not _page.ready() or _mail == null:
		closed.emit()
		return
	_build()
	_refresh()


## `.loop`: A and B leave, START reaches the printer and comes back. Nothing
## else is read, so the d-pad does not close the screen.
func handle_button(button: int) -> bool:
	if _printing:
		if button == PokeButton.B:
			_printing = false
			map_music_requested.emit()
			_refresh()
		return true
	if button == PokeButton.A or button == PokeButton.B:
		closed.emit()
		return true
	if button == PokeButton.START and _start_printing():
		return true
	return button == PokeButton.START


func printing() -> bool:
	return _printing


func _start_printing() -> bool:
	if _data == null or _data.printer_status_string(Gen2DiplomaScreen.STATUS_CONNECTION_ERROR).is_empty():
		return false
	_printing = true
	music_requested.emit(Gen2DiplomaScreen.MUSIC_PRINTER)
	_refresh()
	return true


func _build() -> void:
	var colours: PackedColorArray = _colours()
	add_child(Gen2Screen.Field.create(
		colours[0] if colours.size() > 0 else Color.WHITE
	))

	_background = TextureRect.new()
	_background.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_background)


func _refresh() -> void:
	var indices: PackedByteArray = _page.draw(_mail)
	if _printing:
		_draw_printer_status(indices)
	Gen2PicImage.show(_background, Gen2PicImage.from_indices(
		indices, Gen2Screen.WIDTH, Gen2Screen.HEIGHT, _colours()
	))
	_background.size = Vector2(Gen2Screen.WIDTH, Gen2Screen.HEIGHT)


func _draw_printer_status(indices: PackedByteArray) -> void:
	if _font == null:
		_font = Gen2Font.from_data(_data)
	if _font != null:
		Gen2DiplomaPage.draw_status_box(
			_font, indices, Gen2Screen.WIDTH,
			_data.printer_status_string(Gen2DiplomaScreen.STATUS_CONNECTION_ERROR)
		)


## `LoadMailPalettes`, whole: this is the one screen in the project drawn
## through four cartridge colours rather than a white-to-black pair.
func _colours() -> PackedColorArray:
	if _data == null or _mail == null:
		return PokePalette.pic_palette(PackedColorArray([Color.WHITE, Color.BLACK]))
	return _data.mail_palette(Gen2MailPage.palette_index(_mail))
